#!/bin/sh
# Read-only compatibility boundary checks on an existing OpenWrt VM.
set -eu
helper=${1:-/usr/lib/forkop/tailscale/compat.uc}
for version in 2.3.3 2.2.99 bad ''; do
    if FORKOP_VERSION="$version" ucode "$helper" check; then
        echo "Unexpected native support: $version" >&2; exit 1
    fi
done
for version in 2.3.4 2.3.4-canary.1 2.3.4_rc1 2.3.5 2.4.0 3.0.0; do
    FORKOP_VERSION="$version" ucode "$helper" check
done
echo 'Native Tailscale minimum version checks passed'
