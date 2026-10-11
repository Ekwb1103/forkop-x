#!/usr/bin/env python3
"""Publish a verified Rust X release directory to the Forkop mirror."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
parser.add_argument('destination', type=Path)
parser.add_argument('--latest', action='store_true')
args = parser.parse_args()
source = args.source
m = json.loads((source / 'openwrt-manifest.json').read_text())
version = m['version']
assert re.fullmatch(r'\d+\.\d+\.\d+', version)
assert m['apk_signed'] is True
assert hashlib.sha256((source / 'forkop-apk.pem').read_bytes()).hexdigest() == m['signing_public_key_sha256']
assert len(m['assets']) == 4
assert {(a['architecture'], a['format']) for a in m['assets']} == {
    (arch, fmt) for arch in ('x86_64', 'aarch64_cortex-a53') for fmt in ('apk', 'ipk')}
assets = []
for a in m['assets']:
    revision = 'r1' if a['format'] == 'apk' else '1'
    assert a['package'] == 'rust-x' and a['version'] == version + '-' + revision
    assert a['file'] == f'rust-x_{a["version"]}_{a["architecture"]}.{a["format"]}'
    p = source / a['file']
    assert p.stat().st_size == a['size']
    assert hashlib.sha256(p.read_bytes()).hexdigest() == a['sha256']
    if a['format'] == 'apk':
        assert a['signed'] is True
    assets.append({**a, 'name': a['file'],
                   'url': f'https://mirror.51343.ru/forkop/rust-x/releases/{version}/{a["file"]}'})
catalog = {**m, 'schema': 1, 'name': 'rust-x', 'package_revision': 1, 'assets': assets}
target = args.destination / 'releases' / version
target.mkdir(parents=True, exist_ok=True)
for a in assets:
    p = target / a['name']
    if p.exists():
        assert hashlib.sha256(p.read_bytes()).hexdigest() == a['sha256'], 'Refusing to replace existing package'
    else:
        shutil.copyfile(source / a['name'], p)
for name in ('openwrt-manifest.json', 'forkop-apk.pem', 'SHA256SUMS'):
    shutil.copyfile(source / name, target / name)
data = json.dumps(catalog, indent=2) + '\n'
(target / 'manifest.json').write_text(data)
if args.latest:
    pending = args.destination / 'latest.json.tmp'
    pending.write_text(data)
    pending.replace(args.destination / 'latest.json')
print(f'Verified Rust X {version}: {len(assets)} packages')
