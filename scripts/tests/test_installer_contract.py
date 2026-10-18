"""Check public package branding while keeping installed upgrade identities stable."""
from pathlib import Path
import importlib.util
import re
import struct
import unittest

ROOT = Path(__file__).resolve().parents[2]


class InstallerContractTest(unittest.TestCase):
    def test_optional_test_identity_stays_outside_production_registration(self):
        pattern = r'^Texweft\.Installer\.Test(?:[.-][A-Za-z0-9_-]+)*$'
        for name in ('package_windows.ps1', 'test_windows_installer.ps1'):
            script = (ROOT / 'scripts' / name).read_text(encoding='utf-8-sig')
            self.assertIn(f"[ValidatePattern('{pattern}')]", script)
            self.assertIn("[ValidateLength(1, 100)]", script)
            self.assertIn('A custom test identity requires -InstallerTest.', script)
        self.assertIsNotNone(re.fullmatch(pattern, 'Texweft.Installer.Test.Close-20261018'))
        self.assertIsNone(re.fullmatch(pattern, '{51E79E85-AD4C-4D48-92EC-C1EA09FB4E56}'))
        self.assertIsNone(re.fullmatch(pattern, 'Texweft.Installer.Test/Other'))
        self.assertIsNone(re.fullmatch(pattern, 'Texweft.Installer.Test"Other'))
        setup = (ROOT / 'scripts/installer/Texweft.iss').read_text(encoding='utf-8-sig')
        self.assertIn('AppId={#InstallerTestId}', setup)
        self.assertIn('DefaultDirName={localappdata}\\Temp\\{#InstallerTestId}', setup)

    def test_finder_drag_layout_and_retina_assets(self):
        spec = importlib.util.spec_from_file_location('macos_dmg', ROOT / 'scripts/build_macos_dmg.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        layout = module.layout_settings(Path('/temporary/Vex.app'))
        self.assertEqual(layout['symlinks'], {'Applications': '/Applications'})
        self.assertEqual(layout['hide_extensions'], [])
        self.assertFalse(layout['show_toolbar'])
        self.assertFalse(layout['show_sidebar'])
        self.assertEqual(layout['arrange_by'], None)
        for x, y in layout['icon_locations'].values():
            self.assertGreater(x - module.ICON_SIZE / 2, 0)
            self.assertLess(x + module.ICON_SIZE / 2, module.WINDOW_SIZE[0])
            self.assertGreater(y - module.ICON_SIZE / 2, 110)
            self.assertLess(y + module.ICON_SIZE / 2 + 40, 310)
        for scale, suffix in ((1, ''), (2, '@2x')):
            data = (ROOT / f'scripts/installer/assets/macos-background{suffix}.png').read_bytes()
            self.assertEqual(data[:8], b'\x89PNG\r\n\x1a\n')
            self.assertEqual(struct.unpack_from('>II', data, 16), tuple(n * scale for n in module.WINDOW_SIZE))

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
