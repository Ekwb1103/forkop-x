# Subscription hot reload and alert — 2026-10-19

Forkop subscription updates now use the existing acknowledged Xrust hot-reload planner. Equal generated configs still skip all runtime changes. Unsupported cores or restart-only configuration changes use the existing restart path with selector preservation. A failed hot apply does not fall through to a restart: it restores the old core config, section UI cache and manual selections. Rollback snapshots include selections because a rejected candidate can remove a formerly selected member and prune its core cache entry.

A single private JSON alert lives in /var/run/forkop/subscription-apply-error.json. LuCI receives it through the existing UI state polling, including when the page opens after a nightly failure. Messages distinguish previous config still active, failed recovery, and auxiliary-service errors; Russian translations are included. There is no intervention instruction. Successful subscription apply clears the file and displayed alert. A failed apply remains eligible for retry even when the subscription source cache already contains the new response. The file is replaced, not appended; no new polling timer or event history is added.

Verification was deliberately focused:
- VM ucode transaction tests passed: hot apply, cold fallback, failed commit/ack, successful rollback, failed rollback and persisted alert. Existing unchanged-config and cold readiness/rollback checks passed.
- One live OpenWrt 25 VMware scenario executed the actual subscription update function, actual hot-reload planner/apply/restore, and config/UI-cache commit routines against an isolated test core. Provider fetching, service ownership and auxiliary workers used scoped adapters; installed services, UCI and packages were not changed.
- A real SSH/TCP connection was opened through the test core to the VM SSH daemon. It remained open through subscription application and rollback after an injected missing acknowledgment. PID and manual choice remained the same. The rollback candidate removed the selected server; the original selection was restored from its snapshot. The previous config and UI cache were restored, and the RAM alert reported previous/hot_apply_failed.
- Backend modules compiled. TypeScript checking, changed-file ESLint and the LuCI production build passed. The alert text has a focused frontend test.
- Original installed core PID 7736, running service states, package versions and all four configuration hashes remained unchanged. Test processes and VM temporary files were removed.

Local evidence: tmp/subscription-hot-20261019. No release was published and no customer router was changed. The test does not claim real-provider interoperability or a long memory soak.
