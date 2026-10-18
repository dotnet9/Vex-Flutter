"""Keep the double-click entry local, reproducible and separate from installation."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class LocalWindowsBuildTest(unittest.TestCase):
    def test_batch_preserves_exit_code_and_keeps_the_window_visible(self):
        compatibility = (ROOT / 'build-windows.bat').read_text(encoding='ascii')
        self.assertIn('call "%~dp0scripts\\packaging\\win-x64\\build.bat" %*', compatibility)
        batch = (ROOT / 'scripts/packaging/win-x64/build.bat').read_text(encoding='ascii')
        self.assertIn('%~dp0build.ps1', batch)
        self.assertIn('set "VEX_BUILD_EXIT=%ERRORLEVEL%"', batch)
        self.assertIn('if not defined VEX_NO_PAUSE pause', batch)
        self.assertIn('exit /b %VEX_BUILD_EXIT%', batch)
        self.assertIn('set "PSModulePath=%SystemRoot%\\System32\\WindowsPowerShell\\v1.0\\Modules"', batch)

    def test_build_uses_version_metadata_and_pinned_dependency_resolution(self):
        script = (ROOT / 'scripts/packaging/win-x64/build.ps1').read_text(encoding='ascii')
        for text in ('release_tools.py', 'metadata', 'frameworkVersion', '--suppress-analytics',
                     '--enforce-lockfile', "'--release'", "'lib/main.dart'"):
            self.assertIn(text, script)
        self.assertNotRegex(script, r'(?i)flutter\s+upgrade')

    def test_generated_installers_are_separate_from_github_release_staging(self):
        script = (ROOT / 'scripts/packaging/win-x64/build.ps1').read_text(encoding='ascii')
        self.assertIn('artifacts/local/win-x64/', script)
        self.assertIn('artifacts/build-logs', script)
        self.assertIn("'checksums'", script)
        self.assertIn("'verify'", script)
        self.assertIn("'windows-x64'", script)
        self.assertNotIn('artifacts/release', script)

    def test_default_build_tests_before_producing_an_installer(self):
        script = (ROOT / 'scripts/packaging/win-x64/build.ps1').read_text(encoding='ascii')
        self.assertIn('if ($SkipTests)', script)
        self.assertIn("'analyze', '--no-pub'", script)
        self.assertIn('packages/vex_markdown_core', script)
        self.assertIn('packages/vex_editor', script)
        self.assertIn('packages/vex_mindmap', script)
        self.assertIn('scripts/tests', script)
        self.assertLess(script.index('if ($SkipTests)'), script.index("'build', 'windows'"))

    def test_entry_does_not_install_the_product_or_publish_it(self):
        script = (ROOT / 'scripts/packaging/win-x64/build.ps1').read_text(encoding='ascii')
        for pattern in (r'(?im)^\s*&\s*\$installerPath', r'(?im)^\s*(?:&\s+)?git\s+push',
                        r'(?im)^\s*(?:&\s+)?gh\s+release\s+create', r'(?i)/VERYSILENT'):
            self.assertIsNone(re.search(pattern, script))
        self.assertIn('$CheckOnly', script)
        self.assertIn('exit $exitCode', script)

    def test_cached_inno_download_still_checks_hash_and_signature(self):
        script = (ROOT / 'scripts/packaging/win-x64/install_inno.ps1').read_text(encoding='ascii')
        self.assertIn('if (-not $cached)', script)
        self.assertEqual(script.count('Get-FileHash -LiteralPath $download -Algorithm SHA256'), 2)
        self.assertIn('Get-AuthenticodeSignature', script)
        self.assertLess(script.index('Get-AuthenticodeSignature'), script.index('Start-Process'))


if __name__ == '__main__':
    unittest.main()
