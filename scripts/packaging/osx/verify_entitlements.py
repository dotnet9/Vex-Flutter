"""Validate the actual signed, universal application, not just Xcode sources."""
import argparse
from pathlib import Path
import plistlib
import subprocess

REQUIRED = (
    'com.apple.security.app-sandbox',
    'com.apple.security.files.user-selected.read-write',
    'com.apple.security.network.client',
    'com.apple.security.network.server',
)


def validate(payload):
    entitlements = plistlib.loads(payload)
    missing = [key for key in REQUIRED if entitlements.get(key) is not True]
    if missing:
        raise ValueError('Signed application is missing entitlements: ' + ', '.join(missing))


def verify(app):
    for arch in ('x86_64', 'arm64'):
        output = subprocess.check_output([
            'codesign', '--display', '--arch', arch, '--entitlements', '-', str(app)])
        validate(output)
        print(f'Validated signed {arch} file access and MCP network entitlements.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    verify(parser.parse_args().app)
