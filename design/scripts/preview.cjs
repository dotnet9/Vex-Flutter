const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '../..');
function prepareDocuments() {
  const python = process.env.VEX_PYTHON || (process.platform === 'win32' ? 'python' : 'python3');
  const result = spawnSync(python, [path.join(root, 'scripts/sync_builtin_documents.py')], {encoding:'utf8'});
  if (result.error || result.status !== 0) throw new Error(result.error?.message || result.stderr || 'Document preparation failed');
}
prepareDocuments();
const types = {'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.svg':'image/svg+xml','.md':'text/markdown; charset=utf-8','.png':'image/png','.woff2':'font/woff2','.ttf':'font/ttf'};
const port = Number(process.env.VEX_PREVIEW_PORT || 4317);
const server = http.createServer((req,res) => {
  let pathname;
  try {pathname = decodeURIComponent(new URL(req.url,'http://localhost').pathname);} catch {res.writeHead(400).end();return;}
  if (pathname === '/' || pathname === '/design/') pathname = '/design/index.html';
  if (pathname === '/design/assets/generated/documents-data.js') {
    try { prepareDocuments(); } catch (error) { console.error(error.message);res.writeHead(500).end('Document preparation failed');return; }
  }
  if (!pathname.startsWith('/design/') && !pathname.startsWith('/apps/vex/assets/fonts/')) {res.writeHead(404).end();return;}
  const target = path.resolve(root,'.' + pathname);
  const allowed = ['design','apps/vex/assets/fonts'].some(folder => target.startsWith(path.resolve(root,folder) + path.sep));
  if (!allowed) {res.writeHead(403).end();return;}
  fs.readFile(target,(error,data) => {if (error) {res.writeHead(404).end();return;}res.writeHead(200,{'Content-Type':types[path.extname(target)] || 'application/octet-stream','Cache-Control':'no-store'}).end(data);});
});
server.listen(port,'127.0.0.1',() => console.log('Vex prototype: http://127.0.0.1:' + server.address().port + '/design/'));
