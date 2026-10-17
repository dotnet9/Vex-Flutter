"""Regenerate the Finder background using Vex's bundled, licensed CJK font."""
from io import BytesIO
from pathlib import Path
import zlib

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'scripts/installer/assets'
FONT = ROOT / 'apps/texweft/assets/fonts/NotoSansSC.ttf.z'


def main():
    scale = 2
    image = Image.new('RGB', (740 * scale, 380 * scale), 'white')
    draw = ImageDraw.Draw(image)
    font_bytes = zlib.decompress(FONT.read_bytes())

    def text(value, y, size, color):
        font = ImageFont.truetype(BytesIO(font_bytes), size * scale)
        draw.text((370 * scale, y * scale), value, font=font, fill=color, anchor='mt')

    text('把维刻，放进你的应用程序。', 39, 22, '#253831')
    text('Drag Vex into Applications.', 84, 14, '#617269')
    # Real Finder icons and their labels occupy the space on either side.
    draw.line([(346 * scale, 190 * scale), (394 * scale, 190 * scale)], fill='#617269', width=2 * scale)
    draw.line([(385 * scale, 181 * scale), (394 * scale, 190 * scale), (385 * scale, 199 * scale)], fill='#617269', width=2 * scale)
    text('复制完成后，从「应用程序」打开维刻，并推出此磁盘映像。', 310, 12, '#617269')
    text('Open Vex from Applications, then eject this disk image.', 335, 12, '#617269')
    OUTPUT.mkdir(exist_ok=True)
    image.save(OUTPUT / 'macos-background@2x.png', optimize=True, dpi=(144, 144))
    image.resize((740, 380), Image.Resampling.LANCZOS).save(OUTPUT / 'macos-background.png', optimize=True, dpi=(72, 72))
    print('Finder background regenerated at 1x and 2x.')


if __name__ == '__main__':
    main()
