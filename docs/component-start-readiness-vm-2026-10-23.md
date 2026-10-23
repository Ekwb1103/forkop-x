# Component startup failure and UI recovery, 2026-10-23

## Fix

After a core switch rejects the configuration, the component worker used to
continue polling readiness despite the lifecycle's terminal `start.failure`.
Its nominal 180-second timeout counted only sleeps, excluding status probes.
LuCI correctly treated the still-running worker as an active transition and
kept its service controls disabled throughout this extended wait.

The two component restoration waits now use a monotonic deadline and stop on
a terminal startup failure. While an owned start is active, its old failure
marker is ignored. Successful core readiness still requires the existing
eight-second stability check. Package rollback and component job finalization
are unchanged; controls are not enabled during a real package transition.

## Existing OpenWrt 25 VMware VM

VM: 192.168.1.1, OpenWrt 25.12.5, x86_64, VMware. Removed obsolete test
directories, old package archives and baseline backups requested by the user.
Root free space increased from 5.4 MiB to approximately 165 MiB; working
configuration, installed packages and subscription/list caches were retained.

Updated Forkop, LuCI and Russian translations from 2.4.3 to signed stable 2.4.4
through the existing component updater. The selected Rust X 0.0.25 core was
preserved. No new release was published and no operator-router deployment was
performed by this verification run.

## Results

- Eight simulated-clock cases execute the actual readiness functions: immediate
  terminal rejection, rejection after an owned start, stale marker during a
  successful start, stable success, slow-probe timeouts and a bounded owned start.
- Six existing component-running-state cases passed, including explicit Stop,
  stale markers, failed readiness and healthy legacy runtime.
- `component_config_failure_vm.sh` temporarily adds a synthetic Trojan JSON
  outbound with a valid tag. The real Rust X startup rejects it as excluded.
- The real asynchronous component worker and its cleanup/finalization code,
  using a private copy with package dispatch replaced by the readiness fixture,
  report a terminal failure in one second and release the component lock.
- The real UI-state backend exposes `running: false`, `success: false` for the
  operation. After restoring the original config, the same tracked Start backend
  used by LuCI accepts a new action; service and DNS recover, with no active UI
  transition left behind. `nslookup example.com 127.0.0.1` succeeds.
- Executable SHA-256, installed package list and original Forkop UCI contents
  match their pre-test values. The script restores config on failure as well.

This verifies real startup failure, worker completion and UI recovery. Package
replacement/rollback itself was not exercised in this run; the private fixture
does not call the package installer. No claim of a complete core transition or
Trojan support in the reduced Rust X package follows from these tests.

Evidence was copied to the parent workspace's local
`artifacts/component-readiness-vm-20261023/`; test files and backups on the VM
were removed after verification. The candidate fix runs from a private test copy;
the VM's installed backend remains the published 2.4.4 package.
