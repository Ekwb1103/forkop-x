#!/bin/sh
# ByeDPI is removed from Forkop X; user SOCKS connections stay supported.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
LIB=${FORKOP_LIB:-$ROOT/forkop/files/usr/lib}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

[ ! -e "$LIB/providers/byedpi" ] || fail "ByeDPI provider module is still installed"

# Runtime code, LuCI views (handwritten, bundled and compacted), frontend
# sources and translations must not mention ByeDPI or its ciadpi binary.
if grep -rIil 'byedpi\|ciadpi' \
    "$ROOT/forkop/files" \
    "$ROOT/luci-app-forkop/htdocs" \
    "$ROOT/luci-app-forkop/generated" \
    "$ROOT/luci-app-forkop/po" \
    "$ROOT/fe-app-forkop/src" \
    "$ROOT/fe-app-forkop/locales" >"$WORK/hits"; then
    cat "$WORK/hits" >&2
    fail "ByeDPI references remain"
fi
echo 'No ByeDPI references in runtime, LuCI, frontend or translations'

# Manual SOCKS links and SOCKS JSON outbounds still generate socks outbounds.
cat >"$WORK/fixture.json" <<'JSON'
{"settings":{".name":"settings",".type":"settings","dns_server":"1.1.1.1"},
 "section":[{".name":"socksrule",".type":"section","enabled":"1","action":"connection",
  "selector_proxy_links":["socks5://user:pw@127.0.0.1:1080#Manual%20SOCKS","socks4://127.0.0.1:1081#SOCKS4"],
  "outbound_jsons":["{\"type\":\"socks\",\"tag\":\"JSON SOCKS\",\"server\":\"127.0.0.1\",\"server_port\":1082,\"version\":\"5\"}"]}]}
JSON
ucode -L "$LIB" "$LIB/singbox/generator.uc" generate-config-fixture \
    "$WORK/fixture.json" "$WORK/generated.json" 127.0.0.1 0 1 '' 1.14.2-x-1.0.4 \
    >"$WORK/log" 2>&1 || { cat "$WORK/log" >&2; fail "SOCKS connection generation failed"; }
ucode -e '
let c = json(require("fs").readfile(ARGV[0]));
let socks = {};
for (let o in c.outbounds)
    if (o.type == "socks")
        socks[o.server_port] = o;
assert(socks[1080] && socks[1080].version == "5" && socks[1080].username == "user" && socks[1080].password == "pw", "manual SOCKS5 link lost");
assert(socks[1081] && socks[1081].version == "4", "manual SOCKS4 link lost");
assert(socks[1082] && socks[1082].tag == "JSON SOCKS", "SOCKS JSON outbound lost");
assert(length(keys(socks)) == 3, "unexpected socks outbound");
' "$WORK/generated.json"
echo 'Manual SOCKS links and SOCKS JSON outbounds still generate socks outbounds'
