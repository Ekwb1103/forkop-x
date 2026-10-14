# DNS continuity during Forkop restart

The operator router showed dnsmasq restoring upstream resolvers between stop
and start during a manual restart. This can give clients real addresses that
remain cached after FakeIP policy is active again. This is a plausible cause
of the reported chatgpt.com symptom, not a confirmed explanation of every case.

Restart now stops only the runtime, retaining the DNS transaction and its
local forwarding. The successful start reuses that configuration. Explicit
Stop and failed restart retain the existing DNS rollback. The init.d restart
override uses a serialized runtime transition and keeps the registered
watchdog; restart of an already stopped service still uses normal Start.

Verified on existing OpenWrt 25 x86_64 VM 192.168.1.1 with Forkop 2.3.1_rc1
and Rust X 0.0.12-r1. Package/service state was read before changes; no backup
was created. Only lifecycle.uc, initd.uc and the Forkop init script were
deployed. UCI proxy policy and packages were not changed.

`tests/dns_restart_vm.sh` passed:

- CLI, init.d and manual restart each retained dnsmasq PIDs and the exact DNS
  transaction ID. Each sampled run returned eight FakeIP replies and one
  temporary retry, with no real-address reply or upstream UCI configuration.
- Explicit Stop consumed the DNS transaction and restored the resolver.
- Injected configuration generation failure rejected Restart and restored DNS.
- Subsequent Start recovered; example.com returned 198.18.0.2 and both Forkop
  and its procd DNS watchdog were running.
- ucode load checks, init shell syntax and git diff whitespace checks passed.

The VM uses a baseline/direct policy with example.com configured for FakeIP;
this verifies DNS lifecycle, not real subscription egress or browser behavior
for chatgpt.com. The operator router 192.168.90.1 was not modified. Existing
client caches, client DNS timeouts, and established connections are separate
diagnostic questions. Cold machine boot and core package transitions were
not tested by this change.
