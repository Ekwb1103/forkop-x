# Random TLS fingerprints upstream PR

PR: https://github.com/Dushnilin/tachyon-core/pull/11

Upstream base: `03f0db726aa808f7bff44a4a1a9ec0a47b51a96d`.
Single commit: `ada3c852bc03665e03e8473216c3fc9ff7e18918`.
Worktree: `artifacts/tachyon-core-random-pr`, branch `utls-random-profiles`.
The Rust X checkout remains on its existing main branch.

The attached startup log and the existing Rust X 0.0.5 binary on VM25
reproduce the same missing policy dispatch present in upstream v0.0.5/main:
configuration check accepts random/randomized, but runtime construction
rejects both. The VM baseline is Rust X, not a separately downloaded upstream
release binary; the candidate is built directly from the upstream PR source.

Random chooses one of the same five browser presets as the reference once
per process. Randomized is a native randomized modern profile with stable
process policy and fresh handshake crypto. It does not reproduce uTLS's
seeded generation distribution. ALPN and the hybrid group/share are retained.
The table generator also retains the policy dispatcher when regenerated.

Local validation: whole-workspace formatting and strict Clippy passed;
1269 workspace tests passed, 18 ignored. TLS tests include 64 deterministic
generated-profile handshakes, and 40 process restarts passed TLS/h2 plus
REALITY session-ID sealing. No full deployed REALITY or subscription gRPC
interoperability claim is made.

Privileged validation: exit gate (1), inbounds (12), mandatory SO_MARK tests
(2) and server inbounds (42) passed in an isolated WSL network namespace.
In the ordinary WSL root namespace, the unchanged redirect-without-NAT test
failed because conntrack returned its own listener as SO_ORIGINAL_DST,
causing recursive self-connects. In a fresh namespace the expected ENOENT
occurs and the entire suite passes. No redirect implementation or test was
changed for this TLS PR.

Release x86_64 musl build passed: 13229904 bytes, SHA-256
`6964f300da7c9b20cc020cfd10d5cdb9e2ce13240f43c04f654dd0ec4565bb35`.
VM25 candidate startup passed random/randomized, each with TLS and REALITY.
Only temporary files and isolated loopback processes were used. Package and
service state was captured first; installed sing-box service state and PID
were unchanged after each probe phase. Temporary VM files were removed.

Two existing formatting-only failures in current upstream main were included
to unblock CI. No dependencies, versions, releases or packages were changed.

Evidence: `tmp/random-pr-checks.log`, `tmp/random-pr-process-draws.log`,
`tmp/random-pr-privileged-netns.log`, `tmp/random-pr-musl.log`,
`tmp/random-pr-vm-state-before.txt`, `tmp/random-pr-vm-baseline.json`,
`tmp/random-pr-vm-candidate.json` and corresponding before/after service
snapshots. GitHub CI run: `38090014699`; all seven jobs passed on the first
published commit. Linux, Windows, differential, x86_64, aarch64, ARMv7 and
MIPS are green. No further code commits or replacement PRs were needed.
