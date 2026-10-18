"""Check exact JNI method signatures in the final R8-processed APK DEX files."""
import argparse
from pathlib import Path
import subprocess
import tempfile
import xml.etree.ElementTree as ET
import zipfile

REGISTRAR = 'io.flutter.plugins.sharedpreferences.SharedPreferencesAsyncApiRegistrar'
PARAMETERS = {
    'getString': ['java.lang.String',
                  'io.flutter.plugins.sharedpreferences.SharedPreferencesPigeonOptions',
                  'kotlin.coroutines.Continuation'],
    'setString': ['java.lang.String', 'java.lang.String',
                  'io.flutter.plugins.sharedpreferences.SharedPreferencesPigeonOptions',
                  'kotlin.coroutines.Continuation'],
}
RUNTIME = {
    'kotlin.Unit', 'kotlin.Result', 'kotlin.Result$Failure',
    'kotlin.coroutines.Continuation',
    'kotlin.coroutines.intrinsics.CoroutineSingletons',
    'kotlin.coroutines.intrinsics.IntrinsicsKt',
}


def runtime_classes(xml):
    root = ET.fromstring(xml)
    return {f'{package.get("name")}.{cls.get("name")}'
            for package in root.iter('package') for cls in package.findall('class')} & RUNTIME


def signatures(xml):
    root = ET.fromstring(xml)
    found = set()
    for package in root.iter('package'):
        for cls in package.findall('class'):
            if f'{package.get("name")}.{cls.get("name")}' != REGISTRAR:
                continue
            for method in cls.findall('method'):
                name = method.get('name')
                if (name in PARAMETERS and method.get('return') == 'java.lang.Object'
                        and method.get('static') != 'true'
                        and [p.get('type') for p in method.findall('parameter')] == PARAMETERS[name]):
                    found.add(name)
    return found


def verify(apk, dexdump):
    found = set()
    runtime = set()
    with tempfile.TemporaryDirectory(prefix='vex-jni-') as directory:
        with zipfile.ZipFile(apk) as archive:
            for name in archive.namelist():
                if '/' in name or not name.startswith('classes') or not name.endswith('.dex'):
                    continue
                dex = Path(directory) / name
                dex.write_bytes(archive.read(name))
                output = subprocess.check_output([str(dexdump), '-l', 'xml', str(dex)])
                found.update(signatures(output))
                runtime.update(runtime_classes(output))
    missing = set(PARAMETERS) - found
    if missing:
        raise ValueError('Release APK lost JNI preferences methods: ' + ', '.join(sorted(missing)))
    if RUNTIME - runtime:
        raise ValueError('Release APK lost JNI Kotlin runtime types: ' + ', '.join(sorted(RUNTIME - runtime)))
    print(f'Validated exact JNI preferences method signatures: {Path(apk).name}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    parser.add_argument('--dexdump', type=Path, required=True)
    args = parser.parse_args()
    verify(args.apk, args.dexdump)
