const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname,'..');
const script = fs.readFileSync(path.join(root,'assets/installer.js'),'utf8');
function render(platform,query) {
  const host = {dataset:{},innerHTML:'',querySelector:()=>null};
  const body = {dataset:{platform},classList:{toggle(){}},append(){}};
  const box = {URLSearchParams,URL,location:{search:query,href:'http://localhost/design/Installer.html'},matchMedia:()=>({matches:true}),document:{body,documentElement:{dataset:{}},getElementById:id=>id==='installer-root'?host:id==='system-modal'?{hidden:true}:null,createElement:()=>({}),addEventListener(){}},window:{}};
  vm.runInNewContext(script,box);return host.innerHTML;
}
for(const platform of ['windows','macos','linux','harmonyos','android','ios']) {
  for(const progress of [0,46,100]) {
    for(const device of platform==='harmonyos'?['phone','tablet','desktop']:['phone']) {
      const html=render(platform,`?scenario=installing&progress=${progress}&device=${device}`);
      assert.ok(html.includes(`--install-progress:${progress}%`),platform);
      assert.ok(html.includes(`<strong>${progress}%</strong>`),platform);
      assert.ok(html.includes(`aria-valuenow="${progress}"`),platform);
      assert.ok(html.includes('width:var(--install-progress)'),platform);
      assert.ok(!/progress-sub|Unpacking|Removing vex|复制应用资源/.test(html),platform);
    }
  }
}
assert.ok(render('macos','').includes('draggable="true"'));
assert.ok(render('ios','?scenario=unsigned').includes('此安装包尚不可安装'));
assert.ok(!render('ios','?scenario=unsigned').includes('data-action="install"'));
const css=fs.readFileSync(path.join(root,'assets/installer.css'),'utf8');
assert.ok(css.includes('left:clamp(20px,var(--install-progress),calc(100% - 20px))'));
assert.ok(css.includes('@media(prefers-reduced-motion:reduce)'));
console.log('PASS: six-platform progress, 0/46/100% endpoints, HarmonyOS device variants, no file-copy details, macOS drag and iOS signature gate.');
