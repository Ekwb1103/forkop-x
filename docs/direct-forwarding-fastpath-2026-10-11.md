# Direct forwarding fast path

On GL-MT6000, Steam downloading to 192.168.90.201 slowed while Forkop was
running despite zero TCP TPROXY counters. Temporary early returns for Steam
CDN traffic in mangle and proxy improved observed speed; removing them changed
666.4 Mbps to 580.4 Mbps. These are instantaneous observations, not a controlled
throughput benchmark. Mihomo remained unchanged throughout the comparison.

The code change adds two guards to the existing generated runtime:

- mangle returns for ingress interfaces outside the configured client set.
  All existing prerouting classification rules already require that set.
- proxy returns when the Forkop mark bit is absent. Marked packets remain
  eligible regardless of other mark bits or ingress interface, preserving
  router-originated rerouting and coexistence with mwan3.

No conntrack caching or established-flow bypass is introduced. Client packets
continue to be classified on every packet, preserving late destination-set
updates, section priorities, exclusions and FakeIP handling. DNS, output
classification, QUIC filtering and policy routes are unchanged.

Validation on the existing OpenWrt 25 VMware VM used a separate /tmp checkout:

- tests/nft_atomic_apply.sh passed.
- tests/nft_direct_fastpath_vm.sh passed nft syntax validation and real ICMP
  packet checks in disposable namespaces: non-client ingress skips
  classification, client ingress continues classification, unmarked traffic
  skips interception checks and Forkop plus mwan3 marks remain eligible.
- Initial tests/ipv6_tproxy.sh runs exposed an existing nft/reload signature
  mismatch, also reproduced on HEAD: state.uc serialized disable_quic before
  the other runtime settings, whereas apply.uc serialized it after them.
  Aligning state.uc with the generator fixed the mismatch. The full test now
  passes, including added checks for both QUIC settings and the enabled default
  in every IPv6 detection mode. No assertion was removed from the test.
- kmod-veth was temporarily installed for namespace testing and removed;
  namespaces were deleted. Installed Forkop files and services were untouched.

The new guards have not been installed on 192.168.90.1. Their performance
benefit still needs a router comparison; the Steam-specific bypass bypassed
more checks and is not equivalent to this conservative change.

## Follow-up localization and revision

Live application of the two guards alone did not materially improve Steam
speed (557.8 to 566.6 Mbps). A priority_rules-only bypass did not help; bypassing
only common classification or only the initial DNAT/local-address checks gave
small changes reported by the operator as indistinguishable from noise.
Bypassing priority and common classification together while retaining the
initial checks improved the same download from approximately 520 to 580–610
Mbps. Removing that bypass immediately reduced speed again. All live probes
were removed, including their temporary chain.

The next code revision hoists the client-interface membership check and removes
18 repeated checks inside mangle. All destination/protocol/port checks, priority
rules and mark assignments remain. The full IPv6, atomic nft and namespace
packet tests passed again. No direct-flow conntrack cache is used.

Throughput improvement from this revision is not yet established. At the
attempted follow-up measurement the download had ended (WAN received only
56,279 bytes in two seconds), so no live revision was applied. Router counters
can provide subsequent comparisons without requiring operator screenshots;
application throughput and unrelated background traffic must still be
distinguished.

## Automated router comparison

After the operator restarted Steam downloading, the interface-hoist revision
was tested with a temporary chain containing the existing mangle rules minus
their repeated interface conditions, guarded once at entry. A temporary goto
redirected mangle processing to that chain; no service was restarted. Cleanup
removed the goto and chain automatically.

The first cycle contained a seven-second download pause and was inconclusive.
A second cycle sampled 25 times per phase without scanning conntrack each
second. Excluding the first three samples of each phase, WAN receive rates
were 621.4 Mbps baseline, 759.7 Mbps patched, and 662.9 Mbps after rollback.
Aggregate CPU busy fractions were 73.9%, 70.6%, and 75.0%, respectively.
These are interface rates including protocol overhead and background traffic,
not Steam application rates. Steam's own content log also recorded rates of
530.507 and 583.376 Mbps during the overall comparison period, but its update
interval is too coarse to assign each line to a complete measurement phase.

The patched WAN rate was 22.3% above the first baseline and 14.6% above the
rollback phase. This supports a performance benefit under this workload; it
does not establish an invariant gain for every device or traffic pattern.
The router was restored to its original rules, verified without temporary
codex rules or chains. No installed source file was changed on the router.

## Synthetic core routing comparison

On OpenWrt 25, three disposable network namespaces generated traffic through
the original and optimized nft generators with mirror-verified Sing-Box X
1.0.3 and the existing Rust X 0.0.7 binary. Neither core was installed or
reconfigured in the VM's normal service. The operator's Mihomo stayed active.

Both generators produced identical scenario outcomes for both cores:
client TCP, router-originated TCP and explicitly excluded client TCP passed.
The excluded connection did not increment the TCP TPROXY counter. Client UDP
passed for Sing-Box X but received no response for Rust X. Router-originated
UDP received no response for either core. These three failures also occurred
with the original generator; their cause is unresolved and may involve the
synthetic harness. This is not a complete UDP or subscription transport
compatibility validation, nor evidence of a patch-induced UDP regression.

The harness is tests/core_tproxy_fastpath_vm.sh. Baseline and patched outputs
are retained locally under tmp/speed-diagnostic/core-routing-*.log. Disposable
namespaces were removed, temporary socat and kmod-veth packages uninstalled,
and the VM returned to 225 packages with Forkop running.

## UDP harness localization (2026-10-11)

The failures above were resolved by correcting the test fixture. No core or
production nft change was necessary. Repeating the corrected test with both
the archived original generator and the optimized generator passed every
scenario for Sing-Box X 1.0.3 and Rust X 0.0.7 on the existing OpenWrt 25 VM.

Read-only packet diagnostics and isolated namespace probes established:

- The original socat UDP echo fixture stopped answering subsequent probes:
  plain client UDP passed, but plain router UDP already failed before loading
  nft rules or starting a core. Requests reached WAN, with no echo response.
  Adding server `ignoreeof` was insufficient for the full sequence.
- The stream-based socat client emitted a zero-length UDP datagram at stdin
  EOF. With a deterministic echo server, Rust X returned both datagrams, but
  the empty reply could precede the token reply. The trace showed the token
  reaching the client interface after the empty reply while socat reported an
  empty result. This was an invalid stream-EOF assumption in the UDP probe,
  not evidence that the Rust X inbound failed to receive or route UDP.
- Debug Rust X logs recorded both client and router UDP and selected
  `Outbound(0)`. The earlier info-level logs did not expose this packet path.
- `ip route get` selected WAN with source 11.0.0.2 for unmarked traffic and
  mark 0x08000000; mark 0x04000000 selected the local route in table 305.
  nft traces confirmed interception mark 0x04000000 and the direct socket's
  0x08000000 output bypass. WAN responses were unmarked and not reclassified.
  Reply packets retained source 11.0.0.1:18081 and reached either br-lan for
  the client or loopback for the router's original UDP socket.
- Both cores passed the corrected UDP probe in the diagnostic topology
  without a default route. Sing-Box's missing-default-interface message was
  therefore not the cause of this failure for the connected echo destination.
  The maintained harness now includes a WAN default route for realism.

`tests/helpers/udp_echo.c` replaces UDP socat on both ends. It uses datagram
socket operations, verifies three sequential payload exchanges on the same
socket and a valid empty exchange, and treats timeouts as failures. TCP still
uses socat. The harness first checks plain client/router UDP without nft,
then checks both cores, verifies increasing UDP TPROXY counters, and verifies
excluded client TCP and UDP without increasing their interception counters.
Cleanup also kills remaining namespace processes before deleting namespaces.
The fixture needs gcc (or CC), already installed on this VM.

Local evidence: `tmp/speed-diagnostic/udp-final-baseline.log`,
`udp-final-patched.log`, `udp-fixed-trace/` (packet and nft traces, core logs),
and `udp-stream-eof-trace/` (the empty-reply ordering observation). These are
focused direct/TPROXY echo checks, not subscription or transport compatibility
certification. Both production cores and the nft optimization remain unchanged.

Package versions and service state were captured before temporary installation
of socat, kmod-veth, tcpdump and libpcap1. All four additions were removed;
the final package list exactly matched the initial 225 packages. All service
instance running states and PIDs matched the initial snapshot, including
Forkop and its core; no namespace remained. Mihomo and 192.168.90.1 were untouched.
