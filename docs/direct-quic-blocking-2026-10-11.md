# Direct QUIC blocking, 2026-10-11

The existing disable_quic option rejected sniffed QUIC inside the proxy core
but did not cover forwarded direct traffic. Inspired by Tachyon 1.5.0's
direct QUIC rule, Forkop now adds its own quic_forward chain when this option
is enabled (default true). This applies to UDP destination port 443, not
protocol detection; other UDP protocols using that port are also rejected.

The inet forward chain runs at priority -1, after prerouting classification
and before fw4 forwarding/flowtable insertion. It matches only Forkop source
interfaces and tests the absence of the Forkop proxy mark bit. Other marks
(e.g. mwan3) do not exempt direct traffic. Local destination ranges and DNAT
traffic are preserved. Proxy interception and the existing in-core QUIC rule
remain unchanged. Router-originated output is outside this forwarded-client
rule. Already offloaded flows may require reconnection; no unrelated flow or
conntrack state is flushed.

Use reject with icmpx type port-unreachable rather than silent drop. It sends
an explicit IPv4/IPv6 error to the client instead of waiting for a packet-loss
timeout. Application fallback timing is implementation-dependent; instant
browser fallback is not claimed. Reference:
https://wiki.nftables.org/wiki-nftables/index.php/Rejecting_traffic

disable_quic is included in both nft runtime signatures, especially the
service reload snapshot: changing the option must rebuild nftables as well
as the core config.

## OpenWrt 24 verification

Only the existing VMware VM 192.168.241.2 was used (OpenWrt 24.10.8).
OpenWrt 25 was not accessed. Package and service snapshots were captured
before changes. socat was temporarily installed for packet tests and removed
afterward. The tests create three temporary network namespaces and veth pairs
inside this VM; they use the actual candidate helper in an isolated router
namespace, leaving the production firewall outside that namespace untouched.
Static IPv6 neighbors avoid asynchronous NDP timing in these short probes.

tests/disable_quic_direct_vm.sh passed:

- Option off: UDP/443 echo succeeds on IPv4 and IPv6.
- Option on: IPv4 and IPv6 UDP/443 return socket-visible Connection refused.
- Silent drop produces no explicit error and waits for the test timeout.
- Local IPv4/IPv6 destinations, TCP/443 and UDP/444 still pass.
- Proxy-marked IPv4/IPv6 UDP/443 passes; an unrelated mark does not bypass it.
- DNAT and traffic outside the source-interface set pass.
- Recreating the runtime with the option off removes the blocking behavior.

Both modified ucode modules compile on OpenWrt 24. The VM's installed module
baselines matched the repository except for this change. Temporarily applying
the candidate modules through the real Forkop restart/reload lifecycle created
the chain with the actual 0x04000000 proxy mark. Enabling/disabling the UCI
option rebuilt nftables and removed the chain after the reload completed.
The final disabled state reports running=1, enabled=1, dns_configured=1.
Tests wait for completed state; intermediate delete/recreate during async
reload is not treated as final success.

Evidence: /root/forkop-quic-test-20261011 and the namespace test output directory
on the VM. No customer-router installation or release publication is included.

Restoration verified: package list matches the initial snapshot exactly;
original nft/service-state modules compare equal; Forkop and sing-box UCI
checksums match. No test namespaces remain. Original Forkop is running with
DNS configured and local DNS answers; only the original fw4/Forkop tables remain.
