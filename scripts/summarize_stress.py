"""Sanitize local stress results for review without publishing source paths."""
import argparse
import json
import pathlib

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('input', type=pathlib.Path)
parser.add_argument('output', type=pathlib.Path)
parser.add_argument('--aborted', action='store_true')
args = parser.parse_args()
data = json.loads(args.input.read_text(encoding='utf-8'))
names = list(data['inputs'])
mapping = {}
for i, path in enumerate(names, 1):
    mapping[path] = f'document-{i}'
    mapping[pathlib.PurePath(path).name] = f'document-{i}'
def sanitize(text):
    if text is None:
        return None
    for source, label in sorted(mapping.items(), key=lambda item: -len(item[0])):
        text = text.replace(source, label)
    return text
data['inputs'] = {f'document-{i}': {'utf16Length': value}
                  for i, value in enumerate(data['inputs'].values(), 1)}
for operation in data['operations']:
    operation['operation'] = sanitize(operation['operation'])
    if 'error' in operation:
        operation['error'] = sanitize(operation['error'])
data['pending'] = sanitize(data.get('pending'))
errors = sum('error' in row for row in data['operations'])
data['runStatus'] = ('aborted' if args.aborted else 'failed' if errors else
                     'completed' if data['pending'] is None and data.get('testCompleted') is not False
                     else 'incomplete')
data['summary'] = {'operations': len(data['operations']),
                   'sampledPeakRssMiB': max(row['rssMiB'] for row in data['operations']),
                   'errors': errors}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(data['summary']))
