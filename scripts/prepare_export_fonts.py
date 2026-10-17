"""Create static offline PDF fonts from NotoSansSC[wght].ttf (SIL OFL).

Requires fonttools. Download the source from google/fonts/ofl/notosanssc,
then pass its local path. A static instance avoids the PDF engine selecting
the variable font's lightest default outline instead of the requested weight.
"""
import argparse
from io import BytesIO
from pathlib import Path
import hashlib
import json
import zlib

from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("variable_font", type=Path)
    args = parser.parse_args()
    source = args.variable_font.read_bytes()
    target = ROOT / "apps/texweft/assets/fonts"
    target.mkdir(parents=True, exist_ok=True)
    metadata = {}
    for weight, name in ((400, "NotoSansSC.ttf"), (600, "NotoSansSC-SemiBold.ttf")):
        font = TTFont(BytesIO(source), recalcTimestamp=False)
        instance = instantiateVariableFont(font, {"wght": weight}, inplace=True)
        output = BytesIO()
        instance.save(output)
        data = output.getvalue()
        packed = zlib.compress(data, 9)
        (target / f'{name}.z').write_bytes(packed)
        metadata[name] = {'uncompressedSha256': hashlib.sha256(data).hexdigest(),
                          'uncompressedBytes': len(data), 'compressedBytes': len(packed)}
        print(f"Created {name}.z, weight {weight}: {len(data)} -> {len(packed)} bytes.")
    (target / 'pdf-fonts.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')


if __name__ == "__main__":
    main()
