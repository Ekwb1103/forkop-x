#!/bin/sh
# Run on an existing OpenWrt VM. Uses only a temporary core and loopback API;
# never changes installed services, packages, UCI, firewall or real subscriptions.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
export FORKOP_LIB="$ROOT/forkop/files/usr/lib"
CORE=${FORKOP_TEST_CORE:-/usr/lib/rust-x/sing-box}
export SB_CLASH_API_CONTROLLER_PORT=${FORKOP_TEST_API_PORT:-19091}
export WORK=$(mktemp -d /tmp/forkop-selector-test.XXXXXX)
export FORKOP_TEST_PERSISTENCE=${FORKOP_TEST_PERSISTENCE:-0}
export FORKOP_UCI_CONFIG_DIR="$WORK/uci"
export FORKOP_RUNTIME_STATE_DIR="$WORK/state"
cleanup() {
    sh "$WORK/control.sh" stop-managed-sing-box-runtime 2>/dev/null || true
    rm -rf "$WORK"
}
trap cleanup EXIT INT TERM
mkdir -p "$WORK/uci" "$WORK/state"
if curl -fsS --max-time 1 "http://127.0.0.1:$SB_CLASH_API_CONTROLLER_PORT/proxies" >/dev/null 2>&1; then
    echo 'Test API port already in use' >&2
    exit 1
fi
cat > "$WORK/uci/forkop" <<EOF
config settings 'settings'
    option config_path '$WORK/active.json'
    option enable_yacd_wan_access '0'
    option service_listen_address '127.0.0.1'
EOF
export CORE
cat > "$WORK/control.sh" <<'SH'
#!/bin/sh
set -eu
case "$1" in
sing-box-current-owned-service-runtime)
    test -f "$WORK/pid" && kill -0 "$(cat "$WORK/pid")" 2>/dev/null
    ;;
stop-managed-sing-box-runtime)
    if test -f "$WORK/pid"; then
        pid=$(cat "$WORK/pid")
        kill "$pid" 2>/dev/null || true
        for i in $(seq 1 10); do
            kill -0 "$pid" 2>/dev/null || break
            grep -q ') Z ' "/proc/$pid/stat" 2>/dev/null && break
            sleep 1
        done
        if kill -0 "$pid" 2>/dev/null; then kill -9 "$pid"; fi
        rm -f "$WORK/pid"
    fi
    ;;
start-managed-sing-box-runtime)
    "$CORE" run -c "$WORK/active.json" > "$WORK/core.log" 2>&1 &
    echo $! > "$WORK/pid"
    ;;
wait-managed-sing-box-config-listeners)
    for i in $(seq 1 15); do
        curl -fsS --max-time 1 "http://127.0.0.1:$SB_CLASH_API_CONTROLLER_PORT/proxies" >/dev/null 2>&1 && exit 0
        sleep 1
    done
    cat "$WORK/core.log" >&2
    exit 1
    ;;
*) exit 1 ;;
esac
SH
cat > "$WORK/make.uc" <<'UC'
let fs=require("fs"), work=getenv("WORK"), port=int(getenv("SB_CLASH_API_CONTROLLER_PORT"));
let config={outbounds:[{type:"direct",tag:"a"},{type:"direct",tag:"b"},
 {type:"selector",tag:"Youtube",outbounds:["a","b"],default:"a"},
 {type:"selector",tag:"DS",outbounds:["a","b"],default:"a"},
 {type:"selector",tag:"Proxy",outbounds:["a","b"],default:"a"}],
 route:{final:"Proxy"},experimental:{clash_api:{external_controller:"127.0.0.1:"+port}}};
if(getenv("FORKOP_TEST_PERSISTENCE")=="1")
 config.experimental.cache_file={enabled:true,path:work+"/cache.db"};
fs.writefile(work+"/active.json",sprintf("%J",config));
push(config.outbounds,{type:"direct",tag:"c"});
config.outbounds[4].outbounds=["a","b","c"];
fs.writefile(work+"/candidate.json",sprintf("%J",config));
UC
ucode "$WORK/make.uc"
{
cat <<'UC'
let fs=require("fs"),common=require("core.common");
let work=getenv("WORK"), LIB_DIR=getenv("FORKOP_LIB"), PRIORITY_UC="priority", DNS_FAILOVER_UC="dns";
let subscription_outbounds_changed=false, subscription_failure_detail=null, fail_init=false, clean=false;
function subscription_apply_failure(reason,state){subscription_failure_detail={reason,state};return false;}
function subscription_hot_transition(p){return {handled:false};}
let as_string=common.as_string;
function trim(v){return replace(as_string(v),/^[ \t\r\n]+|[ \t\r\n]+$/g,"");}
function shell_quote(v){return "'"+replace(as_string(v),"'","'\\''")+"'";}
function command_from_args(args){return join(" ",map(args,shell_quote));}
function command_success_from_args(args){return system(command_from_args(args))==0;}
function command_output_from_args(args){let p=fs.popen(command_from_args(args),"r");if(!p)return "";let out=p.read("all");return p.close()==0?out:"";}
function read_json_file(path){try{return json(fs.readfile(path));}catch(e){return null;}}
function option(s,k,f){return s[k]||f;}
function uci_settings(){return {config_path:work+"/active.json"};}
function current_proxy_outbounds_signature(p){return command_output_from_args(["sha256sum",p]);}
function subscription_prepare_cache_request(a,b,c){return {ok:true,updated:1,failed:0};}
function module_capture(args){return {status:0};}
function validation_failure_message(v){return "validation failed";}
function log_message(m,l){print(l+": "+m+"\n");}
function module_success(args){
 if(args[0]==PRIORITY_UC||args[0]==DNS_FAILOVER_UC)return true;
 return command_success_from_args(["ucode","-L",LIB_DIR,args[0],args[1],args[2]]);
}
function singbox_runtime_success(args){
 if(args[0]=="configure-service"||args[0]=="discard-config-stage"||args[0]=="publish-section-cache")return true;
 if(args[0]=="prepare-config-stage")return command_success_from_args(["cp",work+"/candidate.json",args[5]]);
 if(args[0]=="init-config")return !fail_init && command_success_from_args(["cp",work+"/candidate.json",work+"/active.json"]);
 if(args[0]=="restore-config-stage")return command_success_from_args(["cp",args[1],work+"/active.json"]);
 die("unexpected runtime action\n");
}
function service_state_success(args){return command_success_from_args(["sh",work+"/control.sh",args[0]]);}
function write_current_reload_state_clean(){clean=true;return true;}
function schedule_automatic_latency_test(s){return true;}
UC
sed -n '/^function subscription_restore_selectors(/,/^}/p' "$FORKOP_LIB/components/updates.uc"
sed -n '/^function subscription_restore_runtime(/,/^}/p' "$FORKOP_LIB/components/updates.uc"
sed -n '/^function subscription_config_value(/,/^}/p' "$FORKOP_LIB/components/updates.uc"
sed -n '/^function subscription_runtime_change_check(/,/^}/p' "$FORKOP_LIB/components/updates.uc"
sed -n '/^function subscription_update_common_locked(/,/^}/p' "$FORKOP_LIB/components/updates.uc"
cat <<'UC'
function control(action){if(!service_state_success([action]))die("core control failed: "+action+"\n");}
function choices(){return json(command_output_from_args(["curl","-fsS","http://127.0.0.1:"+getenv("SB_CLASH_API_CONTROLLER_PORT")+"/proxies"])).proxies;}
function choose_b(){for(let group in ["Youtube","DS","Proxy"]){if(!command_success_from_args(["curl","-fsS","-X","PUT","--data-raw",'{"name":"b"}',"http://127.0.0.1:"+getenv("SB_CLASH_API_CONTROLLER_PORT")+"/proxies/"+group]))die("select failed\n");}}
function expect(y,d,p){let groups=choices();if(groups.Youtube.now!=y||groups.DS.now!=d||groups.Proxy.now!=p)die("unexpected selector state: "+sprintf("%J",groups)+"\n");}
control("start-managed-sing-box-runtime");control("wait-managed-sing-box-config-listeners");
choose_b();expect("b","b","b");
control("stop-managed-sing-box-runtime");control("start-managed-sing-box-runtime");control("wait-managed-sing-box-config-listeners");
if(getenv("FORKOP_TEST_PERSISTENCE")=="1" && getenv("FORKOP_TEST_EXPECT_RESET")!="1"){
 expect("b","b","b");print("PASS: raw restart preserves cached manual choices\n");
 // An acknowledged choice must also survive abrupt termination.
 command_success_from_args(["kill","-9",trim(fs.readfile(work+"/pid"))]);
 control("stop-managed-sing-box-runtime");control("start-managed-sing-box-runtime");control("wait-managed-sing-box-config-listeners");
 expect("b","b","b");print("PASS: choices survive SIGKILL and a new process\n");
}else{
 expect("a","a","a");print("PASS: raw restart reproduces default reset\n");
}
choose_b();
if(!subscription_update_common_locked(true,"Proxy",0))die("changed update failed\n");
expect("b","b","b");print("PASS: Proxy change preserves all manual groups\n");
let pid=fs.readfile(work+"/pid");
if(!subscription_update_common_locked(true,"Proxy",0)||fs.readfile(work+"/pid")!=pid)die("unchanged update restarted core\n");
expect("b","b","b");print("PASS: identical subscription keeps PID and choices\n");
let candidate=read_json_file(work+"/candidate.json");candidate.outbounds[3].outbounds=["a"];
fs.writefile(work+"/candidate.json",sprintf("%J",candidate));
if(!subscription_update_common_locked(true,"Proxy",0))die("removed member update failed\n");
expect("b","a","b");print("PASS: removed member falls back; other groups preserved\n");
candidate.outbounds[4].outbounds=["a","c"];
fs.writefile(work+"/candidate.json",sprintf("%J",candidate));fail_init=true;clean=false;
if(subscription_update_common_locked(true,"Proxy",0)||clean)die("failed update accepted\n");
expect("b","a","b");print("PASS: rollback restores config and manual choices\n");
UC
} > "$WORK/check.uc"
ucode -L "$FORKOP_LIB" "$WORK/check.uc"
