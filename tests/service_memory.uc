let fs = require("fs");
let memory = require("core.process_memory");
let root = ARGV[0];

function check(actual, expected, label) {
    if (actual !== expected)
        die(label + ": " + sprintf("%J != %J\n", actual, expected));
}

fs.mkdir(root);
fs.mkdir(root + "/42");
let stat = "42 (core with spaces) S";
for (let i = 0; i < 18; i++)
    stat += " 0";
stat += " 123";
fs.writefile(root + "/42/stat", stat);
fs.writefile(root + "/42/status", "VmRSS:\t2048 kB\n");
fs.writefile(root + "/42/cmdline", "/usr/bin/sing-box\x00run\x00-c\x00/etc/sing-box/config.json\x00");
let instance = { running: true, pid: 42, command: [ "/usr/bin/sing-box", "run", "-c", "/etc/sing-box/config.json" ] };
let services = { "sing-box": { instances: { main: instance, duplicate: instance } } };
check(memory.services_rss_bytes(services, "sing-box", root), 2097152, "RSS and deduplication");
instance.command[3] = "/tmp/foreign.json";
check(memory.services_rss_bytes(services, "sing-box", root), null, "Foreign process rejected");
instance.running = false;
check(memory.services_rss_bytes(services, "sing-box", root), 0, "Stopped process excluded");
instance.running = true;
instance.command[3] = "/etc/sing-box/config.json";
fs.unlink(root + "/42/status");
check(memory.services_rss_bytes(services, "sing-box", root), null, "Missing RSS stays unavailable");
fs.unlink(root + "/42/stat");
check(memory.services_rss_bytes(services, "sing-box", root), null, "Stale PID rejected");
fs.unlink(root + "/42/cmdline");
fs.rmdir(root + "/42");
fs.rmdir(root);
print("Service memory tests passed\n");
