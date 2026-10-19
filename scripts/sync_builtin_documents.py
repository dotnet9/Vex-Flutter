"""Generate offline app/prototype resources from the single docs source."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCUMENTS = (
    ('thanks', '鸣谢.md', '鸣谢.md'),
    ('changelog', '更新日志.md', '更新日志.md'),
    ('markdown-sample', 'Markdown功能示例.md', 'Markdown 功能示例.md'),
)


def outputs(root):
    result = {}
    documents = {}
    for key, filename, title in DOCUMENTS:
        content = (root / 'docs' / filename).read_text(encoding='utf-8')
        result[Path('apps/vex/assets/generated/documents') / filename] = content.encode('utf-8')
        documents[key] = {'name': title, 'file': '../docs/' + filename, 'text': content}
    javascript = ('// Generated from docs/*.md by scripts/sync_builtin_documents.py. Do not edit.\n'
                  'window.VexDocuments = ' + json.dumps(documents, ensure_ascii=False, indent=2) + ';\n')
    result[Path('design/assets/generated/documents-data.js')] = javascript.encode('utf-8')
    return result


def prepare(root, *, check=False):
    stale = []
    for relative, content in outputs(root).items():
        target = root / relative
        if target.is_file() and target.read_bytes() == content:
            continue
        stale.append(relative)
        if not check:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
    return stale


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    stale = prepare(ROOT, check=args.check)
    if args.check and stale:
        parser.exit(1, 'Missing/stale generated documents; run python scripts/sync_builtin_documents.py:\n'
                    + '\n'.join(str(path) for path in stale) + '\n')


if __name__ == '__main__':
    main()
