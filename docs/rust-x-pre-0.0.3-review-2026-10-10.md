# Rust X 0.0.3 pre-release review

The review found confirmed SIGHUP termination in the installed Rust X
0.0.2. Forkop uses SIGHUP for DNS failover in service/state.uc:520. The core
waits only for SIGINT/SIGTERM, so a HUP kills it instead of reloading its config.
The isolated OpenWrt 25 probe started mixed TCP port 20156 and TPROXY TCP/UDP
port 20157 successfully, then reported `hup-exited` after sending HUP. No
installed service or configuration was changed. Evidence: tmp/pre003-hup.log.
Issue #5's listener failure is not reproduced by this minimal x86_64 VM probe;
the reported aarch64/full-config case remains unverified.

## Remote DNS rule-set

Upstream issue #8 applies to our source too: DnsService::build constructed a
second RuleSetRegistry while runtime startup fetched only the Router's one.
DNS therefore kept empty remote sets, even though logs reported successful
downloads on the Router's sets.

Local focused fix: runtime startup passes the Router's registry into DNS
construction. Rule Arc objects are shared for initial downloads, restored
cache and future replacements. Standalone DnsService::build remains available
for existing callers/tests. New integration test starts the actual runtime
with a localhost HTTP remote source set and proves DNS returns FakeIP.

Isolated VM25 baseline/candidate comparison passed for both JSON source and
compiled binary SRS sets served by localhost HTTP through SSH reverse forwarding.
Baseline returned 203.0.113.7; candidate returned 198.18.0.2. Both processes
opened mixed/TProxy ports and completed SOCKS5 negotiation. Evidence:
tmp/pre003-vm-results.json and tmp/pre003-vm-binary-results.json. Temporary
VM artifacts were removed; installed runtime PID 7660 and ready flag retained.

Tests on x86_64 musl: new remote DNS regression 1/1, existing compiled rule-set
interpreter-equivalence suite 9/9, DNS unit tests 51/51. Logs:
tmp/rust-x-tools/pre003-tests.log and pre003-build.log.

## Upstream PR #7 matcher changes

Do not copy the Never/catch-all changes blindly. Our pre-existing interpreter
ORs plain rule criteria and an empty object is false; upstream's newer matcher
uses conjunction across criterion groups and treats matcher-free objects as
catch-all. In our branch an empty compiled PlainRule is already false, so
malformed logical children do not gain a true match. Existing corpus includes
malformed logical children and empty objects and passes. Broader semantic
alignment would be a separate requested change.

## SIGHUP fix

The candidate reloads the original CLI file/directory sources on HUP, validates
before stopping the active runtime, aborts and awaits listener/background tasks
before rebinding, and restores the previous parsed configuration if candidate
startup fails. Partial startup tasks are stopped and awaited on errors too.
Remote rule-set recovery/updater tasks are now tracked with the box lifecycle.
Ignoring HUP is deliberately avoided: failover must apply the changed config.

Focused tests passed: same-port reload and partial-start rollback, configuration
validation, remote DNS integration, and all 51 DNS unit tests. Logs are
tmp/rust-x-tools/reload-tests.log and reload-build.log. The additional changes
preserve package/version identity; this is preparation for a separate release.

## Remaining before release

Completed in the follow-up: signed 0.0.3 package/mirror verification and
actual 0.0.2 -> 0.0.3 package updates passed on OpenWrt 24/25, including
installed-package DNS, remote JSON/SRS and reload regressions. Rust X 0.0.3
was published. See rust-x-canary-2.2.0-readiness-2026-10-10.md.

No version bump or release was performed by this review.

## Final verification

All seven reload checks passed on the existing OpenWrt 25 VM: startup,
changed DNS answer on the same ports, invalid JSON preserves the runtime,
partial bind failure restores the previous answer/listeners, subsequent reload
works, PID is unchanged, and SIGTERM releases listeners. Logs/results:
tmp/rust-x-reload-vm.log and tmp/rust-x-reload-vm-results.json; harness:
tmp/rust-x-reload-vm.py. Candidate files and processes were removed afterward.
Installed Forkop PID remained 7660 with watchdog ready. Package/service
snapshots were waived for these isolated test VM probes.

The six core source/test files were committed on our existing main as
`dc2f63e` (Share remote DNS rule sets and reload safely on SIGHUP).
