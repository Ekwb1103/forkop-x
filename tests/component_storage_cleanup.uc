#!/usr/bin/env ucode
let fs = require("fs");
let cleanup = require("components.storage_cleanup");
let work = ARGV[0];
function expect(value, message) {
    if (!value) { warn("FAIL: ", message, "\n"); exit(1); }
}
let dead = "99999999";
let live = trim(fs.readfile("/proc/self/stat"));
live = split(live, " ")[0];
function dir(name, owner, recovery) {
    let path = work + "/" + name;
    expect(fs.mkdir(path), "mkdir fixture");
    fs.writefile(path + "/.forkop-owner", owner);
    fs.writefile(path + "/payload", "temporary data");
    if (recovery) fs.writefile(path + "/.forkop-recovery", "1");
    return path;
}
let abandoned = dir("forkop-updates.abandoned", dead, false);
let running = dir("forkop-updates.running", live, false);
let recovery = dir("forkop-updates.recovery", dead, true);
let backup = dir("forkop-updates.backup", dead, false);
fs.writefile(backup + "/sing-box.forkop-backup", "rollback binary");
let legacy = work + "/forkop-updates.legacy";
expect(fs.mkdir(legacy), "create legacy fixture");
fs.writefile(legacy + "/rust-x_0.0.7-r1_x86_64.apk", "legacy rollback package");
let target = work + "/sing-box";
fs.writefile(target, "installed binary");
fs.writefile(target + ".forkop-new." + dead, "partial download");
fs.writefile(target + ".forkop-new." + live, "active download");
fs.writefile(target + ".forkop-new.operator", "operator file");
let external = work + "/external";
fs.writefile(external, "external data");
expect(fs.symlink(external, abandoned + "/link"), "symlink in abandoned directory");
let now = int(clock()[0]);
expect(cleanup.prune(work, [target], now, 1800, 600) == 0, "fresh entries retained");
expect(cleanup.prune(work, [target], now + 3600, 1800, 600) == 2, "only abandoned directory and partial file deleted");
expect(fs.stat(abandoned) == null, "abandoned directory removed");
expect(fs.stat(target + ".forkop-new." + dead) == null, "partial file removed");
for (let path in [running, recovery, backup, legacy, target, external, target + ".forkop-new." + live, target + ".forkop-new.operator"])
    expect(fs.stat(path) != null, "protected path retained " + path);
print("PASS: stale storage cleanup; live owners, recovery, backups, fresh files and symlink targets protected\n");
let standalone = work + "/forkop-updates-http.ABCdef";
let live_file = work + "/forkop-updates-command." + live;
fs.writefile(standalone, "legacy temporary body");
fs.writefile(live_file, "active body");
let lock = work + "/component-action.lock";
expect(fs.mkdir(lock), "create lock fixture");
fs.writefile(lock + "/pid", live);
expect(cleanup.prune(work, [], now + 3600, 1800, 600, lock, dead) == 0, "another active action protects legacy body");
expect(cleanup.prune(work, [], now + 3600, 1800, 600, lock, live) == 1, "current lock owner can clean abandoned legacy body");
expect(fs.stat(live_file) != null, "live standalone owner protected");
print("PASS: legacy temporary files respect action lock and live PID\n");
