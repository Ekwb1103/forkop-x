# Component restart state capture, 2026-10-11

On 192.168.90.1, switching Extended to Rust X installed rust-x 0.0.7-r1
but logged `Forkop was not running before component change; restart skipped`.
The watchdog subsequently stopped Forkop and restored dnsmasq. A manual
Forkop start recovered DNS and HTTPS through SOCKS (HTTP 204).

The component installer previously captured only strict runtime readiness
through `get_status`, bounded by a six-second timeout. That check includes
stable process age, runtime ports, Clash API and networking. A failed check
cannot distinguish an explicit Stop from an active but temporarily unready
managed runtime. The exact failing readiness predicate during the original
switch was not captured.

Capture now additionally recognizes a completed active lifecycle through
watchdog.ready, shutdown_correctly=0, and the verified procd-owned core
process. Explicit Stop removes the ready marker and records shutdown=1.
Legacy strict-status fallback and post-install readiness/rollback remain.

Validation: six executable cases in tests/component_running_state.uc cover
failed readiness with an active lifecycle, explicit Stop, stale markers,
standalone cores and legacy healthy runtime. They pass on OpenWrt 25 VMware
and the router. The entire modified module compiles with both ucode runtimes.
An isolated capture probe on the existing VMware VM uses its actual UCI,
ready marker and procd-owned core, with readiness forced false; it passes.
VM packages, configuration and services were not changed.

The router's installed action module matched the repository baseline apart
from this patch. The patch was applied atomically, with the previous module,
package/service snapshots and configuration checksums retained under
/root/forkop-component-restart-fix-20261011. Both UCI hashes remained unchanged;
Forkop/core status reports running, DNS configured, and HTTPS through SOCKS
returns 204. No production variant round trip or new release was performed.

## Full VMware transition verification

At the user's request, the existing OpenWrt 25 VM (192.168.1.1) was tested
through the actual component action installer with the patched module.
Before mutations, package/service snapshots, UCI files, the original module,
core files and variant/version markers were saved. Exact original Rust X
0.0.5-r1 x86_64 rollback APK was fetched from the mirror and verified against
the archived manifest (4,754,705 bytes, SHA-256
13086bc52349278d989330ad8c5f4907a091a1a120e2a82a8e20d069046f7228)
and trusted APK signature.

Both real actions succeeded: Rust X 0.0.5 -> Extended 2.7.2 -> Rust X 0.0.7
(the current mirror catalog selected 0.0.7-r1 during this test). The journal
records stopping Forkop before replacement and restarting it afterward.
Forkop reports running=1, enabled=1, dns_configured=1; local DNS answers and
HTTPS to gstatic generate_204 returns 204 after the Extended -> Rust switch.

The first Rust action could not fetch the mirror catalog because mirror DNS
resolved to an unusable cached FakeIP after the Extended transition. It failed
before mutation. The test temporarily pinned mirror.51343.ru in the VM hosts
file to its actual address, confirmed through DNS-over-HTTPS. The retried action
used the original HTTPS mirror URL and normal package validation. Hosts was
restored afterward. Initial SOCKS probes were invalid for this VM configuration:
it has no mixed/SOCKS inbound; the final HTTPS probe used its normal network path.

The original signed Rust X 0.0.5-r1 was restored along with the original module,
UCI files, hosts and version markers. Installed package list exactly matches
the initial snapshot. Both Forkop/sing-box UCI SHA-256 values match; original
module and hosts compare equal. Forkop is again running with DNS configured.
Evidence remains in /root/component-restart-vm-20261011 on the VM. The customer
router was not changed during this verification.
