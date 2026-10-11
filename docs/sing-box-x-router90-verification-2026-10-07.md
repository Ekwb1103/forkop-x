# ARM64 router installation — 2026-10-07

Installed sing-box X 1.0.0, package revision 2, upstream 1.14.2, on the user-authorized GL-MT6000 at 192.168.90.1 (OpenWrt 25.12.5, mediatek/filogic, aarch64_cortex-a53).

The signed APK was downloaded from the Forkop mirror, SHA-256 checked and signature verified. The exact previous Tiny 1.13.21-r1 archive was obtained from the same mirror and its extracted binary compared byte-for-byte with the installed executable before replacement. The matching rollback archive hash is ce9ccc84dc3d2e57ca3948707d505fdb18a410bc6740137df3a89c260096f41f. OpenWrt's archived APK is unsigned (feed indexes normally carry signatures); it is locally staged for narrow offline rollback, with the archive hash and exact binary checked.

The ARM64 X executable accepted the existing configuration before the running package was changed. Forkop was stopped, Tiny removed and X installed offline without package scripts. The existing sing-box UCI settings were restored and Forkop was started normally. The generated runtime configuration was updated by Forkop for upstream 1.14.2.

The operator check initially caused premature rollbacks: absent asynchronous service state made jsonfilter exit nonzero under set -e, and exact UCI comparison was performed during startup's transient state. The check was corrected to wait for the actual running service and retain configuration snapshots. This was a test-script defect; final startup passed. Final Forkop and sing-box UCI hashes exactly match the original hashes.

Verified after installation:

- Package: sing-box-x 1.0.0-r2; executable reports 1.14.2-x-1.0.0.
- procd reports the sing-box process running.
- Clash API /version returns the installed X version.
- Local DNS resolution succeeds.
- Real HTTPS request through the configured mixed/SOCKS inbound at 192.168.90.1:2080 returns HTTP 204 from the Google connectivity endpoint.
- The generated configuration includes one gRPC outbound. This proves configuration acceptance, not an isolated end-to-end test of that particular outbound.
- Binary size: 8,534,028 bytes. Actual writable-overlay file allocation: 8,344 KiB (8.15 MiB). The previous Tiny executable allocated approximately 29.7 MiB.
- Observed RSS/HWM: 49,404 KiB with the user's real configuration (not directly comparable to the minimal VM benchmark).

Rollback packages and private configuration snapshots remain in a root-only temporary directory on the router. The GitHub release was subsequently recreated as stable 1.0.0 with no description, replacing the preliminary 1.0.0 and stable 1.0.0-r2 entries. It contains the exact validated revision 2 binary archives and packages; only release metadata and checksum lists changed. The mirror's latest.json now points to releases/1.0.0, and all seven public assets passed size and SHA-256 checks. Both mirror APK signatures verified. ARM64 and x86-64 packages are published. Editing the new release body through the GitHub API succeeds; the old entries returned HTTP 500.

The user retained application version 1.0.0 and requested a display-only correction. LuCI's Components and Diagnostics views now display **Sing-Box X 1.0.0**, without the Tiny suffix. The underlying version string 1.14.2-x-1.0.0 is preserved for configuration compatibility decisions. The backend recognizes the installed sing-box-x package and clears stale Tiny capabilities.

Display verification: 19 focused frontend tests passed, TypeScript checking passed, and the LuCI bundle rebuilt successfully. The deployed bundle retains Forkop version 1.16.5-canary.1. Its SHA-256 is 957a893448e4f628accf12fead63f612cca1e95f36d69f4388e0c26c4ba44360. After deployment, the core executable hash and process PID (32347) were unchanged, package 1.0.0-r2 remained installed, and sing-box check accepted the existing runtime configuration. The UI change required no core restart.
