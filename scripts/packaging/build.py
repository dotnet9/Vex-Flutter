"""Build native installers without installing the app or publishing a release."""
import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent / 'shared'))
from release_tools import ANDROID_ABIS, ROOT, app_version

HERE = Path(__file__).resolve().parent
TARGETS = ('win-x64', 'linux-x64', 'linux-arm64', 'osx-x64', 'osx-arm64', 'osx-universal', 'android', 'ios-check')


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument('target', choices=TARGETS)
    result.add_argument('--flutter', default=os.environ.get('VEX_FLUTTER', ''))
    result.add_argument('--output', type=Path, help='Relative to repository root; default: artifacts/local/TARGET/VERSION.')
    result.add_argument('--skip-tests', action='store_true', help='Skip analysis/tests, not dependency or artifact checks.')
    result.add_argument('--check-only', action='store_true', help='Check prerequisites without building or downloading.')
    result.add_argument('--dry-run', action='store_true', help='Print the recipe on any host without executing commands.')
    result.add_argument('--no-open-folder', action='store_true', help='Windows: do not open the output folder.')
    result.add_argument('--compiler', default='', help='Windows: existing Inno Setup ISCC.exe.')
    result.add_argument('--sdk-root', type=Path, help='Android SDK directory (or ANDROID_HOME / ANDROID_SDK_ROOT).')
    result.add_argument('--certificate-sha256', default=os.environ.get('ANDROID_CERT_SHA256', ''), help='Android production certificate fingerprint (public).')
    return result


def canonical_target(target):
    # Both Mac architectures intentionally share one universal installer.
    return 'osx-universal' if target in ('osx-x64', 'osx-arm64') else target


def output_directory(target, value=None):
    version, build = app_version()
    path = value if value is not None else Path(f'artifacts/local/{target}/v{version}-build{build}')
    return (ROOT / path).resolve()


def validate_host(target, system=None, machine=None):
    system = system or platform.system()
    machine = (machine or platform.machine()).lower()
    if target == 'win-x64' and (system != 'Windows' or machine not in ('x86_64', 'amd64')):
        raise ValueError('win-x64 requires an x64 Windows host and Visual Studio C++ tools; ARM64 cross-compilation is not configured.')
    if target.startswith('linux-'):
        expected = 'arm64' if machine in ('aarch64', 'arm64') else 'x64' if machine in ('x86_64', 'amd64') else ''
        if system != 'Linux' or target != f'linux-{expected}':
            raise ValueError(f'{target} requires a matching native Linux host; cross-compilation is not configured.')
    if target in ('osx-universal', 'ios-check') and system != 'Darwin':
        raise ValueError(f'{target} requires macOS and Xcode; Windows/Linux cannot build it natively.')
    if target == 'android' and system not in ('Windows', 'Linux', 'Darwin'):
        raise ValueError('Android builds require Windows, Linux or macOS.')


def flutter_executable(explicit):
    if explicit:
        return str(Path(explicit).resolve())
    name = 'flutter.bat' if os.name == 'nt' else 'flutter'
    if os.environ.get('FLUTTER_ROOT'):
        return str(Path(os.environ['FLUTTER_ROOT']) / 'bin' / name)
    return shutil.which(name) or name


def windows_command(args, output):
    shell = Path(os.environ.get('SystemRoot', 'C:/Windows')) / 'System32/WindowsPowerShell/v1.0/powershell.exe'
    command = [str(shell), '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(HERE / 'win-x64/build.ps1'), '-OutputDirectory', str(output)]
    for value, name in ((args.flutter, '-Flutter'), (args.compiler, '-Compiler')):
        if value:
            command.extend((name, value))
    for enabled, name in ((args.skip_tests, '-SkipTests'), (args.no_open_folder, '-NoOpenFolder'), (args.check_only, '-CheckOnly')):
        if enabled:
            command.append(name)
    return command


def android_sdk(args):
    value = args.sdk_root or os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT')
    if not value:
        raise ValueError('Set ANDROID_HOME or pass --sdk-root to the Android SDK directory.')
    return Path(value).resolve()


def prerequisites(args, target, flutter):
    sdk = json.loads(subprocess.check_output([flutter, '--suppress-analytics', '--version', '--machine'], cwd=ROOT, text=True, encoding='utf-8'))
    expected = (ROOT / '.flutter-version').read_text(encoding='ascii').strip()
    if sdk['frameworkVersion'] != expected:
        raise ValueError(f"Flutter {expected} is required; found {sdk['frameworkVersion']}. The SDK is not upgraded automatically.")
    dart = Path(sdk['flutterRoot']) / 'bin' / ('dart.bat' if os.name == 'nt' else 'dart')
    if not dart.is_file():
        raise ValueError('The Flutter SDK has no bundled Dart executable.')
    required = []
    if target.startswith('linux-'):
        required = ['bash', 'clang', 'cmake', 'ninja', 'pkg-config', 'dpkg-deb', 'dpkg-shlibdeps', 'desktop-file-validate', 'file']
    elif target in ('osx-universal', 'ios-check'):
        required = ['bash', 'xcrun', 'xcodebuild', 'pod']
        if target == 'osx-universal':
            required += ['hdiutil', 'codesign', 'lipo', 'ditto']
    elif target == 'android':
        required = ['java']
        sdk_root = android_sdk(args)
        suffix = '.bat' if os.name == 'nt' else ''
        for name in ('apksigner' + suffix, 'aapt.exe' if os.name == 'nt' else 'aapt'):
            if not (sdk_root / 'build-tools/36.0.0' / name).is_file():
                raise ValueError('Install Android Build Tools 36.0.0, platform android-36 and NDK 28.2.13676358.')
        for folder in ('platforms/android-36', 'ndk/28.2.13676358'):
            if not (sdk_root / folder).is_dir():
                raise ValueError(f'Android SDK component missing: {folder}')
        if not (ROOT / 'apps/vex/android/key.properties').is_file():
            raise ValueError('Restore production signing configuration first; see scripts/packaging/README.md. Debug signing is never used.')
        if not re.fullmatch('[a-fA-F0-9]{64}', args.certificate_sha256.replace(':', '')):
            raise ValueError('Set ANDROID_CERT_SHA256 or pass --certificate-sha256 with the public production certificate fingerprint.')
    missing = [name for name in required if not shutil.which(name)]
    if missing:
        raise ValueError('Missing native prerequisites: ' + ', '.join(missing))
    if target.startswith('linux-'):
        subprocess.run(['pkg-config', '--exists', 'gtk+-3.0'], check=True)
    if target in ('osx-universal', 'ios-check'):
        subprocess.run(['xcodebuild', '-version'], check=True)
    return str(dart)


def recipe(args, target, flutter, dart, output):
    """Return argv/cwd pairs so local builds, previews and tests share one recipe."""
    version, _ = app_version()
    steps = [([sys.executable, str(ROOT / 'scripts/sync_builtin_documents.py')], ROOT),
             ([flutter, 'pub', 'get', '--enforce-lockfile'], ROOT)]
    if not args.skip_tests:
        steps.append(([flutter, 'analyze', '--no-pub'], ROOT))
        steps.append(([dart, 'test', '--concurrency=2'], ROOT / 'packages/vex_markdown_core'))
        for project in ('packages/vex_editor', 'packages/vex_mindmap', 'apps/vex'):
            steps.append(([flutter, 'test', '--no-pub', '--concurrency=2'], ROOT / project))
        steps.append(([sys.executable, '-m', 'unittest', 'discover', '-s', 'scripts/tests', '-v'], ROOT))
    app = ROOT / 'apps/vex'
    if target.startswith('linux-'):
        arch = target.removeprefix('linux-')
        steps += [([flutter, 'build', 'linux', '--release', '--target', 'lib/main.dart'], app),
                  (['bash', str(HERE / 'linux/package.sh'), version, arch, str(output)], ROOT)]
        artifacts = [target]
    elif target == 'osx-universal':
        venv = ROOT / 'artifacts/tools/macos-dmg'
        python = str(venv / 'bin/python')
        steps += [([flutter, 'config', '--no-enable-macos-arm64-only'], ROOT),
                  ([flutter, 'build', 'macos', '--release', '--target', 'lib/main.dart'], app),
                  ([sys.executable, '-m', 'venv', str(venv)], ROOT),
                  ([python, '-m', 'pip', 'install', '--require-hashes', '-r', str(HERE / 'osx/dmg-requirements.txt')], ROOT),
                  (['bash', str(HERE / 'osx/package.sh'), version, str(output)], ROOT)]
        artifacts = ['macos-universal']
    elif target == 'android':
        sdk = str(android_sdk(args)) if not args.dry_run else str(args.sdk_root or os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT') or '<ANDROID_HOME>')
        steps += [([flutter, 'build', 'apk', '--release', '--flavor', 'production', '--split-per-abi', '--target-platform', 'android-arm,android-arm64,android-x64', '--target', 'lib/main.dart'], app),
                  ([sys.executable, str(HERE / 'android/collect.py'), '--sdk-root', sdk, '--certificate-sha256', args.certificate_sha256 or '<ANDROID_CERT_SHA256>', '--output', str(output)], ROOT)]
        artifacts = list(ANDROID_ABIS)
    elif target == 'ios-check':
        steps.append(([flutter, 'build', 'ios', '--release', '--no-codesign', '--target', 'lib/main.dart'], app))
        return steps
    else:
        raise ValueError(f'No native recipe for {target}')
    for command in ('checksums', 'verify'):
        steps.append(([sys.executable, str(HERE / 'shared/release_tools.py'), command, '--directory', str(output), '--targets', *artifacts], ROOT))
    return steps


def run_steps(steps, environment, log):
    with log.open('w', encoding='utf-8') as transcript:
        for command, cwd in steps:
            heading = f'[{cwd}] {subprocess.list2cmdline(command)}'
            print(heading, flush=True)
            transcript.write(heading + '\n')
            transcript.flush()
            with subprocess.Popen(command, cwd=cwd, env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                  text=True, encoding='utf-8', errors='replace') as process:
                for line in process.stdout:
                    print(line, end='', flush=True)
                    transcript.write(line)
                if process.wait():
                    raise subprocess.CalledProcessError(process.returncode, command)


def main(argv=None):
    if sys.version_info < (3, 11):
        raise ValueError('Python 3.11+ is required for installer checksum verification.')
    args = parser().parse_args(argv)
    target = canonical_target(args.target)
    if args.compiler and target != 'win-x64':
        raise ValueError('--compiler is only supported for win-x64.')
    if args.sdk_root and target != 'android':
        raise ValueError('--sdk-root is only supported for Android.')
    output = output_directory(target, args.output)
    if args.target in ('osx-x64', 'osx-arm64'):
        print(f'{args.target} uses osx-universal: one DMG contains both Intel and Apple silicon binaries.')
    environment = dict(os.environ, PUB_HOSTED_URL='https://pub.dev', PYTHONIOENCODING='utf-8', FLUTTER_SUPPRESS_ANALYTICS='true')
    if target == 'win-x64':
        environment['PSModulePath'] = str(Path(os.environ.get('SystemRoot', 'C:/Windows')) / 'System32/WindowsPowerShell/v1.0/Modules')
        command = windows_command(args, output)
        if args.dry_run:
            print(subprocess.list2cmdline(command))
            return 0
        validate_host(target)
        return subprocess.call(command, cwd=ROOT, env=environment)
    flutter = flutter_executable(args.flutter)
    if args.dry_run:
        steps = recipe(args, target, flutter, 'dart', output)
        for command, cwd in steps:
            print(f'[{cwd.relative_to(ROOT) or "."}] {subprocess.list2cmdline(command)}')
        return 0
    validate_host(target)
    dart = prerequisites(args, target, flutter)
    if args.check_only:
        print(f'CHECKED: {target}. No dependencies downloaded, app built, installed or published.')
        return 0
    if args.skip_tests:
        print('WARNING: Analysis/tests explicitly skipped; dependency and artifact checks remain enabled.')
    log = ROOT / f'artifacts/build-logs/{target}-{datetime.now():%Y%m%d-%H%M%S-%f}.log'
    log.parent.mkdir(parents=True, exist_ok=True)
    print(f'Log: {log}', flush=True)
    if target == 'osx-universal':
        environment['VEX_PYTHON'] = str(ROOT / 'artifacts/tools/macos-dmg/bin/python')
        environment['CI'] = 'true'
    if target == 'android':
        environment['ANDROID_HOME'] = str(android_sdk(args))
        environment['ANDROID_SDK_ROOT'] = environment['ANDROID_HOME']
    run_steps(recipe(args, target, flutter, dart, output), environment, log)
    print('CHECKED: unsigned iOS compilation only; no installable IPA.' if target == 'ios-check' else f'READY: {output}')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f'BUILD FAILED: {error}', file=sys.stderr)
        sys.exit(error.returncode if isinstance(error, subprocess.CalledProcessError) and error.returncode > 0 else 1)
