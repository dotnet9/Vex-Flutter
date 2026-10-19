import importlib.util
from pathlib import Path
import plistlib
import subprocess
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('entitlements', ROOT / 'scripts/packaging/osx/verify_entitlements.py')
entitlements = importlib.util.module_from_spec(spec)
spec.loader.exec_module(entitlements)


class MacEntitlementsTests(unittest.TestCase):
    def test_debug_and_release_grant_user_selected_file_access(self):
        for name in ('Release', 'DebugProfile'):
            entitlements.validate((ROOT / f'apps/vex/macos/Runner/{name}.entitlements').read_bytes())

    def test_missing_file_access_is_rejected(self):
        payload = {key: True for key in entitlements.REQUIRED}
        payload.pop('com.apple.security.files.user-selected.read-write')
        with self.assertRaisesRegex(ValueError, 'user-selected.read-write'):
            entitlements.validate(plistlib.dumps(payload))

    def test_checks_both_signed_architectures(self):
        with patch.object(entitlements.subprocess, 'check_output',
                          return_value=plistlib.dumps({key: True for key in entitlements.REQUIRED})) as command:
            entitlements.verify(Path('Vex.app'))
        self.assertEqual([call.args[0][3] for call in command.call_args_list], ['x86_64', 'arm64'])

    def test_falls_back_when_xml_flag_is_unsupported(self):
        payload = plistlib.dumps({key: True for key in entitlements.REQUIRED})
        with patch.object(entitlements.subprocess, 'check_output',
                          side_effect=[subprocess.CalledProcessError(1, 'codesign'), payload,
                                       subprocess.CalledProcessError(1, 'codesign'), payload]) as command:
            entitlements.verify(Path('Vex.app'))
        self.assertIn('--xml', command.call_args_list[0].args[0])
        self.assertNotIn('--xml', command.call_args_list[1].args[0])

    def test_packaging_signs_explicitly_and_checks_finished_dmg(self):
        script = (ROOT / 'scripts/packaging/osx/package.sh').read_text(encoding='utf-8')
        self.assertIn('--entitlements "$root/apps/vex/macos/Runner/Release.entitlements"', script)
        self.assertNotIn('codesign --force --deep --sign -', script)
        self.assertEqual(script.count('verify_entitlements.py'), 2)


if __name__ == '__main__':
    unittest.main()
