// Single compatibility contract used by LuCI and procd.
let fs = require('fs');
let pipe = fs.popen('ucode /usr/lib/forkop/core/constants.uc get FORKOP_VERSION', 'r');
let version = pipe ? trim(pipe.read('all') || '') : '';
if (pipe) pipe.close();
let parts = match(version, /^([0-9]+)\.([0-9]+)\.([0-9]+)([-_].*)?$/);
let supported = parts && (int(parts[1]) > 2 || int(parts[1]) == 2 && (int(parts[2]) > 3 || int(parts[2]) == 3 && int(parts[3]) >= 4));
if (ARGV[0] == 'check') exit(supported ? 0 : 1);
print(sprintf('%J\n', {version, supported:!!supported, minimum:'2.3.4'}));
