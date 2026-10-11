# Signed releases in one command

Run on the operator computer from the Forkop main checkout with Python 3,
authenticated `gh`, OpenSSH and access to the existing mirror. The SSH key
defaults to `~/.ssh/codex_forkop_mt6000`. The private APK signing key stays on
the mirror; neither private key is uploaded to GitHub Actions.

```powershell
python scripts/release.py --forkop 2.2.3-canary.1
python scripts/release.py --rust 0.0.8
python scripts/release.py --forkop 2.2.3-canary.1 --rust 0.0.8
```

These are example **new** versions. For Rust X first prepare and push the
workspace version, Cargo.lock and release notes on its existing main branch.
Keep its checkout at `artifacts/tachyon-core`. The command checks the GitHub
main version before it creates a tag. Forkop accepts `x.y.z` and
`x.y.z-canary.N`; its package version is set by the build workflow.

The command checks prerequisites, starts a release workflow, waits for the
exact source commit to build successfully and signs APK on the existing
mirror. It validates package identities and hashes, checks signatures
against the mirror's trusted public key, uploads the signed files to the
draft and verifies their GitHub sizes/digests before publishing. IPK remains
unchanged and is verified by SHA-256. Forkop APK uses `noarch` and maps
`-canary.N` to `_rcN`; IPK retains the public version and architecture `all`.

Forkop's workflow now leaves a draft, including when triggered by a tag.
It no longer exposes unsigned packages as a public release. Rust X already
uses this draft gate. Use the operator command for both projects; no GitHub
signing secret or self-hosted runner is required. Forkop releases include
`forkop-manifest.json`, `forkop-apk.pem` and `SHA256SUMS`; Rust X retains its
existing `openwrt-manifest.json` format.

After publication the command runs the existing stable/canary mirror service
or publishes Rust X's signed directory. It downloads the public packages and
checks catalogs, archived manifests and hashes. The mirror's anonymous
GitHub cache may delay canary selection; synchronization retries within the
timeout. The default timeout is 1800 seconds. Signed output is retained in
`artifacts/signed-releases`.

If signing, uploading or synchronization was interrupted:

```powershell
python scripts/release.py --forkop 2.2.3-canary.1 --resume
python scripts/release.py --rust 0.0.8 --resume
```

A draft can be finalized on retry. An already public signed release can only
be downloaded, verified and synchronized; its assets are never replaced.
Older unsigned Forkop releases cannot be converted using `--resume` because
their mirror archives and hashes are immutable. Publish a new version.
Do not resume an old release to move a channel pointer backward.

Install/update compatibility is retained: the existing installer and LuCI
paths can install signed APK as well as historical unsigned rollback APK.
This change does not remove `--allow-untrusted` from legacy installation or
rollback paths. It adds publisher signatures and enforces them during release
publication, without changing the existing client trust policy.

Verification:

```powershell
python -m unittest discover -s scripts/tests -p test_signed_release.py
```
