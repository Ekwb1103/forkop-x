// Use separate physical stores: cache_id alone cannot isolate database formats.
// Preserve old stores for rollback; never delete user-configured cache files.
let common = require("core.common");
let fs = require("fs");

function family(version) {
    version = lc(common.as_string(version));
    if (index(version, "-rust-x.") >= 0 || index(version, "tachyon") >= 0)
        return "rust-x";
    if (match(version, /-x-[0-9]+[.]/) != null)
        return "x";
    if (index(version, "extended") >= 0)
        return "extended";
    if (index(version, "-lx") >= 0)
        return "lx";
    return "upstream";
}

function path(base, version) {
    base = common.as_string(base);
    // Leave the legacy database to upstream/Tiny. Other implementations get
    // dedicated sibling files, also when the operator configured a custom path.
    let name = family(version);
    return name == "upstream" ? base : base + ".forkop-" + name;
}

function cleanup_previous(previous, active, ready) {
    previous = common.as_string(previous);
    active = common.as_string(active);
    if (!ready || previous == active || previous == "" || active == "" ||
        substr(previous, 0, 1) != "/" || substr(active, 0, 1) != "/")
        return true;
    // Only the exact previously configured database. Never follow a symlink,
    // delete directories, sidecars or glob adjacent operator files.
    let info = fs.lstat(previous);
    if (info == null)
        return true;
    if (info.type != "file")
        return false;
    return fs.unlink(previous);
}

return { family, path, cleanup_previous };
