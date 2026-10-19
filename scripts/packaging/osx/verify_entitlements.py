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


def codesign_output(app, arch):
    """新版 codesign 默认输出 DER，须显式 --xml；旧版不识别 --xml 时回退。"""
    base = ['codesign', '--display', '--arch', arch, '--entitlements', ':-']
    for extra in (['--xml'], []):
        try:
            return subprocess.check_output(base + extra + [str(app)])
        except subprocess.CalledProcessError:
            continue
    raise ValueError(f'codesign could not display entitlements for {app}.')


def verify(app):
    for arch in ('x86_64', 'arm64'):
        validate(codesign_output(app, arch))
        print(f'Validated signed {arch} file access and MCP network entitlements.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    verify(parser.parse_args().app)
