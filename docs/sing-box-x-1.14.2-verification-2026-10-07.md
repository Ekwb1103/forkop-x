# sing-box X candidate 1.14.2 verification

**Follow-up:** the clean-boot repeat in
`sing-box-x-clean-boot-verification-2026-10-07.md` passed without OOM on
both VMs. The low-RAM recommendation below describes the earlier
tmpfs-constrained run and is superseded by that follow-up.

Date: 2026-10-07. Upstream stable source tag v1.14.2, Go 1.26.8,
CGO_ENABLED=0, Linux ARM64 and amd64, -trimpath -buildvcs=false.
Tags: with_utls,with_clash_api,badlinkname,tfogo_checklinkname0.
Linker flags: -s -w -X runtime.godebugDefault=multipathtcp=0,tlssha1=1
-checklinkname=0 -X github.com/sagernet/sing-box/constant.Version=1.14.2.
UPX 5.2.1 -9; upx -t passed for both outputs.

| Architecture | Plain bytes | UPX bytes | UPX MiB |
| --- | ---: | ---: | ---: |
| ARM64 | 34341026 | 9927324 | 9.47 |
| x86_64 | 36847778 | 11449116 | 10.92 |

Prior 1.13.21 ARM64 UPX was 7368188 bytes / 7.03 MiB.
These are un-packaged binaries; ARM64 was built and integrity-checked,
not executed on the x86_64 VMware test VMs.

## Functional checks

- Existing OpenWrt 25 VM: tests/sing_box_dns114.sh passed. Its generated
  1.14.1 profile was accepted by the actual packed 1.14.2 core.
- Both VMs: tests/reality_xhttp.uc passed 308 assertions, without an
  Extended binary argument. These verify generator/import/export behavior,
  not native-core support for Extended-only transports.
- OpenWrt 24: a direct-outbound fixture generated for 1.14.2 was accepted
  by the actual packed 1.14.2 core.
- OpenWrt 25: tests/ruleset_binary_validation_vm.sh passed with PATH
  selecting the packed 1.14.2 executable: real large/nested rule sets,
  malformed/truncated/unsupported rejection, changed-file invalidation,
  full cache publication, unchanged refresh, last-known-good preservation.
- Both VMs: isolated SOCKS HTTP traffic and Clash API version query passed.
  Test configuration includes sniff + protocol=quic reject without with_quic.
  Actual QUIC traffic rejection was not tested.

## RAM result

The eval.sh script from the UPX size evaluation used a 1547045-byte real
adlist.srs and three repetitions of check and binary match beside a resident
test core. Helpers used isolated configuration and ports. No working
packages were replaced.

OpenWrt 25 (1 GiB configured): resident RSS 43588 KiB; check helper peak
48824 KiB; match helper peak 50224 KiB; no new OOM.

OpenWrt 24 (256 MiB configured, MemTotal 207096 KiB, no swap):

1. With existing Tiny still running, helper caused kernel OOM killing the
   experimental resident 1.14.2 core. Existing managed Tiny retained PID 9128.
2. With managed Tiny explicitly stopped and a two-second wait, experimental
   resident RSS was 43480 KiB. Check helper peak 47444 KiB; sampled pair RSS
   reached 91552 KiB, MemAvailable reached 0. Subsequent match caused another
   kernel OOM killing an experimental 1.14.2 process. Managed service was restored.
3. Control: packed 1.13.21 under the same VM/test conditions with managed
   core stopped passed all repetitions with no new OOM. Resident RSS 31272
   KiB; check peak 36128 KiB; match peak 39316 KiB. Minimum MemAvailable
   8808 KiB for check and 9136 KiB for match.

The VM had about 50 MiB shared/tmpfs usage before these tests. This is a
specific constrained reproduction, not a claim that every 256 MiB device
fails. Sampled RSS is not an exact bound and summed RSS can double-count
shared pages. Nevertheless this candidate has less demonstrated headroom
than 1.13.21 for the target audience.

## REALITY compatibility

Loopback test uses the current Forkop generator, temporary keys, synthetic
TLS destination, and classic VLESS + REALITY. The copied test script
substituted version 1.14.2 for the Extended generation version and set
FORKOP_REALITY_CLASSIC=1, FORKOP_REALITY_PREFERENCE= (empty).

- Packed 1.14.2 with Xray 25.8.3: actual HTTP traffic passed; original VM
  package/config/service/enabled states compared equal by the test.
- Packed 1.14.2 with Xray 26.9.30: actual traffic failed. Client reported
  x509 unknown authority; server forwarded SNI to the synthetic destination,
  consistent with failure of REALITY authentication. Exact cause unresolved.
- Packed 1.13.21 with Xray 26.9.30: same test also failed, so simply changing
  the sing-box base version does not resolve this fixture's incompatibility.

This does not establish that post-quantum is mandatory for all Xray VLESS
connections or that all real servers fail. It requires separate handshake
investigation before claiming latest-Xray REALITY compatibility.

## Recommendation

Do not select 1.14.2 as the default X 1.0.0 base solely for being newer.
Keep 1.13.21 as the better-tested low-RAM candidate until helper memory is
addressed, or repeat tests on representative ARM64 hardware and configurations.
Both candidates still need actual ARM64 runtime tests and packaging/migration
checks. No release or mirror publication was performed.

After diagnostics, dedicated /root/forkop-x142-eval and /tmp/forkop-x142
directories were removed. Package lists and existing config checksums were
compared before/after. Both managed services were confirmed running.
