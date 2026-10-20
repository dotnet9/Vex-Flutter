import ast
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('linux_abi', ROOT / 'scripts/packaging/linux/check_abi.py')
abi = importlib.util.module_from_spec(spec)
spec.loader.exec_module(abi)


class LinuxAbiTests(unittest.TestCase):
    def test_only_imported_runtime_versions_are_checked(self):
        output = '''Version definition section '.gnu.version_d':
          Name: GLIBC_9.99
Version needs section '.gnu.version_r':
  Name: GLIBC_2.31  Flags: none Version: 2
  Name: GLIBCXX_3.4.28  Flags: none Version: 3
  Name: CXXABI_1.3.12  Flags: none Version: 4'''
        self.assertEqual(abi.requirements(output), [
            ('GLIBC', (2, 31)), ('GLIBCXX', (3, 4, 28)), ('CXXABI', (1, 3, 12))])

    def test_release_uses_old_runtime_not_dependency_name_substitution(self):
        workflow = (ROOT / '.github/workflows/release.yml').read_text(encoding='utf-8')
        self.assertEqual(workflow.count('container: ubuntu:20.04'), 2)
        package = (ROOT / 'scripts/packaging/linux/package.sh').read_text(encoding='utf-8')
        self.assertIn('check_abi.py', package)
        self.assertIn('dpkg-shlibdeps', package)
        self.assertIn('"$dependencies" == *t64*', package)

    def test_linux_build_python_comes_from_the_container_not_host_toolcache(self):
        workflow = (ROOT / '.github/workflows/release.yml').read_text(encoding='utf-8')
        desktop = workflow.split('\n  desktop:', 1)[1].split('\n  android:', 1)[0]
        self.assertIn('python3 python-is-python3', desktop)
        setup = desktop.split('uses: actions/setup-python@v5', 1)[1].split('      - ', 1)[0]
        self.assertIn("if: runner.os != 'Linux'", setup)
        self.assertIn('python scripts/packaging/build.py "$TARGET" --dry-run --skip-tests', desktop)
        self.assertLess(desktop.index('--dry-run --skip-tests'), desktop.index('uses: subosito/flutter-action'))

    def test_linux_entry_modules_support_python38_syntax(self):
        for name in ('packaging/build.py', 'packaging/shared/release_tools.py',
                     'packaging/linux/check_abi.py', 'sync_builtin_documents.py'):
            with self.subTest(module=name):
                ast.parse((ROOT / 'scripts' / name).read_text(encoding='utf-8'), feature_version=(3, 8))


if __name__ == '__main__':
    unittest.main()
