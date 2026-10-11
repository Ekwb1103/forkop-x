#!/usr/bin/env python3
"""Download signed GitHub stable assets; caller holds the Git updater lock."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import urllib.request


def download(url):
    if not url.startswith('https://github.com/Screamshow/forkop-x/releases/download/'):
        raise ValueError('Unexpected GitHub asset URL')
    with urllib.request.urlopen(url, timeout=60) as response:
        return response.read()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--release-json', type=Path, required=True)
    args = parser.parse_args()
    release = json.loads(args.release_json.read_text())
    version = release['tag_name']
    if release.get('draft') or release.get('prerelease') or not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError('Public stable release required')
    names = {f'{p}_{version}.{ext}' for p in ('forkop', 'luci-app-forkop', 'luci-i18n-forkop-ru') for ext in ('apk', 'ipk')}
    names |= {'forkop-manifest.json', 'forkop-apk.pem', 'SHA256SUMS'}
    assets = {a['name']: a for a in release['assets']}
    with tempfile.TemporaryDirectory(prefix='forkop-signed-stable-', dir='/srv/mirror/build') as temp:
        directory = Path(temp)
        for name in sorted(names):
            asset = assets[name]
            data = download(asset['browser_download_url'])
            if len(data) != asset['size'] or 'sha256:' + hashlib.sha256(data).hexdigest() != asset['digest']:
                raise ValueError(f'GitHub checksum mismatch: {name}')
            (directory / name).write_bytes(data)
        manifest = json.loads((directory / 'forkop-manifest.json').read_text())
        if manifest['version'] != version:
            raise ValueError('Manifest version mismatch')
        subprocess.run(['python3', str(Path(__file__).with_name('publish-forkop-stable.py')), str(directory)], check=True)


if __name__ == '__main__':
    main()
