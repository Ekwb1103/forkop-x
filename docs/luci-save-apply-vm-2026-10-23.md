# Forkop 2.4.3 Save & Apply regression

## Environment and reproduction

Tested on the existing VMware OpenWrt 25 VM at 192.168.1.1:
OpenWrt 25.12.5 r33051-f5dae5ece4, x86/64, ext4, LuCI
26.270.72870~a24d1f2. No customer router was changed.

Captured packages, services, UCI, nftables and config backup under the VM's
restricted `/tmp/saveapply-baseline`. A sysupgrade backup was also copied to
local ignored `tmp/saveapply-vm-20261023`. The VM initially had Forkop 2.3.8
and Rust X 0.0.25-r1. Updated the three Forkop packages to signed stable 2.4.3
from the mirror after SHA-256 verification and APK transaction simulation.
Existing configuration and core selection were retained.

In a real LuCI browser session, added `saveapply_probe` with Bypass action
and domain `saveapply.example`. Saving the section succeeded. Save & Apply
failed with `TypeError: Cannot read properties of undefined (reading 'call')`
at the page's handler, without applying the rule. Reloading showed four
pending changes. Thus OpenWrt 25.12.6 was not needed to reproduce the bug;
the user's conditional firmware upgrade was not performed.

## Cause and fix

The LuCI `view` module exports a class constructor, with `handleSaveApply`
on its prototype. Forkop 2.4.3 called `view.handleSaveApply.call(...)`.
Changed this to `view.prototype.handleSaveApply.call(...)`, preserving
the inherited save, validation and native checked/unchecked apply protocol.
Regenerated the compact package asset and source hash manifest.

An earlier scratch test incorrectly modeled `view` as an object with a
direct handler and therefore missed this regression. Added
`tests/luci_save_apply.cjs`, which models the constructor/prototype boundary
and can also exercise the actual native handler extracted from the VM's
`luci.js`. It checks save-before-apply, both apply modes, and validation
failure without applying. Added the regression check to Frontend CI.

## Verification and recovery

Installed only the corrected generated `forkop.js` on the VM, keeping the
original under `/tmp/saveapply-baseline/forkop-2.4.3.js`. Ordinary browser
reload initially reused the old asset. LuCI versions resource URLs using
the APK database mtime; refreshed that timestamp for this manual test-file
replacement, then reloaded the page.

- Save & Apply completed in the browser; the rule appeared in the running
  core's generated config, and LuCI's pending-change indicator cleared.
- Edited the domain to `saveapply-saved.example` and clicked Save: LuCI
  showed one pending change and the running config still had the old rule.
- Clicked Save & Apply: the new rule appeared in the generated config.
- Deleted the test section via LuCI and applied its removal. Confirmed
  both section and runtime rule were absent.
- Restored the original Forkop config byte for byte from the backup and
  reloaded Forkop. Service was running and enabled; DNS lookup through
  127.0.0.1 succeeded.
- Regression test passed both standalone and with the VM native handler;
  `git diff --check` passed. GitHub CI has not been run for this local fix.

VM left on OpenWrt 25.12.5, Forkop packages 2.4.3 with the local LuCI fix,
original core and original Forkop config. No release was published.
This verifies the shared button failure with a Bypass rule; a fresh install
with a real customer subscription and OpenWrt 25.12.6 were not tested.
