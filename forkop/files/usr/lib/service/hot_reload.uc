#!/usr/bin/env ucode
let fs = require("fs");
let common = require("core.common");
let uci = require("core.uci");
const LIB_DIR = getenv("FORKOP_LIB") || "/usr/lib/forkop";
const CONFIG_NAME = getenv("FORKOP_CONFIG_NAME") || "forkop";
const STATE_UC = LIB_DIR + "/service/state.uc";
const BINARY = getenv("FORKOP_SING_BOX_BIN") || "/usr/bin/sing-box";

function str(value) { return value == null ? "" : "" + value; }
function quote(value) { return "'" + replace(str(value), /'/g, "'\\''") + "'"; }
function capture(args) {
    let encoded = [];
    for (let arg in args) push(encoded, quote(arg));
    let pipe = fs.popen(join(" ", encoded) + " 2>/dev/null", "r");
    if (!pipe) return { status: 1, output: "" };
    let output = pipe.read("all");
    let status = int(pipe.close());
    return { status: status > 255 ? int(status / 256) : status, output: str(output) };
}
function parsed(value) { try { return json(value); } catch (e) { return null; } }
function read(path) { return parsed(fs.readfile(path)); }
function unlink(path) { try { fs.unlink(path); } catch (e) {} }
function provenance() {
    let result = capture([ "ucode", "-L", LIB_DIR, STATE_UC, "sing-box-runtime-provenance" ]);
    return result.status == 0 ? parsed(result.output) : null;
}
function same_process(expected, actual) {
    return type(expected) == "object" && type(actual) == "object" &&
        int(expected.pid) > 0 && expected.pid == actual.pid && expected.start_ticks == actual.start_ticks;
}
function status(config_path) {
    let root = read(config_path);
    let api = type(root) == "object" ? common.object_or_empty(common.object_or_empty(root.experimental).clash_api) : {};
    let address = str(api.external_controller);
    if (address == "") return null;
    address = replace(address, /^0\.0\.0\.0:/, "127.0.0.1:");
    address = replace(address, /^\[::\]:/, "[::1]:");
    // Curl config keeps the controller secret out of process arguments.
    let temporary = trim(capture([ "mktemp" ]).output);
    if (temporary == "") return null;
    let escaped = replace(replace(str(api.secret), /\\/g, "\\\\"), /"/g, "\\\"");
    if (match(escaped, /[\r\n]/) != null || common.write_private_file(temporary,
        "header = \"Authorization: Bearer " + escaped + "\"\n") == null) {
        unlink(temporary); return null;
    }
    let result = capture([ "curl", "--noproxy", "*", "-fsS", "--max-time", "2", "--config", temporary,
        "http://" + address + "/rust-x/applied-config" ]);
    unlink(temporary);
    let value = result.status == 0 ? parsed(result.output) : null;
    return type(value) == "object" && value.schema == 1 && value.ready === true && value.hot_reload === true &&
        int(value.generation) > 0 && match(str(value.config_sha256), /^[a-f0-9]{64}$/) != null ? value : null;
}
function acknowledged(plan, current, actual, fingerprint) {
    return same_process(plan.process, actual) && type(current) == "object" &&
        int(current.pid) == int(plan.process.pid) && int(current.generation) > int(plan.generation) &&
        current.config_sha256 == fingerprint;
}
function plan(stage_path) {
    let cfg = common.object_or_empty(uci.get_all(CONFIG_NAME, "settings"));
    let current_path = str(cfg.config_path);
    let process = provenance();
    let before = status(current_path);
    if (!same_process(process, provenance()) || before == null || int(before.pid) != int(process.pid)) {
        print("cold\n"); return 0;
    }
    let result = capture([ BINARY, "reload-plan", "--current", current_path, "-c", stage_path ]);
    let candidate = result.status == 0 ? parsed(result.output) : null;
    if (candidate == null || candidate.schema != 1) return 1;
    if (!candidate.in_place || candidate.current_sha256 != before.config_sha256) {
        print("cold\n"); return 0;
    }
    let value = { process, generation: before.generation, current_path,
        previous_sha256: before.config_sha256, config_sha256: candidate.config_sha256 };
    if (common.write_private_json_file(stage_path + ".hot-plan", value) == null) return 1;
    print("hot\n"); return 0;
}
function apply(plan_path, restore_path) {
    let value = read(plan_path);
    if (type(value) != "object" || !same_process(value.process, provenance())) return 1;
    let before = status(value.current_path);
    if (before == null || int(before.pid) != int(value.process.pid)) return 1;
    // Require a new acknowledgment for this signal, including rollback of a
    // no-op configuration whose hash is already visible.
    value.generation = int(before.generation);
    let fingerprint = value.config_sha256;
    if (str(restore_path) != "") {
        if (capture([ "cp", "-p", restore_path, value.current_path ]).status != 0) return 1;
        fingerprint = value.previous_sha256;
    }
    if (capture([ "kill", "-HUP", str(value.process.pid) ]).status != 0) return 1;
    let timeout = int(getenv("FORKOP_HOT_RELOAD_TIMEOUT") || "30");
    timeout = timeout > 0 && timeout <= 120 ? timeout : 30;
    let deadline = int(clock(true)[0]) + timeout;
    while (int(clock(true)[0]) <= deadline) {
        let actual = provenance();
        if (!same_process(value.process, actual)) return 1;
        if (acknowledged(value, status(value.current_path), actual, fingerprint)) return 0;
        capture([ "sleep", "0.2" ]);
    }
    return 1;
}
let mode = ARGV[0] || "";
if (mode == "plan") exit(plan(ARGV[1] || ""));
else if (mode == "apply") exit(apply(ARGV[1] || "", ""));
else if (mode == "restore") exit(apply(ARGV[1] || "", ARGV[2] || ""));
else if (mode == "ack-fixture") {
    let fixture = read(ARGV[1]);
    exit(acknowledged(fixture.plan, fixture.current, fixture.actual, fixture.fingerprint) ? 0 : 1);
}
else exit(1);
