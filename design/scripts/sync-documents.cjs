const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const documents = Object.fromEntries([
  ['thanks', 'ACKNOWLEDGEMENTS.md', '鸣谢.md'],
  ['changelog', 'CHANGELOG.md', '更新日志.md']
].map(([key, file, name]) => [key, {name, file:'documents/' + file, text:fs.readFileSync(path.join(root, 'documents', file), 'utf8').replace(/\r\n/g, '\n')}]));
fs.writeFileSync(path.join(root, 'assets', 'documents-data.js'), '// Generated from design/documents/*.md.\nwindow.VexDocuments = ' + JSON.stringify(documents, null, 2) + ';\n');
