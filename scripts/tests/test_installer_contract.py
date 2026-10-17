"""Check public package branding while keeping installed upgrade identities stable."""
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[2]


class InstallerContractTest(unittest.TestCase):
    def test_windows_uses_native_controls_and_only_brand_bitmaps(self):
        script = (ROOT / 'scripts/installer/Texweft.Setup.iss').read_text(encoding='utf-8-sig')
        self.assertIn('TNewButton.Create', script)
        self.assertIn('TNewCheckBox.Create', script)
        self.assertIn('UTF8Decode(LicenseText)', script)
        self.assertIn('TWProgress.Width*TWProgressValue div 100', script)
        self.assertIn('TWProgressNote.Visible:=False; TWFile.Visible:=False;', script)
        self.assertNotIn('skin-', script)
        for theme in ('light', 'dark'):
            data = (ROOT / f'scripts/installer/assets/hero-{theme}.bmp').read_bytes()
            self.assertEqual(data[:2], b'BM')
            self.assertEqual(struct.unpack_from('<ii', data, 18), (224, 224))

    def test_upgrade_ids_stay_stable(self):
        windows = (ROOT / 'scripts/installer/Texweft.iss').read_text(encoding='utf-8-sig')
        self.assertIn('51E79E85-AD4C-4D48-92EC-C1EA09FB4E56', windows)
        self.assertIn('Texweft.Markdown', windows)
        self.assertIn('OutputBaseFilename=Vex-v', windows)
        self.assertIn('DefaultDirName={localappdata}\\Programs\\Vex', windows)
        linux = (ROOT / 'scripts/package_linux.sh').read_text(encoding='utf-8')
        self.assertIn('Package: texweft', linux)
        self.assertIn('Name=Vex', linux)
        self.assertIn('Name[zh_CN]=维刻 Vex', linux)
        self.assertIn('Vex-v$version-linux-', linux)
        macos = (ROOT / 'scripts/package_macos.sh').read_text(encoding='utf-8')
        self.assertIn('$stage/Vex.app', macos)
        self.assertIn('$mount/Vex.app', macos)
        self.assertIn('Vex-v$version-macos-', macos)


if __name__ == '__main__':
    unittest.main()
