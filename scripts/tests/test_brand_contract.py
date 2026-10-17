"""Keep the shipped identity aligned with the approved prototype."""
import json
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
NS = {'svg': 'http://www.w3.org/2000/svg'}


class BrandContractTest(unittest.TestCase):
    def test_logo_matches_approved_v_geometry_and_solid_ink_teal(self):
        logo = ET.parse(ROOT / 'logo.svg').getroot()
        prototype = ET.parse(ROOT / 'design/assets/vex-logo.svg').getroot()
        self.assertEqual(logo.find('svg:rect', NS).get('fill'), '#24766B')
        self.assertEqual(logo.find('svg:path', NS).attrib, prototype.find('svg:path', NS).attrib)
        self.assertEqual(len(logo.findall('svg:path', NS)), 1)

    def test_flutter_and_windows_use_root_sources(self):
        for name in ('logo.svg', 'logo.png'):
            self.assertEqual((ROOT / name).read_bytes(), (ROOT / 'apps/texweft/assets/brand' / name).read_bytes())
        self.assertEqual((ROOT / 'logo.ico').read_bytes(), (ROOT / 'apps/texweft/windows/runner/resources/app_icon.ico').read_bytes())

    def test_android_has_solid_brand_tile_and_updated_names(self):
        base = ROOT / 'apps/texweft/android/app/src'
        android = '{http://schemas.android.com/apk/res/android}'
        bg = ET.parse(base / 'main/res/drawable/ic_launcher_background.xml').getroot()
        self.assertEqual(bg.find('solid').get(android + 'color'), '#24766B')
        for flavor in ('main', 'preview'):
            for strings in (base / flavor / 'res').glob('values*/strings.xml'):
                name = ET.parse(strings).find('./string[@name="app_name"]').text
                self.assertIn('Vex', name)
                self.assertNotIn('Texweft', name)

    def test_localized_brand_titles(self):
        for locale in ('zh', 'zh_Hant', 'en', 'ja'):
            data = json.loads((ROOT / f'apps/texweft/lib/l10n/app_{locale}.arb').read_text(encoding='utf-8'))
            self.assertIn('Vex', data['appTitle'])
            self.assertNotIn('Texweft', data['guideDocument'])


if __name__ == '__main__':
    unittest.main()
