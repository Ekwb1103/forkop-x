# podkop-engine-full compatibility probe — 2026-10-08

Existing VMware OpenWrt 25.12.5 x86_64/APK VM at 192.168.1.1, Forkop 2.1.0-rc1. No repository code changes. Original sing-box X 1.0.1-r1 restored after the test.

Package: podkop-engine-full 1.14.2-r12, x86_64 APK, 15,061,848 bytes, SHA-256 9b5699dda4bfaee1b75243aa3256638c073d04c3747b9265558bbe5277899082. Downloaded from the project's GitHub release. APK metadata confirmed identity, architecture, dependencies ca-bundle/libc and installed size 37,295,275 bytes. Dependencies were already installed. Full installation left about 10 MiB of flash free.

Rollback package: mirror sing-box-x_1.0.1-r1_x86_64.apk, 9,686,562 bytes, SHA-256 b31c287a0a1b8c03784c9eae0f1943ede36ee7aff8e3ec25c1c9da72c231ac5f. Current mirror catalog and metadata verified before changes.

## Results

- Existing generated Forkop config passes sing-box check with Full.
- Forkop and sing-box run after controlled stop/start; Forkop restart also passes.
- Clash connections endpoint at 192.168.1.1:9090 returns HTTP 200; Forkop get_connections command returns JSON.
- DNS through sing-box at 127.0.0.42:53 resolves example.com A/AAAA.
- Separate temporary mixed inbound on 127.0.0.1:14534 with direct outbound successfully carries HTTPS to example.com (CONNECT 200, HTTP/2 200).
- Forkop recognizes this engine as stable, not a dedicated podkop-engine variant.
- Installation hooks changed /etc/config/forkop and /etc/config/sing-box. The generated JSON remained identical. Package auto-start caused an unexpected running sing-box during the initial Forkop start; stopping the package service and sing-box before starting Forkop resolved it. Managed integration needs controlled hooks, preservation of UCI, package identity and rollback handling.
- Original binary and the three configuration files verified against original SHA-256 after rollback; Forkop/sing-box running, Clash HTTP 200 and sing-box DNS working on restored X.

## Limits

The existing VM configuration has no proxy outbounds. This confirms baseline runtime/config/API/DNS and mixed direct traffic compatibility, not real subscription, REALITY, XHTTP, gRPC or NaiveProxy server interoperability, nor LAN-client TPROXY end-to-end behavior. Slim package was not installed. No native podkop-engine integration was added.

VM evidence is in /tmp/pdk-test (temporary, not persistent). State and configurations were captured before package/service mutations.