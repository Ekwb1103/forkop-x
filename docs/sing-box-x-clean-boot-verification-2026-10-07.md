# sing-box X clean-boot comparison, 2026-10-07

Both existing VMware OpenWrt test VMs were rebooted at the user's request
after recording package/service state and checksums. No VM was replaced.

| VM | Old boot ID | New boot ID |
| --- | --- | --- |
| OpenWrt25 | 731d14af-a147-478b-bb5e-0f16ea161b99 | 4bd92568-f667-47c4-bdd0-3a28907c01d4 |
| OpenWrt24 | 93754b25-9c77-49cf-89d0-693904996de1 | 1595b399-1bc4-4be7-9b33-d0de403e85a5 |

After boot OpenWrt24 (256 MiB configured, 207096 KiB MemTotal) /tmp usage
fell from 47432 KiB to 272 KiB; MemAvailable increased from 67756 KiB
to 110452 KiB. OpenWrt25 /tmp fell from 77224 to 404 KiB.
Installed package lists were unchanged. The OpenWrt25 generated
/etc/sing-box/config.json checksum changed during boot; the persistent
/etc/config/forkop checksum did not. A fresh post-boot config baseline
was therefore used for subsequent test-state comparisons.

The same UPX 5.2.1-packed 1.13.21 and 1.14.2 experimental x86_64 builds
from the earlier reports were exercised. Binary, script, real 1547045-byte
adlist.srs and test configs were placed on ext4 under dedicated /root
directories, not tmpfs. The earlier eval.sh was used unchanged: isolated
SOCKS and Clash API, large local rule-set, three sequential repetitions
of config check and rule-set match alongside the resident test process.

## OpenWrt24 results

"Replacement" means the managed sing-box was stopped, a two-second wait
was observed, no managed PID was present at test start, and the service
was restarted afterward. "Additional" keeps the managed Tiny service
running alongside the experimental core and its helper.

| Base | Mode | Resident RSS KiB | Check helper sampled peak RSS KiB | Match helper sampled peak RSS KiB | Lowest sampled MemAvailable KiB |
| --- | --- | ---: | ---: | ---: | ---: |
| 1.13.21 | Additional | 32100 | 41084 | 38864 | 31960 |
| 1.13.21 | Replacement | 31252 | 34472 | 39792 | 41032 |
| 1.14.2 | Additional | 43492 | 51612 | 49508 | 16668 |
| 1.14.2 | Replacement | 43528 | 49884 | 50084 | 17672 |

All operations passed, with no new OOM messages in every run. The
managed core kept its PID during additional-mode tests. Replacement-mode
tests restored the managed service with a new PID, as expected.
The 1.14.2 replacement sample summed RSS reached 94200 KiB; sums may
double-count shared mappings and are not unique physical-memory costs.

## OpenWrt25 results

Both variants passed in additional mode with the managed service running.
Resident RSS: 31124 KiB for 1.13.21, 43564 KiB for 1.14.2.
Check helper sampled peaks: 36276 and 49100 KiB respectively.
Match helper sampled peaks: 41212 and 53408 KiB respectively.
No new OOM, SOCKS HTTP and Clash API passed.

## Updated interpretation

Earlier OOM reproduced a tmpfs-constrained state and does not justify
rejecting 1.14.2 for all 256 MiB routers. After reboot the same 1.14.2
build passes these workloads. It remains more memory-demanding, with
roughly 12 MiB more resident RSS and less helper headroom than 1.13.21.

Stable 1.14.2 is again a viable candidate for sing-box X 1.0.0 canary.
ARM64 UPX executable size remains 9.47 MiB; x86_64 10.92 MiB.
Actual ARM64 execution, representative full generated config and sustained
proxy load, package/migration/rollback tests remain required before release.
The previously recorded newest-Xray REALITY handshake issue is unchanged
by these memory tests and requires independent diagnosis.

Final package lists and post-boot config checksums compared equal. Both
managed services were confirmed running. Dedicated test directories and
state-record files were removed. No packages were upgraded or replaced.
