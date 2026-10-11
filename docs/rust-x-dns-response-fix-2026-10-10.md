# Rust X DNS response fix — 2026-10-10

Scope: Rust X 0.0.2, existing `artifacts/tachyon-core` main, starting HEAD
`abb7824`. Changes are limited to `crates/core-runtime/src/dns/mod.rs` and
`crates/core-runtime/src/dns/rules.rs`; existing Forkop changes were preserved.
No version, release, package, bootstrap fallback or QUIC changes.

## Reproduction

The existing `tmp/dns-response-review.py` was rerun against the installed
Rust X on OpenWrt 25 (`192.168.1.1`). Both failures reproduced:

| Case | Before | Expected / fixed |
| --- | --- | --- |
| evaluate + response IP rule-set | 203.0.113.7 | 198.18.0.2 |
| evaluate + logical bypass respond | 198.18.0.2 | 203.0.113.7 |

`tmp/dns-response-review-results.json` retains the reproduced baseline.

## Change

- Evaluate resolves the configured transport using the shared transport/cache
  path, saves its wire response per request and continues in rule order.
- Response IP rule-sets and direct `ip_cidr` inspect A/AAAA answer addresses.
  Nested AND/OR, source/query predicates and invert are retained. An absent
  response stays unavailable through logical inversion.
- Respond returns the saved response with the request ID. Reaching respond
  without an evaluated response fails rather than selecting a later route.
- Logical parent construction preserves server and action options.
- Evaluate honors disable_cache/rewrite_ttl. Reverse mapping records the
  returned answer and preserves the FakeIP transport's separate mapping.

The action semantics follow the [sing-box DNS action documentation](https://sing-box.sagernet.org/configuration/dns/rule_action/).
This patch targets Forkop's untagged evaluate and `match_response: true`.
It does not establish full tagged-response, race/speculative or other response
field compatibility.

## Focused verification

51 DNS tests pass, including eight new regression tests. Coverage includes
the two failures, source/list misses, IPv4/IPv6, nested invert and absent
responses, logical action options, ordered rules, latest evaluation, request
isolation, wire-response cache/TTL/ID and FakeIP reverse mapping.

```sh
cargo +stable test --locked --offline -p core-runtime --lib \
  --target x86_64-unknown-linux-musl dns::
cargo +stable build --locked --offline --release \
  --target x86_64-unknown-linux-musl
```

Logs: `tmp/rust-x-tools/dns-focused-final.log` and `dns-build-final.log`.
Formatting and `git diff --check` passed. Existing compiler warnings remain.

## VM verification

Harness: `tmp/dns-response-fix-vm.py`. Candidate is copied to
`/tmp/rust-x-dns-fix`, with a local TCP DNS responder and second isolated
core process; fixed test ports are 18553 and 18554. Each case makes two
requests with different IDs. The trap stops only the temporary processes.
Package/service snapshots were waived by the user for these test VMs.

| Case | Answer on both requests |
| --- | --- |
| response-list | 198.18.0.2 |
| bypass | 203.0.113.7 |
| list-miss | 192.0.2.7 |
| bypass-fake-rejected | 198.18.0.2 |
| bypass-ipv6 | 2001:db8::7 |
| bypass-ipv6-fake-rejected | fc00::2 |
| bypass-source-miss | 198.18.0.2 |

Results and per-case logs: `tmp/dns-response-fix-vm-results.json` and
`tmp/dns-fix-*.log`. Installed Forkop runtime PID remained 7660, with
`/var/run/forkop/watchdog.ready` present. No installed binary, package,
UCI, firewall or service configuration was changed.

Final candidate SHA-256 (matched locally and on VM):
`4ec28a45e1047aba1a907cba4a7f73274144615496f3802cdf0401318414cc5c`.
Temporary candidate, fixtures and logs are removed from the VM after copying
the evidence to the workspace.

## Upstream and review preparation

Local upstream `v0.0.2` (`7db0fda`) confirms the partial evaluate/response
matcher and the explicit respond stub. Complex Tachyon-generated rules remain
a source-level concern; they were not reproduced on an upstream binary.
Dushnilin/tachyon 1.5.1 is a separate application, not the Rust X core.

Prepared Issue and PR descriptions: `tmp/rust-x-dns-response-issue.md` and
`tmp/rust-x-dns-response-pr.md`; patch: `tmp/rust-x-dns-response.patch`.
Issue/PR descriptions remain local drafts. At the user's request, the two core
files were committed and pushed to `Screamshow/rust-x` main as
`c2421a98e768ad0a666e0c0910b28ed08516d6a0`; the remote branch SHA was verified.
No release or replacement package was published.
