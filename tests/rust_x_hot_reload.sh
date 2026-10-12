#!/bin/sh
# Run on an OpenWrt integration VM with the candidate Rust X binary.
set -eu
LIB=${FORKOP_LIB:-/usr/lib/forkop}
CORE=${FORKOP_SING_BOX_BIN:-/usr/bin/sing-box}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
for case in good stale-generation wrong-pid reused-pid wrong-hash; do
    CASE="$case" WORK="$WORK" ucode -e '
        let fs = require("fs");
        let f = { plan: { process: { pid: 123, start_ticks: "456" }, generation: 2 },
            current: { pid: 123, generation: 3, config_sha256: "new" },
            actual: { pid: 123, start_ticks: "456" }, fingerprint: "new" };
        let c = getenv("CASE");
        if (c == "stale-generation") f.current.generation = 2;
        if (c == "wrong-pid") f.current.pid = 124;
        if (c == "reused-pid") f.actual.start_ticks = "457";
        if (c == "wrong-hash") f.current.config_sha256 = "old";
        fs.writefile(getenv("WORK") + "/ack.json", sprintf("%J", f));
    '
    if ucode -L "$LIB" "$LIB/service/hot_reload.uc" ack-fixture "$WORK/ack.json"; then
        [ "$case" = good ] || { echo "False acknowledgment: $case"; exit 1; }
    else
        [ "$case" != good ] || { echo 'Valid acknowledgment rejected'; exit 1; }
    fi
done
cat > "$WORK/current.json" <<'EOF'
{"inbounds":[{"type":"mixed","tag":"in","listen":"127.0.0.1","listen_port":12080}],"outbounds":[{"type":"direct","tag":"direct"}],"route":{"final":"direct"}}
EOF
cp "$WORK/current.json" "$WORK/next.json"
"$CORE" reload-plan --current "$WORK/current.json" -c "$WORK/next.json" > "$WORK/plan.json"
WORK="$WORK" ucode -e '
    let fs=require("fs"); let p=json(fs.readfile(getenv("WORK")+"/plan.json"));
    assert(p.schema == 1 && p.in_place && p.current_sha256 == p.config_sha256, "No-op reload plan");
    let c=json(fs.readfile(getenv("WORK")+"/next.json")); c.inbounds[0].listen_port=12081;
    fs.writefile(getenv("WORK")+"/next.json", sprintf("%J",c));
'
"$CORE" reload-plan --current "$WORK/current.json" -c "$WORK/next.json" > "$WORK/plan.json"
WORK="$WORK" ucode -e '
    let fs=require("fs"); let p=json(fs.readfile(getenv("WORK")+"/plan.json"));
    assert(p.in_place === false && p.current_sha256 != p.config_sha256, "Listener change must restart");
'
printf '{broken' > "$WORK/next.json"
if "$CORE" reload-plan --current "$WORK/current.json" -c "$WORK/next.json" >/dev/null 2>&1; then
    echo 'Invalid candidate accepted'; exit 1
fi
echo 'Rust X reload acknowledgment and plan checks passed'
