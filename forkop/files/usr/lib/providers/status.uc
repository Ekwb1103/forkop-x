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

function first_field(line) {
    let fields = split(trim(as_string(line)), /[ \t\r\n]+/);
    return length(fields) > 0 ? as_string(fields[0]) : "";
}

function stdin_first_nonempty_field() {
    for (let line in split(read_stdin(), "\n")) {
        let field = first_field(line);
        if (field != "") {
            print(field, "\n");
            return;
        }
    }
}

let mode = ARGV[0] || "";

if (mode == "stdin-first-nonempty-field")
    stdin_first_nonempty_field();
else {
    warn("Usage: providers/status.uc <operation> ...\n");
    exit(1);
}
