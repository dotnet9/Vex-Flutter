"""Build static application fonts from the locally downloaded Cascadia Code OFL variable font.

Requires fonttools. Source directory: cascadiacode.ttf and cascadiacode-OFL.txt.
Chinese and UI fonts use the system font fallback chain.
No glyphs are modified; all variation axes are pinned to static instances.
"""
import argparse
from io import BytesIO
from pathlib import Path
import hashlib
import json

from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('sources', type=Path)
    args = parser.parse_args()
    target = ROOT / 'apps/texweft/assets/fonts'
    metadata = {}
    for family, name, weights in [
        ('cascadiacode', 'CascadiaCode', (400, 600)),
    ]:
        source = (args.sources / f'{family}.ttf').read_bytes()
        original = TTFont(BytesIO(source))
        metadata[name] = {'sourceSha256': hashlib.sha256(source).hexdigest(),
                          'version': original['name'].getDebugName(5)}
        (target / f'{name}-OFL.txt').write_bytes((args.sources / f'{family}-OFL.txt').read_bytes())
        for weight in weights:
            font = TTFont(BytesIO(source), recalcTimestamp=False)
            axes = {axis.axisTag: weight if axis.axisTag == 'wght' else axis.defaultValue
                    for axis in font['fvar'].axes}
            instance = instantiateVariableFont(font, axes, inplace=True)
            suffix = {400: 'Regular', 600: 'SemiBold', 700: 'Bold'}[weight]
            output = target / f'{name}-{suffix}.ttf'
            instance.save(output)
            print(f'Created {output.name}: {output.stat().st_size // 1024} KB', flush=True)
    (target / 'sources.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

if __name__ == '__main__':
    main()
