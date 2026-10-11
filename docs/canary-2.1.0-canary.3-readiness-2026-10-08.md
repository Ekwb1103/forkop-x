# 2.1.0-canary.3 readiness — 2026-10-08

Candidate built in tmp/canary213-validation/source from main HEAD 8abe52ae
plus only the support_operator_ip_v1 migration. Uncommitted changes from other
work were excluded. Six exact tested artifacts are in
tmp/canary213-validation/packages; sizes and SHA-256 are in manifest.json.
Repeat build payloads of all six APK/IPK matched; archive metadata differs.
IPK migration payload matches the isolated source. APK metadata uses 2.1.0_rc3;
display/public version is 2.1.0-canary.3. Existing build.sh metadata checks passed.

Existing VMware OpenWrt 25.12.5 and 24.10.8 were initially running canary.1.
Package/service inventories, UCI and core hashes captured before mutations.
Published local canary.2 artifacts verified against their publication manifest.
Both VMs passed real package-manager/hook tests:

- install canary.2, then upgrade to exact canary.3 with missing operator option;
- repeat with explicit disabled and custom 100.100.100.100 options;
- preserve all other UCI fields (only new option/migration marker allowed);
- reinstall exact candidate without configuration changes;
- rollback to exact canary.2 after each case;
- core stable/running, exactly one owned process, sing-box config check, local
  DNS lookup and unchanged executable SHA-256 after each installation;
- restore original canary.1 packages and exact Forkop/DHCP configuration.

Both final logs contain ALL_UPGRADE_TESTS_PASSED and BASELINE_RESTORED.
Package inventories, Forkop and DHCP config files match the original baseline.
Services restarted normally; process IDs necessarily differ. Evidence saved in
tmp/canary213-validation/vm25-evidence and vm24-evidence; VM staging removed.

First runner attempt exposed two test assumptions: native UCI discards empty
options (so they cannot represent an explicit opt-out), and lifecycle restart
refreshes forkop_dns_transaction_id. The revised runner tests disabled as the
explicit opt-out and restores the original DHCP file after runtime recovery.
No product change was needed for these runner corrections. An empty native UCI
option is treated as absent and receives the default; use disabled to opt out.

Earlier full support worker suite passed on both VMs, including reverse probes,
timeouts, cancellation/expiry and temporary SSH cleanup. Real customer NAT/DERP
failure was not reproduced. No release published, tag created, mirror sync,
customer installation, reboot, or full clean-install claimed in this stage.
Release notes prepared at docs/releases/2.1.0-canary.3.md. Candidate is ready for
publication of the exact tested packages after release authorization.
