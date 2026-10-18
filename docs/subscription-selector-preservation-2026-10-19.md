# Manual selector preservation — 2026-10-19

The support report describes Forkop 2.3.6 with Xrust 0.0.23. At midnight a subscription refresh changed the generated config and restarted the core. Manual selectors in unrelated sections had first-member defaults. Xrust did not connect selector changes/restoration to its existing `selected` cache bucket; the subscription transition also omitted Forkop's selector snapshot/restore path. The previous subscription/config is unavailable, so the exact provider-side difference cannot be reconstructed.

Changes prepared on the existing main branches:

- Rust X: attach the existing cache to each Router, restore valid group/member pairs before listeners start, and flush accepted manual selections. Preserve the handle across hot reloads. Ignore removed/invalid members and retain the configured default. Persist the latest member under the cache lock so concurrent requests cannot write an older input over a newer choice.
- Forkop: save a private selector snapshot before stopping the owned runtime for subscription changes; restore surviving choices after startup and after rollback, before Priority/DNS workers. If capture fails, leave the running core intact. Unchanged generated configs retain the existing skip-restart guard. Snapshot restore failures produce a warning.

Scope: process restart preservation uses the existing configured cache file. Forkop currently puts the Rust X cache under /tmp; this does not make choices survive a router reboot that clears RAM. No release/version change, publication or customer installation is included.

Verification artifacts are local under tmp/selector-fix-20261019 (not for release commits).

Existing OpenWrt 25 VM 192.168.1.1 was identified as VMware x86/64, OpenWrt 25.12.5. Initial packages, service state, UCI, hashes, processes and nft rules were captured in vm25-before.txt before temporary processes were started. Installed baseline: Forkop 2.3.6, Rust X 0.0.19-r1. No installed binaries, services, UCI, packages or nft configuration were changed. Tests use synthetic subscriptions/configs, separate loopback API and temporary processes under /tmp.

Passed:

- VM ucode unchanged-config checks: equal configs/key order skip restart; server, selector order, DNS, routes and URLTest changes require apply; failed preparation/publication preserves the runtime.
- VM mocked readiness/rollback faults: startup/init/listener/recovery failures, capture before stop, restore before helper workers, capture failure leaves the original runtime running.
- VM live core with its existing cache enabled: raw process restart reproduces first-server reset. The fixed Forkop transition preserves Youtube/DS/Proxy manual choices when only Proxy changes; identical candidate retains PID; a removed member falls back only in its own group; failed apply restores previous config and selections. This executes the actual subscription transition/comparison and actual lifecycle snapshot/restore against live Clash API; cache downloading and service management are scoped test adapters, not the installed cron/UCI service.
- Rust focused integration test: disk contents before shutdown, restart, selection after hot reload/reordering, invalid requested member, removed selected member and cache-disabled fallback.
- Existing Rust tests: cache_file_interop 1/1, clash_api 6/6, hot_reload 9/9. The rust-x feature profile emits 14 existing dead-code warnings.

- Final source formatting check and focused selector test passed after the concurrency adjustment; final x86_64 musl release build completed. Test build still reports source version 0.0.23; it is not a published release. Binary SHA256: bc1b47af5caa13decbc288baa37b8a2227ddbd9e1874497c426b3d6bf5dfa7f8, verified after upload.
- Rebuilt core on VM: cached selections survive normal process restart and SIGKILL/new process; changed Proxy preserves all manual selectors; identical candidate retains PID; removed-member fallback and rollback preserve unaffected groups.
- Final installed Forkop/sing-box services remained running, the original main core PID 7736 remained active, all four captured config hashes were unchanged, installed Forkop/Rust X versions were unchanged, DNS through 127.0.0.42 resolved example.com, and expected nft tables remained present. No temporary test core remained running.
- git diff --check passed in both repositories. No full CI, router reboot, actual provider download comparison, public package release or customer-router installation was performed.
