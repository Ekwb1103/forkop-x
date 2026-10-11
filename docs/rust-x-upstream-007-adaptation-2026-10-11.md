# Rust X: selected upstream v0.0.7 changes

Work on existing `artifacts/tachyon-core` main; no version change or publication.

Adapted Dushnilin/tachyon-core changes, preserving GPL-3.0-only and upstream authorship:

- `175bc007`: reject empty TLS records without indexing an empty handshake.
- `34c8c72f`: wipe software AES-GCM buffers after authentication failure, with forced software-backend coverage.
- `bcfceb61`: nonfatal route resolve errors; replace destination with the resolved IP and retain the domain. Adapted local/hosts bootstrap lookups into Rust X DNS implementation.
- `fcad38d2`: packet sniffers, authenticated QUIC v1/v2 Initial parsing, CRYPTO reassembly and SNI. Preserve Rust X route monitoring and existing single-packet API; add a multi-datagram entry point. UdpHub holds at most eight packets per pending flow and forwards them in order, or routes on timeout.

The existing RLIMIT_NOFILE behavior is equivalent and was retained.

Brutal (`e91f44f3`) was inspected but excluded. Its pacing_rate is reported through ControllerMetrics, which the installed Quinn 0.11.18 uses for statistics rather than pacing. The controller has no ACK/RTT window update; its fixed initial window cannot substantiate the advertised bandwidth behavior. Correct implementation and controlled throughput/loss verification remain a separate increment.

Validation:

- Empty TLS record regression passed.
- Software and selected native AES-GCM authentication/wipe regression passed.
- All 14 UDP integration tests passed: old DNS/QUIC regressions plus eight upstream packet tests, real DNS hijacking, split QUIC SNI routing, packet order and timeout fallback.
- Strict Clippy passed for core-runtime, core-tls and core-crypto, all targets.
- General runtime library run was interrupted after a non-root socket-options failure and a socket-connect test hang; no full-suite pass is claimed. Focused root reruns recorded separately below.
- Focused reruns passed: two resolve regressions, six QUIC reassembly/wire tests and both socket-options/connect tests under root. Together with TLS, AES-GCM and UDP integration coverage, 26 relevant tests passed.

No VM, router, installed package or service was changed. No release was built or published.
