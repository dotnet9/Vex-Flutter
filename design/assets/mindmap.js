(() => {
  'use strict';
  function create(options) {
    const viewport = document.getElementById('map-viewport'), stage = document.getElementById('map-stage');
    let x = 30, y = 40, scale = 1, selected = null, summary = true, folded = new Set(), tree, nodes = [], drag, pan, fitPending = true, bounds;
    let layout = 'right';
    const isolated = new URLSearchParams(location.search).get('preview') === '1', elements = new Map();
    try { const saved = isolated ? null : localStorage.getItem('vex-prototype-map-layout'); if (VexMapLayout.valid(saved)) layout = saved; } catch {}
    const measure = document.createElement('canvas').getContext('2d');
    const links = document.createElementNS('http://www.w3.org/2000/svg','svg');
    links.setAttribute('aria-hidden','true'); stage.appendChild(links);
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
    const transform = (animate = false) => { stage.classList.toggle('animating',animate); stage.style.transform = `translate(${x}px,${y}px) scale(${scale})`; document.getElementById('map-zoom').textContent = Math.round(scale*100)+'%'; };
    function rows(text,width,font) {
      measure.font = font; let count=1,used=0;
      for(const char of text) { const size=measure.measureText(char).width; if(used+size>width){count++;used=0;} used+=size; }
      return count;
    }
    function render() {
      tree = build(options.getText(), options.getTitle());
      function color(node, branch = 0) {
        node.color = colors[branch % colors.length];
        node.children.forEach((child,i) => color(child,node === tree ? i : branch));
      }
      color(tree);
      const font = getComputedStyle(document.body).fontFamily;
      const geometry=VexMapLayout.layout(tree,{
        mode:layout,children:node=>folded.has(node.id)?[]:node.children,
        measure(node){
          const root=node===tree,padding=root?40:32;
          node.width=root?210:190;
          const title=rows(node.title,node.width-padding-4,`${root?'600 15':'550 12'}px ${font}`)*(root?24:19.2);
          const snippet=summary&&node.snippet?Math.min(2,rows(node.snippet,node.width-padding-4,`11px ${font}`))*18+6:0;
          node.height=Math.ceil((root?40:24)+title+snippet+2);
        }
      });
      nodes=geometry.nodes; bounds=geometry; stage.dataset.layout=layout;
      const visible=new Set(nodes.map(node=>node.id));
      elements.forEach((element,id)=>{if(!visible.has(id)){element.remove();elements.delete(id);}});
      nodes.forEach(node=>{
        let element=elements.get(node.id);
        if(!element){element=document.createElement('button');element.type='button';elements.set(node.id,element);stage.appendChild(element);}
        element.className=`map-node ${node===tree?'root':''} ${node.id===selected?'selected':''}`;
        element.dataset.node=node.id; element.dataset.side=node.layoutSide; element.draggable=node!==tree;
        element.setAttribute('aria-label',node.title); element.setAttribute('aria-pressed',String(node.id===selected));
        Object.assign(element.style,{left:node.x+'px',top:node.y+'px',width:node.width+'px',height:node.height+'px'});
        element.style.setProperty('--branch',node.color);
        element.innerHTML=`<strong>${TexEditor.esc(node.title)}</strong>${summary&&node.snippet?`<small>${TexEditor.esc(node.snippet)}</small>`:''}${node.children.length?`<span class="fold-badge" data-fold="${node.id}" role="button" tabindex="0" aria-label="${folded.has(node.id)?'展开':'折叠'}：${TexEditor.esc(node.title)}" aria-expanded="${!folded.has(node.id)}">${folded.has(node.id)?'+':'−'}</span>`:''}`;
      });
      links.setAttribute('width',geometry.width); links.setAttribute('height',geometry.height);
      links.innerHTML=geometry.links.map(link=>`<path d="${link.path}" fill="none" stroke="${link.node.color}" stroke-opacity=".65" stroke-width="1.5"/>`).join('');
      stage.style.width=geometry.width+'px'; stage.style.height=geometry.height+'px';
      document.getElementById('map-node-count').textContent = `${TexEditor.parse(options.getText()).headings.length} 个章节`;
      transform(); if (fitPending && viewport.clientWidth) { fit(); fitPending=false; }
    }
    function fit() {
      if (!nodes.length || !viewport.clientWidth) { fitPending=true; return; }
      const {width,height}=bounds;
      scale=Math.max(.01,Math.min(1,(viewport.clientWidth-40)/width,(viewport.clientHeight-65)/height));
      x=(viewport.clientWidth-width*scale)/2; y=(viewport.clientHeight-height*scale)/2-10; transform(true);
    }
    function zoom(delta) { const old=scale; scale=Math.min(2,Math.max(.01,scale+delta)); const cx=viewport.clientWidth/2,cy=viewport.clientHeight/2; x=cx-(cx-x)*scale/old; y=cy-(cy-y)*scale/old; transform(true); }
    new ResizeObserver(()=>{if(viewport.clientWidth&&viewport.clientHeight)fit();}).observe(viewport);
    viewport.addEventListener('wheel',event=>{event.preventDefault();zoom(event.deltaY>0?-.08:.08);},{passive:false});
    viewport.addEventListener('pointerdown',event=>{if(event.target.closest('.map-node'))return;pan={px:event.clientX,py:event.clientY,x,y};viewport.setPointerCapture(event.pointerId);});
    viewport.addEventListener('pointermove',event=>{if(!pan)return;x=pan.x+event.clientX-pan.px;y=pan.y+event.clientY-pan.py;transform();});
    ['pointerup','pointercancel','lostpointercapture'].forEach(name=>viewport.addEventListener(name,()=>{pan=null;}));
    stage.addEventListener('click',event=>{
      const fold=event.target.closest('[data-fold]');if(fold){folded.has(fold.dataset.fold)?folded.delete(fold.dataset.fold):folded.add(fold.dataset.fold);render();return;}
      const el=event.target.closest('[data-node]');if(!el)return;selected=el.dataset.node;render();options.onSelect(nodes.find(n=>n.id===selected));
    });
    stage.addEventListener('dblclick',event=>{const el=event.target.closest('[data-node]');if(el){selected=el.dataset.node;options.onSelect(nodes.find(n=>n.id===selected),true);}});
    stage.addEventListener('dragstart',event=>{const el=event.target.closest('[data-node]');drag=el?.dataset.node;event.dataTransfer.setData('text/plain',drag||'');event.dataTransfer.effectAllowed='move';});
    stage.addEventListener('dragover',event=>{const el=event.target.closest('[data-node]');if(el&&el.dataset.node!==drag){event.preventDefault();el.classList.add('drop-target');}});
    stage.addEventListener('dragleave',event=>{event.target.closest('[data-node]')?.classList.remove('drop-target');});
    stage.addEventListener('drop',event=>{event.preventDefault();const el=event.target.closest('[data-node]');document.querySelectorAll('.drop-target').forEach(n=>n.classList.remove('drop-target'));if(el&&drag&&drag!==el.dataset.node)options.onMove(drag,el.dataset.node);drag=null;});
    viewport.addEventListener('keydown',event=>{if(event.target.closest('[data-fold]')&&['Enter',' '].includes(event.key)){event.preventDefault();event.target.click();return;}if(!selected)return;if(event.key==='F2'){event.preventDefault();options.onSelect(nodes.find(n=>n.id===selected),true);}if(event.key==='Enter'||event.key==='Tab'){event.preventDefault();options.onAdd(selected,event.key==='Tab');}});
    return { render, fit, zoom, setLayout(key){if(!VexMapLayout.valid(key))return;layout=key;try{if(!isolated)localStorage.setItem('vex-prototype-map-layout',key);}catch{}render();fit();}, get layout(){return layout;}, reset(){scale=1;x=30;y=40;transform();}, toggleSummary(){summary=!summary;render();}, toggleFold(){const target=nodes.find(n=>n.id===selected)||tree;if(!target)return;folded.has(target.id)?folded.delete(target.id):folded.add(target.id);render();}, select(id){selected=id;render();}, get selected(){return selected;}, get nodes(){return nodes;} };
  }
  window.TexMindmap={create};
})();
