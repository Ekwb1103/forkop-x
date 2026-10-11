# sing-box X package preparation â€” 2026-10-07

## Repository and release

Repository: https://github.com/Screamshow/sing-box-x

Application version: 1.0.0. Upstream: SagerNet/sing-box 1.14.2, commit af6e64c3b69e6132ebaee0e1a3d24e93903f6709. Go 1.26.8; UPX 5.2.1. Build tags retain uTLS, Clash API and lightweight gRPC transport and omit native management API, gVisor and QUIC transports. System TUN and QUIC sniff/reject remain.

The first preparation build completed in GitHub Actions. Isolated APK installation and configuration check passed on OpenWrt 25. The OpenWrt 24 IPK test found missing directory entries in data.tar.gz; this was fixed in packaging revision 2. Application version stays 1.0.0; the corrected GitHub release tag is 1.0.0-r2. The original GitHub release is marked superseded. Its candidate pointer was withdrawn before adoption by any Forkop installer.

## Distribution contract

Mirror base: https://mirror.51343.ru/forkop/sing-box-x

Corrected release directory: /forkop/sing-box-x/releases/1.0.0-r2/

A preliminary release uses candidate.json. A stable release uses latest.json. Current Forkop stable/canary catalogs and defaults are unchanged.

Package names: sing-box-x_1.0.0-r2_{architecture}.apk and sing-box-x_1.0.0-2_{architecture}.ipk. Architectures: aarch64_cortex-a53, x86_64. Dependencies: ca-bundle and kmod-tun. Conflicts: sing-box, sing-box-tiny and sing-box-extended. Package provides sing-box. Executable reports 1.14.2-x-1.0.0; the X release number and upstream version are distinct.

Files: /usr/bin/sing-box, /etc/init.d/sing-box, /etc/config/sing-box, /usr/share/sing-box-x/build.json. APK additionally carries OpenWrt package list and conffile metadata. Service configuration is disabled by default; Forkop controls normal startup after integration.

manifest.json asset records contain: package, version, architecture, format, size (download bytes), installed_size (packed payload bytes), binary_bytes, plain_binary_bytes, dependencies, sha256 and mirror URL. APK installed_size is read back from the generated archive. IPK installed size sums payload file bytes. Block allocation and transaction reserves are separate installer concerns.

The mirror validates upstream asset digests and manifest, signs previously unsigned APKs with its existing local key, checks signatures with the published public key, preserves upstream hashes and recalculates published hashes after signing. Release directories are immutable and published atomically. Complete prepared upstream source is included in each release.

## Remaining Forkop integration

- Replace Tiny selection in LuCI with X while retaining recognition of installed Tiny.
- Introduce explicit X identity and separate upstream/application/package versions.
- Use mirror-only metadata and downloads; adopt the new installed-size fields in the transaction preflight.
- Change fresh-install default while preserving user-selected existing Extended installations.
- Stage exact package rollback archives, check dependencies and validate variant switches.
- Complete real gRPC, latest Xray REALITY and ARM64 execution tests before canary adoption.

## Final verification

Corrected build: https://github.com/Screamshow/sing-box-x/actions/runs/37649819963 — success.

Published manifest: https://mirror.51343.ru/forkop/sing-box-x/releases/1.0.0-r2/manifest.json. All seven public asset sizes and SHA-256 hashes, and SHA256SUMS entries, verified. Both APK signatures verified with the existing mirror public key. Both architecture IPK layouts/ELF headers verified.

ARM64 binary: 8,534,028 bytes; APK installed payload: 8,536,284 bytes; IPK payload: 8,536,149 bytes. x86-64 binary: 9,858,380 bytes; APK installed payload: 9,860,624 bytes; IPK payload: 9,860,489 bytes. The measured x86-64 binary allocation on VM ext4 was 9,628–9,632 KiB, separate from package database overhead.

OpenWrt 25: signed APK installed and reinstalled in an isolated root. OpenWrt 24: IPK installed and reinstalled in an isolated root, with --nodeps and copied relevant dependency status including the libgcc1 provider. In both cases, the modified sing-box configuration survived reinstall; the binary reported 1.14.2-x-1.0.0 and accepted a direct+Clash API configuration. Global package lists, configuration hashes and running sing-box service state matched before/after. Temporary roots were removed.

Evidence: artifacts/sing-box-x-public-verification/openwrt25-r2.log, openwrt24-r2.log, verification-r2.json and mirror-manifest-r2.json. This is package preparation validation; real variant migration and rollback remain a separate integration stage.
