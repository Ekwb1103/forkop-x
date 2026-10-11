# Rust X 0.0.6 and Forkop X 2.2.1 canary

Date: 2026-10-11. Requested publication from existing main branches.

## Forkop X

Published 2.2.1-canary.1 from 72eee27655f13f2babdfcce2fdae1032eb7d39e0:
https://github.com/Screamshow/forkop-x/releases/tag/2.2.1-canary.1

Build workflow 38092213927 succeeded. All six APK/IPK GitHub asset lengths
and SHA-256 values matched downloaded build artifacts. The tag-triggered
duplicate workflow 38092520651 was cancelled before package publication.

Started the existing forkop-canary-mirror.service. GitHub's unauthenticated
release-list cache initially selected 2.2.0-canary.1; a later service run
selected 2.2.1-canary.1 and completed successfully. Public canary.json,
releases.json, the archived release.json and all six downloaded package
SHA-256 values agree.

## Rust X

Source: 3ac0522a7f1a406006b41e04f1ba4559dbcceb13. Experimental profile retained.
Ported upstream Trojan, process-stable random uTLS and hot-reload commits,
preserving upstream authorship and GPL-3.0-only. Adapted hot reload to the
existing Rust X DNS singleflight cache, shared rule-set registry and task
lifecycle. Remote rule-set downloads/endpoints prepare before live router
replacement; failed downloads preserve the old router.

Fixed strict Clippy without weakening -D warnings: removed unused direct
inbound helper, redundant DNS reference and unnecessary test mut bindings;
collapsed CLI format validation and handled partial HTTP reads in DNS tests.
Local workspace/all-targets Clippy and GitHub Clippy passed.

Focused tests: 57 DNS, four hot reload, three Rust X profile, five fingerprint,
nine TLS handshake, four CLI rule-set and one remote rule-set/DNS test passed.

Release workflow 38092956675 and platform workflow 38092941109 succeeded.
Signed APK r1 and IPK revision 1 for x86_64/aarch64_cortex-a53 verified with
existing mirror signing key; private signing key never copied or displayed.
Manifest, package identities/revisions, package hashes/lengths, source commit,
static ELF architecture, embedded binary hashes and 12 MiB budgets passed.
Binary sizes: x86_64 11126368 bytes, aarch64 9062248 bytes.

Existing OpenWrt 25 VM: captured package/service state and UCI hashes, then
ran only an isolated process in /tmp. Released binary validates existing
generated Forkop config. Active TCP HTTP request survived SIGHUP (HTTP 200);
invalid reload preserved working runtime. Installed core PID, Forkop service
and UCI unchanged; temporary process stopped. Evidence:
tmp/release006-vm-before.txt and tmp/release006-vm-result.txt.

Rust X 0.0.6 was observed public with publishedAt 2026-10-10T22:57:48Z:
https://github.com/Screamshow/rust-x/releases/tag/rust-x-v0.0.6
The finalizer used in this task left it as a draft; publication was observed
on recheck. All seven public GitHub assets match the verified signed packages
and metadata exactly by length/SHA-256. Published the existing signed staging
directory to the Rust X mirror with --latest. Public latest.json and archived
manifest.json agree; all four public package lengths/SHA-256 values verified:
https://mirror.51343.ru/forkop/rust-x/latest.json

Full CI 38092941112: workspace tests still running at final release check.
Strict Clippy, formatting, Rust X profile/config checks, differential harness,
both cross builds, platform and release workflows passed. Full CI must not
be reported as successful until its remaining test step completes.
