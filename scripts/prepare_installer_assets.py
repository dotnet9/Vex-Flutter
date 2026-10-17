"""Generate installer logo bitmaps from the repository's shared brand source."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'scripts/installer/assets'
OUTPUT.mkdir(exist_ok=True)
logo = Image.open(ROOT / 'logo.png').convert('RGBA')
for theme, brand in (
    ('light', '#e8eee5'),
    ('dark', '#243a2d'),
):
    image = Image.new('RGB', (224, 224), brand)
    mark = logo.resize(image.size, Image.Resampling.LANCZOS)
    image.paste(mark, mask=mark.getchannel('A'))
    image.save(OUTPUT / f'hero-{theme}.bmp')
print('Installer logo bitmaps refreshed from logo.png.')
