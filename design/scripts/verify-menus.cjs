const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assets = path.resolve(__dirname, '../assets');
const interact = fs.readFileSync(path.join(assets, 'desktop/interact.js'), 'utf8');
function menus(platform) {
  const context = {URLSearchParams, location:{search:'?platform=' + platform}};
  context.window = context;
  for (const file of ['palettes.js', 'typography-catalog.js', 'mermaid-catalog.js', 'element-menu.js']) {
    vm.runInNewContext(fs.readFileSync(path.join(assets, file), 'utf8'), context);
  }
  vm.runInNewContext(interact.slice(0, interact.indexOf('  var menuNav =')) + '})();', context);
  return context.VexProto.menuData;
}
function commands(items) {
  return items.flatMap(item => item.sub ? commands(item.sub) : item.sep ? [] : [item]);
}
for (const platform of ['windows', 'macos', 'linux']) {
  const data = menus(platform);
  assert.deepEqual(Array.from(data, menu => menu.key), (platform === 'macos' ? ['app'] : []).concat(['file','edit','paragraph','format','view','tools','help']));
  const all = data.flatMap(menu => commands(menu.items));
  assert.equal(all.length, platform === 'macos' ? 157 : 154, 'Reclassification must retain all existing commands');
  const file = data.find(menu => menu.key === 'file').items;
  const exports = file.find(item => item.label === '导出').sub;
  for (const label of ['导出 HTML','导出 PDF','导出 PNG 长图','导出 Word（.docx）']) {
    assert.ok(exports.some(item => item.label === label && !item.sub));
  }
  assert.ok(file.find(item => item.label === '文档操作').sub);
  const view = data.find(menu => menu.key === 'view').items;
  for (const label of ['编辑方式','侧栏与大纲','编辑显示','窗口','界面配色','Markdown 排版']) {
    assert.ok(view.find(item => item.label === label).sub, label);
  }
  for (const action of ['edit-instant','edit-source','toggle-sidebar','pane-files','pane-outline','toggle-lines','toggle-watermark','toggle-pairs','toggle-word-count','presentation','toggle-focus','toggle-typewriter','toggle-motion','toggle-fullscreen','toggle-topmost','maximize']) {
    assert.ok(all.some(item => item.action === action), action + ' must remain reachable');
  }
  assert.ok(data.find(menu => menu.key === 'edit').items.some(item => item.action === 'toggle-pairs'));
  const tools = data.find(menu => menu.key === 'tools').items;
  for (const target of ['wechat','zhihu','juejin']) assert.ok(tools.some(item => item.action === 'copy-' + target));
  function checkGroups(items) {
    assert.ok(items.filter(item => !item.sep).length <= 13, 'Each level should fit a short vertical menu');
    items.filter(item => item.sub).forEach(item => checkGroups(item.sub));
  }
  data.forEach(menu => checkGroups(menu.items));
}
const polish = fs.readFileSync(path.join(assets, 'desktop/polish.css'), 'utf8');
assert.match(polish, /max-height:\s*none;[\s\S]*overflow:\s*visible;/);
assert.match(polish, /body > \.submenu\.flyout\[hidden\]\s*\{ display: none; \}/);
assert.ok(!interact.includes("box.addEventListener('scroll'"));
const workbench = fs.readFileSync(path.join(assets, 'desktop/workbench.js'), 'utf8');
assert.match(workbench, /fileListMode = bundledDocument \? 'list'/);
assert.match(workbench, /if \(!bundledDocument\) VexStorage.setItem\('vex-design-file-list-mode'/);
console.log('PASS: 154 commands retained across seven menus; bounded semantic groups, hidden submenus and isolated built-in lists.');
