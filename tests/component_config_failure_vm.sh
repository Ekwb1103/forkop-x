#!/bin/sh
# Existing VMware VM only. Real startup rejection and UI recovery; no package IO.
set -eu
[ "${FORKOP_TEST_VM:-}" = 1 ] || { echo 'FORKOP_TEST_VM=1 required' >&2; exit 1; }
ubus call system board | grep -qi VMware || { echo 'VMware VM required' >&2; exit 1; }
sing-box version | head -n 1 | grep -q rust-x || { echo 'Rust X baseline required' >&2; exit 1; }
source_action=${1:?candidate action.uc required}
work=$(mktemp -d /tmp/forkop-config-failure-vm.XXXXXX)
export work
umask 077
echo "Evidence: $work"
cp -p /etc/config/forkop "$work/forkop.before"
cp -p /etc/config/sing-box "$work/sing-box.before"
sha256sum /usr/bin/sing-box > "$work/core.before.sha256"
apk list --installed > "$work/packages.before"
forkop get_ui_state > "$work/ui.before.json"
ucode -e 'let fs=require("fs"); let s=json(fs.readfile(getenv("work")+"/ui.before.json"));
assert(s.service.forkop.running == 1, "running baseline required");
for(let kind in ["service","component"]) for(let a in s.actions[kind]) assert(a.running !== true,"active operation");'
changed=0
restore() {
    if [ "$changed" = 1 ]; then
        cp -p "$work/forkop.before" /etc/config/forkop
        cp -p "$work/sing-box.before" /etc/config/sing-box
        /etc/init.d/forkop start > "$work/emergency-restore.log" 2>&1 || true
    fi
}
trap restore EXIT
trap 'exit 1' HUP INT TERM
mkdir -p "$work/lib"
for entry in /usr/lib/forkop/*; do
    case "$entry" in
        */components) cp -R "$entry" "$work/lib/" ;;
        *) ln -s "$entry" "$work/lib/" ;;
    esac
done
cp "$source_action" "$work/lib/components/action.uc"
# Exercise the real async component worker, response, lock cleanup and UI state.
# Only package dispatch is replaced in this private copy; it calls the actual
# readiness wait after the VM's real lifecycle has rejected the configuration.
ucode -e 'let fs=require("fs"); let p=getenv("work")+"/lib/components/action.uc";
let s=fs.readfile(p); let needle="    capture_forkop_running_state();\n\n    if (component";
assert(index(s,needle)>=0,"component dispatch boundary");
s=replace(s,needle,"    capture_forkop_running_state();\n"+
"    if (component == \"sing_box\" && action == \"install_rust_x\") {\n"+
"        forkop_was_running = true;\n"+
"        if (wait_forkop_running_after_sing_box_change())\n"+
"            action_success(component, action, \"unexpected readiness\");\n"+
"        action_fail(component, action, \"VM fixture: startup config rejected\");\n"+
"    }\n\n    if (component"); fs.writefile(p,s);'
changed=1
/etc/init.d/forkop stop > "$work/stop.log" 2>&1
uci set forkop.vm_rejected_trojan=section
uci set forkop.vm_rejected_trojan.enabled=1
uci set forkop.vm_rejected_trojan.action=connection
uci add_list 'forkop.vm_rejected_trojan.outbound_jsons={"type":"trojan","tag":"vm-trojan","server":"127.0.0.1","server_port":443,"password":"synthetic-vm-test","tls":{"enabled":true,"server_name":"localhost"}}'
uci commit forkop
/etc/init.d/forkop start > "$work/rejected-start.log" 2>&1 || true
for attempt in $(seq 1 30); do
    [ -s /var/run/forkop/start.failure ] && break
    sleep 1
done
[ -s /var/run/forkop/start.failure ] || { echo 'FAIL: startup failure marker absent'; exit 1; }
logread -e forkop > "$work/failure.log"
grep -q 'protocol "trojan" is excluded from Rust X' "$work/failure.log" || { echo 'FAIL: expected config rejection absent'; exit 1; }
echo 'PASS: real Rust X startup rejected unsupported Trojan configuration'
export FORKOP_LIB="$work/lib" UPDATES_JOB_DIR="$work/jobs" UPDATES_LOCK_DIR="$work/component.lock"
export FORKOP_UI_COMPONENT_ACTION_DIR="$work/jobs" FORKOP_UI_STATE_DIR="$work/ui"
export FORKOP_START_FAILURE_FILE=/var/run/forkop/start.failure
started=$(date +%s)
ucode -L "$FORKOP_LIB" "$FORKOP_LIB/components/updates.uc" component-action-async sing_box install_rust_x > "$work/job-start.json"
for attempt in $(seq 1 20); do
    if ucode -e 'let fs=require("fs");let paths=fs.glob(getenv("work")+"/jobs/*.json");
assert(length(paths)==1,"one component job");let a=json(fs.readfile(paths[0]));exit(a.running === false ? 0 : 1);'; then break; fi
    sleep 1
done
elapsed=$(( $(date +%s) - started ))
[ "$elapsed" -lt 20 ] || { echo 'FAIL: readiness wait did not fail promptly'; exit 1; }
ucode -L "$FORKOP_LIB" "$FORKOP_LIB/service/ui.uc" get-ui-state > "$work/ui.failed.json"
ucode -e 'let fs=require("fs");let s=json(fs.readfile(getenv("work")+"/ui.failed.json"));
assert(length(s.actions.component)==1,"component result retained");let a=s.actions.component[0];
assert(a.running === false && a.success === false,"terminal failure visible to LuCI");
assert(index(a.message,"startup config rejected")>=0,"failure reason retained");'
[ ! -d "$work/component.lock" ] || { echo 'FAIL: component lock leaked'; exit 1; }
echo "PASS: async component operation failed in ${elapsed}s; UI result terminal and lock released"
cp -p "$work/forkop.before" /etc/config/forkop
cp -p "$work/sing-box.before" /etc/config/sing-box
# Use the same tracked service-action backend invoked by LuCI's Start button.
ucode -L "$FORKOP_LIB" "$FORKOP_LIB/service/ui.uc" service-action-async start > "$work/start-action.json"
ucode -e 'let fs=require("fs");assert(json(fs.readfile(getenv("work")+"/start-action.json")).success === true,"Start allowed after failed component action");'
for attempt in $(seq 1 60); do
    forkop get_status > "$work/status.after.json"
    if ucode -e 'let fs=require("fs");let s=json(fs.readfile(getenv("work")+"/status.after.json"));exit(s.running==1 && s.dns_configured==1 ? 0 : 1);'; then break; fi
    sleep 1
done
ucode -L "$FORKOP_LIB" "$FORKOP_LIB/service/ui.uc" get-ui-state > "$work/ui.after.json"
ucode -e 'let fs=require("fs");let s=json(fs.readfile(getenv("work")+"/ui.after.json"));
assert(s.service.forkop.running==1 && s.service.forkop.dns_configured==1,"service and DNS recovered");
for(let kind in ["service","component"]) for(let a in s.actions[kind]) assert(a.running !== true,"UI no longer transitioning");'
nslookup example.com 127.0.0.1 > "$work/dns.after.txt" 2>&1
sha256sum -c "$work/core.before.sha256"
apk list --installed > "$work/packages.after"
cmp "$work/packages.before" "$work/packages.after"
cmp "$work/forkop.before" /etc/config/forkop
changed=0
echo 'PASS: Start accepted via LuCI backend; runtime and DNS recovered; core/packages/UCI preserved'
