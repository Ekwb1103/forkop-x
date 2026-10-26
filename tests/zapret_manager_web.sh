#!/bin/sh
set -eu
# Installing Zapret-Manager from Forkop also activates its web version
# ("w" in the script), keeps the Forkop mirror launchers, and removal takes
# the web version along.
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
ACTION="$ROOT/forkop/files/usr/lib/components/action.uc"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

ucode -e '
let fs = require("fs");
let source = fs.readfile(ARGV[0]);
function extract(name) {
    let start = index(source, "function " + name + "(");
    assert(start >= 0, name + " exists");
    let tail = substr(source, start);
    return substr(tail, 0, index(tail, "\n}") + 2);
}
let code = `
const FORKOP_MIRROR_BASE_URL = "https://mirror.test";
const ZAPRET_MANAGER_WEB_BACKEND = "/usr/libexec/rpcd/zapret-manager";
const ZAPRET_MANAGER_WEB_SCRIPT = "/opt/zapret-manager-luci/backend.sh";
let tmp_dir = "/t", files = {}, downloads = [], runs = [], download_ok = true, installer_ok = true;
let installer_text = "#!/bin/sh\\nread -r _ _ V <<EOF\\n# Version: 4.62\\nEOF\\n";
function as_string(v) { return v == null ? "" : "" + v; }
function read_file(p) { return files[p] || ""; }
function file_exists(p) { return files[p] != null; }
function remove_file(p) { delete files[p]; }
function updates_log(m) {}
function command_from_args(a) { return join(" ", a); }
function download_with_retry(url, path, label) {
    push(downloads, url);
    if (download_ok) files[path] = installer_text;
    return download_ok;
}
function run_logged(d, command) {
    push(runs, command);
    if (installer_ok) {
        files[ZAPRET_MANAGER_WEB_BACKEND] = "x";
        files[ZAPRET_MANAGER_WEB_SCRIPT] = "ZM_VERSION=\\"4.62\\"\\n";
    }
    return installer_ok;
}
` + join("\n", map([ "zapret_manager_web_installed_version", "zapret_manager_version_newer",
    "activate_zapret_manager_web", "zapret_manager_launcher_owned" ], extract)) + `
let script = "ZM_LUCI_URL=\\"$" + "{GH_RAW}/StressOzz/Zapret-Manager/main/ZapretManager_LuCI.sh\\"; ZM_LUCI_CACHE=x\\n";
function reset() { files = {}; downloads = []; runs = []; download_ok = true; installer_ok = true; }

assert(zapret_manager_version_newer("4.62", "4.6") && zapret_manager_version_newer("4.10", "4.9"), "newer");
assert(!zapret_manager_version_newer("4.62", "4.62") && !zapret_manager_version_newer("4.5", "4.62"), "not newer");

reset();
assert(activate_zapret_manager_web(script) == "", "fresh activation failed");
assert(downloads[0] == "https://mirror.test/zapret-manager/proxy/raw.githubusercontent.com/StressOzz/Zapret-Manager/main/ZapretManager_LuCI.sh", "installer URL: " + downloads[0]);
assert(length(runs) == 1 && index(runs[0], "sh /t/ZapretManager_LuCI.sh") == 0 && index(runs[0], "</dev/null") > 0, "installer not run non-interactively: " + runs[0]);
assert(!file_exists("/t/ZapretManager_LuCI.sh"), "installer left in tmp");

files[ZAPRET_MANAGER_WEB_BACKEND] = "x"; files[ZAPRET_MANAGER_WEB_SCRIPT] = "ZM_VERSION=\\"4.62\\"\\n"; runs = [];
assert(activate_zapret_manager_web(script) == "" && length(runs) == 0, "an up-to-date web version was reinstalled or removed");

files[ZAPRET_MANAGER_WEB_SCRIPT] = "ZM_VERSION=\\"4.50\\"\\n"; runs = [];
assert(activate_zapret_manager_web(script) == "" && length(runs) == 1, "an older web version was not updated");

reset(); installer_ok = false;
assert(index(activate_zapret_manager_web(script), "installer failed") >= 0, "installer failure not reported");
reset(); download_ok = false;
assert(index(activate_zapret_manager_web(script), "could not be downloaded") >= 0, "download failure not reported");
reset();
assert(activate_zapret_manager_web("no installer here") != "" && length(downloads) == 0, "script without ZM_LUCI_URL");

assert(zapret_manager_launcher_owned("exec sh <(wget -q -O - https://mirror.test/zapret-manager/proxy/raw.githubusercontent.com/Screamshow/Zapret-Manager/main/Zapret-Manager.sh)"), "mirror launcher");
assert(zapret_manager_launcher_owned("u=\\"https://raw.githubusercontent.com/StressOzz/Zapret-Manager/main/Zapret-Manager.sh\\"\\nt=\\"/tmp/zm-get.$$.sh\\"\\n"), "web installer launcher");
assert(!zapret_manager_launcher_owned("#!/bin/sh\\nmy own zms\\n"), "user launcher would be removed");
print("ok\n");
`;
let path = "/tmp/forkop-zapret-manager-web." + fs.readlink("/proc/self") + ".uc";
fs.writefile(path, code);
let status = system([ "ucode", path ]);
fs.unlink(path);
exit(status);
' "$ACTION" >/dev/null || fail 'Zapret-Manager web version activation'

# The web installer overwrites zms; Forkop writes its mirror launchers after it.
awk '
  /^function install_zapret_manager\(/ { f = 1 }
  f && /activate_zapret_manager_web\(/ && !web { web = NR }
  f && /write_zapret_manager_launchers\(/ && !launch { launch = NR }
  f && /^}/ { exit }
  END { exit !(web && launch > web) }
' "$ACTION" || fail 'mirror launchers are written before the web installer'
grep -A2 'write_file("/usr/bin/zmw"' "$ACTION" | grep -q 'zmw' && grep -Fq '"/usr/bin/zmw" ]' "$ACTION" ||
  fail 'the zmw command is not kept on the mirror'

# Removal refuses a foreign launcher before it removes anything.
awk '
  /^function remove_zapret_manager\(/ { f = 1 }
  f && /zapret_manager_launcher_owned/ && !own { own = NR }
  f && /remove_zapret_manager_web\(\)/ && !web { web = NR }
  f && /remove_file\(path\)/ && !rm { rm = NR }
  f && /^}/ { exit }
  END { exit !(own && web > own && rm > web) }
' "$ACTION" || fail 'removal order: ownership check, web version, launchers'
grep -Fq 'uci -q delete uhttpd.zmweb && uci -q commit uhttpd' "$ACTION" ||
  fail 'the web version removal does not drop its uhttpd instance'

echo 'Zapret-Manager web version is activated and removed with Forkop: OK'
