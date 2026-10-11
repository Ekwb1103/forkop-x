# Rust X 0.0.7: matched monitoring conditions

Update: 0.0.7 and 0.0.8 releases/tags were withdrawn at the user's request. Mirror latest is back at 0.0.6; the router now has a local build. See `rust-x-local-telegram-monitoring-2026-10-11.md`. Publication information below records the earlier state.

Source: `Screamshow/rust-x`, main commit `a0815a4499862ab2f84cad40fec0474d094cdfbd`.

Logical rules retain their complete expression in `rule`. The Clash API now also supplies the actual matching destination condition in `rulePayload`, which Forkop's existing monitoring UI already prefers. Successful inverted rules do not invent positive evidence; OR rules use the first successful branch.

Verification: four focused core monitoring tests, strict workspace/all-target Clippy, seven existing frontend route-reason tests, and an isolated OpenWrt 25 test passed.

On the user's router 192.168.90.1, the installed 0.0.6 initially returned 23 logical connections with empty payloads. At the user's explicit request, the signed aarch64 APK was installed from the mirror as 0.0.7-r1 and Forkop restarted. The package signature, length and SHA-256 were checked before installation. The previous signed 0.0.6-r1 package and UCI backups remain under `/root/rust-x-007-rollback` on that router. Both UCI checksums remained unchanged and the service reported running.

The production Clash API after installation returned two live `chatgpt.com` connections with `rulePayload=domain_suffix=chatgpt.com`; neither had an empty exact payload. This verifies the production API evidence used by the UI; the browser rendering itself was not inspected.

Release: https://github.com/Screamshow/rust-x/releases/tag/rust-x-v0.0.7

All seven GitHub asset digests match the signed local release. The mirror's public latest catalog, release manifest, and all four package lengths/hashes were verified for 0.0.7 revision 1.
