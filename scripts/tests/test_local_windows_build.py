"""Keep the double-click entry local, reproducible and separate from installation."""
from pathlib import Path
import json
import os
import re
import shutil
import subprocess
import tempfile
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
        self.assertGreater(script.index('scripts/sync_builtin_documents.py'), script.index('if ($CheckOnly)'))
        self.assertLess(script.index('scripts/sync_builtin_documents.py'), script.index("'pub', 'get'"))

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

    def test_command_resolution_selects_one_executable_when_path_has_duplicates(self):
        script = (ROOT / 'scripts/packaging/win-x64/build.ps1').read_text(encoding='ascii')
        expressions = [re.search(r'Get-Command ' + re.escape(name) + r'[^\n]+', script).group(0)
                       for name in ('python', 'flutter.bat')]
        for expression in expressions:
            self.assertIn('| Select-Object -First 1', expression)
        if os.name != 'nt':
            return
        shell = Path(os.environ['SystemRoot']) / 'System32/WindowsPowerShell/v1.0/powershell.exe'
        with tempfile.TemporaryDirectory(prefix='vex command paths ') as temporary:
            paths = [Path(temporary) / name for name in ('first', 'second')]
            for path in paths:
                path.mkdir()
                shutil.copyfile(Path(os.environ['SystemRoot']) / 'System32/cmd.exe', path / 'python.exe')
                (path / 'flutter.bat').write_text('@exit /b 0\n', encoding='ascii')
            for name, expression in zip(('python.exe', 'flutter.bat'), expressions):
                expected = str(paths[0] / name).replace("'", "''")
                command = (f"$env:PATH='{';'.join(str(path) for path in paths)}'; "
                           f"$found=@({expression}); "
                           f"if ($found.Count -ne 1 -or $found[0].Source -ne '{expected}') {{ exit 1 }}")
                environment = dict(os.environ, PSModulePath=str(shell.parents[1] / 'v1.0/Modules'))
                result = subprocess.run([str(shell), '-NoLogo', '-NoProfile', '-Command', command],
                                        env=environment, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    @unittest.skipUnless(os.name == 'nt', 'Windows NTFS junction behavior')
    def test_plugin_links_are_idempotent_and_leave_packages_and_metadata_unchanged(self):
        shell = Path(os.environ['SystemRoot']) / 'System32/WindowsPowerShell/v1.0/powershell.exe'
        script = ROOT / 'scripts/packaging/win-x64/build.ps1'
        with tempfile.TemporaryDirectory(prefix='vex plugin paths ') as temporary:
            root = Path(temporary)
            package = root / 'pub cache/plugin source'
            package.mkdir(parents=True)
            (package / 'marker.txt').write_text('package remains intact', encoding='ascii')
            for platform in ('windows', 'linux'):
                (root / f'apps/vex/{platform}').mkdir(parents=True)
            manifest = root / 'apps/vex/.flutter-plugins-dependencies'
            metadata = json.dumps({'plugins': {
                platform: [{'name': 'test_plugin', 'path': str(package)}]
                for platform in ('windows', 'linux')
            }})
            manifest.write_text(metadata, encoding='utf-8')
            root_literal = str(root).replace("'", "''")
            script_literal = str(script).replace("'", "''")
            command = (
                "$ErrorActionPreference = 'Stop'; "
                f"$root = '{root_literal}'; "
                f"$source = [IO.File]::ReadAllText('{script_literal}'); "
                "$tree = [System.Management.Automation.Language.Parser]::ParseInput($source, [ref]$null, [ref]$null); "
                "$function = $tree.Find({ param($node) "
                "$node -is [System.Management.Automation.Language.FunctionDefinitionAst] "
                "-and $node.Name -eq 'Initialize-PluginLinks' }, $true); "
                ". ([ScriptBlock]::Create($function.Extent.Text)); "
                "Initialize-PluginLinks; Initialize-PluginLinks"
            )
            environment = dict(os.environ, PSModulePath=str(shell.parent / 'Modules'))
            result = subprocess.run([str(shell), '-NoLogo', '-NoProfile', '-Command', command],
                                    env=environment, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            for platform in ('windows', 'linux'):
                link = root / f'apps/vex/{platform}/flutter/ephemeral/.plugin_symlinks/test_plugin'
                self.assertTrue(link.is_dir())
                self.assertEqual(link.resolve(), package.resolve())
                self.assertEqual((link / 'marker.txt').read_text(encoding='ascii'), 'package remains intact')
            self.assertEqual(manifest.read_text(encoding='utf-8'), metadata)
            self.assertEqual((package / 'marker.txt').read_text(encoding='ascii'), 'package remains intact')


if __name__ == '__main__':
    unittest.main()
