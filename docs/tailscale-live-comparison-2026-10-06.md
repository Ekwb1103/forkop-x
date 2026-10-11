# Tailscale control connection comparison, 2026-10-06

## Scope

The user supplied a reusable test authorization key for VM diagnostics. It was
transferred over SSH stdin from a masked console input, never placed in process
arguments or repository files. Each registration used a root-only RAM file;
the file was deleted after registration or on test failure. No customer router
was contacted during this comparison.

Package/service/process state was captured on the existing OpenWrt 25 VMware VM.
The installed main tailscaled process and Forkop service were left running.
Diagnostic daemons used separate RAM directories, `--state=mem:`,
`--tun=userspace-networking`, separate sockets and random UDP ports, with
`--accept-dns=false --accept-routes=false --netfilter-mode=off`.

## Builds and initial checks

- Forkop Lite 1.98.3 r2: upstream commit
  `8f2c8d6a14419e95fb9d02d6bf6113893daef5c3`, Go 1.26.3 (tailscale/go
  `e877d97384`). The upstream control, transport and backend source files were
  unchanged in the source checkout; feature build tags differ.
- Full daemon built from the same commit with the same Go toolchain and no Lite
  feature tags. Its separate CLI was built from the same source. Diagnostic
  test additions made the CLI report a dirty development version; those
  additions are tests only and are not part of either daemon's runtime code.
- HTTPS key retrieval and fresh Noise `debug ts2021`/whoami checks succeeded on
  the VM for the installed full build and Lite.
- A local Noise/HTTP2 diagnostic exercised a map-like open stream concurrently
  with short requests, then canceled that stream and reused the client. Five
  repetitions of ten cancellation/reuse cycles passed for full and Lite tags.
  This does not reproduce the live control-plane failure.

## Live observations

The simultaneous full/Lite test started at 19:22:50–52 UTC (22:22:50–52 Moscow).
Registration and initial network map acquisition succeeded in both builds.
The test ran without Forkop's recovery worker or generated peer pings.

Both builds experienced a control TCP reset on port 80 after about 22 seconds,
then used port 443. Both subsequently experienced repeated two-minute map
watchdog timeouts and further control connection resets on port 443. In each
build, Online status sometimes changed while BackendState remained Running and
Health was empty. Fresh maps intermittently restored Online status, but further
timeouts occurred; brief recovery is not a permanent fix. At completion of the
ten-minute run, each build had recorded four map-watchdog timeouts.

A separate Lite registration with `TS_FORCE_NOISE_443=true` authenticated but
failed to obtain the initial map and enter Running within the configured
60-second startup window. Its daemon was stopped on failure. This negative
test does not justify enabling force-443 in production, and does not prove that
443 never works.

VM WAN TCP-header capture recorded active TCP acknowledgements and inbound RST
packets for the control connection. Header-only capture cannot identify whether
the resets originated at the control server or intervening network equipment,
and TCP acknowledgement alone does not prove the remote map service is healthy.
No payload capture or SSH/authentication traffic capture was performed.

The original runner used an unavailable `timeout` command, so its initial status
files were empty. A separate bounded sampler corrected status collection while
the same daemons continued running; conclusions use the valid samples and daemon
logs, not those empty initial files.

## Conclusions and limits

- The live map-stream failure reproduces in ordinary Tailscale as well as Lite;
  switching to the full build is not a demonstrated fix.
- The evidence isolates the symptom to control map delivery/connection lifetime,
  not initial registration, a daemon crash, or a Lite-only code modification.
- It does not distinguish a control-service bug from network-path interference
  or a shared upstream transport bug. No production transport patch is justified
  by these tests alone.
- Similar symptoms were independently reported for ordinary Linux Tailscale in
  [upstream issue #20630](https://github.com/tailscale/tailscale/issues/20630).
  Similarity does not establish a shared root cause or a fixed version.
- Forkop's existing bounded down/up recovery remains a workaround; it was already
  observed restoring the customer session earlier, not a permanent repair of
  the underlying map-stream failure.

Raw diagnostic logs and synthetic test scripts are retained locally under
`tmp`/`artifacts`, outside release packages. No release or production code change
was made by this investigation.

All three diagnostic daemons stopped after their bounded tests. The temporarily
added tcpdump-mini/libpcap1 packages were removed; the resulting package list
hash matches the pre-test list. The installed main tailscaled retained PID
12544, and Forkop remained running. VM24 was inspected read-only and was not
used for the concurrent daemon test because of its smaller RAM budget.
