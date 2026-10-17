"""Bundle built-in Markdown at build time, never in a user's documents folder."""
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    for name in ('ACKNOWLEDGEMENTS.md', 'CHANGELOG.md'):
        source = ROOT / 'design/documents' / name
        target = ROOT / 'apps/texweft/assets/documents' / name
        content = source.read_bytes()
        if args.check:
            if not target.exists() or target.read_bytes() != content:
                parser.exit(1, f'Built-in document is stale: {name}\n')
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)


if __name__ == '__main__':
    main()
