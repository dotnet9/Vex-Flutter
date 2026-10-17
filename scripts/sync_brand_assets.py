"""Copy the root brand sources into Flutter's asset boundary before building.

Edit only root logo.svg / logo.png / logo.ico. Generated copies are committed so
flutter run works immediately after cloning. CI uses --check to prevent drift.
"""
import argparse
import io
import json
from pathlib import Path
import xml.etree.ElementTree as ET

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "apps/texweft/assets/brand"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    stale = []

    def write(target, source):
        if args.check:
            if not target.exists() or target.read_bytes() != source:
                stale.append(str(target.relative_to(ROOT)))
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source)

    def png(target, image):
        output = io.BytesIO()
        image.save(output, format='PNG', optimize=True)
        write(target, output.getvalue())

    for name in ("logo.svg", "logo.png"):
        write(TARGET / name, (ROOT / name).read_bytes())
    write(ROOT / 'apps/texweft/windows/runner/resources/app_icon.ico',
          (ROOT / 'logo.ico').read_bytes())
    image = Image.open(ROOT / 'logo.png').convert('RGBA')
    app = ROOT / 'apps/texweft'
    for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96),
                          ('xxhdpi', 144), ('xxxhdpi', 192)]:
        png(app / f'android/app/src/main/res/mipmap-{density}/ic_launcher.png',
            image.resize((size, size), Image.Resampling.LANCZOS))

    # Derive Android's maskable foreground from the same SVG paths. Keep the
    # mark inside the adaptive icon safe zone rather than nesting a second tile.
    svg = ET.parse(ROOT / 'logo.svg').getroot()
    ns = {'svg': 'http://www.w3.org/2000/svg'}
    colors = [stop.attrib['stop-color'] for stop in svg.findall('.//svg:stop', ns)]
    android = 'http://schemas.android.com/apk/res/android'
    ET.register_namespace('android', android)
    def attr(key):
        return f'{{{android}}}{key}'
    for monochrome in (False, True):
        vector = ET.Element('vector', {
            attr('width'): '108dp', attr('height'): '108dp',
            attr('viewportWidth'): '256', attr('viewportHeight'): '256',
        })
        group = ET.SubElement(vector, 'group', {
            attr('scaleX'): '0.70', attr('scaleY'): '0.70',
            attr('translateX'): '38.4', attr('translateY'): '38.4',
        })
        for path in svg.findall('svg:path', ns):
            properties = {attr('pathData'): path.attrib['d'], attr('fillColor'): '#00000000'}
            for source_key, target_key in [('stroke', 'strokeColor'), ('stroke-width', 'strokeWidth'),
                                          ('stroke-linecap', 'strokeLineCap'), ('stroke-linejoin', 'strokeLineJoin')]:
                if source_key in path.attrib:
                    properties[attr(target_key)] = '#FFFFFF' if monochrome and source_key == 'stroke' else path.attrib[source_key]
            ET.SubElement(group, 'path', properties)
        name = 'ic_launcher_monochrome' if monochrome else 'ic_launcher_foreground'
        write(app / f'android/app/src/main/res/drawable/{name}.xml',
              ET.tostring(vector, encoding='utf-8', xml_declaration=True))
    background = ET.Element('shape', {attr('shape'): 'rectangle'})
    ET.SubElement(background, 'gradient', {
        attr('startColor'): colors[0], attr('endColor'): colors[-1], attr('angle'): '315',
    })
    write(app / 'android/app/src/main/res/drawable/ic_launcher_background.xml',
          ET.tostring(background, encoding='utf-8', xml_declaration=True))
    for version in (26, 33):
        icon = ET.Element('adaptive-icon')
        for layer in ('background', 'foreground') + (('monochrome',) if version == 33 else ()):
            ET.SubElement(icon, layer, {attr('drawable'): f'@drawable/ic_launcher_{layer}'})
        write(app / f'android/app/src/main/res/mipmap-anydpi-v{version}/ic_launcher.xml',
              ET.tostring(icon, encoding='utf-8', xml_declaration=True))

    for platform in ('ios', 'macos'):
        target = app / platform / 'Runner/Assets.xcassets/AppIcon.appiconset'
        entries = json.loads((target / 'Contents.json').read_text(encoding='utf-8'))['images']
        for entry in entries:
            if 'filename' not in entry:
                continue
            size = round(float(entry['size'].split('x')[0]) * float(entry['scale'].removesuffix('x')))
            icon = image.resize((size, size), Image.Resampling.LANCZOS)
            if platform == 'ios':
                opaque = Image.new('RGB', icon.size, colors[0])
                opaque.paste(icon, mask=icon.getchannel('A'))
                icon = opaque
            else:
                inset = round(size * .1)
                tile = image.resize((size - 2 * inset, size - 2 * inset), Image.Resampling.LANCZOS)
                icon = Image.new('RGBA', (size, size))
                icon.alpha_composite(tile, (inset, inset))
            png(target / entry['filename'], icon)
    png(app / 'linux/packaging/icons/com.codewf.texweft.png', image)
    if stale:
        parser.exit(1, f"Brand assets differ: {', '.join(stale)}. Run scripts/sync_brand_assets.py.\n")
    print("Brand assets match root sources." if args.check else "Updated Flutter brand assets.")


if __name__ == "__main__":
    main()
