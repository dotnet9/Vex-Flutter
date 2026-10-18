"""Version and installer contract shared by local packaging and GitHub Actions.

Only installers and their individual SHA-256 files may enter the release directory.
GitHub's automatic source archives and internal Actions artifact transport are not
application distribution packages.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import struct
import zipfile

ROOT = Path(__file__).resolve().parents[3]
INSTALLERS = {
    'windows-x64': '-windows-x64-setup.exe',
    'macos-universal': '-macos-universal.dmg',
    'linux-x64': '-linux-x64.deb',
    'linux-arm64': '-linux-arm64.deb',
    'android-armv7': '-android-armv7.apk',
    'android-arm64': '-android-arm64.apk',
    'android-x64': '-android-x64.apk',
    'ios': '-ios.ipa',
}
DEFAULT_TARGETS = tuple(key for key in INSTALLERS if key != 'ios')
ANDROID_ABIS = {'android-armv7': 'armeabi-v7a', 'android-arm64': 'arm64-v8a', 'android-x64': 'x86_64'}


def app_version(root=ROOT):
    spec = (root / 'apps/vex/pubspec.yaml').read_text(encoding='utf-8')
    match = re.search(r'^version: (\d+\.\d+\.\d+)\+([1-9]\d*)\s*$', spec, re.M)
    if not match:
        raise ValueError('Application version must be x.y.z+build.')
    return match.groups()


def filename(target, version):
    return f'Vex-v{version}{INSTALLERS[target]}'


def sha256(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def check_installer(path, target, version):
    if path.stat().st_size < 1024:
        raise ValueError(f'Installer is empty or implausibly small: {path.name}')
    with path.open('rb') as source:
        header = source.read(64)
        if target == 'windows-x64':
            if header[:2] != b'MZ':
                raise ValueError('Windows installer is not a PE executable.')
            source.seek(struct.unpack_from('<I', header, 60)[0])
            if source.read(4) != b'PE\0\0':
                raise ValueError('Windows PE signature is missing.')
        elif target.startswith('linux-'):
            if header[:8] != b'!<arch>\n' or b'debian-binary' not in header:
                raise ValueError('Linux installer is not a Debian package.')
        elif target == 'macos-universal':
            source.seek(-512, 2)
            if source.read(4) != b'koly':
                raise ValueError('macOS installer is not a UDIF disk image.')
    if target in ANDROID_ABIS:
        with zipfile.ZipFile(path) as apk:
            names = set(apk.namelist())
            abi = ANDROID_ABIS[target]
            if 'AndroidManifest.xml' not in names or f'lib/{abi}/libapp.so' not in names:
                raise ValueError(f'APK is missing its manifest or {abi} release code.')
            abis = {name.split('/')[1] for name in names if name.startswith('lib/') and name.endswith('/libapp.so')}
            if abis != {abi}:
                raise ValueError(f'Unexpected APK architectures: {abis}')
    elif target == 'ios':
        with zipfile.ZipFile(path) as ipa:
            bundles = [n for n in ipa.namelist() if re.fullmatch(r'Payload/[^/]+\.app/Info.plist', n)]
            if len(bundles) != 1:
                raise ValueError('IPA must contain one application bundle.')
            info = plistlib.loads(ipa.read(bundles[0]))
            if info.get('CFBundleIdentifier') != 'com.codewf.vex' or info.get('CFBundleShortVersionString') != version:
                raise ValueError('IPA identity or version mismatch.')
            prefix = bundles[0].removesuffix('Info.plist')
            if prefix + 'embedded.mobileprovision' not in ipa.namelist() or prefix + '_CodeSignature/CodeResources' not in ipa.namelist():
                raise ValueError('IPA provisioning profile or signature is missing.')


def verify(directory, targets, version):
    expected = set()
    for target in targets:
        name = filename(target, version)
        expected.update((name, name + '.sha256'))
        path = directory / name
        check_installer(path, target, version)
        checksum = (directory / (name + '.sha256')).read_text(encoding='ascii').strip()
        if checksum != f'{sha256(path)}  {name}':
            raise ValueError(f'Checksum or checksum target mismatch: {name}')
    actual = {entry.name for entry in directory.iterdir()}
    if actual != expected:
        raise ValueError(f'Release files mismatch; missing={sorted(expected - actual)}, unexpected={sorted(actual - expected)}')
    print(f'Validated {len(targets)} installers and SHA-256 files; no portable archives.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    metadata = sub.add_parser('metadata')
    metadata.add_argument('--tag', default='')
    metadata.add_argument('--github-output', action='store_true')
    for command in ('checksums', 'verify'):
        item = sub.add_parser(command)
        item.add_argument('--directory', type=Path, default=ROOT / 'artifacts/release')
        item.add_argument('--targets', nargs='+', choices=INSTALLERS, default=DEFAULT_TARGETS)
    args = parser.parse_args()
    version, build = app_version()
    if args.command == 'metadata':
        if args.tag and args.tag != f'v{version}':
            raise ValueError(f'Tag {args.tag} must match pubspec version v{version}.')
        values = {'version': version, 'build': build, 'tag': f'v{version}',
                  'flutter': (ROOT / '.flutter-version').read_text().strip()}
        if args.github_output:
            with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as output:
                for key, value in values.items():
                    output.write(f'{key}={value}\n')
        print(json.dumps(values))
    elif args.command == 'checksums':
        for target in args.targets:
            path = args.directory / filename(target, version)
            check_installer(path, target, version)
            path.with_name(path.name + '.sha256').write_text(f'{sha256(path)}  {path.name}\n', encoding='ascii')
    else:
        verify(args.directory, args.targets, version)


if __name__ == '__main__':
    main()
