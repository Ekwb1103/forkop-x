# Tachyon primary core on OpenWrt 25

On 2026-10-10, switched existing VM 192.168.1.1 to published Tachyon 0.0.1
at the user's request. No backups were created. Package/service state was
captured in tmp/tachyon-core-vm/25-switch-before.txt.

The native binary is /usr/lib/tachyon-core/sing-box. /usr/bin/sing-box is a
small wrapper that delegates commands and reports a configuration compatibility
baseline of 1.14.2 separately from the actual Tachyon version 0.0.1. Its
transport.xhttp tag allows Forkop to retain XHTTP configurations. This is a
VM-local experimental installation, not packaged Tachyon support.

The executable basename must be sing-box for Forkop's existing process
ownership checks. Initial tachyon-core naming caused Forkop to reject readiness;
the final naming passed and /var/run/forkop/watchdog.ready exists.

Final native process PID: 31284, managed by procd sing-box.main, running the
full /etc/sing-box/config.json. RSS observed at 12276 kB. DNS github.com
returned a public IPv4 address. Clash API exposes 65 proxy objects, including
the subscription selector tachyon_probe-out. Its URL delay probe succeeded
at 133 ms against https://www.gstatic.com/generate_204.

Section tachyon_probe and subscription_url child tachyon_probe_sub were added
on both existing VMs. Native Forkop subscription download with automatic
User-Agent and HWID produced real nodes; a manual User-Agent-only request had
produced an unsupported-client placeholder. Effective UA: INCY/2.1.0.
The normalized subscription had 63 actual nodes: 60 TCP REALITY/Vision,
two TLS XHTTP and one REALITY gRPC. Existing Forkop filters/groups affect
the final runtime set. OpenWrt 24 was not switched to Tachyon.

Isolated actual HTTPS test of subscription node 63 (VLESS/gRPC/REALITY) on
VM25 returned HTTP 200 and 577 bytes from https://example.com. The temporary
process was stopped. Nodes 1 and 2 (REALITY/Vision) passed validation but
closed SOCKS connections; their failures have not been diagnosed or compared
with X. Node 61's standalone fixture failed validation; not diagnosed.
These results do not establish all-node or full Vision/XHTTP compatibility.

The APK database still records the previously installed sing-box-x package;
this manual binary replacement does not change package metadata. A package
reinstall/update or component switch may overwrite the wrapper and restore X.
No repository production code was modified.
