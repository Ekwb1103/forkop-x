# Tachyon 1.4.12: Forkop comparison

Reviewed the current local main branch sequentially. Reference sources were
retrieved from Tachyon tag 1.4.12, not its moving main branch.

## Applied

- FakeIP routes now only accept A and AAAA. Logical AND rules carry this
  restriction as a child matcher, because sing-box rejects query_type on the
  logical rule itself. Diagnostic FakeIP domains have the same restriction.
- Discord community rules use DNS query matching, including community aliases
  resolved through ensure_community_ruleset. Response matching is not used for
  this set: shared Cloudflare addresses must not select FakeIP by response IP.
- Shared Cloudflare Discord ranges now have separate TCP media rules for
  443, 1080, 2053, 2083, 2087, 2096 and 8443. UDP voice ranges are preserved.
  The nft path uses separate TCP IPv4/IPv6 sets; section source exclusions,
  explicit destination ports and section order remain authoritative.

Reference: https://github.com/Dushnilin/tachyon/releases/tag/1.4.12
and its tachyon/files/usr/lib/core/ip.uc and singbox/generator_routes.uc.

## Already implemented

REALITY parameters are only retained when explicitly provided, including both
supported spellings and explicit false. Binary SRS acceptance uses sing-box
rule-set match, with digest-based validation reuse in the ruleset cache.

## DNS failover: retain controlled replacement

Do not port a purported session-preserving SIGHUP reload. The configured X
upstream commit af6e64c3b69e6132ebaee0e1a3d24e93903f6709 handles SIGHUP by
checking the config, cancelling the context, calling instance.Close(), then
creating another instance. Keeping the process PID is not proof of preserving
connections. The X preparation script does not change this signal handler.

Source: https://github.com/SagerNet/sing-box/blob/af6e64c3b69e6132ebaee0e1a3d24e93903f6709/cmd/sing-box/cmd_run.go

Forkop's current DNS failover deliberately stops its managed runtime before
publishing the configuration to avoid racing a vendor init-script watcher.
It starts and checks the replacement, with rollback on failure. This review
does not change that lifecycle or claim uninterrupted active connections.

## Verification

OpenWrt 25 at 192.168.1.1, sing-box 1.14.2-x-1.0.1:

- sing_box_dns114.sh passed for generated 1.12.25, 1.13.18, 1.14.0 and 1.14.1
  capabilities. These are generation cases, not four installed core versions.
- community_subnet_routes.sh passed, including sing-box check, section scope,
  missing/empty/corrupt subnet rejection, cache materialization and TCP nft
  entries for IPv4 and IPv6.
- nft_atomic_apply.sh passed, using its fake nft executable.
- sing-box check passed with the real Discord binary ruleset substituted into
  the generated 1.14 fixture; its attachments-upload Google Storage domain
  matched the real set's domain rule.
- git diff --check passed.

Package/service state was captured before staging tests. Everything ran from
/tmp/forkop-tachyon-review; installed modules, UCI and running services were
not changed. Evidence is in local tmp/tachyon-review. OpenWrt 24 SSH timed out;
no changes were made there. Live Discord clients, real subscription REALITY
handshakes and active-session continuity were not exercised.

## Follow-up: both VMs reachable

Both existing VMs were reachable on the subsequent run. Both reported
1.14.2-x-1.0.1. DNS generation, community subnet routing, sing-box schema and
mocked nft atomic candidate tests passed on both. OpenWrt 24 has no bash;
temporary test copies replaced BASH_SOURCE[0] with 0 and ran under ash.
No package was installed.

An isolated sing-box process listening on 127.0.0.1:15453 was started on each
VM using a minimal address-only FakeIP rule and the existing local DNS as its
normal resolver. A and AAAA returned FakeIP; TXT github.com, MX gmail.com and
SRV _xmpp-server._tcp.jabber.org completed with NOERROR on both VMs. This
checks real DNS behavior for the restriction, not an installed full Forkop
configuration. The temporary processes were stopped by EXIT traps. The first
attempt rejected a missing default_domain_resolver; the fixture was corrected
and both repeats passed. Main service running states and PIDs matched the
captured state afterward.

Actual firewall application and a real Discord client's voice/media traffic
remain untested. The nft tests generate and inspect candidates with fake nft;
they do not apply them to the live firewall.
