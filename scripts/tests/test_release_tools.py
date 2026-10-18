"""Regression checks for the release boundary (never use these fixtures as artifacts)."""
import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location('release_tools', Path(__file__).resolve().parents[1] / 'release_tools.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseContractTest(unittest.TestCase):
    def test_current_brand_and_signed_platform_boundary(self):
        self.assertEqual(release.filename('windows-x64', '1.2.3'), 'Vex-v1.2.3-windows-x64-setup.exe')
        self.assertEqual(len(release.DEFAULT_TARGETS), 7)
        self.assertNotIn('ios', release.DEFAULT_TARGETS)
        self.assertNotIn('harmonyos', release.DEFAULT_TARGETS)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.version = '1.2.3'
        self.target = 'windows-x64'
        self.path = self.directory / release.filename(self.target, self.version)
        content = bytearray(2048)
        content[:2] = b'MZ'
        struct.pack_into('<I', content, 60, 128)
        content[128:132] = b'PE\0\0'
        self.path.write_bytes(content)
        self.hash_path = self.path.with_name(self.path.name + '.sha256')
        self.hash_path.write_text(f'{release.sha256(self.path)}  {self.path.name}\n', encoding='ascii')

    def verify(self):
        release.verify(self.directory, [self.target], self.version)

    def test_accept_complete_pair(self):
        self.verify()

    def test_reject_portable_archive(self):
        (self.directory / 'portable.zip').write_bytes(b'PK')
        with self.assertRaisesRegex(ValueError, 'unexpected'):
            self.verify()

    def test_reject_missing_platform(self):
        with self.assertRaises(FileNotFoundError):
            release.verify(self.directory, ['linux-arm64'], self.version)

    def test_reject_renamed_archive(self):
        self.path.write_bytes(b'PK' + bytes(2048))
        with self.assertRaisesRegex(ValueError, 'PE executable'):
            self.verify()

    def test_reject_tampered_installer(self):
        with self.path.open('ab') as output:
            output.write(b'changed')
        with self.assertRaisesRegex(ValueError, 'Checksum'):
            self.verify()

    def test_reject_checksum_for_another_file(self):
        self.hash_path.write_text(f'{release.sha256(self.path)}  other.exe\n')
        with self.assertRaisesRegex(ValueError, 'Checksum'):
            self.verify()

    def test_reject_debug_or_wrong_abi_apk(self):
        path = self.directory / 'wrong.apk'
        with zipfile.ZipFile(path, 'w') as apk:
            apk.writestr('AndroidManifest.xml', bytes(2048))
            apk.writestr('lib/x86_64/libapp.so', bytes(2048))
        with self.assertRaisesRegex(ValueError, 'arm64-v8a'):
            release.check_installer(path, 'android-arm64', self.version)

    def test_reject_unsigned_ipa(self):
        import plistlib
        path = self.directory / 'unsigned.ipa'
        with zipfile.ZipFile(path, 'w') as ipa:
            ipa.writestr('Payload/Runner.app/Info.plist', plistlib.dumps({
                'CFBundleIdentifier': 'com.codewf.vex', 'CFBundleShortVersionString': self.version}))
            ipa.writestr('Payload/Runner.app/Runner', bytes(2048))
        with self.assertRaisesRegex(ValueError, 'signature is missing'):
            release.check_installer(path, 'ios', self.version)


if __name__ == '__main__':
    unittest.main()
