#!/usr/bin/env ucode

let fs = require("fs");

function as_string(value) {
    return value == null ? "" : "" + value;
}

function read_stdin() {
    let input = fs.open("/dev/stdin", "r");
    if (!input)
        return "";
    let data = input.read("all");
    input.close();
    return data == null ? "" : data;
}

function write_compact_string_array(values) {
    print("[");
    for (let i = 0; i < length(values); i++) {
        if (i > 0)
            print(",");
        print(sprintf("%J", as_string(values[i])));
    }
    print("]\n");
}

function digit_char(value) {
    return match(as_string(value), /^[0-9]$/) != null;
}

function strip_leading_zeroes(value) {
    value = as_string(value);
    let i = 0;
    while (i < length(value) - 1 && substr(value, i, 1) == "0")
        i++;
    return substr(value, i);
}

function version_compare(lhs, rhs) {
    lhs = as_string(lhs);
    rhs = as_string(rhs);

    let li = 0, ri = 0;
    while (li < length(lhs) || ri < length(rhs)) {
        if (li >= length(lhs))
            return substr(rhs, ri, 1) == "~" ? 1 : -1;
        if (ri >= length(rhs))
            return substr(lhs, li, 1) == "~" ? -1 : 1;

        let lc = substr(lhs, li, 1);
        let rc = substr(rhs, ri, 1);
        if (lc == rc) {
            li++;
            ri++;
            continue;
        }

        if (lc == "~" || rc == "~")
            return lc == "~" ? -1 : 1;

        if (digit_char(lc) && digit_char(rc)) {
            let ls = li, rs = ri;
            while (li < length(lhs) && digit_char(substr(lhs, li, 1)))
                li++;
            while (ri < length(rhs) && digit_char(substr(rhs, ri, 1)))
                ri++;

            let lnum = strip_leading_zeroes(substr(lhs, ls, li - ls));
            let rnum = strip_leading_zeroes(substr(rhs, rs, ri - rs));
            if (length(lnum) != length(rnum))
                return length(lnum) < length(rnum) ? -1 : 1;
            if (lnum != rnum)
                return lnum < rnum ? -1 : 1;
            continue;
        }

        return lc < rc ? -1 : 1;
    }

    return 0;
}

function version_at_least(current, required) {
    return version_compare(current, required) >= 0;
}

function first_index_any(value, needles, start) {
    value = as_string(value);
    start = int(start || 0);

    for (let i = start; i < length(value); i++) {
        let c = substr(value, i, 1);
        for (let needle in needles)
            if (c == needle)
                return i;
    }

    return -1;
}

function strip_first_scheme_marker(value) {
    value = as_string(value);
    let marker = index(value, "://");
    return marker >= 0 ? substr(value, marker + 3) : value;
}

function url_authority(value) {
    value = strip_first_scheme_marker(value);
    let at = index(value, "@");
    if (at >= 0)
        value = substr(value, at + 1);

    let end = first_index_any(value, ["/", "?", "#"], 0);
    return end >= 0 ? substr(value, 0, end) : value;
}

function url_get_host(value) {
    let authority = url_authority(value);
    let colon = index(authority, ":");
    print(colon >= 0 ? substr(authority, 0, colon) : authority, "\n");
}

function stdin_lines_to_json_array() {
    let input = read_stdin();
    if (input == "") {
        print("[]\n");
        return;
    }

    if (substr(input, length(input) - 1) == "\n")
        input = substr(input, 0, length(input) - 1);

    write_compact_string_array(split(input, "\n"));
}

function stdin_first_line_last_field() {
    let input = read_stdin();
    if (input == "")
        return;

    let newline = index(input, "\n");
    let line = newline >= 0 ? substr(input, 0, newline) : input;
    let trimmed = trim(line);
    if (trimmed == "") {
        print(line, "\n");
        return;
    }

    let fields = split(trimmed, /[ \t\r\n]+/);
    if (length(fields) > 0 && fields[0] != "")
        print(fields[length(fields) - 1], "\n");
    else
        print("\n");
}

let mode = ARGV[0] || "";

if (mode == "stdin-lines-to-json-array")
    stdin_lines_to_json_array();
else if (mode == "version-at-least")
    exit(version_at_least(ARGV[1], ARGV[2]) ? 0 : 1);
else if (mode == "stdin-first-line-last-field")
    stdin_first_line_last_field();
else if (mode == "url-get-host")
    url_get_host(ARGV[1]);
else {
    warn("Usage: core/helpers.uc <operation> ...\n");
    exit(1);
}
