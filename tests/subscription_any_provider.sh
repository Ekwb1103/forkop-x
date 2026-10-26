#!/bin/sh
# Backend and LuCI checks that subscription URLs are not limited to a provider list.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
LIB=${FORKOP_LIB:-$ROOT/forkop/files/usr/lib}
ucode -L "$LIB" "$ROOT/tests/subscription_any_provider.uc"
if command -v node >/dev/null 2>&1 && [ -d "$ROOT/fe-app-forkop/node_modules/esbuild" ]; then
    node "$ROOT/tests/subscription_any_provider.cjs"
else
    echo "SKIP: LuCI check needs node and fe-app-forkop/node_modules"
fi
