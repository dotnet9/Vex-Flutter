const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assets = path.resolve(__dirname, '../assets');
const run = (file, context) => vm.runInNewContext(fs.readFileSync(path.join(assets, file), 'utf8'), context);

async function main() {
  const catalog = {};
  catalog.window = catalog;
  run('typography-catalog.js', catalog);
  assert.equal(catalog.VexTypes.length, 9);
  assert.equal(new Set(catalog.VexTypes.map(type => type.rules)).size, 9);
  for (const type of catalog.VexTypes) {
    const rules = catalog.VexTypeRules(type.key, false);
    for (const level of [1, 2, 3, 4]) assert.ok(rules.includes(`BODY h${level}{`));
    assert.ok(!catalog.VexTypeExport(type.key, false).includes('BODY'));
    assert.match(rules, /BODY h1\{[^}]*margin:0 0 \.55em;padding:0;/);
    assert.ok(!/letter-spacing:-/.test(rules));
  }
  let liveStyles;
  catalog.document = {createElement: () => ({}), head: {appendChild: style => { liveStyles = style.textContent; }}};
  run('typography-preview.js', catalog);
  for (const type of catalog.VexTypes) {
    const preview = catalog.VexTypePreview(type.key);
    for (const level of [1, 2, 3, 4]) assert.ok(preview.includes(`<h${level}>`));
    assert.ok(liveStyles.includes(`:root[data-typography="${type.key}"] .markdown-body`));
  }

  let storage = new Map(), launched;
  const launcher = {
    URL, URLSearchParams, crypto: {randomUUID: () => 'review-document'},
    location: {href: 'http://localhost/design/Vex.html?theme=dark&preview=1', search: '?theme=dark&preview=1'},
    sessionStorage: {getItem: key => storage.get(key) ?? null, setItem: (key, value) => storage.set(key, value), removeItem: key => storage.delete(key)},
    VexDocuments: {thanks: {file: '../docs/鸣谢.md', name: '鸣谢.md', text: '# 鸣谢'}},
    open: href => { launched = {url: new URL(href), storage: new Map(storage)}; return {}; }
  };
  launcher.window = launcher;
  run('document-window.js', launcher);
  assert.ok(launcher.VexDocumentWindow.open({builtin: 'thanks'}));
  assert.equal(launched.url.pathname, '/design/Vex.html');
  assert.equal(launched.url.searchParams.get('file'), '../docs/鸣谢.md');
  assert.equal(launched.url.searchParams.get('theme'), 'dark');
  assert.equal(launched.url.searchParams.has('child'), false);
  launcher.location.search = launched.url.search;
  assert.equal(launcher.VexDocumentWindow.read().builtin, true);
  assert.equal(launcher.VexDocumentWindow.read().readOnly, true);
  const polish = fs.readFileSync(path.join(assets, 'desktop/polish.css'), 'utf8');
  const themeScript = fs.readFileSync(path.join(assets, 'desktop/theme.js'), 'utf8');
  const typographyScript = fs.readFileSync(path.join(assets, 'desktop/typography.js'), 'utf8');
  assert.match(polish, /:root\\.theme-switching[\\s\\S]*transition:\\s*none\\s*!important/);
  assert.match(polish, /grid-template-columns:\\s*repeat\\(2,\\s*minmax\\(0,1fr\\)\\)/);
  assert.match(polish, /\\.type-swatch \\.type-document h1[\\s\\S]*font-size:\\s*19px\\s*!important/);
  assert.match(themeScript, /cancelAnimationFrame\\(themeFrame\\)/);
  assert.match(typographyScript, /new MutationObserver\\(syncThemeAccent\\)/);
  assert.doesNotMatch(typographyScript, /new MutationObserver\\(apply\\)/);

  const content = {name: '新文章.md', text: '# 一段想法\n\n保留这段内容。'};
  assert.ok(launcher.VexDocumentWindow.open({document: content}));
  assert.equal(storage.size, 0, 'The parent must release its temporary handoff');
  storage = launched.storage;
  launcher.location.search = launched.url.search;
  assert.equal(launcher.VexDocumentWindow.read().text, content.text);
  assert.equal(launcher.VexDocumentWindow.read().text, content.text, 'Refresh must retain the child document');
  storage.set('vex-document-launch:review-document', '{broken');
  assert.equal(launcher.VexDocumentWindow.read(), null);

  const notifications = [];
  let copied;
  const social = {navigator: {clipboard: {writeText: async text => { copied = text; }}}};
  social.window = social;
  run('social-copy.js', social);
  assert.equal(social.VexSocialCopy.platforms.length, 3);
  assert.equal(await social.VexSocialCopy.copy({platform: 'juejin', text: content.text, toast: text => notifications.push(text)}), true);
  assert.equal(copied, content.text);
  social.navigator.clipboard.writeText = async () => { throw new Error('Denied'); };
  assert.equal(await social.VexSocialCopy.copy({platform: 'juejin', text: content.text, toast: text => notifications.push(text)}), false);
  assert.match(notifications.at(-1), /未能访问剪贴板/);
  console.log('PASS: nine shared typography styles, four heading levels, compact title spacing, full workspace launches, refresh retention and social clipboard outcomes.');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
