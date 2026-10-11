// Pure readiness planning shared by runtime checks and focused tests.
function config_requirements(config) {
    if (type(config) != "object" || type(config.inbounds) != "array")
        return null;
    let result = { listeners: [], tunnels: [] };
    for (let inbound in config.inbounds) {
        if (type(inbound) != "object")
            return null;
        if (inbound.type == "tun") {
            if (type(inbound.interface_name) != "string" ||
                match(inbound.interface_name, /^[A-Za-z0-9_.-]+$/) == null)
                return null;
            push(result.tunnels, inbound.interface_name);
            continue;
        }
        let protocols;
        if (inbound.type == "mixed" || inbound.type == "socks" || inbound.type == "http")
            protocols = [ "tcp" ];
        else if (inbound.type == "direct" || inbound.type == "tproxy")
            protocols = inbound.network == null || inbound.network == ""
                ? [ "tcp", "udp" ]
                : (type(inbound.network) == "array" ? inbound.network : split(inbound.network, ","));
        else
            continue;
        if (int(inbound.listen_port || 0) < 1 || int(inbound.listen_port) > 65535)
            return null;
        for (let protocol in protocols) {
            if (protocol != "tcp" && protocol != "udp")
                return null;
            push(result.listeners, {
                protocol,
                listen: inbound.listen || "0.0.0.0",
                port: "" + inbound.listen_port
            });
        }
    }
    return result;
}

// Measure the grace period from observing this managed process, avoiding
// architecture-specific assumptions about /proc starttime clock ticks.
function observe_runtime(previous, provenance, now, grace_seconds) {
    if (type(provenance) != "object" || int(provenance.pid || 0) <= 0 || provenance.start_ticks == null)
        return { ready: false, state: null };
    if (type(previous) != "object" || previous.pid != provenance.pid ||
        previous.start_ticks != provenance.start_ticks || now < previous.observed_at)
        previous = { pid: provenance.pid, start_ticks: provenance.start_ticks, observed_at: now };
    return { ready: now - previous.observed_at >= grace_seconds, state: previous };
}

return { config_requirements, observe_runtime };
