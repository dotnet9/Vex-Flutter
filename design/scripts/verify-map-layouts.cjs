const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname,'..');
const sandbox = {window:{}};
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(path.join(root,'assets/vendor/d3-hierarchy/d3-hierarchy.min.js'),'utf8'),sandbox);
vm.runInContext(fs.readFileSync(path.join(root,'assets/map-layout.js'),'utf8'),sandbox);
const {items,valid,layout} = sandbox.window.VexMapLayout;
assert.equal(items.length,6);
assert.equal(valid('timeline'),false);
function node(id,children=[]) { return {id,text:'unchanged '+id,children}; }
function content(node) { return {id:node.id,text:node.text,children:node.children.map(content)}; }
const samples = [
  node('root'),
  node('root',[node('a')]),
  node('root',Array.from({length:12},(_,i)=>node('branch'+i,Array.from({length:i%4},(_,j)=>node('leaf'+i+'-'+j))))),
  node('root',[node('a',[node('b',[node('c',[node('d')])])]),node('e',[node('f'),node('g')]),node('h')])
];
for(const tree of samples) for(const {key} of items) {
  const original=JSON.stringify(content(tree));
  const result=layout(tree,{mode:key,measure(n){n.width=180+(n.id.length%3)*24;n.height=48+(n.id.length%4)*35;}});
  assert.ok(Number.isFinite(result.width)&&Number.isFinite(result.height),key+' bounds');
  for(const a of result.nodes) {
    assert.ok(a.x>=0&&a.y>=0&&a.x+a.width<=result.width&&a.y+a.height<=result.height,key+' contained');
    for(const b of result.nodes) if(a!==b) {
      const overlap=Math.min(a.x+a.width,b.x+b.width)-Math.max(a.x,b.x)>0.01&&Math.min(a.y+a.height,b.y+b.height)-Math.max(a.y,b.y)>0.01;
      assert.equal(overlap,false,`${key}: ${a.id} overlaps ${b.id}`);
    }
  }
  assert.ok(result.links.every(link=>!/(NaN|Infinity)/.test(link.path)),key+' paths');
  const after=JSON.stringify(content(tree));
  assert.equal(after,original,key+' must not change content or child order');
}
const folded=layout(samples.at(-1),{mode:'balanced',children:n=>n.id==='a'?[]:n.children});
assert.equal(folded.nodes.some(n=>n.id==='b'),false);
assert.equal(layout(node('root'),{mode:'invalid'}).nodes[0].layoutSide,'right');
const large=node('root',Array.from({length:60},(_,i)=>node('b'+i,Array.from({length:5},(_,j)=>node('c'+i+'-'+j)))));
const radial=layout(large,{mode:'radial'});
assert.equal(radial.nodes.length,361);
assert.ok(radial.links.every(link=>!/(NaN|Infinity)/.test(link.path)));
console.log('PASS: six map layouts, variable sizes, no overlaps, folded branches, valid paths and unchanged content/order.');
