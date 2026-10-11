#!/usr/bin/env ucode
// Exercise the real capture and restart functions with failed readiness,
// explicit Stop, stale markers and legacy installations, without package IO.
let fs = require("fs");
let source = fs.readfile(ARGV[0]);
function extract(name) {
    let start = index(source, "function " + name + "(");
    let tail = substr(source, start);
    let end = index(tail, "\n}");
    return substr(tail, 0, end + 2);
}
let functions = extract("capture_forkop_running_state") + "\n" +
    extract("restart_forkop_after_successful_change");
let cases = [
    [ "active despite failed readiness", true, "0", true, false, true ],
    [ "explicit stop", false, "1", false, false, false ],
    [ "stale ready marker after stop", true, "1", true, false, false ],
    [ "unmanaged standalone core", false, "0", true, false, false ],
    [ "stale marker without core", true, "0", false, false, false ],
    [ "healthy legacy runtime", false, "", false, true, true ]
];
for (let c in cases) {
    let code = 'let LIB_DIR="/lib", RUNTIME_STATE_DIR="/run", CONFIG_NAME="forkop", BIN_PATH="/bin/forkop", SERVICE_INIT="/init";\n' +
        'let forkop_was_running=false, forkop_stopped_for_sing_box_change=true, starts=0, disables=0;\n' +
        'let uci_core={get: function(path) { return ' + sprintf("%J", c[2]) + '; }};\n' +
        'function file_exists(path) { return path=="/run/watchdog.ready" ? ' + sprintf("%J", c[1]) + ' : true; }\n' +
        'function module_success(args) { return ' + sprintf("%J", c[3]) + '; }\n' +
        'function forkop_status_running_with_timeout() { return ' + sprintf("%J", c[4]) + '; }\n' +
        'function updates_log(text) {}\nfunction prepare_sing_box_service_disabled() { disables++; }\n' +
        'function command_from_args(args) { if (args[1]!="start") die("wrong action"); return ""; }\n' +
        'function run_logged(text, command) { starts++; return true; }\n' + functions + '\n' +
        'capture_forkop_running_state(); if (forkop_was_running!=' + sprintf("%J", c[5]) + ') die("capture failed");\n' +
        'if (!restart_forkop_after_successful_change()) die("restart failed");\n' +
        'if (starts!=' + (c[5] ? "1" : "0") + ' || disables!=' + (c[5] ? "0" : "1") + ') die("restore failed");';
    let path = "/tmp/forkop-component-state-case." + fs.readlink("/proc/self") + ".uc";
    fs.writefile(path, code);
    if (system("ucode " + path) != 0)
        die(c[0]);
    fs.unlink(path);
    print("PASS: ", c[0], "\n");
}
