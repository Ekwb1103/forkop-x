import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


signer = module('signer', ROOT / 'mirror/sign-forkop-release.py')
release = module('release', ROOT / 'scripts/release.py')


def archive(name, data):
    output = io.BytesIO()
    with tarfile.open(fileobj=output, mode='w:gz') as tar:
        member = tarfile.TarInfo(name)
        member.size = len(data)
        tar.addfile(member, io.BytesIO(data))
    return output.getvalue()


class SignatureGateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        version = '2.2.3-canary.1'
        self.manifest = dict(version=version, source_commit='a' * 40, apk_signed=False, assets=[])
        for package in signer.PACKAGES:
            for ext in ('apk', 'ipk'):
                name = f'{package}_{version}.{ext}'
                data = b'unsigned-test-apk'
                if ext == 'ipk':
                    control = f'Package: {package}\nVersion: {version}\nArchitecture: all\n'.encode()
                    data = archive('./control.tar.gz', archive('./control', control))
                (self.directory / name).write_bytes(data)
                self.manifest['assets'].append(dict(file=name, package=package, format=ext,
                    architecture='noarch' if ext == 'apk' else 'all', version=signer.apk_version(version) if ext == 'apk' else version,
                    size=len(data), sha256=hashlib.sha256(data).hexdigest()))

    def test_accepts_complete_release_with_correct_ipk_identity(self):
        signer.validate(self.directory, self.manifest)

    def test_rejects_corruption(self):
        (self.directory / self.manifest['assets'][0]['file']).write_bytes(b'corrupted')
        with self.assertRaisesRegex(ValueError, 'Checksum'):
            signer.validate(self.directory, self.manifest)

    def test_rejects_missing_duplicate_or_traversal_asset(self):
        for kind in ('missing', 'duplicate', 'traversal'):
            with self.subTest(kind=kind):
                manifest = copy.deepcopy(self.manifest)
                if kind == 'missing':
                    manifest['assets'].pop()
                elif kind == 'duplicate':
                    manifest['assets'][-1] = manifest['assets'][0]
                else:
                    manifest['assets'][0]['file'] = '../foreign.apk'
                with self.assertRaisesRegex(ValueError, 'six'):
                    signer.validate(self.directory, manifest)

    def test_rejects_wrong_ipk_control_even_with_matching_hash(self):
        asset = next(a for a in self.manifest['assets'] if a['format'] == 'ipk')
        data = archive('control.tar.gz', archive('control', b'Package: foreign\nVersion: 2.2.3-canary.1\nArchitecture: all\n'))
        (self.directory / asset['file']).write_bytes(data)
        asset.update(size=len(data), sha256=hashlib.sha256(data).hexdigest())
        with self.assertRaisesRegex(ValueError, 'IPK metadata'):
            signer.validate(self.directory, self.manifest)

    def test_signed_flag_required_for_each_apk(self):
        self.manifest['apk_signed'] = True
        with self.assertRaisesRegex(ValueError, 'Unsigned APK'):
            signer.validate(self.directory, self.manifest, signed=True)

    def test_signed_key_hash_checked(self):
        for asset in self.manifest['assets']:
            asset['signed'] = True
        self.manifest.update(apk_signed=True, signing_public_key_sha256='0' * 64)
        (self.directory / 'forkop-apk.pem').write_bytes(b'public-key')
        with self.assertRaisesRegex(ValueError, 'Public key'):
            signer.validate(self.directory, self.manifest, signed=True)

    def test_mismatched_uploaded_digest_rejected(self):
        asset = self.manifest['assets'][0]
        uploaded = dict(assets=[dict(name=asset['file'], size=asset['size'], digest='sha256:' + '0' * 64)])
        with self.assertRaisesRegex(ValueError, 'GitHub asset'):
            release.verify_uploaded(uploaded, self.directory, [asset['file']])

    def test_failed_build_stops_gate(self):
        with patch.object(release, 'gh', return_value=dict(headSha='a' * 40, status='completed', conclusion='failure')):
            with self.assertRaisesRegex(RuntimeError, 'Build failed'):
                release.wait_run('example/repo', 1, 'a' * 40, 1)

    def test_build_from_changed_main_rejected(self):
        with patch.object(release, 'gh', return_value=dict(headSha='b' * 40, status='completed', conclusion='success')):
            with self.assertRaisesRegex(ValueError, 'source changed'):
                release.wait_run('example/repo', 1, 'a' * 40, 1)

    def test_canary_version_order(self):
        self.assertLess(release.version_key('2.2.3-canary.2'), release.version_key('2.2.3-canary.10'))
        self.assertLess(release.version_key('2.2.3-canary.10'), release.version_key('2.2.3'))

    def operation(self):
        return release.Release(SimpleNamespace(output=self.directory, ssh_key=Path('test-key'), timeout=1, resume=True), 'forkop', '2.2.3-canary.1')

    def test_public_release_cannot_be_resigned(self):
        operation = self.operation()
        with patch.object(operation, 'current', return_value={'isDraft': False}), patch.object(release, 'run') as mutate:
            with self.assertRaisesRegex(ValueError, 'public Forkop'):
                operation.finalize_forkop()
            mutate.assert_not_called()

    def test_unsigned_public_release_resume_cannot_modify_github(self):
        operation = self.operation()
        operation.source = 'a' * 40
        operation.directory.mkdir(parents=True)
        (operation.directory / 'forkop-manifest.json').write_text(json.dumps(self.manifest))
        for asset in self.manifest['assets']:
            (operation.directory / asset['file']).write_bytes((self.directory / asset['file']).read_bytes())
        with patch.object(operation, 'current', return_value={'isDraft': False}), patch.object(release, 'run') as commands:
            with self.assertRaisesRegex(ValueError, 'Unsigned APK'):
                operation.finalize()
            self.assertTrue(all(call.args[:3] == ('gh', 'release', 'download') for call in commands.call_args_list))


if __name__ == '__main__':
    unittest.main()
