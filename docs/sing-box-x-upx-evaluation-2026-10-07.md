# sing-box X UPX evaluation, 2026-10-07

Experimental sing-box X is upstream 1.13.21 built without gVisor/QUIC,
retaining uTLS and Clash API. Go 1.26.8, CGO disabled; the comparative
build parameters are in sing-box-size-comparison-2026-10-07.md.
UPX 5.2.1 official Windows distribution, compression `-9`.
`upx -t` passed for both packed architectures.

| Architecture | Original bytes | UPX bytes | Packed MiB |
| --- | ---: | ---: | ---: |
| ARM64 | 24248482 | 7368188 | 7.03 |
| x86_64 | 26222754 | 8542244 | 8.15 |

On existing OpenWrt 25 x86_64 VMware ext4, allocated blocks measured by
`du -k` were 7200 KiB (7.03 MiB) for the packed ARM64 file, 8348 KiB
for packed x86_64, and 25616 KiB for ordinary x86_64. ARM64 was stored
but not executed on the x86_64 VMs. These are executable-file costs,
not measurements of a completed APK/IPK package installation or NAND use.

## Runtime checks

The test script is tmp/singbox-size-check/eval.sh. It starts an isolated
loopback SOCKS and Clash API runtime with a real 1547045-byte adlist.srs
from https://mirror.51343.ru/forkop/lists/rulesets/adlist.srs. HTTP through
SOCKS, API version query, configuration checks, and binary rule-set match
passed. Check and match each ran three times beside the resident runtime.
No new kernel OOM messages were observed. RSS is sampled, not an exact
bound, and summed RSS may double-count shared pages. Tests were short;
there was no sustained external proxy traffic or ARM64 execution.

OpenWrt 25 VM (1 GiB configured, existing service also running):

| Variant | Resident sampled RSS KiB | Check child peak RSS KiB | Match child peak RSS KiB |
| --- | ---: | ---: | ---: |
| Ordinary | 27212 | 36148 | 35452 |
| UPX | 31136 | 40116 | 40732 |

UPX resident had RssAnon 21188 KiB vs ordinary 7432 KiB;
ordinary also had 19780 KiB file-backed RSS. UPX therefore changes
reclaimability/sharing as well as total RSS.

OpenWrt 24 VM (256 MiB configured, MemTotal 207096 KiB, no swap):

- Existing Tiny plus isolated UPX runtime plus helper: all checks passed;
  sampled minimum MemAvailable 4636 KiB during match.
- Repeated with managed sing-box stopped temporarily: resident RSS
  34216 KiB; check child peak 36344 KiB, match child peak 39372 KiB;
  peak combined sampled RSS 74096 KiB and minimum MemAvailable 5300 KiB.
- At the second run baseline /tmp shared memory was 47392 KiB.
  Service stop was asynchronous: the old PID was still visible at the
  start of the script and disappeared by the end, so this is not a clean
  steady-state two-process memory bound.

Thus these checks demonstrate functionality, not a comfortable RAM margin
on every 256 MiB router. A normal default installation must still test
actual generated configs, target ARM64, traffic load and repeated updates.

Package/service states were captured before mutations. No installed package
was replaced. OpenWrt 24 managed service was restarted and confirmed running;
package lists were unchanged. Only dedicated test directories under /root
were created and removed; runtime scripts used test ports and configs.

## Interpretation

The 10–15 MiB executable-storage target is exceeded: ARM64 is about 7 MiB.
UPX operates on the linked executable and is not a feature selector. Optional
features should be excluded at build time; UPX then packs that executable.
UPX decompression needs memory at launch rather than an installed plain
23 MiB file. Forkop installation preflight must measure the packed payload
and separately check temporary-memory requirements. A future package's
installed-size must describe its actual packed files, not the original ELF.
