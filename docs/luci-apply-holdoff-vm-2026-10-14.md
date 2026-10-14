# Forkop-only LuCI apply holdoff

Implemented in the Forkop page only. Before native LuCI apply, read the full
staged UCI changes. Only a nonempty Forkop-only change set skips the initial
confirmation holdoff. Empty, mixed, malformed or failed reads keep the native
delay. Native checked/unchecked apply, confirmation token and rollback paths
are retained. Restore the shared holdoff immediately after native confirm
schedules its first request, including exceptions.

## Verification

- Existing VMware OpenWrt 25 VM, 192.168.1.1, OpenWrt 25.12.5 x86/64.
- Native LuCI settings: holdoff 4 s, successful status display 1.5 s.
  The latter remains unchanged.
- Saved package list, service state, Forkop UCI export and original page JS
  under `/tmp/forkop-holdoff-test` before mutation.
- Uploaded the generated Forkop page JS. Logged into LuCI and changed only
  the Direct baseline section label, then used Save & Apply. The page
  reloaded successfully and the new label was committed; no pending changes.
- sing-box remained running (PID 4077), DNS on 127.0.0.1 answered, and nftables
  retained fw4 and ForkopTable.
- Restored the original Forkop UCI export and reloaded Forkop. Export and
  package list compare equal to their snapshots. No pending CLI UCI changes.
  Updated UI JS remains installed on the test VM.
- `node tests/luci_apply_holdoff.cjs tmp/holdoff-vm-ui.js` passed using the
  actual native confirm implementation downloaded from the VM. Its timer
  harness verifies 0 ms for Forkop only and 4000 ms for mixed/other/empty/
  malformed changes and RPC failure. Also checks exception cleanup, argument
  forwarding and repeated setup. This is not a live mixed network-change test.
- Generated assets rebuilt with semantic AST equivalence checks; diff check
  passed. No release, mirror or operator router changes.

The change removes the fixed initial wait; it does not make native LuCI
confirmation a Forkop runtime readiness check. No deliberate loss of access
or live rollback-expiry test was performed.
