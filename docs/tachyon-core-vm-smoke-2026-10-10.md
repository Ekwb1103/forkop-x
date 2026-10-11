# Tachyon core v0.0.1 VM smoke test

Tested the published x86_64 musl release on the existing VMware OpenWrt
25.12.5 (192.168.1.1) and 24.10.8 (192.168.241.2) VMs on 2026-10-10.
Package and service state was captured before staging. No backups requested.

Release archive SHA-256 matched published SHA256SUMS:
`35280ba1fd4e9cf8788b495cdc86ae0e1953366c9be72ae924d85d073dfbdde2`.

Binary and fixtures were staged under `/tmp/forkop-tachyon-core-test`.
No package install, UCI change, firewall change or main service restart was
performed. Temporary processes were stopped by EXIT traps.

Both VMs passed:

- `version`: tachyon-core 0.0.1.
- `check -c /etc/sing-box/config.json`: exit success against existing config.
- Standalone run with mixed inbound at 127.0.0.1:15480, DNS at :15453 and
  Clash API at :15490.
- HTTP example.com through SOCKS5 with remote hostname resolution: HTTP 200.
- FakeIP example.com A: 198.18.0.2; AAAA: fc00::2.
- Real DNS github.com A: public address returned.
- Clash `/version`: JSON response.

RSS after smoke traffic: 8076 kB on OpenWrt 25, 7984 kB on OpenWrt 24,
three threads each. This is a small direct/DNS fixture, not a production
memory benchmark or comparison with X.

Installed sing-box processes retained PIDs 20977 (25) and 22751 (24).
Local evidence: `tmp/tachyon-core-vm`, including before/after state and
smoke script/output. No active core process remained after the tests.

Full Forkop traffic interception, existing configuration runtime, real proxy
subscriptions, REALITY, Vision, XHTTP, gRPC, remote SRS and long-running load
were not tested. Existing configuration acceptance proves validation only.
