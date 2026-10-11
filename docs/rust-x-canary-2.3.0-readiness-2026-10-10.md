# Rust X integration in Forkop 2.3.0-canary.1

Date: 2026-10-10. Existing main branch; existing VMware OpenWrt 24/25 only.

## Implemented

Explicit `install_rust_x` component action and experimental installation choice.
Rust X identity recognized from package state and `1.14.2-rust-x.0.0.2` CLI
signature. LuCI component and diagnostic labels show `Rust X` with version
`0.0.2`; CLI diagnostics include `Rust X 0.0.2`. Compatibility baseline is
retained for configuration gates, while update comparison uses Rust X version
and package revision. Shared installer preserves installed Rust X on Forkop
upgrade; default new-install core remains Sing-Box X.

Own-core catalog resolver validates architecture/format, exact package filename,
mirror URL, version/revision, SHA-256 and length before package mutation.
The existing transaction stages exact rollback packages and dependencies,
measures extracted payload, checks runtime recovery and preserves UCI.
Rust X native executable is included in writable-file credit. IPK control
metadata accepts both `./control` and `control` archive members.
Diagnostic cache validity also checks the installed package identity, so a
cache populated by an opkg hook before package configuration cannot retain an
empty core package name for its one-hour TTL.

## Mirror

Published separate Rust X catalogs and package archives for 0.0.1 and 0.0.2:
https://mirror.51343.ru/forkop/rust-x/latest.json

Source release: https://github.com/Screamshow/rust-x/releases/tag/rust-x-v0.0.2
Binary source commit: 25c0cbf766e6cc1e410ee5a8cf5e352f6e7a706a.
APK revisions 0.0.2-r1; IPK revisions 0.0.2-1.
Both architectures: x86_64 and aarch64_cortex-a53.
Public HTTPS downloads of all eight archived packages matched catalog sizes and
SHA-256. Both 0.0.2 APK signatures verified with the mirror's existing public key.
No private key contents were read, copied or printed.

## Verification

- TypeScript noEmit check, frontend production build and 19 focused frontend
  tests passed, including separate Rust X/Go X identities and stale flags.
- build.sh produced six APK/IPK packages with release metadata validation.
- VM25: real mirror package update Rust X 0.0.1 -> 0.0.2; Rust X -> Sing-Box X
  -> Rust X; injected X package failure restored exact Rust X package and
  working runtime. UCI unchanged, generated config valid, DNS works.
- VM24: real mirror IPK update Rust X 0.0.1 -> 0.0.2. First attempt refused
  before mutation because the existing metadata parser required ./control;
  corrected parser passed, then installed and recovered normally.
- APK and IPK package metadata/storage preflight suites passed, including wrong
  identity/version rejection and exact extracted payload sizes of 11019509 and
  11019353 bytes respectively.
- Final six-package candidate installation/reinstallation on both VMs passed
  unchanged Forkop/core UCI, Rust X package detection, CLI version display,
  config validation, DNS, service recovery and Rust X update comparison.

Before each package/service mutation, VM package and service state was captured.
VM25 UCI hashes after transitions match original capture. Final VMs are intended
to remain on candidate Forkop and Rust X 0.0.2 for further testing.

## Real subscription limits

Subscription was downloaded by native Forkop and refreshed during its restart,
using the existing configured URL and client identity. No subscription URL,
node credentials or connection configurations are included in this document.
The generated runtime contained 59 TCP REALITY/Vision, two TLS XHTTP and one
REALITY gRPC node at test time (previous cache had 60 TCP nodes).

Temporary native processes used a localhost mixed inbound and copies of
generated production outbounds, without changing subscription UCI or selection.
Initial fixtures omitted a DNS detour. Two Vision and two XHTTP nodes passed
config validation but curl reported SOCKS failure (97). Follow-up debug logs
showed `dns: timeout after 5s`, before the HTTPS request. Rust X DNS transport
uses the router's default outbound when detour is absent; here that was the
selected proxy. Changing only the DNS server to localhost did not fix this.
Adding an explicit direct outbound and DNS `detour: direct` removed the timeout.
On the corrected fixture all five tested nodes (two REALITY/Vision, two
XHTTP/TLS, one gRPC/REALITY) returned HTTPS 200 / 577 bytes from example.com.
The initial negative transport compatibility conclusion was a test setup error
and is withdrawn. No released core or Forkop runtime configuration was changed
for this correction. These tests do not establish all-node or long-running
subscription support. Rust X remains explicitly experimental.

## Artifacts and publication

Candidate packages: `tmp/canary230/packages` (six files). Evidence and sanitized
before-state captures are under `tmp/canary230*`, and transition evidence is
on VM25 at `/tmp/forkop-rust-x-transition.plhhdF`.
No Forkop release tag or public Canary release has been published in this task.

## Publication gate after DNS/reload fixes

Rechecked on 2026-10-10: Rust X main is clean at dc2f63e, but GitHub and
the public Rust X mirror still publish 0.0.2 from 25c0cbf. That package does
not contain the new DNS, remote rule-set and SIGHUP fixes. Latest-commit
platform build is running and CI is pending; no successful final CI result
has been established. Previous platform build failed in several targets,
including x86_64-musl; its cause has not been diagnosed in this sync check.

Started forkop-canary-mirror.service successfully. Public canary.json,
releases.json and release.json agree on existing 2.1.1-canary.1; downloaded
all six public canary packages and verified their SHA-256 values. No 2.3.0
release exists to synchronize yet. Verification downloads are in
tmp/release-sync-check.

2.3.0-canary.1 remains blocked on publishing signed Rust X 0.0.3 packages,
verifying their public mirror metadata/hashes, and testing actual package
updates on both OpenWrt VMs. Earlier candidate tests used core 0.0.2 and
cannot substitute for those update checks.
