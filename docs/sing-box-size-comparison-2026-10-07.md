# sing-box ARM64 size comparison

Measured on 2026-10-07 from upstream sing-box v1.13.21, Go 1.26.8.
Source: https://github.com/SagerNet/sing-box/tree/v1.13.21

All builds use GOOS=linux, GOARCH=arm64, CGO_ENABLED=0, -trimpath,
and linker flags `-s -w -checklinkname=0 -X github.com/sagernet/sing-box/constant.Version=1.13.21`.
All retain `with_utls,with_clash_api,badlinkname,tfogo_checklinkname0`.

| Variant | Additional tags | Bytes | MiB | Saved vs control |
| --- | --- | ---: | ---: | ---: |
| Tiny control | with_gvisor,with_quic | 31064226 | 29.63 | — |
| Without gVisor | with_quic | 27197602 | 25.94 | 3.69 MiB / 12.4% |
| Without gVisor and QUIC | none | 24248482 | 23.13 | 6.50 MiB / 21.9% |

Artifacts remain in `tmp/singbox-size-check/`: tiny-arm64,
no-gvisor-arm64, lite-arm64. Build metadata checked with `go version -m`.
These are comparative binaries, not packaged or runtime-validated releases.
No router or VM package changes were made for this comparison.

The installed OpenWrt aarch64_cortex-a53 Tiny binary measured earlier was
31137064 bytes, with CGO enabled. Its different toolchain/linkage means
the absolute sizes above are not a guarantee for future APK/IPK packages.
The controlled comparison establishes the effect of the removed tags.

Forkop generates TProxy inbounds, not gVisor TUN stacks. Removing gVisor
is a candidate for preserving generated-config functionality; custom
gVisor/mixed TUN configurations require separate handling. Removing QUIC
loses Hysteria2/TUIC/QUIC transports and needs explicit capability handling.
uTLS and Clash API are used by Forkop and were preserved in every build.
