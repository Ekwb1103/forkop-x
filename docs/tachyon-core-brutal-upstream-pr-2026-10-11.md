# Brutal upstream PR

PR: https://github.com/Dushnilin/tachyon-core/pull/17

Base: upstream main `ecba3d136103d226b98838c28e1d4e1ea039efb0`.
Commit: `d022ff49e2ee4047a003f5f0784ba95395ad859d`.
Checkout: `artifacts/tachyon-core-brutal-pr`, branch `fix-brutal-pacing`.
Rust X checkout and its existing local changes remain separate on main.

The original upstream controller advertised a rate in qlog metrics, but Quinn's
actual pacer used its unchanged cwnd/RTT path. ACK/RTT callbacks were absent;
the fixed window also divided an already-byte-valued send_bps by eight.

Implemented explicit byte-rate pacing in vendored quinn-proto 0.11.18,
RTT-sized window, five-second packet samples, minimum 50 samples, ACK-rate
floor 0.8 and idle expiry. BBR/Cubic/NewReno keep the original pacing path.
Quinn licenses retained; the algorithm reference is apernet/hysteria Brutal
at f2ad1de5da52a1da9622285a1d61553ddaa41f21 (MIT).

Local checks passed before PR creation:

- workspace formatting and strict Clippy;
- 1355 workspace tests, 19 ignored (the controlled throughput experiment is
  explicitly executed separately and in Linux CI);
- seven tests against the exact vendored pacer, included in workspace CI;
- 61 privileged checks in isolated WSL network namespace (exit gate 1,
  inbounds 12, SO_MARK 2, server inbounds 46);
- strict differential: 251 passed, zero failures/gaps against
  sing-box-lx 1.14.2-lx.11;
- static musl test executable on existing OpenWrt 25 VM, controlled loopback
  QUIC stream delivery at RTT 20/200ms and every tenth client packet dropped.
  Finite 1 MB transfers at configured 500000 bytes/s measured
  484610 / 441662 / 368161 bytes/s respectively. These include stream
  completion time and do not establish steady-state WAN/Hysteria-server rates.

VM package/service snapshots before/after were identical; installed core PID
and hash remained unchanged. Temporary files/processes were removed. No UCI,
firewall, package or service mutation was performed.

Existing upstream check blockers were fixed narrowly: loopback SO_MARK test
expectation (runtime already bypasses loopback mark/interface), byte-char-slices
Clippy warning in desync, and rustfmt layout in rule_set_remote. Runtime
behavior of these modules was not changed.

Evidence: `tmp/brutal-preflight-final.log`, `tmp/brutal-full-checks-final.log`,
`tmp/brutal-privileged.log`, `tmp/brutal-musl-test.log`,
`tmp/brutal-vm-wire.log`, `tmp/brutal-vm-before.txt`, `tmp/brutal-vm-after.txt`.
GitHub CI: https://github.com/Dushnilin/tachyon-core/actions/runs/38143638486

GitHub CI completed successfully on d022ff49e2ee4047a003f5f0784ba95395ad859d.
All seven jobs passed on the first publication: Linux, Windows, differential,
x86_64, aarch64, ARMv7 and MIPS. Linux explicitly ran the controlled QUIC
transfer test; all four cross-build size budgets passed. PR description updated
with the confirmed results. No replacement commits or CI reruns were needed.
