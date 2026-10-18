"""Keep the shipped identity aligned with the approved prototype."""
import json
from pathlib import Path
import re
import subprocess
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
NS = {'svg': 'http://www.w3.org/2000/svg'}
LEGACY_NAMES = ('tex' + 'weft', '\u7b3a\u7eac')


class BrandContractTest(unittest.TestCase):
    def test_logo_matches_approved_v_geometry_and_solid_ink_teal(self):
        logo = ET.parse(ROOT / 'logo.svg').getroot()
        prototype = ET.parse(ROOT / 'design/assets/vex-logo.svg').getroot()
        self.assertEqual(logo.find('svg:rect', NS).get('fill'), '#24766B')
        self.assertEqual(logo.find('svg:path', NS).attrib, prototype.find('svg:path', NS).attrib)
        self.assertEqual(len(logo.findall('svg:path', NS)), 1)

    def test_flutter_and_windows_use_root_sources(self):
        for name in ('logo.svg', 'logo.png'):
            self.assertEqual((ROOT / name).read_bytes(), (ROOT / 'apps/vex/assets/brand' / name).read_bytes())
        self.assertEqual((ROOT / 'logo.ico').read_bytes(), (ROOT / 'apps/vex/windows/runner/resources/app_icon.ico').read_bytes())

    def test_android_has_solid_brand_tile_and_updated_names(self):
        base = ROOT / 'apps/vex/android/app/src'
        android = '{http://schemas.android.com/apk/res/android}'
        bg = ET.parse(base / 'main/res/drawable/ic_launcher_background.xml').getroot()
        self.assertEqual(bg.find('solid').get(android + 'color'), '#24766B')
        for flavor in ('main', 'preview'):
            for strings in (base / flavor / 'res').glob('values*/strings.xml'):
                name = ET.parse(strings).find('./string[@name="app_name"]').text
                self.assertIn('Vex', name)

    def test_localized_brand_titles(self):
        for locale in ('zh', 'zh_Hant', 'en', 'ja'):
            data = json.loads((ROOT / f'apps/vex/lib/l10n/app_{locale}.arb').read_text(encoding='utf-8'))
            self.assertIn('Vex', data['appTitle'])
            self.assertIn('Vex', data['guideDocument'])

    def test_repository_has_no_legacy_product_names(self):
        files = subprocess.check_output(
            ['git', 'ls-files', '-c', '-o', '--exclude-standard', '-z'], cwd=ROOT
        ).decode('utf-8').split('\0')
        violations = []
        for relative in sorted(set(files)):
            file = ROOT / relative
            if not relative or not file.is_file():
                continue
            if any(name in relative.lower() for name in LEGACY_NAMES):
                violations.append(relative)
                continue
            content = file.read_bytes()
            if b'\0' in content:
                continue
            try:
                text = content.decode('utf-8-sig').lower()
            except UnicodeDecodeError:
                continue
            if any(name in text for name in LEGACY_NAMES):
                violations.append(relative)
        self.assertEqual(violations, [], 'Legacy product names: ' + ', '.join(violations))

    def test_workspace_packages_and_entrypoints_use_lower_snake_case(self):
        packages = {
            'apps/vex': 'vex',
            'packages/vex_editor': 'vex_editor',
            'packages/vex_markdown_core': 'vex_markdown_core',
            'packages/vex_mindmap': 'vex_mindmap',
            'packages/vex_editor/example': 'vex_editor_example',
            'packages/vex_mindmap/example': 'vex_mindmap_example',
        }
        workspace = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
        for directory, name in packages.items():
            self.assertIn('  - ' + directory, workspace)
            spec = (ROOT / directory / 'pubspec.yaml').read_text(encoding='utf-8')
            self.assertRegex(spec, r'(?m)^name: ' + re.escape(name) + r'$')
            if directory.startswith('packages/') and not directory.endswith('/example'):
                self.assertTrue((ROOT / directory / 'lib' / (name + '.dart')).is_file())

    def test_platform_identities_and_desktop_binary_names(self):
        app = ROOT / 'apps/vex'
        gradle = (app / 'android/app/build.gradle.kts').read_text(encoding='utf-8')
        for setting in ('namespace', 'applicationId'):
            self.assertIn(setting + ' = "com.codewf.vex"', gradle)
        activity = app / 'android/app/src/main/kotlin/com/codewf/vex/MainActivity.kt'
        self.assertIn('package com.codewf.vex', activity.read_text(encoding='utf-8'))
        for platform in ('ios', 'macos'):
            project = (app / platform / 'Runner.xcodeproj/project.pbxproj').read_text(encoding='utf-8')
            self.assertIn('PRODUCT_BUNDLE_IDENTIFIER = com.codewf.vex', project)
        for platform in ('windows', 'linux'):
            cmake = (app / platform / 'CMakeLists.txt').read_text(encoding='utf-8')
            self.assertIn('set(BINARY_NAME "vex")', cmake)
        macos = (app / 'macos/Runner/Configs/AppInfo.xcconfig').read_text(encoding='utf-8')
        self.assertIn('PRODUCT_NAME = Vex', macos)
        installer = (ROOT / 'scripts/installer/Vex.iss').read_text(encoding='utf-8-sig')
        self.assertIn('AppId={{51E79E85-AD4C-4D48-92EC-C1EA09FB4E56}', installer)

    def test_windows_user_data_has_no_company_subdirectory(self):
        resources = (ROOT / 'apps/vex/windows/runner/Runner.rc').read_text(encoding='utf-8')
        self.assertRegex(resources, r'VALUE "CompanyName", "" "\\0"')
        self.assertRegex(resources, r'VALUE "ProductName", "Vex" "\\0"')
        self.assertIn('CodeWF', resources)


if __name__ == '__main__':
    unittest.main()
