# Tachyon + tachyon-core DNS response code review

Reviewed public source on 2026-10-10, without changing upstream or running its
binary. Previous Rust X fixes remain untouched.

- Tachyon 1.5.1 / current main: `05c87b24dcc848d3f073d4f0abf9a839b2d9b5a8`.
- tachyon-core current main / current remote v0.0.2:
  `595910d5a24ce55600eda920fafaa2d2f2c220f1`.
  This is the current remote tag resolution, distinct from the older locally
  cached v0.0.2 commit used in the earlier Forkop review.

## Conclusion

The upstream core needs the sequential/nested response-matching part of the
fix for use with ordinary Tachyon. The complete Rust X patch should be adapted
to upstream rather than copied blindly: upstream already has a simple
evaluate + top-level IP rule-set implementation.

Tachyon's current DNS generators do not emit respond. Its bypass DNS server is
selected with a route action, so the Forkop source-aware evaluate/respond
bypass failure is not the same active scenario in ordinary Tachyon.
Respond remains an explicit upstream stub and needs implementation if that
action is to be supported or introduced by the application.

## Source evidence

1. [generator.uc](https://github.com/Dushnilin/tachyon/blob/05c87b24dcc848d3f073d4f0abf9a839b2d9b5a8/tachyon/files/usr/lib/singbox/generator.uc#L709)
   treats tachyon-core as 1.14-capable. Therefore response rules are enabled
   for its own version series, not just for sing-box >=1.14.
2. [generator_routes.uc](https://github.com/Dushnilin/tachyon/blob/05c87b24dcc848d3f073d4f0abf9a839b2d9b5a8/tachyon/files/usr/lib/singbox/generator_routes.uc#L2391)
   emits evaluate followed by match_response for address rule-sets. Lines
   1974–2030 wrap the response matcher into logical AND when client addresses
   are excluded; match_response stays inside the child rule.
3. [core DNS walk](https://github.com/Dushnilin/tachyon-core/blob/595910d5a24ce55600eda920fafaa2d2f2c220f1/crates/core-runtime/src/dns/mod.rs#L430)
   scans only response rules whose parent match_response flag is true.
   A logical parent with the flag in its child is skipped. Evaluate also scans
   the whole rule list and returns or breaks instead of continuing in listed
   order. This is incompatible with general sequential rule evaluation.
4. [core rule builder](https://github.com/Dushnilin/tachyon-core/blob/595910d5a24ce55600eda920fafaa2d2f2c220f1/crates/core-runtime/src/dns/rules.rs#L336)
   builds logical parents from action alone, losing server and action options.
   Its response matcher at line 241 does not recursively evaluate logical
   subrules or apply the rule's invert.
5. The core explicitly ignores respond at lines 508–511. No respond action
   appears in the reviewed current generator, routes, DNS, DNS presets or DNS
   failover modules. section_dns_server at generator_routes.uc:1555 selects
   the real DNS server for bypass without the Forkop respond flow.

These are source-level incompatibilities. Actual failures of this Tachyon +
upstream-core combination, including complex generated rules, have not been
reproduced on its binary. The earlier VM proof applies only to our Rust X.

Recommended scope: fix ordered evaluation, recursive response matching and
logical action preservation in tachyon-core; add a generated-rule regression
with excluded clients. Give the Tachyon application an explicit DNS-response
capability check rather than inferring all behavior from schema 1.14.
Implement respond as core support, but do not claim ordinary Tachyon currently
depends on it. No upstream modifications, Issue or PR were published here.
