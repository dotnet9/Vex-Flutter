/* Shared bounded placement for desktop and adaptive tour bubbles. */
(() => {
  'use strict';
  const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
  function place(target, bounds, size, preferred = 'bottom', avoid = []) {
    const gap = 12, margin = 12, {width, height} = size;
    const right = target.x + target.width, bottom = target.y + target.height;
    const cx = target.x + target.width / 2, cy = target.y + target.height / 2;
    const overlap = (a, b) => Math.max(0, Math.min(a.x + a.width, b.x + b.width) - Math.max(a.x, b.x)) * Math.max(0, Math.min(a.y + a.height, b.y + b.height) - Math.max(a.y, b.y));
    const candidates = ['bottom','right','left','top'].map(side => {
      let x = side === 'right' ? right + gap : side === 'left' ? target.x - width - gap : cx - width / 2;
      let y = side === 'bottom' ? bottom + gap : side === 'top' ? target.y - height - gap : cy - height / 2;
      const rawX = x, rawY = y;
      x = clamp(x, bounds.x + margin, bounds.x + bounds.width - width - margin);
      y = clamp(y, bounds.y + margin, bounds.y + bounds.height - height - margin);
      const rect = {x,y,width,height};
      const score = overlap(rect,target) * 20 + avoid.reduce((sum, r) => sum + overlap(rect,r),0) * 2 + Math.abs(rawX-x) + Math.abs(rawY-y) + (side === preferred ? 0 : 16);
      return {x,y,side,score,offset:side === 'top' || side === 'bottom' ? clamp(cx-x,22,width-22) : clamp(cy-y,22,height-22)};
    });
    return candidates.sort((a,b) => a.score-b.score)[0];
  }
  function attach(card, pointer, target, bounds, preferred, avoid) {
    card.style.maxWidth = Math.max(200,bounds.width-24) + 'px';
    card.style.maxHeight = Math.max(160,bounds.height-24) + 'px';
    const result = place(target,bounds,card.getBoundingClientRect(),preferred,avoid);
    card.style.left = result.x + 'px'; card.style.top = result.y + 'px';
    card.style.setProperty('--vex-tour-left',result.x + 'px');
    pointer.dataset.side = result.side;
    const horizontal = result.side === 'top' || result.side === 'bottom';
    pointer.style.left = (horizontal ? result.x + result.offset - 6 : result.side === 'right' ? result.x - 6 : result.x + card.offsetWidth - 6) + 'px';
    pointer.style.top = (horizontal ? result.side === 'bottom' ? result.y - 6 : result.y + card.offsetHeight - 6 : result.y + result.offset - 6) + 'px';
    return result;
  }
  window.VexTourPlacement = {place,attach};
})();
