#!/bin/sh
set -eu
# Run only on an authorized existing OpenWrt VM with ip-full and socat.
[ "${FORKOP_TEST_VM:-}" = 1 ] || exit 1
ubus call system board | grep -qi VMware || exit 1
module="${1:?candidate nft/apply.uc}"
lib="${FORKOP_LIB:-/usr/lib/forkop}"
work="$(mktemp -d /tmp/forkop-quic.XXXXXX)"
prefix="fq$$"
client="$prefix-c"; router="$prefix-r"; server="$prefix-s"
cleanup() {
    for ns in "$client" "$router" "$server"; do
        ip netns pids "$ns" 2>/dev/null | xargs -r kill 2>/dev/null || true
        ip netns del "$ns" 2>/dev/null || true
    done
}
trap cleanup EXIT INT TERM
r() { ip netns exec "$router" "$@"; }
c() { ip netns exec "$client" "$@"; }
s() { ip netns exec "$server" "$@"; }
fail() { echo "FAIL: $*; evidence: $work" >&2; exit 1; }
for ns in "$client" "$router" "$server"; do ip netns add "$ns"; ip -n "$ns" link set lo up; done
ip link add fqc type veth peer name fqi
ip link set fqc netns "$client"; ip link set fqi netns "$router"
ip link add fqo type veth peer name fqs
ip link set fqo netns "$router"; ip link set fqs netns "$server"
for pair in "$client fqc" "$router fqi" "$router fqo" "$server fqs"; do set -- $pair; ip -n "$1" link set "$2" up; done
ip -n "$client" addr add 172.30.0.2/24 dev fqc
ip -n "$router" addr add 172.30.0.1/24 dev fqi
ip -n "$router" addr add 198.51.100.1/24 dev fqo
ip -n "$server" addr add 198.51.100.2/24 dev fqs
ip -n "$server" addr add 10.1.0.2/24 dev fqs
ip -n "$router" route add 10.1.0.0/24 dev fqo
ip -n "$client" route add default via 172.30.0.1
ip -n "$server" route add default via 198.51.100.1
ip -n "$client" -6 addr add 2001:db8:1::2/64 dev fqc nodad
ip -n "$router" -6 addr add 2001:db8:1::1/64 dev fqi nodad
ip -n "$router" -6 addr add 2001:db8:2::1/64 dev fqo nodad
ip -n "$server" -6 addr add 2001:db8:2::2/64 dev fqs nodad
ip -n "$server" -6 addr add fd00::2/64 dev fqs nodad
ip -n "$router" -6 route add fd00::/64 dev fqo
ip -n "$client" -6 route add default via 2001:db8:1::1
ip -n "$server" -6 route add default via 2001:db8:2::1
for pair in "$client fqc" "$router fqi" "$router fqo" "$server fqs"; do set -- $pair; ip -n "$1" link set "$2" up; done
r sysctl -qw net.ipv4.ip_forward=1 net.ipv6.conf.all.forwarding=1
cmac="$(c cat /sys/class/net/fqc/address)"
rimac="$(r cat /sys/class/net/fqi/address)"
romac="$(r cat /sys/class/net/fqo/address)"
smac="$(s cat /sys/class/net/fqs/address)"
ip -n "$client" -6 neigh replace 2001:db8:1::1 lladdr "$rimac" nud permanent dev fqc
ip -n "$router" -6 neigh replace 2001:db8:1::2 lladdr "$cmac" nud permanent dev fqi
ip -n "$router" -6 neigh replace 2001:db8:2::2 lladdr "$smac" nud permanent dev fqo
ip -n "$router" -6 neigh replace fd00::2 lladdr "$smac" nud permanent dev fqo
ip -n "$server" -6 neigh replace 2001:db8:2::1 lladdr "$romac" nud permanent dev fqs
s socat UDP4-RECVFROM:443,bind=198.51.100.2,fork EXEC:/bin/cat >"$work/server4.log" 2>&1 &
s socat UDP4-RECVFROM:443,bind=10.1.0.2,fork EXEC:/bin/cat >"$work/local4.log" 2>&1 &
s socat 'UDP6-RECVFROM:443,bind=[2001:db8:2::2],ipv6only=1,fork' EXEC:/bin/cat >"$work/server6.log" 2>&1 &
s socat 'UDP6-RECVFROM:443,bind=[fd00::2],ipv6only=1,fork' EXEC:/bin/cat >"$work/local6.log" 2>&1 &
s socat UDP4-RECVFROM:444,fork EXEC:/bin/cat >"$work/server444.log" 2>&1 &
s socat TCP4-LISTEN:443,reuseaddr,fork EXEC:/bin/cat >"$work/tcp.log" 2>&1 &
sleep 1
cat >"$work/base.nft" <<'EOF'
add table inet quic_test
add set inet quic_test sources { type ifname; elements = { "fqi" }; }
add set inet quic_test local4 { type ipv4_addr; flags interval; elements = { 10.0.0.0/8 }; }
add set inet quic_test local6 { type ipv6_addr; flags interval; elements = { fd00::/8 }; }
add chain inet quic_test classify { type filter hook prerouting priority -149; policy accept; }
EOF
r nft -f "$work/base.nft"
apply() { r ucode -L "$lib" "$module" nft-add-direct-quic-rules-fixture quic_test sources local4 local6 0x10000 "$1"; }
echo_probe() {
    result="$(printf 'probe\n' | c socat -T 1 - "$1" 2>"$work/client.err" || true)"
    if [ "$result" != probe ]; then
        for ns in "$client" "$router" "$server"; do ip -n "$ns" -6 addr; ip -n "$ns" -6 route; ip -n "$ns" -6 neigh; done
        fail "expected echo: $1 $(cat "$work/client.err")"
    fi
    echo "PASS echo: $1"
}
reject_probe() {
    result="$(printf 'probe\n' | c socat -T 2 - "$1" 2>"$work/client.err" || true)"
    [ -z "$result" ] && grep -qi 'Connection refused' "$work/client.err" || fail "expected ICMP port unreachable: $1"
    echo "PASS reject: $1"
}
apply 0
echo_probe UDP4:198.51.100.2:443
echo_probe 'UDP6:[2001:db8:2::2]:443'
apply 1
reject_probe UDP4:198.51.100.2:443
reject_probe 'UDP6:[2001:db8:2::2]:443'
# Compare socket-visible feedback. No browser fallback timing is inferred.
r nft flush chain inet quic_test quic_forward
r nft add rule inet quic_test quic_forward udp dport 443 counter drop
result="$(printf 'probe\n' | c socat -T 2 - UDP4:198.51.100.2:443 2>"$work/drop.err" || true)"
[ -z "$result" ] && ! grep -qi 'Connection refused' "$work/drop.err" || fail 'drop unexpectedly supplied explicit rejection'
echo 'PASS drop: silent timeout; reject: explicit port unreachable'
r nft delete chain inet quic_test quic_forward
apply 1
echo_probe UDP4:10.1.0.2:443
echo_probe 'UDP6:[fd00::2]:443'
echo_probe UDP4:198.51.100.2:444
echo_probe TCP4:198.51.100.2:443
r nft add rule inet quic_test classify meta mark set 0x10000
echo_probe UDP4:198.51.100.2:443
echo_probe 'UDP6:[2001:db8:2::2]:443'
r nft flush chain inet quic_test classify
r nft add rule inet quic_test classify meta mark set 0x200
reject_probe UDP4:198.51.100.2:443
r nft flush chain inet quic_test classify
r nft 'add chain inet quic_test nat { type nat hook prerouting priority -100; }'
r nft add rule inet quic_test nat ip daddr 198.51.100.3 udp dport 443 dnat ip to 198.51.100.2
echo_probe UDP4:198.51.100.3:443
r nft flush set inet quic_test sources
echo_probe UDP4:198.51.100.2:443
r nft list table inet quic_test >"$work/rules.nft"
r nft delete table inet quic_test
r nft -f "$work/base.nft"
apply 0
echo_probe UDP4:198.51.100.2:443
echo_probe 'UDP6:[2001:db8:2::2]:443'
echo "All direct QUIC namespace checks passed; evidence: $work"
