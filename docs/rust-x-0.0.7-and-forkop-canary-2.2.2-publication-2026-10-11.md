# Forkop X 2.2.2 canary and Rust X 0.0.7 publication

Date: 2026-10-11. Requested build from existing Git main branches and mirror synchronization.

Forkop: 2.2.2-canary.1, source 1d21060b19ee523d5a97a02075d6790b7fb1147b.
https://github.com/Screamshow/forkop-x/releases/tag/2.2.2-canary.1
Workflow 38104784174 succeeded. All six GitHub APK/IPK asset sizes and SHA-256
matched downloaded build artifacts. Existing forkop-canary-mirror.service
completed successfully. Public canary.json, releases.json and archived
release.json agree; all six public package SHA-256 values verified.

Rust X: 0.0.7, source 54d4a96d413d1c994bcd3db3244db112d8d526fc.
https://github.com/Screamshow/rust-x/releases/tag/rust-x-v0.0.7
Only release metadata/version changed beyond the existing requested source.
Release workflow 38104796946 and platform workflow 38104795559 succeeded.
APK r1 signed on existing mirror with existing signing key; key never copied
or displayed. IPK revision 1. Both x86_64 and aarch64_cortex-a53 verified:
signatures, identities, revisions, manifest hashes/lengths, source commit,
embedded binary hashes, static ELF architecture and <=12 MiB budgets.
Binary sizes: x86_64 11136416 bytes, ARM64 9071128 bytes.
All seven published GitHub assets match local signed artifacts by size/SHA-256.
Mirror latest.json and releases/0.0.7/manifest.json agree; all four public
packages downloaded and checked by length/SHA-256.
https://mirror.51343.ru/forkop/rust-x/latest.json

Existing VM25: captured package/service state before isolated /tmp process.
Released binary validates existing generated config; HTTP 200 after active
TCP session survived SIGHUP; invalid reload preserved runtime. Installed
core PID, service and UCI unchanged; temporary process stopped.
Evidence: tmp/release007-vm-initial.txt, tmp/release007-vm-before.txt,
tmp/release007-vm-result.txt. No customer router installation performed.

CI 38104795437: formatting, strict Clippy, Rust X profile/config, differential
harness and both cross builds passed. Full workspace test step still running
at final check; full CI must not be reported as successful yet.
