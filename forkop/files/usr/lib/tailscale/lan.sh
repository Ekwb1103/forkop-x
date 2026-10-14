#!/bin/sh
# Owned ephemeral IPv4 forwarding only. No UCI firewall or global routes changed.
set -eu
state=/etc/forkop-tailscale
owned=/var/run/forkop/ui-state/tailscale-lan-owned
cleanup() {
    for chain in forward input; do
        nft -a list chain inet fw4 "$chain" 2>/dev/null | sed -n '/comment "forkop-native-tailscale"/s/.*# handle \([0-9][0-9]*\).*/\1/p' | while read -r handle; do
            nft delete rule inet fw4 "$chain" handle "$handle" 2>/dev/null || true
        done
    done
    if [ -f "$owned" ]; then
        nft delete table inet forkop_native_tailscale 2>/dev/null || true
        ip rule del priority 104 fwmark 0x880000/0xff0000 table 52743 2>/dev/null || true
        ip route flush table 52743 2>/dev/null || true
        rm -f "$owned"
    fi
}
[ "${1:-}" = cleanup ] && { cleanup; exit 0; }
[ -f "$state/lan.json" ] || exit 1
device=$(jsonfilter -i "$state/lan.json" -e '@.device')
routes=$(jsonfilter -i "$state/lan.json" -e '@.routes[*]')
case "$device" in ''|*[!a-zA-Z0-9_.-]*) exit 1;; esac
[ -n "$routes" ] || exit 1
[ -e /sys/class/net/forkop-tslan ] || exit 1
[ "$(cat /proc/sys/net/ipv4/ip_forward)" = 1 ] || exit 1
if ! nft list table inet forkop_native_tailscale >/dev/null 2>&1; then
    # Refuse to overwrite another feature's reserved policy rule/table.
    ip rule show | grep -q '^104:' && exit 1
    [ -z "$(ip route show table 52743 2>/dev/null)" ] || exit 1
    ip link set forkop-tslan mtu 1280 up
    ip route add table 52743 100.64.0.0/10 dev forkop-tslan
    touch "$owned"
    ip rule add priority 104 fwmark 0x880000/0xff0000 table 52743
    # Device has no address: all router service traffic remains in userspace.
    nft -f - <<EOF
table inet forkop_native_tailscale {
    chain mark_reply { type filter hook prerouting priority -149; policy accept;
        iifname "forkop-tslan" ct mark set 0x880000
        ct direction reply ct mark 0x880000 meta mark set 0x880000
    }
    chain nat { type nat hook postrouting priority srcnat; policy accept;
        iifname "forkop-tslan" oifname "$device" masquerade
    }
    chain guard { type filter hook forward priority -1; policy accept;
        iifname "forkop-tslan" oifname != "$device" drop
    }
}
EOF
fi
[ -f "$owned" ] || exit 1
# Restore only our hook after fw4 reload. The subnet ACL is enforced in Rust.
if ! nft list chain inet fw4 forward | grep -q 'comment "forkop-native-tailscale"'; then
    nft insert rule inet fw4 forward iifname '"forkop-tslan"' oifname "\"$device\"" accept comment '"forkop-native-tailscale"'
fi
if ! nft list chain inet fw4 input | grep -q 'comment "forkop-native-tailscale"'; then
    nft insert rule inet fw4 input iifname '"forkop-tslan"' drop comment '"forkop-native-tailscale"'
fi
