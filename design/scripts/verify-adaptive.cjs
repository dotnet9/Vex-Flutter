const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname,'..');
const read = name => fs.readFileSync(path.join(root,name),'utf8');
const sandbox = {window:{}};
vm.runInNewContext(read('assets/mermaid-catalog.js'),sandbox);
const catalog = sandbox.window.VexMermaid;
assert.equal(catalog.items.length,22);
assert.equal(new Set(catalog.items.map(item => item.key)).size,22);
for (const item of catalog.items) {
  assert.equal(catalog.label(item.source),item.label);
  assert.ok(catalog.snippet(item.key).includes('```mermaid\n' + item.source));
}
assert.equal(catalog.label('%% comment\ngraph TD\n A-->B'),'流程图');
assert.equal(catalog.label('C4Container\n title Demo'),'C4 架构图');
vm.runInNewContext(read('assets/desktop/samples.js'),{window:sandbox.window,VexMermaid:catalog});
const examples = sandbox.window.TexweftSamples.find(doc => doc.name.includes('Mermaid'));
assert.equal((examples.text.match(/```mermaid/g) || []).length,22);

let focused = 0;
const focus = {isConnected:true,closest:() => null,focus:() => focused++};
const normal = {inert:false}, alreadyInert = {inert:true};
const host = {classList:{toggle:(name,value) => assert.equal(value,true)}};
const scope = {clientWidth:386,children:[normal,alreadyInert],append(element) { this.children.push(element); element.parentElement = this; }};
const document = {body:{},activeElement:focus,getElementById:() => scope};
const overlaySandbox = {window:{},document};
vm.runInNewContext(read('assets/overlay.js'),overlaySandbox);
const overlay = overlaySandbox.window.VexOverlay;
assert.equal(overlay.mount(host),scope);
assert.equal(overlay.width(),386);
const release = overlay.lock(host);
assert.equal(normal.inert,true);
assert.equal(host.inert,undefined);
release(); release();
assert.equal(normal.inert,false);
assert.equal(alreadyInert.inert,true);
assert.equal(focused,1);

const adaptive = read('Texweft-Adaptive.html'), desktop = read('Texweft.html');
assert.ok(adaptive.indexOf('id="find-bar"') > adaptive.indexOf('id="document-workspace"'));
assert.ok(adaptive.indexOf('id="find-bar"') < adaptive.indexOf('id="view-surface"'));
assert.ok(desktop.indexOf('id="findbar"') > desktop.indexOf('class="workspace-main"'));
assert.ok(desktop.indexOf('id="findbar"') < desktop.indexOf('class="content-area"'));
assert.match(read('assets/app.js'),/class="modal-body"/);
assert.match(read('assets/presentation.js'),/scope === document.body && !priorFullscreen/);
assert.match(read('assets/presentation.js'),/class="deck-tools"/);
assert.match(read('assets/presentation.js'),/class="deck-pages"/);
assert.match(read('assets/presentation.js'),/mapMode && narrow \? controlIcon\('min'\)/);
assert.match(read('assets/presentation.css'),/\.deck-tools button\[hidden\] \{ display:none; \}/);
assert.match(adaptive, /id="i-min"/);
for (const html of [adaptive,desktop]) assert.match(html, /id="i-arrow"/);
assert.ok(!read('assets/preferences.js').includes('<h3 id="vex-section-title">'));
assert.ok(desktop.indexOf('id="texweft-update"') < desktop.indexOf('class="about-footer"'));
assert.match(desktop,/<div class="slogan" data-proto-label="写下想法，看见脉络。">写下想法，看见脉络。<\/div>/);
assert.match(desktop,/class="about-framework">Flutter \/ Dart/);
assert.match(read('assets/prototype.css'),/\.vex-settings \{ width:min\(675px,100%\)/);
assert.match(read('assets/app.js'),/class="vex-about-version"/);
assert.match(read('assets/desktop/refinement.css'),/\.about-updated \{ width:420px/);
assert.match(read('assets/prototype.css'),/\.modal:has\(\.vex-about\) \{ width:min\(100%,360px\)/);
assert.match(read('assets/preferences.js'),/class="vex-token-field"/);
assert.match(read('assets/prototype.css'),/\.vex-token-actions \{ position:absolute; right:3px/);
for (const html of [adaptive,desktop]) {
  assert.ok(html.indexOf('assets/vendor/d3-hierarchy/d3-hierarchy.min.js') < html.indexOf('assets/map-layout.js'));
  assert.match(html,/assets\/map-layout.js/);
}
console.log('PASS: 22 Mermaid templates/examples, overlay bounds and inert restoration, editor-local find bars and preference/about layout.');
