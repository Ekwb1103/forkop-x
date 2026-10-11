let fs = require("fs");

function start_ticks(stat) {
    let marker = rindex(stat || "", ") ");
    let fields = marker >= 0 ? split(trim(substr(stat, marker + 2)), /\s+/) : [];
    return length(fields) >= 20 ? fields[19] : null;
}

function services_rss_bytes(services, service_name, proc_root) {
    if (type(services) != "object" || type(services[service_name]) != "object")
        return null;
    let instances = services[service_name].instances || {};
    let total = 0;
    let seen = {};
    for (let _, instance in instances) {
        let pid = int(instance.pid || 0);
        if (instance.running !== true || pid <= 0 || seen[pid])
            continue;
        let path = proc_root + "/" + pid;
        let before = start_ticks(fs.readfile(path + "/stat"));
        let cmdline = fs.readfile(path + "/cmdline");
        let command = instance.command;
        if (before == null || cmdline == null || type(command) != "array" || !length(command))
            return null;
        let args = split(cmdline, "\x00");
        if (args[length(args) - 1] == "")
            pop(args);
        if (length(args) != length(command))
            return null;
        for (let i = 0; i < length(args); i++) {
            // procd may resolve the interpreter through PATH.
            let actual = i == 0 ? replace(args[i], /^.*\//, "") : args[i];
            let expected = i == 0 ? replace(command[i], /^.*\//, "") : command[i];
            if (actual != expected)
                return null;
        }
        let rss = match(fs.readfile(path + "/status") || "", /VmRSS:[ \t]+([0-9]+)[ \t]+kB/);
        if (rss == null || before != start_ticks(fs.readfile(path + "/stat")))
            return null;
        seen[pid] = true;
        total += int(rss[1]) * 1024;
    }
    return total;
}

// Only count live procd children whose command still matches the registered
// instance. Never infer core identity from its process name or memory usage.
function service_rss_bytes(service_name) {
    if (match(service_name || "", /^[A-Za-z0-9_.-]+$/) == null)
        return null;
    let pipe = fs.popen("ubus call service list '{\"name\":\"" + service_name + "\"}' 2>/dev/null", "r");
    if (!pipe)
        return null;
    let output = pipe.read("all");
    let status = pipe.close();
    let services;
    try { services = json(output); } catch (e) { return null; }
    if (status != 0)
        return null;
    return services_rss_bytes(services, service_name, "/proc");
}


return { service_rss_bytes, services_rss_bytes };
