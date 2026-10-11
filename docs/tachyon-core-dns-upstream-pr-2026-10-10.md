# Tachyon DNS upstream PR — 2026-10-10

Published PR: https://github.com/Dushnilin/tachyon-core/pull/7

Separate checkout: `artifacts/tachyon-core-upstream-pr`, branch
`dns-response-tachyon`, commit `0087eefcb5df809020afa1630199c37e4e2559dc`.
The interrupted publication had already created PR #6; it was closed and its
temporary branch deleted at the user's request to omit the assistant name.
Rust X checkout remains on main at `c2421a98`, unchanged.

Upstream main and remote v0.0.2 both resolved to
`cd5410141858cf6de2b500f493c85bcb54d56278`; Tachyon 1.5.1/main resolved to
`05c87b24dcc848d3f073d4f0abf9a839b2d9b5a8`.

The unmodified upstream binary reproduced the ordinary Tachyon exclusion
wrapper failure for A and AAAA, premature return before later query rules,
backward application of response rules, and lost response route-options.
The simple top-level IP rule-set and excluded-client controls already passed.
The exact exclusion function from the pinned generator was run using ucode
on the existing OpenWrt 25 VM. This is a focused generated-rule test, not a
full LuCI/UCI application integration test.

The adaptation changes only four native DNS files: sequential request-local
evaluation, recursive response predicates with AND/OR/invert, logical parent
action options, shared transport/cache processing, and returned-answer reverse
mapping with cache age retained. Untagged respond is implemented as mechanism
support; reviewed ordinary Tachyon generators do not emit it.

Verification: 49 DNS tests pass, including eight focused new regressions.
Release x86_64 musl build passes. All eight isolated candidate VM scenarios
pass with two request IDs each. Candidate SHA-256:
`cffca84f777ca52546055129fa9714cb53a515ab562900d1b9d7f102abf4f01c`.
Temporary VM processes/files were cleaned up. Installed runtime PID remained
7660, with watchdog readiness present; no installed binary/service was changed.

Evidence: `tmp/tachyon-dns-vm.py`, generated fixtures and baseline/candidate
VM results under `tmp/tachyon-dns-*`; focused test/build/Clippy logs use the
same prefix. Changed-file formatting and git whitespace checks pass.
Clippy completes with seven existing collapsible-if warnings in unchanged
routing files. GitHub Linux CI fails at whole-workspace formatting; locally
the formatting differences are confined to unchanged routing files.
Other GitHub builds were still running at the last status check.

Before publication, maintainer replies in issues #2/#3 were read: native
upstream changes are preferred over importing fork code or references.
PR #4 had no textual maintainer comment/review, but Dushnilin merged it.
The new PR describes the Tachyon/core problem and upstream evidence directly.
GPL-3.0-only and upstream history remain intact; no branding, versions,
bootstrap fallback, QUIC, package or release changes are included.

## CI completion follow-up

The user explicitly requested fixing all blockers and delivering a ready PR.
Follow-up commits on the same branch repair whole-workspace formatting and
seven Clippy warnings, synchronize MIPS CI with upstream release libunwind
setup, bound the socket test's asynchronous accept and rerun SO_MARK with a
mandatory privileged assertion, and restore compiled rule-set equivalence for
malformed logical children and matcher-free catch-all objects.
The port-statistics test now reflects separate fallback storage while still
checking a real port match. No checks are disabled; ordinary socket options
are verified without privileges and SO_MARK is mandatory in privileged CI.

Latest commit: `fe8d73522e9571f709460036bcee1c400bfe598d`.
Whole-workspace formatting and strict Clippy pass locally. All 10 compiled
rule-set tests pass. All 16 dial tests pass unprivileged and under root with
`TACHYON_TEST_REQUIRE_SO_MARK=1`. Full workspace results: 1,241 passed, 18 ignored, no failures. Final GitHub CI
run `38043586089` is pending at this point.
Logs: `tmp/tachyon-pr-ruleset.log`, `tmp/tachyon-pr-clippy-final.log`,
`tmp/tachyon-pr-dial-user.log`, `tmp/tachyon-pr-dial-root.log`,
`tmp/tachyon-pr-tests-final.log`.

Final VM rerun: all eight probes passed; binary SHA-256 e6c001df90c1f26b5fecea3174c5d70afa70ab53d46228ac5947422a499df588. Temporary processes and fixtures were cleaned up; installed runtime PID remained 7660. The final commit changes only the exit-gate test: its generated evaluate-before-FakeIP ordering is retained and dns-server uses local hosts data. Privileged exit-gate (1) and inbound (11) tests passed; strict Clippy passed again. Log: tmp/tachyon-pr-privileged-final.log.

Final published HEAD: 34a9cd3eb7417085946f185329d2338f6fc8ddbc. All seven CI jobs passed: https://github.com/Dushnilin/tachyon-core/actions/runs/38043932762. Required root SO_MARK reruns are scoped to the two tests that check the mark; the normal full workspace suite remains enabled. A root-only MPTCP failure observed when rerunning the entire dial suite is outside this DNS change and is not claimed as fixed. PR description updated with final validation.
