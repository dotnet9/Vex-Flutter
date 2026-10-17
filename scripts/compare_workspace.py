"""Compare fixed-size native captures with the reviewed prototype screenshot.

Reports regional foreground errors, never a whole-product fidelity percentage.
Requires Pillow and numpy. Reference crop removes the prototype's outer frame.
"""
import argparse
import json
import pathlib

import numpy as np
from PIL import Image, ImageChops

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--reference', type=pathlib.Path, required=True)
parser.add_argument('--before', type=pathlib.Path, required=True)
parser.add_argument('--after', type=pathlib.Path, required=True)
parser.add_argument('--output', type=pathlib.Path, required=True)
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
reference = Image.open(args.reference).convert('RGB').crop((25, 25, 1255, 775))
before = Image.open(args.before / 'idle.png').convert('RGB')
after = Image.open(args.after / 'idle.png').convert('RGB')
assert reference.size == before.size == after.size == (1230, 750)
reference.save(args.output / 'prototype.png')
after.save(args.output / 'implementation.png')
Image.blend(reference, after, .5).save(args.output / 'overlay.png')
ImageChops.difference(reference, after).point(lambda v: min(v * 4, 255)).save(
    args.output / 'difference-x4.png')

regions = {'titlebar': (0, 0, 1230, 40), 'workbar': (0, 40, 1230, 102),
           'sidebar': (0, 102, 226, 405), 'formatbar': (226, 102, 1230, 144),
           'document-content': (270, 170, 1180, 440),
           'statusbar': (0, 718, 1230, 750)}
measurements = {}
for name, box in regions.items():
    ref = np.asarray(reference.crop(box), dtype=np.float32)
    values = {}
    for state, source in [('before', before), ('after', after)]:
        actual = np.asarray(source.crop(box), dtype=np.float32)
        mask = (ref.min(axis=2) < 190) | (actual.min(axis=2) < 190)
        error = np.abs(ref - actual).mean(axis=2)
        values[state] = {'foregroundPixels': int(mask.sum()),
                         'foregroundMeanAbsoluteRGBError': round(float(error[mask].mean()), 3),
                         'meanAbsoluteRGBError': round(float(error.mean()), 3)}
    measurements[name] = values

geometry = {}
for state, folder in [('before', args.before), ('after', args.after)]:
    data = json.loads((folder / 'geometry.json').read_text(encoding='utf-8'))
    geometry[state] = {'layoutButton': data['idle']['layoutButton'],
                       'typographyButton': data['idle']['typographyButton'],
                       'pickerClose': data['pickerClose'],
                       'codeDisplacementAfterHeadingClick':
                           data['heading-edit']['code']['y'] - data['idle']['code']['y'],
                       'paragraphDisplacementAfterCodeClick':
                           (data['code-edit']['followingParagraph']['y']
                            - data['idle']['followingParagraph']['y'])
                           if 'code-edit' in data else None}
result = {'clientSize': [1230, 750], 'referenceCrop': [25, 25, 1255, 775],
          'regions': measurements, 'geometry': geometry,
          'limitations': 'Historical prototype capture; font rasterization, titlebar controls, dirty state and status text differ. Regional error is not product fidelity. Blank document area is excluded from content ROI.'}
(args.output / 'measurements.json').write_text(
    json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(geometry, indent=2))
