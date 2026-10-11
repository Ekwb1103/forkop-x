# Rust X DNS response review

Scope: compare Rust X 0.0.2 with upstream tachyon-core v0.0.2 and reproduce DNS response routing on the existing OpenWrt 25 VM. Bootstrap fallback is excluded. No installed packages, UCI or Forkop services changed.

Forkop passes the executable version `1.14.2-rust-x.0.0.2` into its generator. The numeric >=1.14 check enables evaluate/respond and response matching. These rules are used for source-specific bypass and address rule-set DNS routing.

Our DNS walk ignores evaluate/respond. Its match_response flag is parsed but not used to distinguish response matching. Upstream adds evaluate and a separate response matcher, but respond remains explicitly ignored. Its response matcher only examines top-level rule sets and query metadata; it does not implement the logical nested IP/invert matcher generated for source-specific bypass. Therefore copying the two upstream files is insufficient.

Isolated VM probes use a local TCP DNS responder returning 203.0.113.7 and a second Rust X process. Fixtures, harness and logs are under tmp/dns-response-review.py, tmp/dns-review-*.json and tmp/dns-review-*.log; results are tmp/dns-response-review-results.json.

The address-list case should select FakeIP for 203.0.113.0/24 but returns the real address. The bypass case should return the evaluated real answer but falls through to FakeIP. Logs confirm evaluate/respond are ignored. Both temporary processes exit after each probe; the installed Forkop runtime remains running.

Recommendation: implement and test coherent response-stage matching (including nested IP predicates and invert), evaluate and respond before advertising that capability for Rust X. Use an explicit core capability rather than the compatibility version alone. Do not port bootstrap fallback or publish a replacement 0.0.2 build as part of this review.
