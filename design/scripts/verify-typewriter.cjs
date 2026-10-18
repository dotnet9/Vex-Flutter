const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const frames = new Map(), handlers = new Map();
let nextFrame = 0, enabled = false, reduced = false, caretLine = 180, selection;
function element() {
  const classes = new Set(), properties = new Map();
  return {
    clientTop: 0, offsetHeight: 600, clientHeight: 600, scrollTop: 0,
    style: { setProperty: (key, value) => properties.set(key, value) },
    classList: { toggle: (key, value) => value ? classes.add(key) : classes.delete(key), contains: key => classes.has(key) },
    properties, listeners: {},
    addEventListener(name, fn) { this.listeners[name] = fn; },
    closest() { return null; },
    getBoundingClientRect() { return {top: 100, height: 600}; }
  };
}
const sourceScroll = element(), instantScroll = element(), source = element(), host = element();
source.value = 'one\ntwo\nthree'; source.selectionStart = source.selectionEnd = 0;
source.closest = () => sourceScroll;
host.closest = selector => selector === '.instant-scroll' ? instantScroll : null;
host.contains = node => node === host;
const sourceStyle = () => ({
  lineHeight: '23px', borderTopWidth: '0px', borderBottomWidth: '0px',
  paddingTop: sourceScroll.classList.contains('typewriter-on') ? sourceScroll.properties.get('--typewriter-space') : '22px',
  paddingBottom: sourceScroll.classList.contains('typewriter-on') ? sourceScroll.properties.get('--typewriter-space') : '60px'
});
Object.defineProperty(source, 'offsetHeight', {get: () => Number.parseFloat(source.style.height) || 151});
Object.defineProperty(sourceScroll, 'scrollHeight', {get: () => source.offsetHeight});
instantScroll.scrollHeight = 2400;
source.getBoundingClientRect = () => ({top: 100 - sourceScroll.scrollTop, height: source.offsetHeight});
const document = {activeElement: source, addEventListener: (name, fn) => handlers.set(name, fn)};
const window = {addEventListener() {}};
const sandbox = {
  window, document, getComputedStyle: node => node === source ? sourceStyle() : {zoom:'1'},
  getSelection: () => selection,
  ResizeObserver: class { observe() {} },
  requestAnimationFrame(fn) { frames.set(++nextFrame, fn); return nextFrame; },
  cancelAnimationFrame(id) { frames.delete(id); }
};
vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../assets/desktop/typewriter.js'), 'utf8'), sandbox);
const typewriter = window.VexTypewriter.create({source, instant: host, enabled: () => enabled, reducedMotion: () => reduced});
function flush() {
  let time = 0;
  while (frames.size && time < 1000) {
    const pending = [...frames.values()]; frames.clear(); time += 16;
    pending.forEach(fn => fn(time));
  }
  assert.equal(frames.size, 0, 'Scroll animation must settle');
}
const near = (actual, expected) => assert.ok(Math.abs(actual - expected) < .01, `${actual} != ${expected}`);
enabled = true; typewriter.refresh();
handlers.get('focusin')({target: source}); flush();
near(sourceScroll.scrollTop, 11.5);
source.selectionStart = source.selectionEnd = source.value.length;
handlers.get('selectionchange')(); flush();
near(sourceScroll.scrollTop, 57.5);
assert.equal(typewriter.sourceHeight(), 669, 'Both ends need half a viewport of padding');
source.selectionStart = 0;
handlers.get('selectionchange')(); flush();
near(sourceScroll.scrollTop, 57.5);
source.selectionStart = source.selectionEnd = 4;
reduced = true; handlers.get('selectionchange')(); flush();
near(sourceScroll.scrollTop, 34.5);
document.activeElement = host;
selection = {rangeCount:1, isCollapsed:true, focusNode:host, getRangeAt: () => ({
  cloneRange() { return this; }, collapse() {},
  getBoundingClientRect: () => ({top:100 + 300 + caretLine - instantScroll.scrollTop, height:20})
})};
handlers.get('focusin')({target:host}); flush();
near(instantScroll.scrollTop, 190);
caretLine = 360; handlers.get('selectionchange')(); flush();
near(instantScroll.scrollTop, 370);
handlers.get('pointerdown')({target:host}); caretLine = 450;
handlers.get('selectionchange')(); flush(); near(instantScroll.scrollTop, 370);
handlers.get('pointerup')(); flush(); near(instantScroll.scrollTop, 460);
enabled = false; typewriter.refresh(); caretLine = 520;
handlers.get('selectionchange')(); flush(); near(instantScroll.scrollTop, 460);
assert.equal(sourceScroll.classList.contains('typewriter-on'), false);
assert.equal(typewriter.sourceHeight(), 151, 'Disabling restores normal document spacing');
const target = window.VexTypewriter.scrollTarget;
near(target(instantScroll, {top:-1000,height:20}), 0);
near(target(instantScroll, {top:5000,height:20}), 1800);
const scaled = {...instantScroll, scrollTop:100, getBoundingClientRect: () => ({top:100,height:1200})};
near(target(scaled, {top:780,height:40}), 150);
const desktop = fs.readFileSync(path.join(__dirname,'../Vex.html'),'utf8');
assert.ok(desktop.indexOf('desktop/typewriter.js') < desktop.indexOf('desktop/workbench.js'));
const instant = fs.readFileSync(path.join(__dirname,'../assets/desktop/instant-editor.js'),'utf8');
assert.ok(!instant.includes("active.element.scrollIntoView({ block: 'center' })"));
console.log('PASS: source first/last line, caret-line centering, keyboard/selection changes, dragging, reduced motion, disable, bounds and scaled viewport.');
