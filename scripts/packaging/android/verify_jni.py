"""Check exact JNI method signatures in the final R8-processed APK DEX files."""
import argparse
from pathlib import Path
import subprocess
import tempfile
import xml.etree.ElementTree as ET
import zipfile

REGISTRAR = 'io.flutter.plugins.sharedpreferences.SharedPreferencesAsyncApiRegistrar'
# shared_preferences_android 2.5.5 起注册器参数由 SharedPreferencesPigeonOptions 变为 byte[] 实例句柄
PARAMETERS = {
    'getString': ['java.lang.String', 'byte[]', 'kotlin.coroutines.Continuation'],
    'setString': ['java.lang.String', 'java.lang.String', 'byte[]', 'kotlin.coroutines.Continuation'],
}
RUNTIME = {
    'kotlin.Unit', 'kotlin.Result', 'kotlin.Result$Failure',
    'kotlin.coroutines.Continuation',
    'kotlin.coroutines.intrinsics.CoroutineSingletons',
    'kotlin.coroutines.intrinsics.IntrinsicsKt',
}


def runtime_classes(root):
    return {f'{package.get("name")}.{cls.get("name")}'
            for package in root.iter('package') for cls in package.findall('class')} & RUNTIME


PRIMITIVES = {
    'boolean': 'Z', 'byte': 'B', 'char': 'C', 'short': 'S',
    'int': 'I', 'long': 'J', 'float': 'F', 'double': 'D',
}


def descriptor(type_name):
    """把 Java 点分类型名规范到 JVM 描述符形式，兼容不同 dexdump 版本的输出表示"""
    if type_name.startswith('[') or (type_name.startswith('L') and type_name.endswith(';')):
        return type_name
    if type_name.endswith('[]'):
        return '[' + descriptor(type_name[:-2])
    if type_name in PRIMITIVES:
        return PRIMITIVES[type_name]
    return 'L' + type_name.replace('.', '/') + ';'


def signatures(root):
    found = set()
    for package in root.iter('package'):
        for cls in package.findall('class'):
            if f'{package.get("name")}.{cls.get("name")}' != REGISTRAR:
                continue
            for method in cls.findall('method'):
                name = method.get('name')
                if (name in PARAMETERS
                        and descriptor(method.get('return')) == descriptor('java.lang.Object')
                        and method.get('static') not in ('true', '1')
                        and [descriptor(p.get('type')) for p in method.iter('parameter')]
                        == [descriptor(t) for t in PARAMETERS[name]]):
                    found.add(name)
    return found


def diagnose(roots):
    """校验失败时输出 dexdump 解析诊断，定位输出结构或 R8 处理的变化"""
    related = set()
    registrar = None
    for root in roots:
        for package in root.iter('package'):
            for cls in package.findall('class'):
                full = f'{package.get("name")}.{cls.get("name")}'
                if 'sharedpreferences' in full.lower():
                    related.add(full)
                if full == REGISTRAR:
                    registrar = cls
    print(f'DIAG dex files parsed: {len(roots)}')
    print('DIAG sharedpreferences classes: ' + (', '.join(sorted(related)) or '(none)'))
    if registrar is None:
        print(f'DIAG registrar class {REGISTRAR} not found in any dex')
        return
    for method in registrar.findall('method'):
        params = [p.get('type') or '(no-type)' for p in method.iter('parameter')]
        print(f"DIAG registrar method {method.get('name')} return={method.get('return')} "
              f"static={method.get('static')} params={params if params else '(no <parameter> children)'}")


def verify(apk, dexdump):
    found = set()
    runtime = set()
    roots = []
    with tempfile.TemporaryDirectory(prefix='vex-jni-') as directory:
        with zipfile.ZipFile(apk) as archive:
            for name in archive.namelist():
                if '/' in name or not name.startswith('classes') or not name.endswith('.dex'):
                    continue
                dex = Path(directory) / name
                dex.write_bytes(archive.read(name))
                output = subprocess.check_output([str(dexdump), '-l', 'xml', str(dex)])
                root = ET.fromstring(output)
                roots.append(root)
                found.update(signatures(root))
                runtime.update(runtime_classes(root))
    missing = set(PARAMETERS) - found
    if missing:
        diagnose(roots)
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
