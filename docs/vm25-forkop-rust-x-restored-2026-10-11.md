# OpenWrt 25 returned to Forkop X, 2026-10-11

User requested complete Tachyon removal and current Forkop X/Rust X installation on the existing test VM 192.168.1.1.

Captured installed packages and ubus service state in tmp/forkop-return-vm-before.txt. No backup created. Purged Tachyon configuration, credentials, runtime, LuCI, APK packages and remaining watchdog processes; final searches found no Tachyon-named files under inspected runtime/config/application directories and no Tachyon processes.

Installed mirror canary Forkop X 2.2.2-canary.1 (APK version 2.2.2_rc1), LuCI and Russian translation. All three package SHA256 values matched public canary catalog. These historical Forkop APKs are untrusted by the VM keyring and installed using the documented legacy allow-untrusted compatibility path; no claim of verified Forkop signatures.

Installed mirror Rust X 0.0.7-r1 x86_64. Catalog package identity, architecture/format, mirror URL, length 4755421 and SHA256 b1ab6aa6812a5b306bdb492cbda40ed6a0c4053d05db8fd3d385d779de3bf447 checked before installation. apk verify returned OK with the existing mirror public key.

Dependency fetch initially failed because downloads.openwrt.org resolved to a stale FakeIP. A temporary /etc/hosts entry using an independently queried real address allowed completion; that entry was then removed. Required OpenWrt dependencies installed.

Forkop configured with one direct/bypass baseline section (example.com) and canary update channel; Rust X variant metadata 0.0.7. No HY2 credentials retained. Forkop autostart enabled. Executable reports 1.14.2-rust-x.0.0.7 and Rust X 0.0.7. Generated config validates, core runs, DNS answers, HTTPS example.com returns 200, ForkopTable present. No proxy section configured.