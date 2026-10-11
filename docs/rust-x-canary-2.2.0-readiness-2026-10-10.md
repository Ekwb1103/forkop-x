# Forkop 2.2.0-canary.1 / Rust X 0.0.3 release verification

The requested candidate version is 2.2.0-canary.1, replacing the earlier
unpublished 2.3.0-canary.1 candidate. Earlier integration work and evidence
remain in rust-x-canary-2.3.0-readiness-2026-10-10.md.

## Rust X release

Tag rust-x-v0.0.3 points to c2fd1deb36013e0aa20a38659dd6e2416b75c2a2,
including the DNS response, remote rule-set and SIGHUP fixes. Cargo.toml and
all workspace Cargo.lock versions agree; dependency versions were preserved.
The missing x86_64 musl C compiler was added to the CI/build-all workflows.

The release workflow passed for x86_64 and aarch64. Its four APK/IPK assets
were signed using the existing mirror signer, without reading or copying
private key contents. APK signatures and all checksums passed. Package
identity, architecture, static ELF, embedded source commit, executable hashes
and the 12 MiB ceiling passed. Actual release executables are 11031392 bytes
(x86_64) and 8982120 bytes (aarch64).

Mirror latest.json and versioned manifests identify 0.0.3 and the exact tag
commit. Public downloads of all four packages match lengths and SHA-256;
the public signing key hash matches the signed manifest. Evidence:
tmp/rust-x-release-0.0.3/packages and public-check; tmp/verify-release003.py.

Focused 0.0.3 tests passed: 51 DNS, two reload and one runtime remote rule-set.
Formatting and profile/DirectProxy smoke passed. Evidence: tmp/rust-x-tools/
final003-*-tests.log, build-x86-003.log and build-arm64-003.log.

## Actual VM update

Six freshly built Forkop 2.2.0-canary.1 APK/IPK candidates were installed on
the existing VMware OpenWrt 24/25 VMs. The corrected candidate version was
applied without changing Forkop/core UCI. Both runtimes recovered.

Both VMs then used the ordinary Forkop component install action to update
Rust X from public mirror 0.0.2 to 0.0.3. Package preflight/update succeeded,
UCI hashes stayed unchanged, native config validation and DNS passed, LuCI
diagnostics show Rust X 0.0.3, and update detection reports latest. SIGHUP
with the actual generated Forkop config retained the native PID and DNS.
Both installed executable hashes match the actual release IPK payload.

Evidence: tmp/canary220/vm24-core-update.log, vm25-core-update.log;
VM evidence directories /tmp/release003-update.paaLdl (24) and
/tmp/release003-update.OmFmdd (25). Update harness:
tmp/release003-update-check.sh. The test VM snapshot requirement was waived
by the user; no customer system was used.

## Installed-package regression probes

The first repeat DNS fixture was rejected before startup because it omitted
the required default_domain_resolver. The reload entry point now validates
configuration. The fixture was migrated to an explicit resolver; this did
not change DNS matching, transport detours or the production config.

OpenWrt 25 passed all seven DNS scenarios with two distinct request IDs,
all seven reload checks (including invalid config and partial bind rollback),
and remote JSON/SRS rule sets with FakeIP, SOCKS and TProxy listeners.
OpenWrt 24 passed the same complete set. Fixtures launch isolated extra processes
using /usr/lib/rust-x/sing-box from the installed package, not a separate
candidate executable. Harness: tmp/release003-vm.py; per-VM results:
tmp/release003-vm*-*.json and tmp/canary220/*-regression.log.

## Scope and publication

Rust X remains experimental; Sing-Box X remains the default. QUIC and
bootstrap fallback changes are excluded. Earlier real-subscription evidence
belongs to 0.0.2 and is not presented as a repeated 0.0.3 transport audit.

The supported two-architecture release workflow is successful. The broader
build-all matrix still fails for MIPS/MIPSEL/RISC-V, outside the published
package architectures. Older Windows full-suite CI failed a DNS fixture;
latest overall CI has not completed successfully. These are not green-CI
claims or full compatibility certification.

Forkop candidate packages and exact hashes: tmp/canary220/packages and
manifest.json. Release notes: docs/releases/2.2.0-canary.1.md.
Rust X 0.0.3 is public at
https://github.com/Screamshow/rust-x/releases/tag/rust-x-v0.0.3;
all seven public GitHub assets match local signed lengths and SHA-256.
Temporary fixture files/processes were removed, test listener ports are free,
and installed Forkop remains running with DNS on both VMs.

Forkop 2.2.0-canary.1 is ready as an experimental Canary candidate within
the verified scope above. Forkop Canary has not been published. Prepared
bundle: tmp/canary220/Forkop-2.2.0-canary.1.zip. No broad CI or untested
platform compatibility claim is made.

## Supported-platform cleanup

At the user's request, Rust X now supports only OpenWrt x86_64 and
aarch64_cortex-a53. Linux tests/differential checks remain; CI, Cargo target
configuration and manual build/package scripts no longer select Windows,
macOS, ARMv6/v7, MIPS/MIPSEL or RISC-V. Workflow YAML and exact target sets
passed validation; both musl builds, shell syntax, two-archive checksums and
profile/DirectProxy smoke passed. This is build infrastructure cleanup;
the already published 0.0.3 release/tag/assets were not replaced.

## Canary publication

Published 2.2.0-canary.1 at the user's explicit request, with an empty release
body and exactly the six tested APK/IPK packages:
https://github.com/Screamshow/forkop-x/releases/tag/2.2.0-canary.1.
Source integration committed on existing main at
386172ae4bbdb2b07b59052dca30032a827d6bae; unrelated local changes preserved.
All uploaded asset sizes/digests match tmp/canary220/manifest.json.

Started forkop-canary-mirror.service; Result=success, ExecMainStatus=0.
Public canary.json, releases.json and versioned release.json identify the
new release; all six public package hashes match the tested candidate.
Automatic tag build 38046874855 was cancelled so it cannot replace the
already verified release assets with another build.
