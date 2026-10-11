#!/bin/sh
# Requires socat, gcc (or CC), and kmod-veth. No installed config changes.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
LIB=${FORKOP_LIB:-$ROOT/forkop/files/usr/lib}
X=${FORKOP_TEST_X_BINARY:?Set path to mirror-verified Sing-Box X binary}
RUST=${FORKOP_TEST_RUST_BINARY:-/usr/lib/rust-x/sing-box}
WORK=$(mktemp -d)
R=core-router-$$ C=core-client-$$ B=core-server-$$
pids=''
cleanup() {
    for pid in $pids; do kill "$pid" 2>/dev/null || true; done
    for ns in "$C" "$R" "$B"; do
        for pid in $(ip netns pids "$ns" 2>/dev/null); do kill "$pid" 2>/dev/null || true; done
    done
    for ns in "$C" "$R" "$B"; do ip netns del "$ns" 2>/dev/null || true; done
    rm -rf "$WORK"
}
trap cleanup EXIT HUP INT TERM
${CC:-gcc} -O2 -Wall -Wextra "$ROOT/tests/helpers/udp_echo.c" -o "$WORK/udp-echo"
for ns in "$C" "$R" "$B"; do ip netns add "$ns"; ip -n "$ns" link set lo up; done
ip -n "$R" link add br-lan type veth peer name client
ip -n "$R" link set client netns "$C"
ip -n "$R" addr add 192.0.2.1/24 dev br-lan
ip -n "$C" addr add 192.0.2.2/24 dev client
ip -n "$R" link set br-lan up
ip -n "$C" link set client up
ip -n "$R" link add wan type veth peer name server
ip -n "$R" link set server netns "$B"
ip -n "$R" addr add 11.0.0.2/24 dev wan
ip -n "$B" addr add 11.0.0.1/24 dev server
ip -n "$R" link set wan up
ip -n "$B" link set server up
ip -n "$C" route add default via 192.0.2.1
ip -n "$R" route add default via 11.0.0.1
ip -n "$B" route add 192.0.2.0/24 via 11.0.0.2
ip netns exec "$R" sysctl -qw net.ipv4.ip_forward=1
ip -n "$R" route add local 0.0.0.0/0 dev lo table 305
ip -n "$R" rule add fwmark 0x04000000/0x04000000 lookup 305 priority 105
FORKOP_NFT_BATCH_FILE="$WORK/base.nft" ucode -L "$LIB" "$LIB/nft/apply.uc" nft-create-runtime-base \
    CoreTest localv4 subnets ports ip_ports interfaces br-lan 0x04000000 0x08000000 198.18.0.0/15 1602 0 localv6 subnets6 ip_ports6 fc00::/18 ::1
FORKOP_NFT_BATCH_FILE="$WORK/base.nft" ucode -L "$LIB" "$LIB/nft/apply.uc" nft-create-runtime-output-rules \
    CoreTest localv4 subnets ports ip_ports 0x04000000 198.18.0.0/15 localv6 subnets6 ip_ports6 fc00::/18
echo 'add element inet CoreTest subnets { 11.0.0.1 }' >>"$WORK/base.nft"
echo 'add element inet CoreTest ip_ports { 11.0.0.1 . 18080, 11.0.0.1 . 18081 }' >>"$WORK/base.nft"
echo 'add element inet CoreTest ports { 18080, 18081 }' >>"$WORK/base.nft"
ip netns exec "$R" nft -c -f "$WORK/base.nft"
ip netns exec "$B" socat TCP4-LISTEN:18080,reuseaddr,fork EXEC:/bin/cat >"$WORK/tcp.log" 2>&1 &
pids="$pids $!"
ip netns exec "$B" "$WORK/udp-echo" >"$WORK/udp.log" 2>&1 &
pids="$pids $!"
cat >"$WORK/core.json" <<'EOF'
{"log":{"level":"info"},"inbounds":[{"type":"tproxy","tag":"test-in","listen":"0.0.0.0","listen_port":1602}],"outbounds":[{"type":"direct","tag":"test-direct","routing_mark":134217728}],"route":{"final":"test-direct"}}
EOF
exchange() {
    ns=$1 protocol=$2 port=$3 token=$4
    if [ "$protocol" = UDP4 ]; then
        result=$(ip netns exec "$ns" "$WORK/udp-echo" 11.0.0.1 "$token") || {
            echo "FAIL: $token UDP fixture"; return 1;
        }
    else
        result=$(printf '%s\n' "$token" | ip netns exec "$ns" socat -T 3 -t 2 - "$protocol:11.0.0.1:$port")
    fi
    [ "$result" = "$token" ] || { echo "FAIL: $token got '$result'"; cat "$WORK/core.log"; return 1; }
    echo "PASS: $token"
}
tcp_count() {
    ip netns exec "$R" nft list chain inet CoreTest proxy | awk '/l4proto tcp tproxy ip to/ {for(i=1;i<=NF;i++) if($i=="packets") print $(i+1)}'
}
udp_count() {
    ip netns exec "$R" nft list chain inet CoreTest proxy | awk '/l4proto udp tproxy ip to/ {for(i=1;i<=NF;i++) if($i=="packets") print $(i+1)}'
}
sleep 1
exchange "$C" UDP4 18081 plain-client-udp
exchange "$R" UDP4 18081 plain-router-udp
ip netns exec "$R" nft -f "$WORK/base.nft"
failures=0
for binary in "$X" "$RUST"; do
    "$binary" check -c "$WORK/core.json"
    ip netns exec "$R" "$binary" run -c "$WORK/core.json" >"$WORK/core.log" 2>&1 &
    core_pid=$!; pids="$pids $core_pid"
    sleep 2
    kill -0 "$core_pid"
    exchange "$C" TCP4 18080 client-tcp || failures=$((failures + 1))
    udp_before=$(udp_count)
    exchange "$C" UDP4 18081 client-udp || failures=$((failures + 1))
    udp_after=$(udp_count)
    [ "$udp_after" -gt "$udp_before" ] || { echo 'FAIL: client UDP not intercepted'; exit 1; }
    exchange "$R" TCP4 18080 router-tcp || failures=$((failures + 1))
    udp_before=$(udp_count)
    if ! exchange "$R" UDP4 18081 router-udp; then
        failures=$((failures + 1))
    fi
    udp_after=$(udp_count)
    [ "$udp_after" -gt "$udp_before" ] || { echo 'FAIL: router UDP not intercepted'; exit 1; }
    before=$(tcp_count)
    udp_before=$(udp_count)
    ip netns exec "$R" nft 'add rule inet CoreTest priority_rules ip saddr 192.0.2.2 counter accept'
    exchange "$C" TCP4 18080 excluded-client-tcp
    exchange "$C" UDP4 18081 excluded-client-udp
    after=$(tcp_count)
    [ "$before" = "$after" ] || { echo 'FAIL: excluded client intercepted'; exit 1; }
    udp_after=$(udp_count)
    [ "$udp_before" = "$udp_after" ] || { echo 'FAIL: excluded client UDP intercepted'; exit 1; }
    ip netns exec "$R" nft flush chain inet CoreTest priority_rules
    grep -q 'test-in' "$WORK/core.log" || { echo 'FAIL: core did not log interception'; exit 1; }
    kill "$core_pid"; wait "$core_pid" 2>/dev/null || true
    echo "DONE: core $binary"
done
# All captured probes also match the later IP+port and port sets. Those rules
# must remain unused after the first subnet decision in both packet paths.
for chain in mangle mangle_output; do
    later=$(ip netns exec "$R" nft list chain inet CoreTest "$chain" | awk '/@(ip_ports|ports) / {for(i=1;i<=NF;i++) if($i=="packets") sum+=$(i+1)} END {print sum+0}')
    [ "$later" = 0 ] || { echo "FAIL: $chain continued after subnet marking"; exit 1; }
done
[ "$failures" = 0 ] || { echo "FAIL: $failures scenarios; compare baseline"; exit 1; }
echo 'Both core TPROXY routing checks passed'
