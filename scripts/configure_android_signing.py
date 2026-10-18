"""Materialize ignored signing files from environment; never log secret values."""
import base64
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def property_value(value):
    result = ''
    for char in value:
        if char in '\\ :=#!':
            result += '\\' + char
        elif not 32 <= ord(char) <= 126:
            data = char.encode('utf-16-be')
            result += ''.join(f'\\u{int.from_bytes(data[i:i+2], "big"):04x}' for i in range(0, len(data), 2))
        else:
            result += char
    return result


def configure():
    names = ('ANDROID_KEYSTORE_BASE64', 'ANDROID_STORE_PASSWORD', 'ANDROID_KEY_ALIAS', 'ANDROID_KEY_PASSWORD')
    values = {name: os.environ.get(name, '') for name in names}
    missing = [name for name, value in values.items() if not value]
    if missing:
        raise ValueError('Release signing requires GitHub Secrets: ' + ', '.join(missing))
    directory = ROOT / '.signing'
    directory.mkdir(mode=0o700, exist_ok=True)
    key = directory / 'android-release.jks'
    key.write_bytes(base64.b64decode(values['ANDROID_KEYSTORE_BASE64'], validate=True))
    key.chmod(0o600)
    properties = ROOT / 'apps/vex/android/key.properties'
    entries = {'storeFile': key.as_posix(), 'storePassword': values['ANDROID_STORE_PASSWORD'],
               'keyAlias': values['ANDROID_KEY_ALIAS'], 'keyPassword': values['ANDROID_KEY_PASSWORD']}
    properties.write_text(''.join(f'{k}={property_value(v)}\n' for k, v in entries.items()), encoding='ascii')
    properties.chmod(0o600)
    print('Production signing files prepared (ignored by Git).')


if __name__ == '__main__':
    configure()
