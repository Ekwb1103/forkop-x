# Rust X 0.0.5 publication

- Release: https://github.com/Screamshow/rust-x/releases/tag/rust-x-v0.0.5
- Source: 2e1a5994b956fadb33f7da153971671368558429
- Release workflow 38088191777 and OpenWrt platform builds passed.
- Focused verification: 57 DNS tests and 4 CLI rule-set tests passed; formatting passed.
- Signed APK r1 and IPK revision 1 for ARM64/x86_64: signatures, hashes, package identity, static ELF architecture and size budget verified.
- Mirror latest.json and releases/0.0.5/manifest.json agree; all four public package lengths and SHA-256 hashes verified.
- Released binary on VM25: 32 parallel DNS queries plus cached query required one A and one AAAA bootstrap request; malformed AAAA preserved successful A.
- VM25 regular Components update 0.0.4 -> 0.0.5 passed, including config validation, DNS, SIGHUP with same PID, unchanged UCI and latest UI version.
- VM update evidence: /tmp/release005-update.FCLPEk; initial state: /tmp/rust-x-release005-state.
- Existing Forkop 2.2.0-canary.1 retained. Router90 was not modified.
- General CI 38088189681 failed at strict Clippy: unused Direct::shutdown_socket and needless borrow at dns/mod.rs:184. Full CI must not be reported as passing. No runtime/test failure was reported by this job because the strict lint step stopped it.
