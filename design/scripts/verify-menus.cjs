const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assets = path.resolve(__dirname,'../assets');
const interact = fs.readFileSync(path.join(assets,'desktop/interact.js'),'utf8');
function menus(platform) {
  const context = {
    window:{},document:{querySelector:()=>({innerHTML:''})},
    VexPalettes:[],VexTypes:[],VexMermaid:{items:[]},VexElementMenu:{tableItems:()=>[]},
    URLSearchParams,location:{search:'?platform='+platform}
  };
  vm.runInNewContext(interact,context);
  return context.window.VexProto.menuData;
}
for(const platform of ['windows','macos','linux']) {
  const data = menus(platform);
  const file = data.find(menu=>menu.key==='file').items;
  for(const label of ['导出 HTML','导出 PDF','导出 PNG 长图','导出 Word（.docx）']) {
    const item = file.find(item=>item.label===label);
    assert.ok(item && !item.sub, `${label} must be a first-level command`);
  }
  assert.ok(!file.some(item=>item.label==='导出'));
  const view = data.find(menu=>menu.key==='view').items;
  for(const label of ['编辑方式','文档导航','编辑显示','写作辅助','窗口'])assert.ok(!view.some(item=>item.label===label));
  for(const action of ['edit-instant','edit-source','toggle-sidebar','pane-files','pane-outline','toggle-lines','toggle-watermark','toggle-pairs','toggle-word-count','presentation','toggle-focus','toggle-typewriter','toggle-motion','toggle-fullscreen','toggle-topmost','maximize']) {
    const item = view.find(item=>item.action===action);
    assert.ok(item && !item.sub, `${action} must remain directly accessible`);
  }
  assert.ok(view.find(item=>item.label==='界面配色').sub);
  assert.ok(view.find(item=>item.label==='Markdown 排版').sub);
  const tools = data.find(menu=>menu.key==='tools').items;
  assert.ok(!tools.some(item=>item.label==='复制到'));
  for(const platform of ['wechat','zhihu','juejin'])assert.ok(tools.find(item=>item.action==='copy-'+platform&&!item.sub));
}
function element(className, height=0) {
  return {
    className,offsetHeight:height,children:[],style:{},
    classList:{contains:name=>name===className},setAttribute(){},
    appendChild(child){
      if(child.parent)child.parent.children.splice(child.parent.children.indexOf(child),1);
      this.children.push(child);child.parent=this;
    },
    replaceChildren(...children){
      for(const child of this.children)child.parent=null;
      this.children=[];for(const child of children)this.appendChild(child);
    },
    querySelectorAll(){return this.children.flatMap(child=>child.className==='menu-column'?child.children:[child]);}
  };
}
const fitting={
  document:{createElement:()=>element('menu-column')},
  getComputedStyle:node=>node.className==='menu-sep'?{marginTop:'5px',marginBottom:'5px'}:{paddingTop:'5px',paddingBottom:'5px',borderTopWidth:'1px',borderBottomWidth:'1px'}
};
vm.runInNewContext(interact.slice(interact.indexOf('  function fitMenu('),interact.indexOf('  function buildItem(')),fitting);
for(const menu of menus('windows').concat([{items:Array.from({length:28},()=>({label:'Mermaid'}))}])) {
  const box=element('flyout');
  const rows=menu.items.map(item=>element(item.sep?'menu-sep':'menu-item',item.sep?1:36));
  rows.forEach(row=>box.appendChild(row));
  const expected=rows.filter(row=>row.className==='menu-item');
  for(const height of [360,520,700,950,520]) {
    fitting.fitMenu(box,height);
    const actual=box.children.flatMap(column=>column.children.filter(row=>row.className==='menu-item'));
    assert.equal(actual.length,expected.length,'Reflow must preserve every command');
    assert.ok(actual.every((row,index)=>row===expected[index]),'Reflow must preserve command order');
    for(const column of box.children) {
      assert.notEqual(column.children[0].className,'menu-sep');
      assert.notEqual(column.children.at(-1).className,'menu-sep');
      const used=column.children.reduce((sum,row)=>sum+(row.className==='menu-sep'?11:36),12);
      assert.ok(used<=height,`Column height ${used} exceeds ${height}`);
    }
  }
}
const css=fs.readFileSync(path.join(assets,'prototype.css'),'utf8');
assert.match(css,/\.menu-flyout>\.flyout,body>\.submenu\.flyout\s*\{[^}]*max-height:none;[^}]*overflow:visible;/);
assert.ok(!interact.includes("box.addEventListener('scroll'"));
const workbench = fs.readFileSync(path.join(assets,'desktop/workbench.js'),'utf8');
assert.match(workbench,/fileListMode = bundledDocument \? 'list'/);
assert.match(workbench,/if \(!bundledDocument\) VexStorage.setItem\('vex-design-file-list-mode'/);
console.log('PASS: flat commands, non-scrolling grouped columns and repeated reflow without omissions; isolated built-in document lists.');
