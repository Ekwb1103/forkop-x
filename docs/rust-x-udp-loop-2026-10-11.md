# Rust X / Forkop UDP loop diagnostics, 2026-10-11

## Scope and observed state

Read-only SSH diagnostics on the operator's local GL-MT6000 at 192.168.90.1.
No packages, settings, rules or service state were changed by this investigation.
OpenWrt 25.12.5, Linux 6.12.94; Forkop 2.2.5_rc1; Rust X 0.0.8-r1.
The log records replacement of sing-box-x 1.0.4-r1 with rust-x 0.0.8-r1.

The same Rust X PID 8041 reached 4093/4096 file descriptors, fell to 38
without a restart, and subsequently reached 4096 again. TPROXY reports
`No file descriptors available (os error 24)`. This is repeated session
amplification, not evidence of a permanently unreleased FD leak.

Forkop counters initially showed one LAN UDP packet to FakeIP and 6108
locally generated UDP packets to FakeIP, with 6109 TPROXY UDP packets.
Later the LAN counter was two and the output counter was 12222.
Live UDP endpoints include WAN-source sockets to 198.18.0.50:443 and
transparent reply sockets in the opposite direction. Conntrack contains many
different source ports for that same FakeIP destination, without replies.

## Required Forkop correction: own-traffic bypass

`forkop/files/usr/lib/nft/apply.uc:949` emits an exact equality check:

```
meta mark 0x08000000 counter return
```

The active mwan3 OUTPUT hook uses the same mangle priority and adds bits in
mask 0x3f00. Its policy selects 0x100; combined marks such as 0x08000100 no
longer satisfy Forkop's exact equality. `priority_output_rules` returning
for a nonzero mark does not exit the calling `mangle_output` chain: its
later unconditional FakeIP rules set 0x04000000 and route the packet back
to TPROXY. Rust X already parses route.default_mark, propagates it to the
direct dialer and applies SO_MARK on Linux UDP sockets in the v0.0.8 source.

Change the own-traffic exclusion to a mask check for the Forkop outbound bit.
Check preservation of unrelated mark bits where Forkop adds interception
bits; do not change mwan3 policy or disable mwan3 as the solution.
The exact mark of a particular amplified packet was not captured; the rule
collision is established from active rules and versioned socket code, while
the packet counters independently establish local UDP recirculation.

## Required Rust X corrections: FakeIP lifecycle and missing records

In v0.0.8 and current main, `FakeIpStore` in
`crates/core-runtime/src/dns/transport.rs` is an in-memory pool. It supports
in-process migration on reload, but it is not attached to CacheFile and does
not restore/save its mappings or allocation cursors. `store_fakeip` is parsed
and a fakeip bucket exists in the generic cache layer, but this does not wire
the DNS allocator into persistence. Runtime initialization builds the DNS
service without attaching the opened cache store.

The router has `store_fakeip: true` and an existing cache.db from before the
component transition. Existing clients can retain FakeIP answers from the
previous Go core while Rust X starts with an empty pool. The particular
client/domain that originally used 198.18.0.50 was not recovered.

`route/mod.rs:1379` only rewrites an IP when a reverse mapping exists. It
does not distinguish an unknown address within the configured FakeIP pool
from an ordinary destination. `inbound/udp.rs:554` consequently allows the
synthetic address to reach `connect_udp_index`. This explains the observed
outgoing sockets addressed to FakeIP. The reference Go routing code checks
pool membership and errors on a missing mapping instead of dialing the
synthetic address.

Required behavior:

- Attach FakeIpStore to cache persistence, including bidirectional mappings
  and allocation state. Verify actual compatibility with the Go cache format
  before promising preservation across a Go-to-Rust transition.
- Detect configured FakeIP pool membership separately from successful lookup.
  An unknown FakeIP must never reach a direct network dial. Either reject it
  with a clear diagnostic or use a validated domain recovered by sniffing.
- Apply the same rule to TCP and UDP and avoid noisy per-packet error floods.

## Package integration correction

Rust X's packaged `packaging/files/etc/init.d/sing-box` lacks a procd nofile
limit. The installed script matches this behavior. Rust X's CLI raises only
the soft limit up to min(65535, inherited hard limit), so it cannot escape
the inherited hard ceiling of 4096. Package/service integration must provide
an explicit suitable hard/soft limit and verify it after component changes.
Raising the limit alone would increase the capacity of this loop.

## Focused acceptance checks for follow-up implementation

1. Forkop exclusion accepts 0x08000000, 0x08000100 and 0x08000200; packets
   without the outbound bit remain subject to interception.
2. On an existing OpenWrt test VM, one UDP datagram cannot create successive
   locally generated FakeIP flows. Test own-traffic marks with extra policy
   bits and inspect output/TPROXY counters and FD growth.
3. An unmapped FakeIP fails without opening an outbound socket, for TCP and
   UDP. A valid mapping preserves the real domain during routing/dialing.
4. A FakeIP allocated by one Rust X process remains mapped after a fresh
   process start with store_fakeip enabled. Test Go-to-Rust cache migration
   separately, including both address families and cursor continuity.
5. Component installation/update retains the intended nofile limit; ordinary
   UDP sessions expire and FD counts recover without a restart.

## Implementation and verification follow-up

The user subsequently authorized implementation. Changes are prepared on
the existing main branches in Forkop and `artifacts/tachyon-core`:

- Forkop generates a masked own-traffic exclusion, preserving bypass when
  mwan3 adds policy bits.
- Rust X rejects unknown configured FakeIP addresses before TCP/UDP routing
  can select an outbound. A valid mapping continues to supply its domain.
- FakeIpStore reads/writes Go-compatible `fakeip_address`, `fakeip_domain4`,
  `fakeip_domain6` records and length-prefixed `fakeip_metadata` cursors.
  Missing metadata falls back to the highest retained address in each pool.
  Generic bbolt/cache handling now preserves binary keys instead of decoding
  packed IP addresses with lossy UTF-8 conversion. Paired records and cursors
  are updated together before a due flush. Idle-time flushing and shutdown
  flushing persist changes even when no further queries arrive.
- The in-memory LRU reverse map now removes entries actually evicted by its
  bounded forward caches; disk-backed mappings remain available on demand.
- Rust X's packaged sing-box service sets nofile to 65535/65535. The separate
  upstream-style tachyon-core init script already had that setting.

Targeted checks include FakeIP allocation/wrap unit tests, cache round trips,
binary-key preservation, fixtures for Go records/metadata, allocation cursor
continuity, disabled persistence, periodic and shutdown flushing, and
unknown FakeIP rejection for both network protocols and address families.
The Go netip binary field layout was checked against the
[Go implementation](https://raw.githubusercontent.com/golang/go/go1.26.0/src/net/netip/netip.go).
This is focused cache-format coverage, not a claim of full Go/Rust data-plane
compatibility or complete live cross-variant migration coverage.

On the existing OpenWrt 25 VMware VM (192.168.1.1), package and service state
was captured before mutations in `tmp/udp-loop-vm-before.txt`. Only temporary
test binaries, a separate nft table limited to localhost UDP port 18599,
and a temporary procd sleep service were used. The nft probe compared exact
and masked exclusions on actual packets carrying 0x08000000, 0x08000100,
0x08000200 and 0x00000100. The old rule bypassed one and recaptured three;
the fixed rule bypassed three and left the non-Forkop mark eligible. All
three new FakeIP regression tests passed on the VM, and the temporary procd
process had a verified 65535/65535 nofile limit. Temporary objects were
removed; the original Forkop and sing-box services remained running.

The local router at 192.168.90.1 was not modified. These changes have not
been published as packages or installed on that router.
