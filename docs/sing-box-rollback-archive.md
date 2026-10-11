# Exact sing-box package rollback archive

The rolling OpenWrt index cannot retrieve an arbitrary installed version.
`opkg download sing-box` downloads the current candidate, not the installed
version. The component updater now tries the mirror archive, then the
current repository. A package that does not match
the requested identity is rejected before the package change starts.

Router packages are staged only in `/tmp/forkop-updates.*`, as before.
There is no persistent package cache and no added package writes to flash.
The exact previous archive remains in RAM for offline rollback during the
current operation. Long-term retention is performed only on the mirror.

Public catalog: `https://mirror.51343.ru/forkop/sing-box-archive/packages.json`.
Blobs use SHA-256 in the URL and never overwrite another build. Distinct
builds with identical name/version/architecture/format are retained separately.
The client verifies SHA-256 and internal archive metadata before accepting a
download. The archive catalog is served over HTTPS; its digest is an integrity
check, not an independent signature. APK package-manager signature policy
continues to apply during installation.

`mirror/archive-sing-box.py` imports retained OpenWrt mirror packages and
fetches current official stable/Tiny packages for `aarch64_cortex-a53` and
`x86_64`. IPK downloads are checked against the official Packages.gz SHA-256.
APK files are obtained via official HTTPS feed listings and archived with
their computed digest; client-side APK metadata validation remains required.
Additional architectures can be configured with `--arches`.

On 2026-10-08, `--history` imported all retained sing-box/Tiny versions from
official `archive.openwrt.org` package feeds for the configured architectures.
The deployed service now uses `--refresh --history`. Historical downloads
use official HTTPS and computed SHA-256; current IPKs additionally match
the official index hash. Inputs are archived before refresh, retaining
previous builds when upstream rebuilds the same package version.

The first historical sync published 65 blobs. All public downloads passed
SHA-256 verification. The four 1.12.17-r1 APKs (sing-box/Tiny, aarch64/x86_64)
passed internal name/version/architecture inspection with OpenWrt 25
`apk adbdump`. No VM packages or services were changed. Two tests covering
retention, corruption rejection and historical discovery/idempotence passed.

Deployment on Openwrt-Mirror:

- `/usr/local/lib/forkop/archive-sing-box.py`
- `sing-box-archive.service` and `.timer`: refresh every six hours.
- `openwrt-mirror.service.d/sing-box-archive.conf`: preserve existing packages
  before feed sync and refresh/import afterward.

The public archive initially contains 14 artifacts, including retained
1.13.18-r1 APKs, current 1.13.21-r1 APKs and 1.12.22-r1 IPKs. Historical
1.12.12-r1 and 1.12.17-r1 packages were recovered from the official archive
on 2026-10-08. Missing upstream packages cannot be reconstructed or
substituted. Missing versions remain a fail-closed preflight error.

Validation: Python archive retention/rebuild/corruption test; catalog identity
and URL tests on existing OpenWrt 24/25 VMs; real IPK/APK staging from the public
archive into RAM. No VM packages were
installed and no VM services stopped. Client changes require the next Forkop
release; installed 1.16.3 clients still use the previous lookup code.
