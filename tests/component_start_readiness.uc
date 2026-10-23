#!/usr/bin/env ucode
// Exercise the actual component readiness waits with a simulated clock.
// No packages, services or router configuration are changed.
let fs = require("fs");
let source = fs.readfile(ARGV[0]);
function extract(start_text) {
    let start = index(source, start_text);
    assert(start >= 0, "readiness function exists");
    let tail = substr(source, start);
    let end = index(tail, "\n}");
    return substr(tail, 0, end + 2);
}
let functions = extract("function wait_for_forkop_restore(") + "\n" +
    extract("wait_forkop_running_after_sing_box_change = function(") + ";\n";
let cases = [
    { name: "terminal config failure ends component wait immediately", failure: true, expected: false, max_time: 0, max_checks: 0 },
    { name: "terminal config failure ends package restore wait immediately", restore: true, failure: true, expected: false, max_time: 0, max_checks: 0 },
    { name: "failure after owned start triggers rollback", failure: true, starting_until: 4, expected: false, max_time: 4, max_checks: 0 },
    { name: "stale failure marker does not reject an owned successful start", starting_until: 4, failure_until: 4, ready_at: 4, expected: true, max_time: 14, max_checks: 2 },
    { name: "healthy runtime is checked twice before success", ready_at: 0, expected: true, max_time: 10, max_checks: 2 },
    { name: "component timeout includes slow readiness checks", probe_seconds: 6, expected: false, max_time: 186, max_checks: 19 },
    { name: "package restore timeout includes slow readiness checks", restore: true, probe_seconds: 6, expected: false, max_time: 186, max_checks: 27 },
    { name: "owned start is bounded without readiness probes", starting_until: 1000, expected: false, max_time: 180, max_checks: 0 }
];
for (let c in cases) {
    let code = 'let c=' + sprintf("%J", c) + ';\n' +
        'let time=0, checks=0, forkop_was_running=true, wait_forkop_running_after_sing_box_change;\n' +
        'const BIN_PATH="/bin/forkop", START_FAILURE_FILE="/run/start.failure", PACKAGE_UPGRADE_STATE="/run/upgrade";\n' +
        'function now_seconds() { return time; }\n' +
        'function forkop_starting() { return time < (c.starting_until || 0); }\n' +
        'function file_exists(path) { return path == START_FAILURE_FILE ? (c.failure || time < (c.failure_until || 0)) : true; }\n' +
        'function forkop_status_running_with_timeout() { checks++; time += c.probe_seconds || 1; return c.ready_at != null && time >= c.ready_at; }\n' +
        'function command_success_from_args(args) { assert(args[0]=="sleep", "only simulated sleeps"); time += int(args[1]); return true; }\n' +
        'function updates_log(message, level) {}\n' + functions + '\n' +
        'let ok=c.restore ? wait_for_forkop_restore(true) : wait_forkop_running_after_sing_box_change();\n' +
        'assert(ok === c.expected, "readiness outcome");\n' +
        'assert(time <= c.max_time, "bounded wall time includes probes");\n' +
        'assert(checks <= c.max_checks, "bounded probe count");\n';
    let path = "/tmp/forkop-readiness-case." + fs.readlink("/proc/self") + ".uc";
    fs.writefile(path, code);
    let status = system("ucode " + path);
    fs.unlink(path);
    if (status != 0) die(c.name, "\n");
    print("PASS: ", c.name, "\n");
}
