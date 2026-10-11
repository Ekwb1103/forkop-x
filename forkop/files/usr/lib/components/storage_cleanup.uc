let fs = require("fs");

function live(pid) {
    return match(pid || "", /^[1-9][0-9]*$/) != null && fs.stat("/proc/" + pid) != null;
}

function remove_tree(path) {
    let info = fs.lstat(path);
    if (info == null) return true;
    if (info.type != "directory") return fs.unlink(path);
    let entries = fs.lsdir(path);
    if (entries == null) return false;
    for (let name in entries) {
        if (name == "." || name == "..") continue;
        if (!remove_tree(path + "/" + name)) return false;
    }
    return fs.rmdir(path);
}

function recovery_files(path) {
    if (fs.lstat(path + "/.forkop-recovery") != null) return true;
    let legacy = fs.lstat(path + "/.forkop-owner") == null;
    for (let name in (fs.lsdir(path) || [])) {
        if (index(name, "rollback-") == 0 || index(name, "forkop-backup") >= 0)
            return true;
        // Old updater versions did not mark transactions, and their exact
        // rollback package can have an ordinary package filename.
        if (legacy && match(name, /\.(apk|ipk)$/) != null) return true;
    }
    return false;
}

function prune(root, staged_targets, now, directory_ttl, file_ttl, lock_path, current_owner) {
    let removed = 0;
    for (let name in (fs.lsdir(root) || [])) {
        let path = root + "/" + name;
        let info = fs.lstat(path);
        if (info == null) continue;
        if (info.type == "directory" && match(name, /^forkop-updates\.[A-Za-z0-9]+$/) != null) {
            let owner = trim(fs.readfile(path + "/.forkop-owner") || "");
            if (now - info.mtime < directory_ttl || live(owner) || recovery_files(path)) continue;
            if (remove_tree(path)) removed++;
        }
        else if (info.type == "file" && match(name, /^forkop-updates-(command|http)\.[A-Za-z0-9.]+$/) != null &&
            now - info.mtime >= file_ttl) {
            // Legacy standalone files have no reliable owner metadata. Keep
            // them while any component action owns the global lock.
            let owner = trim(fs.readfile((lock_path || root + "/component-action.lock") + "/pid") || "");
            let suffix = match(name, /^forkop-updates-(command|http)\.([0-9]+)(\.|$)/);
            if (suffix != null && live(suffix[2])) continue;
            if ((!live(owner) || owner == current_owner) && fs.unlink(path)) removed++;
        }
    }
    for (let target in staged_targets) {
        for (let path in (fs.glob(target + ".forkop-new.*") || [])) {
            let suffix = substr(path, length(target + ".forkop-new."));
            let info = fs.lstat(path);
            if (match(suffix, /^[1-9][0-9]*$/) == null || live(suffix) ||
                info == null || info.type != "file" || now - info.mtime < file_ttl) continue;
            if (fs.unlink(path)) removed++;
        }
    }
    return removed;
}

return { prune };
