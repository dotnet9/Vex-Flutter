const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname,'..');
const sandbox = {window:{}};
vm.runInNewContext(fs.readFileSync(path.join(root,'assets/tour-placement.js'),'utf8'),sandbox);
const place = sandbox.window.VexTourPlacement.place;
const bounds = {x:0,y:0,width:1280,height:800};
const size = {width:344,height:292};
for (const target of [
  {x:500,y:150,width:300,height:50},
  {x:20,y:100,width:226,height:580},
  {x:400,y:320,width:510,height:250},
  {x:1160,y:20,width:80,height:32},
  {x:20,y:740,width:300,height:40}
]) {
  const p = place(target,bounds,size);
  assert.ok(p.x >= 12 && p.y >= 12);
  assert.ok(p.x+size.width <= bounds.width-12 && p.y+size.height <= bounds.height-12);
  const overlap = Math.max(0,Math.min(p.x+size.width,target.x+target.width)-Math.max(p.x,target.x)) * Math.max(0,Math.min(p.y+size.height,target.y+target.height)-Math.max(p.y,target.y));
  assert.equal(overlap,0,'Tour must not cover its target');
  const gap = Math.max(p.x-target.x-target.width,target.x-p.x-size.width,p.y-target.y-target.height,target.y-p.y-size.height);
  assert.equal(gap,12,'Bubble should stay adjacent to its target');
}
for (const y of [80,650]) {
  const p = place({x:24,y,width:340,height:40},{x:8,y:8,width:386,height:820},{width:310,height:230});
  assert.ok(p.x >= 20 && p.x+310 <= 382);
  assert.equal(p.side,y === 80 ? 'bottom' : 'top');
}
const preferences = fs.readFileSync(path.join(root,'assets/preferences.js'),'utf8');
assert.ok(preferences.includes('watermarkPreview:false,watermarkExport:false'));
const changelog = fs.readFileSync(path.join(root,'documents/CHANGELOG.md'),'utf8');
assert.match(changelog,/## v0\.2\.2（2026-10-17）\n\n- /);
assert.match(changelog,/## v0\.2\.1（2026-10-17）\n\n- /);
const app = fs.readFileSync(path.join(root,'assets/app.js'),'utf8');
const adaptive = fs.readFileSync(path.join(root,'Vex-Adaptive.html'),'utf8');
const css = fs.readFileSync(path.join(root,'assets/prototype.css'),'utf8');
const desktop = fs.readFileSync(path.join(root,'Vex.html'),'utf8');
const interact = fs.readFileSync(path.join(root,'assets/desktop/interact.js'),'utf8');
const workspace = fs.readFileSync(path.join(root,'assets/desktop/workspace.js'),'utf8');
const elementMenu = fs.readFileSync(path.join(root,'assets/element-menu.js'),'utf8');
const elementCSS = fs.readFileSync(path.join(root,'assets/element-menu.css'),'utf8');
assert.match(desktop,/<span data-proto-label="关于">关于<\/span>/);
assert.ok(!desktop.includes('data-l10n="AboutVexTitle"'));
assert.ok(!interact.includes("a.textContent = '›'"));
assert.match(interact,/class="ico vex-expand-icon"/);
assert.ok(!workspace.includes('>⌄</span>'));
assert.ok(!desktop.includes('>⌄</span>'));
assert.match(css,/--vex-operation-icon-size:var\(--window-control-icon,14px\)/);
assert.equal((elementMenu.match(/item\.children\?icon\('chevron'\)/g)||[]).length,2);
assert.ok(!elementMenu.includes("icon('arrow')"));
assert.match(elementCSS,/\.vex-element-icon \{[^}]*width:var\(--vex-operation-icon-size,18px\); height:var\(--vex-operation-icon-size,18px\)/);
assert.match(elementCSS,/\.vex-element-row \{[^}]*align-items:center/);
const chevron = html => html.match(/<symbol id="i-chevron"[^>]*>(.*?)<\/symbol>/)[1];
assert.equal(chevron(desktop),chevron(adaptive));
assert.match(css,/background-position:right 9px center/);
assert.match(adaptive,/id="phone-sheet-host" hidden/);
assert.match(app,/if\(isPhone\(\)&&name==='mobile'\)\{phoneActions\(anchor\);return;\}/);
assert.match(app,/sheetInert\.forEach\(\(\[el,inert\]\)=>el\.inert=inert\)/);
assert.match(app,/sheetHost\.addEventListener\('pointercancel',endSheetDrag\)/);
assert.match(css,/\.phone-sheet-row \{[^}]*min-height:52px/);
assert.match(css,/\.phone-sheet-content \{[^}]*overflow-x:hidden/);
console.log('PASS: adjacent tour placement, viewport bounds, phone placement, watermark defaults, release sections and phone sheet guards.');
