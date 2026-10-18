"""Keep documentation discoverable after renames without duplicate sources."""
from collections import defaultdict
from pathlib import Path
import re
import subprocess
import unittest
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[2]


def markdown_files():
    output = subprocess.check_output(
        ['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'],
        cwd=ROOT,
    ).decode('utf-8')
    return sorted({ROOT / name for name in output.split('\0')
                   if name.endswith('.md') and (ROOT / name).is_file()})


def local_links(content):
    content = re.sub(r'^(`{3,}|~{3,})[^\n]*\n.*?^\1[^\n]*$', '', content,
                     flags=re.MULTILINE | re.DOTALL)
    for target in re.findall(r'\]\(([^\s)]+)(?:\s+"[^"]*")?\)', content):
        target = target.strip('<>')
        if re.match(r'^(?:[a-z]+:|#|/)', target, re.IGNORECASE):
            continue
        yield unquote(re.split(r'[?#]', target, maxsplit=1)[0])


class DocumentationContractTest(unittest.TestCase):
    def test_local_document_and_image_links_exist(self):
        for document in markdown_files():
            for target in local_links(document.read_text(encoding='utf-8')):
                with self.subTest(document=document.relative_to(ROOT), target=target):
                    self.assertTrue((document.parent / target).exists())

    def test_docs_have_chinese_readable_filenames(self):
        for document in markdown_files():
            if document.is_relative_to(ROOT / 'docs'):
                with self.subTest(document=document.relative_to(ROOT)):
                    self.assertRegex(document.stem, r'[\u4e00-\u9fff]')

    def test_source_directories_only_keep_short_documentation_links(self):
        for document in markdown_files():
            if (document.is_relative_to(ROOT / 'docs') or document == ROOT / 'README.md'
                    or document.is_relative_to(ROOT / '.github')):
                continue
            with self.subTest(document=document.relative_to(ROOT)):
                self.assertIn(document.name, ('README.md', 'CHANGELOG.md', 'CONTRIBUTING.md', 'SECURITY.md'))
                content = document.read_text(encoding='utf-8')
                self.assertLessEqual(len(content.splitlines()), 6)
                self.assertTrue(any((document.parent / target).resolve().is_relative_to(ROOT / 'docs')
                                    for target in local_links(content)))

    def test_no_identical_maintained_markdown_sources(self):
        documents = defaultdict(list)
        for document in markdown_files():
            content = document.read_text(encoding='utf-8').strip()
            documents[content].append(str(document.relative_to(ROOT)))
        duplicates = [names for names in documents.values() if len(names) > 1]
        self.assertEqual(duplicates, [])


if __name__ == '__main__':
    unittest.main()
