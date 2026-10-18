const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const types = {'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.svg':'image/svg+xml','.md':'text/markdown; charset=utf-8','.png':'image/png','.woff2':'font/woff2','.ttf':'font/ttf'};
const port = Number(process.env.VEX_PREVIEW_PORT || 4317);
http.createServer((req,res) => {
  let pathname;
  try {pathname = decodeURIComponent(new URL(req.url,'http://localhost').pathname);} catch {res.writeHead(400).end();return;}
  if (pathname === '/' || pathname === '/design/') pathname = '/design/index.html';
  if (!pathname.startsWith('/design/') && !pathname.startsWith('/apps/vex/assets/fonts/')) {res.writeHead(404).end();return;}
  const target = path.resolve(root,'.' + pathname);
  const allowed = ['design','apps/vex/assets/fonts'].some(folder => target.startsWith(path.resolve(root,folder) + path.sep));
  if (!allowed) {res.writeHead(403).end();return;}
  fs.readFile(target,(error,data) => {if (error) {res.writeHead(404).end();return;}res.writeHead(200,{'Content-Type':types[path.extname(target)] || 'application/octet-stream','Cache-Control':'no-store'}).end(data);});
}).listen(port,'127.0.0.1',() => console.log('Vex prototype: http://127.0.0.1:' + port + '/design/'));
