"""Reject bundled ELF objects that require a newer Linux runtime than our baseline."""
import argparse
import os
from pathlib import Path
import re
import subprocess

BASELINE = {'GLIBC': (2, 31), 'GLIBCXX': (3, 4, 28), 'CXXABI': (1, 3, 12)}


def requirements(output):
    # Version definitions belong to the library itself; only imported versions
    # in the ELF version-needs table constrain the target system.
    section = output.partition('Version needs section')[2]
    return [(name, tuple(map(int, version.split('.'))))
            for name, version in re.findall(r'Name: (GLIBCXX|GLIBC|CXXABI)_([0-9.]+)', section)]


def check(directory):
    failures = []
    count = 0
    for path in sorted(Path(directory).rglob('*')):
        if not path.is_file():
            continue
        with path.open('rb') as stream:
            if stream.read(4) != b'\x7fELF':
                continue
        count += 1
        output = subprocess.check_output(['readelf', '--version-info', '--wide', str(path)],
                                         text=True, encoding='utf-8', env={**os.environ, 'LC_ALL': 'C'})
        for name, version in requirements(output):
            if version > BASELINE[name]:
                failures.append(f'{path}: requires {name}_{".".join(map(str, version))}')
    if not count:
        raise ValueError('No ELF binaries were found in the Flutter bundle.')
    if failures:
        raise ValueError('Ubuntu 20.04 / Kylin V10 runtime baseline exceeded:\n' + '\n'.join(failures))
    print(f'Validated {count} ELF files: glibc <= 2.31, libstdc++ <= GCC 9 baseline.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('bundle', type=Path)
    check(parser.parse_args().bundle)
