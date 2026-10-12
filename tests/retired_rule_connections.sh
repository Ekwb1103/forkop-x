#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
LIB="$ROOT/forkop/files/usr/lib"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cat > "$WORK/fixture.json" <<'EOF'
{"previous":{"route":{"rule_set":[{"tag":"removed"},{"tag":"keep"}]}},"current":{"route":{"rule_set":[{"tag":"keep"}]}},"connections":[{"id":"1","rulePayload":"rule_set=removed"},{"id":"2","rulePayload":"rule_set=keep"},{"id":"3","rulePayload":"rule_set=removed-extra"},{"id":"4","rulePayload":"rule_set=keep rule_set=removed"},{"id":"bad/path","rulePayload":"rule_set=removed"}]}
EOF
result=$(ucode -L "$LIB" "$LIB/service/hot_reload.uc" connections-fixture "$WORK/fixture.json")
[ "$result" = '[ "1", "4" ]' ]
echo 'Removed rule connection selection: exact tokens, unrelated rules and safe IDs passed'
