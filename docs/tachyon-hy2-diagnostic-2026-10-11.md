# HY2 diagnostic, 2026-10-11

The supplied credentials are deliberately omitted.

Official Dushnilin/tachyon-core v0.0.6 Windows amd64 executable tested locally through an isolated mixed inbound on 127.0.0.1:31879. Executable SHA256 00fdff29cfe3b51a9c1164057b89f61788923775fef32fdf23361341adc1ed83 matches published SHA256SUMS. Version reports tachyon-core 0.0.6. Configuration validation passed. SOCKS5 remote DNS HTTPS HEAD https://example.com returned HTTP/1.1 200 OK through the supplied HY2 server, with complete username:password authentication, Salamander, supplied SNI and insecure=true. Process stopped; credential-bearing temporary config removed. No router or VM changed.

Upstream v0.0.6 source tag: 1b703ffb6454b5ffeac84db096b5b4db21dd52d1.
PR #14 and #16 were open/unmerged when inspected. They affect inbound UDP packet route sniffing, not HY2 outbound authentication. This official release does not include them.

Current Tachyon parser process_hysteria2 preserves the complete userinfo as password, imports SNI, insecure and Salamander. It reads certificate pin from pcs, but ignores pinSHA256 from the supplied URL. Since insecure=true and no pin is applied, this omission does not explain this connection failure. QUIC client TLS config in the inspected Rust X source also does not apply configured certificate pins; that is a separate verification gap, not a proven cause of this failure.

The actual failing Tachyon generated outbound, selected binary identity and runtime error have not been inspected. The successful Windows test does not establish router-platform or TUN/UDP routing correctness. Next diagnostic input: redacted generated hysteria2 outbound, tachyon-core version, failure log. Do not infer a specific application fault without those.

Sources:
https://github.com/Dushnilin/tachyon-core/releases/tag/v0.0.6
https://github.com/Dushnilin/tachyon-core/pull/14
https://github.com/Dushnilin/tachyon-core/pull/16
https://github.com/Dushnilin/tachyon/blob/main/tachyon/files/usr/lib/subscription/parser.uc
## OpenWrt 25 VM lightweight follow-up

Existing VMware OpenWrt 25.12.5 x86/64, 192.168.1.1. Package inventory and ubus service state inspected before starting an isolated /tmp process. No backup, package installation, firewall change or service restart.

Official upstream v0.0.6 x86_64 executable SHA256 c92cbba87b5a2799221f2538dfd00ea41533ef2a832dd15d19ec71c4effc3d96 matches published SHA256SUMS. Manual HY2 outbound: validation passed and three HTTPS requests through local SOCKS5 returned HTTP 200. Current upstream Tachyon parser and its dependencies were copied into /tmp and run with the exact supplied link. Imported authentication, obfs, TLS enabled/insecure/SNI, server and port match manual configuration. Imported outbound: validation passed and three requests returned HTTP 200. A corrected repeat produced the same six successes. Initial object serialization comparison reported TLS false solely because property order differed; field-wise comparison passed.

Test processes shut down. Credential-bearing files removed on VM and operator computer. Existing installed sing-box PID remained 10670. Installed core remains Rust X; Tachyon service/UI and transparent routing were not installed or exercised.

Conclusion: HY2 outbound in official upstream 0.0.6 works on OpenWrt x86_64 with this server; current Tachyon share-link parser also produces a working outbound. The observed user failure is not reproduced. Full Tachyon generated routing/DNS, actual installed build/version, platform or older importer remain candidates. These tests do not exclude a core bug on the transparent UDP/TUN path.

## Full Tachyon installation test and retained setup

Installed official Tachyon/LuCI 1.5.4 APKs on OpenWrt 25 after SHA256 verification. Removed conflicting Forkop packages and Rust X package on that VM. Installed official upstream tachyon-core 0.0.6 as /usr/bin/sing-box and generated Tachyon's managed init script. Reset Tachyon settings for a focused test. No operator backup made.

Section hy2test imports the supplied HY2 link; domain routing matches example.com and api.ipify.org; section mixed proxy listens at 192.168.1.1:31879. disable_quic=1 retained. Three mixed HTTPS requests returned 200; ipify returned 151.245.112.60.

Transparent client test used existing OpenWrt 24 VM over the shared VMware WAN segment, adding eth1 temporarily to Tachyon source interfaces and a temporary FakeIP route on VM24. Initial test was invalid because Forkop was still active on VM24 and remapped the destination into its own FakeIP range; the HY2 server rejected those unmapped addresses. After stopping the client VM's Forkop, the correct Tachyon FakeIP addresses produced three HTTPS 200 responses and ipify returned 151.245.112.60. Core logs showed matching section routing. The earlier apparent core FakeIP failure was therefore a test-topology artifact, not a confirmed core bug.

Conclusion: Tachyon 1.5.4 plus official upstream core 0.0.6 works with this key in both mixed and transparent TCP paths on OpenWrt x86_64. Original customer failure remains unreproduced; actual customer version/configuration, client DNS mappings and platform require inspection. No claim of complete UDP/TUN coverage.

User requested keeping Tachyon working for manual inspection. Cleanup had already disabled the section when interrupted; restored it with the key and enabled Tachyon autostart. Retained source interface br-lan, log level warn, test domains and mixed port. Test client VM24 Forkop had already restarted and temporary route was removed; VM25 remains Tachyon. Credential-bearing operator scripts deleted. VM25 intentionally retains credentials in its Tachyon configuration for the authorized manual test.
