# Router 192.168.90.1: DNS EOF comparison, 2026-10-09

Installed X: 1.0.3-r1 / upstream 1.14.2. Temporary Tiny: 1.13.21-r1, extracted without installation from the mirror archive; SHA-256 966e7a70fad8aa5051e981e4103551284da6ca186ded86fc7f6419b29306132a. Working X process and UCI were not replaced or modified.

Tests used temporary processes listening only on 127.0.0.1:15353. Logs/configs are on the router in /tmp/forkop-dns-eof-check. Temporary processes were stopped afterward. Working Forkop and X were running at completion.

- Minimal DoH config, 77.88.8.8:443, cache disabled: 10 sequential A queries per variant, no EOF.
- Five fresh starts per variant, 20 concurrent A queries per start: 100 successful queries per variant, no EOF.
- Current 22-member URL-test group copied into the same temporary config, DNS strategy prefer_ipv4: X had 21/22 successful node checks in both starts; Tiny had 19/22 and 16/22. All failed node checks in these runs reported DNS unexpected EOF. Counts are node checks, not DNS request counts.
- X with the same group and DoH 1.1.1.1: two starts, 22/22 successful checks each, no EOF.
- Forcing HTTP/1.1 against 77.88.8.8 failed all node checks with EOF; curl --http1.1 independently received an empty reply. This is not a usable mitigation.

Tiny recorded the reproduced lookup failures at DEBUG. X recorded DNS exchange failures at DEBUG plus ERROR summaries after 10 seconds. Thus absence in Tiny's ordinary log does not establish absence of the underlying failure.

Both user-reported domains resolved successfully through the working router before and after testing. The working process also logged four further exchange failures during the temporary startup tests, so the issue is not proven limited to process startup; concurrent tests added load against the same upstream.

Conclusion: not demonstrated to be an X-only regression. Failure is associated with the Yandex DoH path under URL-test startup traffic. Evidence cannot distinguish remote server behavior, intermediate network interference, or shared client/DoH interoperability. It temporarily marks affected nodes unavailable and can fail a first lookup. No process crash or sustained total DNS outage observed. Working DNS remained Yandex; Cloudflare was tested only in temporary configs.
