#!/usr/bin/env bash
# Exercise the real backend staging shared by IPK/APK, including normalization.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
set -- 2.4.1 "$work/output"
source <(sed '$d' "$repo/build.sh")
ROOT_DIR="$repo"
build_backend_root "$work/backend"
for script in tailscale/lan.sh tailscale/transport.sh; do
    mode=$(stat -c '%a' "$work/backend/usr/lib/forkop/$script")
    [ "$mode" = 755 ] || { echo "FAIL: $script has mode $mode" >&2; exit 1; }
done
grep -q "2.4.1" "$work/backend/usr/lib/forkop/core/constants.uc"
echo 'Tailscale package staging permissions passed'
