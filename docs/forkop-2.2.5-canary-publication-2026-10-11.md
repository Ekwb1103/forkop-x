# Forkop X 2.2.5-canary.1 publication

- Previous canary: 2.2.4-canary.1, source b2b1a481202aefcd4d539e78971cee26c04065aa.
- Release source: db00f5b95b7a57f25a082a2cb69f05b5cd115a95, existing main branch.
- Reviewed intervening commits 75270858 and bcaf16c2. Included transport-aware nft rulesets, runtime readiness and subscription rollback, DNS startup grace, GitHub backoff and the new service RSS monitoring.
- GitHub Actions run 38145700939 completed successfully and built all six APK/IPK packages.
- Release notes use the previous canary format and include the exact build source. Workflow dispatch now falls back to docs/releases/VERSION.md when tag notes are unavailable.
- Three APK packages signed on the existing mirror with its existing key; package identities, versions, lengths, hashes and signatures verified by scripts/release.py.
- Public prerelease published at https://github.com/Screamshow/forkop-x/releases/tag/2.2.5-canary.1.
- forkop-canary-mirror.service completed successfully. Public updates/canary.json, updates/releases.json, archived release.json and all six downloaded package SHA-256 hashes verified against the exact signed GitHub assets.
- Local service monitoring verification: 19 frontend tests, TypeScript check and LuCI build passed. OpenWrt 25 native ucode compilation and memory fixtures passed; live RSS read correctly without package/service changes.
- Release tooling: 15 focused tests passed. Fixed UTF-8 subprocess output on Windows and draft resume before GitHub creates the public tag; pinned source and conflicting-tag checks remain enforced.
- The initial mirror connection timeout and interrupted GitHub upload were recovered. No router packages were installed during publication; core repositories and versions were unchanged.
