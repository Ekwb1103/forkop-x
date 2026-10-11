# Local Telegram monitoring fix

GitHub releases and tags 0.0.7 and 0.0.8 were removed at the user's request, and the 0.0.8 release workflow cancelled. Changes remain on main at `1a4d4375e189c4067de28fffef4b361d7eaf00fc`. Public mirror latest was restored to 0.0.6; the public 0.0.7 directory was withdrawn.

Rust X binaries and APK/IPK packages were built locally under WSL on the operator computer. APKs were signed in a private directory using the existing mirror key, without creating a public release or catalog.

The local 0.0.8-r1 ARM64 APK was installed on 192.168.90.1 after signature, size and SHA-256 verification. Forkop restarted successfully and both UCI checksums stayed unchanged. Prior package and UCI backups remain under `/root/rust-x-local008-rollback`.

Installed binary SHA-256 matched the locally built binary: `2fb3f70f1c099b77a80e65eb4b1274525723836e3ef79fb417d83146f6acc9c5`.

The production API returned a live `149.154.167.50` connection with `rulePayload=rule_set=VPN-telegram-community-ruleset`; its full logical rule also contained that tag. The existing UI formatter maps this tag to Telegram. Browser rendering was not inspected. A subsequent snapshot had no active connections.

Five focused monitoring tests, strict workspace/all-target Clippy and seven frontend route-reason tests passed.
