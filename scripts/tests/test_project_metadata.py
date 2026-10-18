"""Keep generated version metadata aligned with the application release."""
import json
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]


class ProjectMetadataTest(unittest.TestCase):
    def test_generated_versions_match_app_pubspec(self):
        spec = (ROOT / 'apps/vex/pubspec.yaml').read_text(encoding='utf-8')
        version = re.search(r'^version:\s*(\S+)', spec, re.M).group(1)
        dart = (ROOT / 'apps/vex/lib/data/app_version.dart').read_text(encoding='utf-8')
        self.assertIn(f"const vexVersion = '{version}';", dart)
        script = (ROOT / 'design/assets/project-info.js').read_text(encoding='utf-8')
        metadata = json.loads(re.search(r'window\.VexProject = (.+);', script).group(1))
        self.assertEqual(metadata['version'], version)


if __name__ == '__main__':
    unittest.main()
