(() => {
  'use strict';
  function create(options) {
    const viewport = document.getElementById('map-viewport'), stage = document.getElementById('map-stage');
    let x = 30, y = 40, scale = 1, selected = null, summary = true, folded = new Set(), tree, nodes = [], drag, pan, fitPending = true;
    const colors = ['#5a9987','#a39362','#7898b1','#b48e88','#9386a5','#839c6d'];
    function build(text, title) {
      const headings = TexEditor.parse(text).headings;
      const first = headings[0]?.level === 1 ? headings[0] : null;
      const root = { id: first?.id || 'root', title: first?.title || title.replace(/\.md$/,''), level: first?.level || 0, heading: first, children: [], depth: 0 };
      const stack = [root];
      for (const heading of headings) {
        if (heading === first) continue;
        while (stack.length > 1 && stack.at(-1).level >= heading.level) stack.pop();
        const parent = stack.at(-1), index = headings.indexOf(heading), next = headings[index+1];
        const snippet = text.slice(heading.end, next?.start ?? text.length).trim().replace(/[#*`>|\[\]-]/g,'').slice(0,48);
        const node = { id:heading.id, title:heading.title, level:heading.level, heading, children:[], parent, depth:parent.depth+1, snippet };
        parent.children.push(node); stack.push(node);
      }
      return root;
    }
    const transform = () => { stage.style.transform = `translate(${x}px,${y}px) scale(${scale})`; document.getElementById('map-zoom').textContent = Math.round(scale*100)+'%'; };
    function render() {
      tree = build(options.getText(), options.getTitle()); nodes=[]; let cursor = 25;
      function place(node, branch = 0) {
        node.color = colors[branch % colors.length];
        const children = folded.has(node.id) ? [] : node.children;
        children.forEach((child,i) => place(child, node === tree ? i : branch));
        node.x = 30 + node.depth*260;
        if (!children.length) { node.y = cursor; cursor += summary ? 115 : 83; }
        else node.y = (children[0].y + children.at(-1).y)/2;
        nodes.push(node);
      }
      place(tree);
      const paths = nodes.filter(n => n.parent).map(n => { const p=n.parent, sx=p.x+(p===tree?210:190), sy=p.y+28, ex=n.x, ey=n.y+28; return `<path d="M ${sx} ${sy} C ${sx+40} ${sy}, ${ex-40} ${ey}, ${ex} ${ey}" fill="none" stroke="${n.color}" stroke-opacity=".65" stroke-width="1.5"/>`; }).join('');
      stage.innerHTML = `<svg width="1800" height="${Math.max(1200,cursor)}" aria-hidden="true">${paths}</svg>` + nodes.map(n => `<button class="map-node ${n===tree?'root':''} ${n.id===selected?'selected':''}" data-node="${n.id}" draggable="${n!==tree}" style="left:${n.x}px;top:${n.y}px;--branch:${n.color}" aria-label="${TexEditor.esc(n.title)}"><strong>${TexEditor.esc(n.title)}</strong>${summary && n.snippet ? `<small>${TexEditor.esc(n.snippet)}</small>` : ''}${n.children.length ? `<span class="fold-badge" data-fold="${n.id}">${folded.has(n.id)?'+':'−'}</span>`:''}</button>`).join('');
      document.getElementById('map-node-count').textContent = `${TexEditor.parse(options.getText()).headings.length} 个章节`;
      transform(); if (fitPending && viewport.clientWidth) { fit(); fitPending=false; }
    }
    function fit() {
      if (!nodes.length || !viewport.clientWidth) { fitPending=true; return; }
      const width = Math.max(...nodes.map(n=>n.x+220))+20, height = Math.max(...nodes.map(n=>n.y+100))+25;
      scale=Math.min(1,(viewport.clientWidth-40)/width,(viewport.clientHeight-65)/height); scale=Math.max(.22,scale);
      x=(viewport.clientWidth-width*scale)/2; y=Math.max(20,(viewport.clientHeight-height*scale)/2-10); transform();
    }
    function zoom(delta) { const old=scale; scale=Math.min(2,Math.max(.22,scale+delta)); const cx=viewport.clientWidth/2,cy=viewport.clientHeight/2; x=cx-(cx-x)*scale/old; y=cy-(cy-y)*scale/old; transform(); }
    viewport.addEventListener('wheel',event=>{event.preventDefault();zoom(event.deltaY>0?-.08:.08);},{passive:false});
    viewport.addEventListener('pointerdown',event=>{if(event.target.closest('.map-node'))return;pan={px:event.clientX,py:event.clientY,x,y};viewport.setPointerCapture(event.pointerId);});
    viewport.addEventListener('pointermove',event=>{if(!pan)return;x=pan.x+event.clientX-pan.px;y=pan.y+event.clientY-pan.py;transform();});
    viewport.addEventListener('pointerup',()=>{pan=null;});
    stage.addEventListener('click',event=>{
      const fold=event.target.closest('[data-fold]');if(fold){folded.has(fold.dataset.fold)?folded.delete(fold.dataset.fold):folded.add(fold.dataset.fold);render();return;}
      const el=event.target.closest('[data-node]');if(!el)return;selected=el.dataset.node;render();options.onSelect(nodes.find(n=>n.id===selected));
    });
    stage.addEventListener('dblclick',event=>{const el=event.target.closest('[data-node]');if(el){selected=el.dataset.node;options.onSelect(nodes.find(n=>n.id===selected),true);}});
    stage.addEventListener('dragstart',event=>{const el=event.target.closest('[data-node]');drag=el?.dataset.node;event.dataTransfer.setData('text/plain',drag||'');event.dataTransfer.effectAllowed='move';});
    stage.addEventListener('dragover',event=>{const el=event.target.closest('[data-node]');if(el&&el.dataset.node!==drag){event.preventDefault();el.classList.add('drop-target');}});
    stage.addEventListener('dragleave',event=>{event.target.closest('[data-node]')?.classList.remove('drop-target');});
    stage.addEventListener('drop',event=>{event.preventDefault();const el=event.target.closest('[data-node]');document.querySelectorAll('.drop-target').forEach(n=>n.classList.remove('drop-target'));if(el&&drag&&drag!==el.dataset.node)options.onMove(drag,el.dataset.node);drag=null;});
    viewport.addEventListener('keydown',event=>{if(!selected)return;if(event.key==='F2'){event.preventDefault();options.onSelect(nodes.find(n=>n.id===selected),true);}if(event.key==='Enter'||event.key==='Tab'){event.preventDefault();options.onAdd(selected,event.key==='Tab');}});
    return { render, fit, zoom, reset(){scale=1;x=30;y=40;transform();}, toggleSummary(){summary=!summary;render();}, toggleFold(){const target=nodes.find(n=>n.id===selected)||tree;if(!target)return;folded.has(target.id)?folded.delete(target.id):folded.add(target.id);render();}, select(id){selected=id;render();}, get selected(){return selected;}, get nodes(){return nodes;} };
  }
  window.TexMindmap={create};
})();
