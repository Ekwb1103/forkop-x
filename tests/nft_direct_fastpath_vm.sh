#!/bin/sh
# Run on an integration VM; all packet tests stay in temporary namespaces.
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
LIB=${FORKOP_LIB:-$ROOT_DIR/forkop/files/usr/lib}
WORK=$(mktemp -d)
NS=fastpath-$$
PEER=fastpeer-$$
cleanup() {
    ip netns del "$NS" 2>/dev/null || true
    ip netns del "$PEER" 2>/dev/null || true
    rm -rf "$WORK"
}
trap cleanup EXIT HUP INT TERM
ip netns add "$NS"
ip netns add "$PEER"
ip -n "$NS" link set lo up
ip -n "$PEER" link set lo up
for pair in 'br-lan lan 192.0.2.1 192.0.2.2' 'wan uplink 192.0.2.5 192.0.2.6'; do
    set -- $pair
    ip -n "$NS" link add "$1" type veth peer name "$2"
    ip -n "$NS" link set "$2" netns "$PEER"
    ip -n "$NS" addr add "$3/30" dev "$1"
    ip -n "$PEER" addr add "$4/30" dev "$2"
    ip -n "$NS" link set "$1" up
    ip -n "$PEER" link set "$2" up
done
FORKOP_NFT_BATCH_FILE="$WORK/base.nft" ucode -L "$LIB" "$LIB/nft/apply.uc" nft-create-runtime-base \
    FastpathTest localv4 subnets ports ip_ports interfaces br-lan 0x04000000 0x08000000 198.18.0.0/15 1602 0 localv6 subnets6 ip_ports6 fc00::/18 ::1
# Track whether packets reached the end of each generated chain.
cat >>"$WORK/base.nft" <<'EOF'
add counter inet FastpathTest classified
add counter inet FastpathTest intercepted
add rule inet FastpathTest mangle counter name classified
add rule inet FastpathTest proxy counter name intercepted
EOF
ip netns exec "$NS" nft -c -f "$WORK/base.nft"
ip netns exec "$NS" nft -f "$WORK/base.nft"
count() {
    ip netns exec "$NS" nft list counter inet FastpathTest "$1" | awk '/packets/ {print $2}'
}
ip netns exec "$PEER" ping -I uplink -c 3 -W 1 192.0.2.5 >/dev/null
[ "$(count classified)" = 0 ] || { echo 'WAN replies reached classification'; exit 1; }
[ "$(count intercepted)" = 0 ] || { echo 'Unmarked WAN traffic reached interception'; exit 1; }
# Public destination avoids the existing local-address bypass.
ip -n "$NS" addr add 11.0.0.1/32 dev lo
ip -n "$PEER" route add 11.0.0.1/32 via 192.0.2.1
ip netns exec "$PEER" ping -c 3 -W 1 11.0.0.1 >/dev/null
[ "$(count classified)" = 3 ] || { echo 'Client traffic skipped classification'; exit 1; }
[ "$(count intercepted)" = 0 ] || { echo 'Unmarked client traffic reached interception'; exit 1; }
# Preserve interception eligibility with other components' mark bits present.
ip netns exec "$NS" nft 'add chain inet FastpathTest probe_mark { type filter hook prerouting priority -151; }'
ip netns exec "$NS" nft 'add rule inet FastpathTest probe_mark iifname br-lan ip protocol icmp meta mark set 0x04000100'
ip netns exec "$PEER" ping -c 3 -W 1 11.0.0.1 >/dev/null
[ "$(count intercepted)" = 3 ] || { echo 'Forkop mark plus mwan3 bits skipped interception'; exit 1; }
ip netns exec "$NS" nft flush chain inet FastpathTest probe_mark
# Generated priority rules rely on the parent ingress guard. Verify that both
# destination and fully-routed bypass decisions terminate client classification.
cat >"$WORK/priority.json" <<'EOF'
{"section":[{".name":"direct",".type":"section","action":"bypass","ip_cidr":"11.0.0.1/32","fully_routed_ips":["192.0.2.2/32","192.0.2.6/32"]}]}
EOF
FORKOP_NFT_BATCH_FILE="$WORK/priority.nft" ucode -L "$LIB" "$LIB/nft/apply.uc" nft-add-section-priority-rules-fixture \
    "$WORK/priority.json" FastpathTest interfaces localv4 localv6 0x04000000 198.18.0.0/15 fc00::/18
ip netns exec "$NS" nft -c -f "$WORK/priority.nft"
ip netns exec "$NS" nft -f "$WORK/priority.nft"
ip netns exec "$NS" nft 'add element inet FastpathTest forkop_rule_direct_subnets { 11.0.0.1 }'
ip netns exec "$PEER" ping -c 3 -W 1 11.0.0.1 >/dev/null
[ "$(count classified)" = 6 ] || { echo 'Priority destination bypass did not terminate classification'; exit 1; }
ip netns exec "$NS" nft flush set inet FastpathTest forkop_rule_direct_subnets
ip netns exec "$NS" nft 'add element inet FastpathTest forkop_rule_direct_fully_sources { 192.0.2.2, 192.0.2.6 }'
ip netns exec "$PEER" ping -c 3 -W 1 11.0.0.1 >/dev/null
[ "$(count classified)" = 6 ] || { echo 'Fully-routed bypass did not terminate classification'; exit 1; }
ip -n "$PEER" route replace 11.0.0.1/32 via 192.0.2.5
ip netns exec "$PEER" ping -I uplink -c 3 -W 1 11.0.0.1 >/dev/null
hits=$(ip netns exec "$NS" nft list chain inet FastpathTest priority_rules | awk '/counter packets/ {for(i=1;i<=NF;i++) if($i=="packets") sum+=$(i+1)} END {print sum+0}')
[ "$hits" = 6 ] || { echo 'WAN ingress reached generated priority rules'; exit 1; }
echo 'Direct fastpath namespace packet checks passed'
