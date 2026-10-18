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


if __name__ == '__main__':
    unittest.main()
