"""Rasterize the canonical SVG. Run sync_brand_assets.py afterwards."""
import io
from pathlib import Path

import cairosvg
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def main():
    bitmap = cairosvg.svg2png(url=str(ROOT / 'logo.svg'), output_width=1024, output_height=1024)
    image = Image.open(io.BytesIO(bitmap)).convert('RGBA')
    image.save(ROOT / 'logo.png', optimize=True)
    image.save(ROOT / 'logo.ico', sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])


if __name__ == '__main__':
    main()
