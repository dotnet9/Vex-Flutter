"""Create static offline PDF fonts from NotoSansSC[wght].ttf (SIL OFL).

Requires fonttools. Download the source from google/fonts/ofl/notosanssc,
then pass its local path. A static instance avoids the PDF engine selecting
the variable font's lightest default outline instead of the requested weight.
"""
import argparse
from io import BytesIO
from pathlib import Path

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
    for weight, name in ((400, "NotoSansSC.ttf"), (600, "NotoSansSC-SemiBold.ttf")):
        font = TTFont(BytesIO(source))
        instance = instantiateVariableFont(font, {"wght": weight}, inplace=True)
        instance.save(target / name)
        print(f"Created {name}, weight {weight}.")


if __name__ == "__main__":
    main()
