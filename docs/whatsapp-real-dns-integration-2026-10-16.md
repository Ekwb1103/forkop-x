# WhatsApp real DNS: implementation and VM verification

The advanced-settings flag `whatsapp_real_dns` defaults to off. With it enabled,
FakeIP DNS rules exclude `whatsapp.com`, `whatsapp.net`, `whatsapp.biz`, `wa.me`
and their subdomains. Queries continue through the existing ordered DNS rules
to an explicit DNS action or the configured main DNS resolver. FakeIP test
domains and other service controls are unchanged. DNS reverse mapping is
enabled to retain domain routing for real-address connections where supported
by the core and the answer TTL.

The option does not create an outbound, change a section target, replace
dnsmasq, or disable QUIC filtering. The existing Meta subnet lists provide
real-address traffic interception and address-based routing. Enabling requires
an enabled routing section with Meta and without source or port filters;
missing subnet ruleset caches are rejected during generation. Missing options
in existing installations continue to mean off. The option participates in
the sing-box reload signature.

## Prerequisites and interactions

- Add Meta to the intended routing section and download its lists before
  enabling. This uses Meta address coverage; it is not a dynamic DNS-to-nftset
  synchronizer. Newly allocated addresses outside those lists still require
  list updates.
- Explicit DNS sections keep their priority. A custom resolver or DNS action
  may change the returned addresses, including supplying its own synthetic
  answers. A device bypassing the router with its own DoH is outside this flag.
- Source exclusions, fully routed devices, block/bypass targets and section
  order retain their configured route rules. Overlapping address lists and
  domains still follow that order. Real IPs shared by multiple domains can
  make reverse mapping ambiguous; subnet routing remains important.
- DNS detours, failover and strategy are retained. IPv4-only/IPv6-only DNS
  strategies retain their existing effect. The QUIC switch is independent.
- Clients may retain previously cached FakeIP answers after the change;
  refresh their DNS/application connections when evaluating the setting.

## Tested environments

Existing VMware VMs were used, with package/service/firewall state captured
before changes. OpenWrt 25 lacked kmod-veth, and both VMs lacked socat; these
were temporarily added for isolated packet tests. Installed dnsmasq on both
VMs has no nftset support, so no dnsmasq nftset dependency was introduced.

| OpenWrt | Core | DNS / configuration | TCP+UDP, IPv4+IPv6 |
| --- | --- | --- | --- |
| 25.12.5, 192.168.1.1 | Rust X 0.0.17, baseline 1.14.2 | Passed | Passed |
| 25.12.5, 192.168.1.1 | Sing-Box X 1.0.4, core 1.14.2 | Passed | Passed |
| 24.10.8, 192.168.241.2 | Rust X 0.0.17, baseline 1.14.2 | Passed | Passed |
| 24.10.8, 192.168.241.2 | Sing-Box X 1.0.4, core 1.14.2 | Passed | Passed |

Sing-Box X was taken from the mirror catalog's linux-amd64 archive, whose
download length and SHA-256 were checked before extraction. It was run from
`/tmp`; the installed Rust X package was not replaced.

`tests/whatsapp_real_dns_vm.sh` runs candidate modules and actual cores in
temporary router/client/server network namespaces. It uses a deterministic
mixed Meta ruleset and authoritative synthetic DNS answers, not live WhatsApp
servers. Checks cover:

- core config checks and Forkop validation;
- all four WhatsApp suffixes, real A/AAAA when enabled and FakeIP when disabled;
- unchanged FakeIP for an unrelated domain and the control probe;
- off/on/off recovery and a higher-priority explicit DNS resolver;
- unchanged route rules/outbounds and a changed reload signature;
- refusal of missing/filtered Meta configuration and missing subnet cache;
- generated nftables TPROXY classification, echo payloads over TCP and UDP
  for IPv4/IPv6, and the selected section in core routing logs.

The packet test uses a direct outbound inside the selected connection section;
it proves classification and core routing, not a remote subscription/proxy
handshake. It does not prove WhatsApp login, media delivery or voice/video
calls on a real phone. Installed VM UCI, service files, core packages and
production firewall were not replaced. LuCI JavaScript was syntax checked;
the installed LuCI page was not changed or visually tested. No release was
published and no operator/customer router was changed.

After the final passes, the temporary socat packages and the newly added
OpenWrt 25 kmod-veth package were removed. Installed package listings matched
their pre-test copies. The original Forkop/DHCP UCI files and generated core
config matched byte-for-byte. Both existing Forkop and dnsmasq services remained
running on the original Rust X package; router DNS queries succeeded. Temporary
test namespaces were removed. Evidence was copied under the local untracked
`tmp/whatsapp-real-dns/` directory.

Invocation on an authorized VM after uploading the candidate library:

```sh
FORKOP_TEST_VM=1 FORKOP_LIB=/tmp/wa-candidate/lib \
  FORKOP_TEST_WORK=/tmp/wa-rust sh /tmp/wa-candidate/whatsapp_real_dns_vm.sh
FORKOP_TEST_VM=1 FORKOP_LIB=/tmp/wa-candidate/lib \
  FORKOP_TEST_CORE=/tmp/wa-x/sing-box FORKOP_TEST_WORK=/tmp/wa-singbox \
  sh /tmp/wa-candidate/whatsapp_real_dns_vm.sh
```

## Save protection and localized errors

LuCI now validates the parsed configuration before persisting either the main
form or a section editor modal. Removing the last eligible Meta section is
checked before deleting that section or its child items. Disabling the last
eligible section, removing Meta, changing its action to DNS, or adding source/
port filters produces an actionable warning instead of saving that invalid
combination. Another eligible Meta section permits the change. Turning off
the WhatsApp option and removing Meta in one main-form save is permitted.

The warning and backend prerequisite/cache errors have English and Russian UI
messages. Technical logs retain the original English diagnostics; the log UI
shows the localized explanation above the original technical details. UCI/SSH
changes bypass the frontend guard and remain subject to backend validation.
There is no automatic reset of an explicitly enabled flag.

Focused save-protection/error-message tests: 19 passed, including actual
Russian PO lookup, English fallback, pre-persistence rejection, whole-section
removal, eligibility changes, and disabling the flag together with removing
Meta. TypeScript checking, LuCI JavaScript syntax checks and frontend build
passed. These frontend-only follow-ups did not change the previously tested
DNS/core/nftables behavior; VM packet tests were not repeated for them.
