"""Verify signed production APKs before copying them to the release directory."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess

from release_tools import ANDROID_ABIS, ROOT, app_version, check_installer, filename


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--sdk-root', type=Path, default=Path(os.environ.get('ANDROID_HOME', '')))
    parser.add_argument('--certificate-sha256', required=True)
    args = parser.parse_args()
    fingerprint = args.certificate_sha256.lower().replace(':', '')
    if not re.fullmatch('[a-f0-9]{64}', fingerprint):
        raise ValueError('Expected production certificate SHA-256 is required.')
    build_tools = max((args.sdk_root / 'build-tools').iterdir(), key=lambda p: tuple(int(n) for n in p.name.split('.')))
    apksigner = build_tools / ('apksigner.bat' if os.name == 'nt' else 'apksigner')
    aapt = build_tools / ('aapt.exe' if os.name == 'nt' else 'aapt')
    version, _ = app_version()
    output = ROOT / 'artifacts/release'
    output.mkdir(parents=True, exist_ok=True)
    for target, abi in ANDROID_ABIS.items():
        source = ROOT / f'apps/vex/build/app/outputs/flutter-apk/app-{abi}-production-release.apk'
        verified = subprocess.check_output([str(apksigner), 'verify', '--verbose', '--print-certs', str(source)], text=True)
        certificates = re.findall(r'^Signer #\d+ certificate SHA-256 digest: (\w+)$', verified, re.M)
        if certificates != [fingerprint]:
            raise ValueError(f'Production signing identity mismatch: {abi}')
        badging = subprocess.check_output([str(aapt), 'dump', 'badging', str(source)], text=True, encoding='utf-8')
        if not re.search(r"^package: name='com\.codewf\.vex' versionCode='[1-9]\d*' versionName='" + re.escape(version) + "'", badging, re.M):
            raise ValueError(f'Production package identity / version mismatch: {abi}')
        if 'application-debuggable' in badging:
            raise ValueError('Debuggable APK must not be released.')
        check_installer(source, target, version)
        destination = output / filename(target, version)
        shutil.copyfile(source, destination)
        print(f'Verified production signature, identity, version and ABI: {destination.name}')


if __name__ == '__main__':
    main()
