"""Verify one maintained Markdown source and reproducible offline resources."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[2]
ENTRY = ROOT / 'scripts/sync_builtin_documents.py'
spec = importlib.util.spec_from_file_location('builtin_documents', ENTRY)
documents = importlib.util.module_from_spec(spec)
spec.loader.exec_module(documents)


class BuiltinDocumentsTest(unittest.TestCase):
    def source(self, root, newline='\n'):
        (root / 'docs').mkdir()
        for _, name, _ in documents.DOCUMENTS:
            (root / 'docs' / name).write_bytes(f'# {name}{newline}{newline}- 内容{newline}'.encode('utf-8'))

    def test_clean_checkout_generates_app_and_prototype_from_chinese_sources(self):
        with tempfile.TemporaryDirectory(prefix='vex 文档 ') as temporary:
            root = Path(temporary)
            self.source(root)
            self.assertEqual(len(documents.prepare(root)), len(documents.DOCUMENTS) + 1)
            for _, name, _ in documents.DOCUMENTS:
                self.assertEqual((root / 'docs' / name).read_bytes(),
                                 (root / 'apps/vex/assets/generated/documents' / name).read_bytes())
            source = (root / 'design/assets/generated/documents-data.js').read_text(encoding='utf-8')
            data = json.loads(source.split('window.VexDocuments = ', 1)[1].removesuffix(';\n'))
            for key, name, title in documents.DOCUMENTS:
                self.assertEqual(data[key], {'name': title, 'file': '../docs/' + name,
                                            'text': (root / 'docs' / name).read_text(encoding='utf-8')})

    def test_check_does_not_create_missing_outputs(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.source(root)
            self.assertEqual(len(documents.prepare(root, check=True)), len(documents.DOCUMENTS) + 1)
            self.assertFalse((root / 'apps').exists())
            self.assertFalse((root / 'design').exists())

    def test_generation_is_idempotent_and_does_not_rewrite_unchanged_outputs(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.source(root)
            documents.prepare(root)
            before = {path: (root / path).stat().st_mtime_ns for path in documents.outputs(root)}
            self.assertEqual(documents.prepare(root), [])
            self.assertEqual(documents.prepare(root, check=True), [])
            self.assertEqual(before, {path: (root / path).stat().st_mtime_ns for path in before})

    def test_source_edit_and_damaged_output_are_detected_without_mutation(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.source(root)
            documents.prepare(root)
            name = documents.DOCUMENTS[0][1]
            (root / 'docs' / name).write_text('# 新内容\n', encoding='utf-8')
            other = root / 'apps/vex/assets/generated/documents' / documents.DOCUMENTS[1][1]
            other.write_bytes(b'damaged')
            self.assertEqual(len(documents.prepare(root, check=True)), len(documents.DOCUMENTS) + 1)
            self.assertEqual(other.read_bytes(), b'damaged')
            self.assertEqual(len(documents.prepare(root)), len(documents.DOCUMENTS) + 1)
            self.assertEqual(documents.prepare(root, check=True), [])

    def test_windows_source_newlines_generate_the_same_lf_bytes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.source(root, '\r\n')
            documents.prepare(root)
            self.assertTrue(all(b'\r' not in (root / path).read_bytes() for path in documents.outputs(root)))

    def test_missing_source_does_not_leave_a_partial_bundle(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.source(root)
            (root / 'docs' / documents.DOCUMENTS[1][1]).unlink()
            with self.assertRaises(FileNotFoundError):
                documents.prepare(root)
            self.assertFalse((root / 'apps').exists())

    def test_ci_prepares_documents_before_prototype_and_flutter_checks(self):
        workflow = (ROOT / '.github/workflows/ci.yml').read_text(encoding='utf-8')
        preparation = workflow.index('python scripts/sync_builtin_documents.py')
        self.assertLess(preparation, workflow.index('for script in design/scripts/verify'))
        self.assertLess(preparation, workflow.index('flutter pub get'))

    @unittest.skipUnless(shutil.which('node'), 'Node is only needed for prototype preview')
    def test_preview_cold_start_and_source_changes_use_the_shared_generator(self):
        with tempfile.TemporaryDirectory(prefix='vex 原型 ') as temporary:
            root = Path(temporary)
            self.source(root)
            (root / 'design/scripts').mkdir(parents=True)
            (root / 'scripts').mkdir()
            shutil.copyfile(ENTRY, root / 'scripts/sync_builtin_documents.py')
            shutil.copyfile(ROOT / 'design/scripts/preview.cjs', root / 'design/scripts/preview.cjs')
            env = dict(os.environ, VEX_PYTHON=sys.executable, VEX_PREVIEW_PORT='0')
            process = subprocess.Popen(['node', str(root / 'design/scripts/preview.cjs')], env=env,
                                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding='utf-8')
            try:
                url = process.stdout.readline().strip().split('Vex prototype: ', 1)[1]
                resource = url + 'assets/generated/documents-data.js'
                with urlopen(resource, timeout=10) as response:
                    self.assertIn('window.VexDocuments', response.read().decode('utf-8'))
                (root / 'docs' / documents.DOCUMENTS[0][1]).write_text('# 实时修改\n', encoding='utf-8')
                with urlopen(resource, timeout=10) as response:
                    self.assertIn('实时修改', response.read().decode('utf-8'))
            finally:
                process.terminate()
                process.communicate(timeout=10)


if __name__ == '__main__':
    unittest.main()
