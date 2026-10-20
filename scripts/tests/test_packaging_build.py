"""Exercise unified build recipes without building, signing or installing apps."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
ENTRY = ROOT / 'scripts/packaging/build.py'
spec = importlib.util.spec_from_file_location('packaging_build', ENTRY)
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)


class PackagingBuildTest(unittest.TestCase):
    def args(self, target, *options):
        return build.parser().parse_args([target, *options])

    def steps(self, target, *options):
        args = self.args(target, *options)
        canonical = build.canonical_target(target)
        return build.recipe(args, canonical, 'flutter', 'dart', build.output_directory(canonical))

    def test_all_target_entries_exist_and_forward_arguments(self):
        for target in ('linux-x64', 'linux-arm64', 'osx-x64', 'osx-arm64', 'osx-universal', 'android'):
            wrapper = (ENTRY.parent / target / 'build.sh').read_text(encoding='ascii')
            self.assertIn(f'build.py" {target} "$@"', wrapper)
            self.assertIn('BASH_SOURCE[0]', wrapper)
            self.assertIn('exec "${VEX_PYTHON:-python3}"', wrapper)
        batch = (ENTRY.parent / 'android/build.bat').read_text(encoding='ascii')
        self.assertIn('build.py" android %*', batch)
        self.assertIn('exit /b %VEX_BUILD_EXIT%', batch)

    def test_macos_architecture_entries_preserve_the_universal_release_contract(self):
        for target in ('osx-x64', 'osx-arm64', 'osx-universal'):
            self.assertEqual(build.canonical_target(target), 'osx-universal')
            steps = self.steps(target, '--skip-tests')
            commands = [command for command, _ in steps]
            self.assertIn(['flutter', 'config', '--no-enable-macos-arm64-only'], commands)
            self.assertEqual(commands[-1][-1], 'macos-universal')
            pip = next(command for command in commands if '--require-hashes' in command)
            self.assertIn('artifacts/tools/macos-dmg', pip[0].replace('\\', '/'))

    def test_cli_accepts_only_documented_build_targets(self):
        for target in build.TARGETS:
            with self.subTest(target=target):
                self.assertEqual(self.args(target).target, target)
        for target in ('windows-x64', 'macos-universal', 'unknown'):
            with self.subTest(target=target), contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as error:
                    self.args(target)
                self.assertEqual(error.exception.code, 2)

    def test_hosts_and_linux_architectures_are_not_silently_cross_compiled(self):
        for target, system, machine in (
            ('win-x64', 'Linux', 'x86_64'), ('win-x64', 'Windows', 'ARM64'),
            ('linux-arm64', 'Linux', 'x86_64'),
            ('linux-x64', 'Linux', 'aarch64'), ('linux-x64', 'Windows', 'AMD64'),
            ('osx-universal', 'Windows', 'AMD64'), ('ios-check', 'Linux', 'x86_64'),
        ):
            with self.subTest(target=target, system=system, machine=machine):
                with self.assertRaises(ValueError):
                    build.validate_host(target, system, machine)
        for target, system, machine in (
            ('win-x64', 'Windows', 'AMD64'), ('linux-arm64', 'Linux', 'aarch64'),
            ('linux-x64', 'Linux', 'x86_64'), ('osx-universal', 'Darwin', 'arm64'),
            ('android', 'Windows', 'AMD64'), ('android', 'Darwin', 'arm64'),
        ):
            build.validate_host(target, system, machine)

    def test_local_output_is_isolated_by_target_and_version(self):
        version, number = build.app_version()
        for target in build.TARGETS:
            self.assertEqual(build.output_directory(target), ROOT / f'artifacts/local/{target}/v{version}-build{number}')
        self.assertEqual(build.output_directory('android', Path('artifacts/a space')), ROOT / 'artifacts/a space')

    def test_default_tests_precede_release_build_and_use_explicit_production_entry(self):
        steps = self.steps('linux-x64')
        commands = [command for command, _ in steps]
        self.assertEqual(commands[0], [sys.executable, str(ROOT / 'scripts/sync_builtin_documents.py')])
        self.assertEqual(commands[1], ['flutter', 'pub', 'get', '--enforce-lockfile'])
        self.assertIn(['flutter', 'analyze', '--no-pub'], commands)
        self.assertIn(['dart', 'test', '--concurrency=2'], commands)
        self.assertEqual(sum(command[1:3] == ['test', '--no-pub'] for command in commands), 3)
        build_index = next(i for i, command in enumerate(commands) if command[1:3] == ['build', 'linux'])
        self.assertIn('scripts/tests', commands[build_index - 1])
        self.assertEqual(commands[build_index][-2:], ['--target', 'lib/main.dart'])
        self.assertEqual(steps[build_index][1], ROOT / 'apps/vex')

    def test_skip_tests_keeps_locked_dependencies_and_artifact_checks(self):
        for target in ('linux-x64', 'linux-arm64', 'osx-universal', 'android'):
            commands = [command for command, _ in self.steps(target, '--skip-tests', '--dry-run')]
            self.assertEqual(commands[0], [sys.executable, str(ROOT / 'scripts/sync_builtin_documents.py')])
            self.assertIn('--enforce-lockfile', commands[1])
            self.assertFalse(any('analyze' in command or 'test' in command for command in commands))
            self.assertEqual(commands[-2][2], 'checksums')
            self.assertEqual(commands[-1][2], 'verify')

    def test_android_recipe_requires_production_abis_and_public_signature_verification(self):
        commands = [command for command, _ in self.steps('android', '--skip-tests', '--dry-run')]
        apk = next(command for command in commands if 'apk' in command)
        self.assertIn('production', apk)
        self.assertIn('--split-per-abi', apk)
        self.assertNotIn('--debug', apk)
        collect = next(command for command in commands if any('android/collect.py' in arg.replace('\\', '/') for arg in command))
        self.assertIn('--certificate-sha256', collect)
        self.assertIn('--sdk-root', collect)
        self.assertEqual(commands[-1][-3:], ['android-armv7', 'android-arm64', 'android-x64'])
        source = (ENTRY.parent / 'android/collect.py').read_text(encoding='utf-8')
        self.assertIn("'build-tools/36.0.0'", source)
        self.assertNotIn('max(', source)

    def test_ios_is_compile_only_not_an_installable_ipa(self):
        commands = [command for command, _ in self.steps('ios-check', '--skip-tests')]
        self.assertEqual(commands[-1], ['flutter', 'build', 'ios', '--release', '--no-codesign', '--target', 'lib/main.dart'])
        self.assertEqual(len(commands), 3)

    def test_windows_dispatch_preserves_module_isolation_and_arguments(self):
        args = self.args('win-x64', '--skip-tests', '--check-only', '--no-open-folder', '--compiler', 'C:/a space/ISCC.exe', '--flutter', 'C:/sdk/flutter.bat')
        command = build.windows_command(args, ROOT / 'artifacts/a space')
        for expected in ('-SkipTests', '-CheckOnly', '-NoOpenFolder', 'C:/a space/ISCC.exe', 'C:/sdk/flutter.bat'):
            self.assertIn(expected, command)
        with patch.object(build, 'validate_host'), patch.object(build.subprocess, 'call', return_value=9) as run:
            self.assertEqual(build.main(['win-x64', '--check-only']), 9)
            self.assertIn('WindowsPowerShell', run.call_args.kwargs['env']['PSModulePath'])
            self.assertEqual(run.call_args.kwargs['cwd'], ROOT)

    def test_check_only_has_no_build_or_log_side_effects(self):
        with patch.object(build, 'validate_host'), patch.object(build, 'prerequisites', return_value='dart') as check:
            with patch.object(build, 'run_steps') as run, contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(build.main(['linux-x64', '--check-only']), 0)
            check.assert_called_once()
            run.assert_not_called()

    def test_prerequisites_reject_the_wrong_sdk_without_building(self):
        with patch.object(build.subprocess, 'check_output', return_value=json.dumps({'frameworkVersion': '0.0.1'})) as run:
            with self.assertRaisesRegex(ValueError, 'is required'):
                build.prerequisites(self.args('linux-x64'), 'linux-x64', 'flutter')
            self.assertIn('--suppress-analytics', run.call_args.args[0])

    def test_python_version_is_checked_before_starting_a_build(self):
        with patch.object(build.sys, 'version_info', (3, 7, 0)):
            with self.assertRaisesRegex(ValueError, 'Python 3.8'):
                build.main(['linux-x64', '--check-only'])
        with patch.object(build.sys, 'version_info', (3, 10, 0)):
            with self.assertRaisesRegex(ValueError, 'Python 3.11'):
                build.main(['android', '--check-only'])

    def test_linux_baseline_python_can_plan_both_native_architectures(self):
        with patch.object(build.sys, 'version_info', (3, 8, 0)), contextlib.redirect_stdout(io.StringIO()):
            for target in ('linux-x64', 'linux-arm64'):
                self.assertEqual(build.main([target, '--dry-run', '--skip-tests']), 0)

    def test_missing_android_signing_or_fingerprint_fails_before_build(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / '.flutter-version').write_text('1.2.3')
            sdk = root / 'flutter'
            (sdk / 'bin').mkdir(parents=True)
            (sdk / 'bin/dart').touch()
            (sdk / 'bin/dart.bat').touch()
            android = root / 'android'
            for folder in ('build-tools/36.0.0', 'platforms/android-36', 'ndk/28.2.13676358'):
                (android / folder).mkdir(parents=True)
            for name in ('apksigner', 'apksigner.bat', 'aapt', 'aapt.exe'):
                (android / 'build-tools/36.0.0' / name).touch()
            args = self.args('android', '--sdk-root', str(android), '--certificate-sha256', 'invalid')
            with patch.object(build, 'ROOT', root), patch.object(build.subprocess, 'check_output', return_value=json.dumps({'frameworkVersion': '1.2.3', 'flutterRoot': str(sdk)})):
                with self.assertRaisesRegex(ValueError, 'Restore production signing'):
                    build.prerequisites(args, 'android', 'flutter')
                properties = root / 'apps/vex/android/key.properties'
                properties.parent.mkdir(parents=True)
                properties.touch()
                with self.assertRaisesRegex(ValueError, 'public production certificate'):
                    build.prerequisites(args, 'android', 'flutter')

    def test_cli_dry_run_works_outside_repo_for_every_target(self):
        with tempfile.TemporaryDirectory(prefix='vex build ') as temporary:
            for target in build.TARGETS:
                result = subprocess.run([sys.executable, str(ENTRY), target, '--dry-run', '--skip-tests', '--output', 'artifacts/a space'],
                                        cwd=temporary, capture_output=True, text=True, encoding='utf-8')
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('build.ps1' if target == 'win-x64' else 'lib/main.dart', result.stdout)
                self.assertNotIn('BUILD FAILED', result.stderr)

    def test_subprocess_failure_stops_the_recipe_and_preserves_its_exit_code(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            steps = [([sys.executable, '-c', 'raise SystemExit(7)'], folder),
                     ([sys.executable, '-c', 'print("must not run")'], folder)]
            with self.assertRaises(subprocess.CalledProcessError) as error, contextlib.redirect_stdout(io.StringIO()):
                build.run_steps(steps, os.environ.copy(), folder / 'build.log')
            self.assertEqual(error.exception.returncode, 7)
            self.assertNotIn('must not run', (folder / 'build.log').read_text())

    def test_ci_packaging_paths_exist_and_use_unified_builds(self):
        for name in ('release.yml', 'installer-check.yml', 'ci.yml'):
            workflow = (ROOT / '.github/workflows' / name).read_text(encoding='utf-8')
            for path in re.findall(r'scripts/packaging/[\w./-]+\.(?:py|sh|ps1|txt)', workflow):
                self.assertTrue((ROOT / path).is_file(), path)
            if name != 'ci.yml':
                self.assertIn('scripts/packaging/build.py win-x64', workflow)
                self.assertIn('scripts/packaging/build.py osx-universal', workflow)

    def test_release_validates_the_tag_before_reading_current_metadata(self):
        workflow = (ROOT / '.github/workflows/release.yml').read_text(encoding='utf-8')
        check = workflow.index('git show-ref --verify "refs/tags/$RELEASE_TAG"')
        metadata = workflow.index('python scripts/packaging/shared/release_tools.py metadata')
        self.assertLess(check, metadata)

    def test_linux_flutter_is_trusted_before_its_first_version_check(self):
        workflow = (ROOT / '.github/workflows/release.yml').read_text(encoding='utf-8')
        desktop = workflow.split('\n  desktop:', 1)[1].split('\n  android:', 1)[0]
        arm = desktop.split('git clone --depth 1', 1)[1]
        self.assertIn('echo "FLUTTER_ROOT=$RUNNER_TEMP/flutter-sdk" >> "$GITHUB_ENV"', arm)
        trust = desktop.index('git config --global --add safe.directory "$flutter_sdk"')
        first_flutter = desktop.index('"$flutter_sdk/bin/flutter" --suppress-analytics --version --machine')
        self.assertLess(trust, first_flutter)
        self.assertLess(first_flutter, desktop.index('安装 Linux 原生构建依赖'))
        self.assertNotIn('"$RUNNER_TEMP/flutter-sdk/bin/flutter"', desktop[:trust])
        self.assertNotRegex(desktop, r'safe\.directory\s+[\'"]?\*')

    def test_sdk_trust_resolves_ownership_mismatch_without_trusting_other_repositories(self):
        with tempfile.TemporaryDirectory(prefix='vex sdk trust ') as temporary:
            folder = Path(temporary)
            sdk, other = folder / 'flutter-sdk', folder / 'unrelated-repository'
            env = {**os.environ, 'GIT_CONFIG_GLOBAL': str(folder / 'gitconfig'),
                   'GIT_CONFIG_NOSYSTEM': '1', 'GIT_TEST_ASSUME_DIFFERENT_OWNER': '1'}

            def git(*args):
                return subprocess.run(['git', *args], env=env, capture_output=True, text=True)

            for repository in (sdk, other):
                self.assertEqual(git('init', '-q', str(repository)).returncode, 0)
                refused = git('-C', str(repository), 'rev-parse', '--show-toplevel')
                self.assertNotEqual(refused.returncode, 0)
                self.assertIn('dubious ownership', refused.stderr)
            configured = git('config', '--global', '--add', 'safe.directory', sdk.resolve().as_posix())
            self.assertEqual(configured.returncode, 0, configured.stderr)
            accepted = git('-C', str(sdk), 'rev-parse', '--show-toplevel')
            self.assertEqual(accepted.returncode, 0, accepted.stderr)
            self.assertNotEqual(git('-C', str(other), 'rev-parse', '--show-toplevel').returncode, 0)


if __name__ == '__main__':
    unittest.main()
