#!/bin/sh
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
FORKOP_LIB="$ROOT/forkop/files/usr/lib"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Real libuci cursor, with both config and savedir confined to the test tree.
mkdir -p "$WORK/config" "$WORK/save"
FORKOP_UCI_CONFIG_DIR="$WORK/config" FORKOP_UCI_SAVE_DIR="$WORK/save" \
ucode -L "$FORKOP_LIB" -e '
let u=require("core.uci"), fs=require("fs");
if (!u.set_section("sing-box.main", "sing-box") || !u.set("sing-box.main.workdir", ARGV[0]+"/custom-workdir") || !u.commit("sing-box")) die("missing config creation failed\n");
let before=fs.readfile(ARGV[0]+"/config/sing-box");
if (!u.set_section("sing-box.other", "sing-box") || u.get("sing-box.main.workdir") != ARGV[0]+"/custom-workdir") die("existing settings overwritten\n");
if (fs.readfile(ARGV[0]+"/config/sing-box") != before) die("unexpected config overwrite\n");
if (u.set_section("../escape.main", "sing-box")) die("package traversal accepted\n");
fs.writefile(ARGV[0]+"/config/broken", "config \"unterminated\n");
if (u.set_section("broken.main", "sing-box")) die("invalid config replaced\n");
if (fs.readfile(ARGV[0]+"/config/broken") != "config \"unterminated\n") die("invalid config modified\n");
print("Real UCI clean-install checks passed\n");
' "$WORK"

# Exercise configure_service with a real isolated UCI package and a missing
# custom workdir. Service-control calls are disabled in the fixture.
{
cat <<'UC'
let fs=require("fs"), uci_core=require("core.uci");
const CONFIG_NAME="forkop";
function uci_settings(){return {config_path:ARGV[0]+"/config.json"};}
function uci_get_option(c,s,k){return uci_core.get(c+"."+s+"."+k);}
function uci_set_option(c,s,k,v){return uci_core.set(c+"."+s+"."+k,v);}
function uci_commit(c){return uci_core.commit(c);}
function ensure_sing_box_main_section(){return uci_core.exists("sing-box.main") || uci_core.set_section("sing-box.main","sing-box");}
function sing_box_compressed_marker_set(){return false;}
function ensure_dir(p){return fs.stat(p)!=null || fs.mkdir(p,0700);}
function option(s,k,f){return s[k]||f;}
function file_exists(p){return false;}
function log_message(m,l){}
UC
sed -n '/^function configure_service(/,/^}/p' "$FORKOP_LIB/singbox/runtime.uc"
cat <<'UC'
configure_service();
if(fs.stat(ARGV[0]+"/custom-workdir")?.type!="directory")die("custom workdir not created\n");
if(uci_core.get("sing-box.main.workdir")!=ARGV[0]+"/custom-workdir")die("custom workdir changed\n");
if(uci_core.get("sing-box.main.enabled")!="1" || uci_core.get("sing-box.main.conffile")!=ARGV[0]+"/config.json")die("service defaults missing\n");
print("Missing workdir configuration check passed\n");
UC
} > "$WORK/workdir.uc"
FORKOP_UCI_CONFIG_DIR="$WORK/config" FORKOP_UCI_SAVE_DIR="$WORK/save" \
 ucode -L "$FORKOP_LIB" "$WORK/workdir.uc" "$WORK"

ucode -L "$FORKOP_LIB" -e '
let h=require("core.runtime_health"), n=require("core.netstat"), g=require("core.github_http");
function check(v,msg) { if (!v) die(msg+"\n"); }
let req=h.config_requirements({inbounds:[{type:"direct",listen:"127.0.0.42",listen_port:53},{type:"tproxy",listen:"::1",listen_port:1602,network:"udp"},{type:"tun",interface_name:"tun0"}]});
check(length(req.listeners)==3 && req.listeners[1].protocol=="udp" && req.tunnels[0]=="tun0","DNS/TProxy/TUN requirements");
check(h.config_requirements({inbounds:[]}) != null,"no mixed config");
check(h.config_requirements({}) == null,"missing config accepted");
check(h.config_requirements({inbounds:[{type:"direct",listen_port:0}]})==null,"invalid socket accepted");
check(h.config_requirements({inbounds:[{type:"tun",interface_name:"../bad"}]})==null,"invalid interface accepted");
let udp="udp 0 0 127.0.0.42:53 0.0.0.0:* 4200/sing-box";
check(n.socket_port_owned(udp,"udp","127.0.0.42",53,4200),"UDP owner missing");
check(!n.socket_port_owned(udp,"udp","127.0.0.42",53,420),"UDP wrong PID");
check(!n.socket_port_owned(udp,"tcp","127.0.0.42",53,4200),"UDP as TCP");
check(!n.socket_port_owned(udp,"udp","127.0.0.42",530,4200),"UDP port prefix");
check(n.socket_port_owned("udp6 0 0 :::53 :::* UNCONN 4200/sing-box","udp","::1",53,4200),"UDP6 with state");
check(!n.socket_port_owned("udp6 0 0 :::53 :::* 4200/sing-box","udp","127.0.0.42",53,4200),"IPv6 socket accepted as IPv4 readiness");
check(!n.socket_port_owned("tcp 0 0 0.0.0.0:53 0.0.0.0:* LISTEN 4200/sing-box","tcp","::1",53,4200),"IPv4 socket accepted as IPv6 readiness");
let p={pid:42,start_ticks:100};
let first=h.observe_runtime(null,p,1000,90);
check(!first.ready,"new process probed immediately");
check(!h.observe_runtime(first.state,p,1089,90).ready,"grace too short");
check(h.observe_runtime(first.state,p,1090,90).ready,"grace never expires");
check(!h.observe_runtime(first.state,{pid:43,start_ticks:200},2000,90).ready,"PID change not reset");
check(!h.observe_runtime(first.state,{pid:42,start_ticks:200},2000,90).ready,"PID reuse not reset");
check(h.observe_runtime(first.state,null,2000,90).state==null,"missing process not reset");
check(!h.observe_runtime(first.state,p,999,90).ready,"clock regression not reset");
let headers="HTTP/1.1 200 Connection established\r\nX-RateLimit-Remaining: 99\r\n\r\nHTTP/2 403\r\nx-ratelimit-remaining: 0\r\nx-ratelimit-reset: 4600\r\n";
check(g.rate_limit(403,headers,"{}",1000).until==4600,"primary reset header");
check(g.rate_limit(429,"Retry-After: 120\n","{}",1000).until==1120,"retry-after");
check(g.rate_limit(403,"","{\"message\":\"You have exceeded a secondary rate limit\"}",1000)!=null,"secondary limit");
check(g.rate_limit(403,"","{\"message\":\"Forbidden\"}",1000)==null,"ordinary 403 as limit");
check(g.rate_limit(200,headers,"{}",1000)==null,"success as limit");
check(g.rate_limit(500,headers,"{}",1000)==null,"server error as limit");
check(g.rate_limit(403,"","{\"message\":123}",1000)==null,"malformed error body");
print("Readiness, DNS grace and GitHub policy checks passed\n");
'

# Exercise the actual HTTP path and persisted backoff with a fake curl.
mkdir "$WORK/bin" "$WORK/state"
cat >"$WORK/bin/curl" <<'SH'
#!/bin/sh
echo call >> "$CALLS"
while [ "$#" -gt 0 ]; do
  case "$1" in -o) body=$2; shift;; -D) headers=$2; shift;; esac
  shift
done
case "$CASE" in
  limit) printf 'HTTP/2 403\nx-ratelimit-remaining: 0\nretry-after: 120\n' > "$headers"; printf '{"message":"API rate limit exceeded"}' > "$body"; printf 403;;
  ok) printf 'HTTP/2 200\n' > "$headers"; printf '[]' > "$body"; printf 200;;
  error) printf 'HTTP/2 500\n' > "$headers"; printf '{}' > "$body"; printf 500;;
esac
SH
chmod +x "$WORK/bin/curl"
export PATH="$WORK/bin:$PATH" CALLS="$WORK/calls" FORKOP_LIB FORKOP_RUNTIME_STATE_DIR="$WORK/state"
export FORKOP_UCI_STATE_FILE="$WORK/uci.state"
printf 'forkop.settings=settings\n' > "$FORKOP_UCI_STATE_FILE"
CASE=limit ucode -L "$FORKOP_LIB" "$FORKOP_LIB/components/action.uc" github-json-fixture > "$WORK/result"
[ ! -s "$WORK/result" ]
[ -s "$WORK/state/github-api-backoff.json" ]
CASE=ok ucode -L "$FORKOP_LIB" "$FORKOP_LIB/components/action.uc" github-json-fixture > "$WORK/result"
[ "$(wc -l < "$CALLS")" -eq 1 ]
printf '{"until":1}' > "$WORK/state/github-api-backoff.json"
CASE=ok ucode -L "$FORKOP_LIB" "$FORKOP_LIB/components/action.uc" github-json-fixture > "$WORK/result"
[ "$(cat "$WORK/result")" = '[]' ]
CASE=error ucode -L "$FORKOP_LIB" "$FORKOP_LIB/components/action.uc" github-json-fixture > "$WORK/result"
[ ! -s "$WORK/result" ]
printf 'GitHub HTTP/backoff integration checks passed\n'
