function header_value(headers, name) {
    let value = "";
    for (let line in split(headers || "", "\n")) {
        // Redirects and proxy CONNECT may produce multiple header blocks.
        if (match(line, /^HTTP\//))
            value = "";
        let colon = index(line, ":");
        if (colon > 0 && lc(substr(line, 0, colon)) == name)
            value = trim(substr(line, colon + 1));
    }
    return value;
}

function rate_limit(status, headers, body, now) {
    status = int(status);
    if (status != 403 && status != 429)
        return null;
    let message = "";
    try {
        let payload = json(body);
        if (type(payload) == "object" && type(payload.message) == "string")
            message = payload.message;
    }
    catch (e) {}
    if (status != 429 && header_value(headers, "x-ratelimit-remaining") != "0" &&
        match(message, /rate limit|secondary rate|abuse detection/i) == null)
        return null;
    let wait = 60;
    let reset = header_value(headers, "x-ratelimit-reset");
    let retry = header_value(headers, "retry-after");
    if (match(reset, /^[0-9]+$/) != null && int(reset) > now)
        wait = int(reset) - now;
    if (match(retry, /^[0-9]+$/) != null && int(retry) > wait)
        wait = int(retry);
    // Bound remote hints and tolerate an unset router clock.
    wait = wait > 86400 ? 86400 : wait;
    return { until: now + wait, message: "GitHub API rate limit; retry in " + wait + "s" };
}

return { header_value, rate_limit };
