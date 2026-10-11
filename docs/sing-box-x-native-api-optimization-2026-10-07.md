# sing-box X 1.14.2 native API optimization

The 1.14.2 CLI and include registry unconditionally reference the new native
API service and its command client. This pulls daemon, gRPC and protobuf
code into the executable even when the API is not configured. This is
separate from experimental.clash_api, which Forkop uses.

An experimental exclusion isolated the cost. The reproducible preparation
script is scripts/prepare-sing-box-x.py. It adds without_native_api to all
58 cmd_api*.go file constraints and moves service registration into a
conditional helper. Without the tag, native API remains available; with
the tag, CLI and native API registration are omitted. Clash API, transport
gRPC selection, DNS and proxy/routing code are unchanged.

The script refuses unexpected upstream registry patterns and existing
helper paths. Initial and repeated application were exercised on a separate
1.14.2 source copy. Both architectures with the tag and amd64 without the
tag built successfully. go list -deps with the tag confirmed that
google.golang.org/grpc and service/api were absent and experimental/clashapi
was present for the current X feature profile.

## Sizes

Go 1.26.8, Linux, CGO disabled, same linker flags as the previous 1.14.2
report; UPX 5.2.1 -9. These remain experimental binaries, not release packages.

| Architecture | Original X plain bytes | With exclusion plain bytes | With exclusion UPX bytes | UPX MiB |
| --- | ---: | ---: | ---: | ---: |
| ARM64 | 34341026 | 28836002 | 8534108 | 8.14 |
| x86_64 | 36847778 | 31133858 | 9858372 | 9.40 |

The default build after preparation, without without_native_api, remained
36847778 bytes on amd64. UPX integrity tests passed for both architectures.
ARM64 runtime has not been exercised on the x86_64 VMs.

## Runtime

Existing OpenWrt24 VMware VM after the previously authorized clean reboot:
256 MiB configured, 207096 KiB MemTotal, no swap, /tmp about 300 KiB.
Dedicated test files were on ext4 under /root, not tmpfs. Real 1547045-byte
adlist.srs, SOCKS HTTP and Clash API checks used the previous eval.sh.

Earlier unmodified 1.14.2 had resident RSS 43528 KiB in replacement mode.
The exclusion prototype had 35000 KiB; final tagged binary had 35020 KiB.
The final tagged binary passed three check and match repetitions beside
its resident runtime: check helper sampled peak 40532 KiB, match 46388 KiB,
minimum sampled MemAvailable 28656 KiB (about 28 MiB). Prototype repeat
minimum was 33880 KiB (about 33 MiB). Both had no new OOM. These are sampled
short-run results; variation is not a guaranteed memory bound.

With the managed service left running, the prototype also passed with
minimum MemAvailable 27836 KiB and resident RSS 35136 KiB.
The managed service was stopped only for replacement-mode tests, with
a two-second wait, and restored after each run.

On existing OpenWrt25 VM, prototype runtime RSS was 35108 KiB. The current
Forkop DNS generation test passed and its generated 1.14 profile was
accepted by both prototype and final tagged executables. Actual binary
rule-set validation passed for large/nested, malformed/truncated/unsupported,
changed-file invalidation, publication, unchanged refresh and preservation
of last-known-good cache. SOCKS HTTP and Clash API passed with the prototype;
final tagged build repeated them on OpenWrt24. No new OOM occurred.

This removes a substantial, measured part of the 1.13-to-1.14 increase:
about 8.3 MiB resident RSS and 1.33 MiB ARM64 packed storage. It does not
attribute or remove the entire residual increase. UPX loads unpacked code
into memory, and dependency initialization also contributes; exact split
between code and heap was not profiled. Native API service/dashboard and
`sing-box api` are intentionally unavailable in this X profile; Forkop's
Clash API monitoring/control remains available.

Package lists and existing config checksums compared equal after testing;
both managed services were confirmed running. Dedicated test directories
were removed. Installed packages and persistent configs were not replaced.
Packaging, ARM64 runtime, full generated-config traffic and newest-Xray
REALITY compatibility still require separate work before canary publication.
