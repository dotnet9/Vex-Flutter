(function () {
  'use strict';
  var $ = function (id) { return document.getElementById(id); }, MM = window.VexMindMap;
  // 原型始终提供演示文档；正式应用的空启动由 Flutter 工作区独立处理。
  var docs = VexSamples.map(function (doc) { return Object.assign({}, doc); });
  var builtin = window.VexDocuments?.[new URLSearchParams(location.search).get('document')];
  var launched = VexDocumentWindow.read();
  if (launched) docs = [launched];
  else if (builtin) docs = [{name:builtin.name,text:builtin.text,readOnly:true}];
  var bundledDocument = !!builtin || !!launched?.builtin;
  var workspaceFolder = bundledDocument ? '内置文档' : '演示文档';
  var fileListMode = bundledDocument ? 'list' : VexStorage.getItem('vex-design-file-list-mode') || 'tree', fileDescending = false;
  var settings = { length: 30, paragraphs: true, lists: true, blocks: false, layout: 'right' };
  try {
    var saved = JSON.parse(VexStorage.getItem('vex-design-mindmap') || '{}');
    if (Number.isInteger(saved.length) && saved.length >= 1 && saved.length <= 120) settings.length = saved.length;
    ['paragraphs', 'lists', 'blocks'].forEach(function (key) { if (typeof saved[key] === 'boolean') settings[key] = saved[key]; });
    if (VexMapLayout.valid(saved.layout)) settings.layout = saved.layout;
  } catch (_) {}
  var editMode = 'instant';
  try { if (VexStorage.getItem('vex-design-edit-method') === 'source') editMode = 'source'; } catch (_) {}
  var requestedEdit = new URLSearchParams(location.search).get('edit');
  if (['instant', 'source'].includes(requestedEdit)) editMode = requestedEdit;
  var state = { view: 'edit', editMode: editMode, autoPair: true, focus: false, typewriter: false, motion: true, topmost: false, language: 'zh-CN', undo: [], redo: [], sidebar: true, source: false, doc: 0, selected: null, collapsed: new Set(), scale: 1, presentation: false, presentationScale: 1.5, x: 0, y: 0, dirty: false, parsed: null, nodes: [], pending: null };
  // 原型只持久化隔离的演示宽度，不接触宿主应用设置。
  var sidebar = document.querySelector('.sidebar'), splitter = $('sidebar-splitter'), workspace = document.querySelector('.workspace'), sidebarWidth = 226;
  try { var storedWidth = Number(VexStorage.getItem('vex-design-sidebar-width')); if (storedWidth >= 200 && storedWidth <= 560) sidebarWidth = storedWidth; } catch (_) {}
  function resizeSidebar(width, persist) {
    var available = document.querySelector('.workspace').clientWidth;
    var maximum = Math.min(560, Math.max(200, available - 365));
    sidebarWidth = Math.max(200, Math.min(maximum, width));
    sidebar.style.setProperty('--sidebar-width', sidebarWidth + 'px');
    // Keep the visible edge tied to the pointer even while the layout is busy reflowing.
    sidebar.style.width = sidebarWidth + 'px';
    splitter.setAttribute('aria-valuenow', Math.round(sidebarWidth));
    if (persist) try { VexStorage.setItem('vex-design-sidebar-width', String(sidebarWidth)); } catch (_) {}
  }
  resizeSidebar(sidebarWidth, false);
  var sidebarDrag;
  splitter.addEventListener('pointerdown', function (event) {
    if (event.button !== 0) return; event.preventDefault();
    var current = sidebar.getBoundingClientRect(), host = workspace.getBoundingClientRect();
    sidebarDrag = { offset: event.clientX - current.right, hostLeft: host.left };
    splitter.setPointerCapture(event.pointerId); document.body.classList.add('sidebar-resizing');
  });
  splitter.addEventListener('pointermove', function (event) {
    if (!sidebarDrag) return;
    var samples = event.getCoalescedEvents ? event.getCoalescedEvents() : [event], latest = samples[samples.length - 1];
    resizeSidebar(latest.clientX - sidebarDrag.hostLeft - sidebarDrag.offset, false);
  });
  ['pointerup', 'pointercancel', 'lostpointercapture'].forEach(function (name) {
    splitter.addEventListener(name, function () { if (!sidebarDrag) return; sidebarDrag = null; document.body.classList.remove('sidebar-resizing'); resizeSidebar(sidebarWidth, true); });
  });
  splitter.addEventListener('keydown', function (event) {
    if (event.key !== 'ArrowLeft' && event.key !== 'ArrowRight') return;
    event.preventDefault(); resizeSidebar(sidebarWidth + (event.key === 'ArrowRight' ? 10 : -10), true);
  });


  // Right-side outline splitter: independent width, keyboard accessible, persisted in prototype storage.
  var structureSidebar = $('structure-sidebar'), structureSplitter = $('structure-splitter');
  var structureWidth = 240, structureInner = structureSidebar.querySelector('.structure-inner');
  try {
    var savedStructureWidth = Number(VexStorage.getItem('vex-design-structure-width'));
    if (savedStructureWidth >= 180 && savedStructureWidth <= 480) structureWidth = savedStructureWidth;
  } catch (_) {}
  function resizeStructure(width, persist) {
    var available = workspace.clientWidth;
    var leftWidth = sidebar.classList.contains('closed') ? 0 : sidebarWidth;
    var maximum = Math.min(480, Math.max(180, available - leftWidth - 480));
    structureWidth = Math.max(180, Math.min(maximum, width));
    structureSidebar.style.width = structureWidth + 'px';
    structureSidebar.style.minWidth = '0';
    structureInner.style.width = structureWidth + 'px';
    structureSplitter.setAttribute('aria-valuenow', String(Math.round(structureWidth)));
    if (persist) {
      try { VexStorage.setItem('vex-design-structure-width', String(structureWidth)); VexStorage.setItem('vex-design-structure', '1'); } catch (_) {}
      structureSidebar.classList.remove('collapsed');
      structureSidebar.querySelector('.structure-toggle').setAttribute('aria-expanded', 'true');
    }
  }
  resizeStructure(structureWidth, false);
  var structureDrag = null;
  structureSplitter.addEventListener('pointerdown', function (event) {
    if (event.button !== 0) return;
    event.preventDefault();
    structureSidebar.classList.remove('collapsed');
    var current = structureSplitter.getBoundingClientRect(), host = workspace.getBoundingClientRect();
    structureDrag = { offset: current.right - event.clientX, hostRight: host.right };
    structureSplitter.setPointerCapture(event.pointerId);
    document.body.classList.add('structure-resizing');
  });
  structureSplitter.addEventListener('pointermove', function (event) {
    if (!structureDrag) return;
    var samples = event.getCoalescedEvents ? event.getCoalescedEvents() : [event], latest = samples[samples.length - 1];
    resizeStructure(structureDrag.hostRight - (latest.clientX + structureDrag.offset), false);
  });
  ['pointerup', 'pointercancel', 'lostpointercapture'].forEach(function (name) {
    structureSplitter.addEventListener(name, function () {
      if (!structureDrag) return;
      structureDrag = null;
      document.body.classList.remove('structure-resizing');
      resizeStructure(structureWidth, true);
    });
  });
  structureSplitter.addEventListener('keydown', function (event) {
    if (event.key !== 'ArrowLeft' && event.key !== 'ArrowRight') return;
    event.preventDefault();
    structureSidebar.classList.remove('collapsed');
    resizeStructure(structureWidth + (event.key === 'ArrowLeft' ? 12 : -12), true);
  });
  window.addEventListener('resize', function () {
    resizeSidebar(sidebarWidth, false);
    resizeStructure(structureWidth, false);
  });

  var canvas = $('map-viewport'), scene = $('map-scene'), input = $('markdown-input'), mapElements = new Map();
  var labels = { heading: '标题', paragraph: '段落', quote: '引用', list: '列表项', code: '代码块', table: '表格' };
  var branchColors = ['var(--accent)', 'var(--success)', 'var(--warning)', 'var(--accent)', 'var(--muted)'];
  var textMeasure = document.createElement('canvas').getContext('2d');
  var typewriter = VexTypewriter.create({
    source: input, instant: $('instant-content'), enabled: function () { return state.typewriter; },
    reducedMotion: function () { return reducedMotion() || document.documentElement.dataset.motion === 'false'; }
  });
  var instant = createVexInstantEditor({
    input: input, blocks: function () { return state.parsed ? state.parsed.blocks : []; },
    renderBlock: function (block) {
      var element = $('markdown-preview').querySelector('[data-line="' + block.line + '"]');
      var listTag = /^\s*\d+[.)]\s/.test(block.raw) ? 'ol' : 'ul';
      return element ? (block.kind === 'list' ? '<' + listTag + '>' + element.outerHTML + '</' + listTag + '>' : element.outerHTML) : '<p></p>';
    },
    refresh: refreshNow, cursor: updateCursor, remember: remember,
    autoPair: function () { return state.autoPair; }, typewriter: function () { return state.typewriter; }
  });
  function remember(text) {
    if (state.undo[state.undo.length - 1] !== text) state.undo.push(text);
    if (state.undo.length > 100) state.undo.shift(); state.redo = [];
  }
  function escape(text) { return text.replace(/[&<>"']/g, function (char) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]; }); }
  function icon(name) { return '<svg class="ico" aria-hidden="true"><use href="#i-' + name + '"/></svg>'; }
  function closeLayers() { document.querySelectorAll('.win-layer').forEach(function (layer) { layer.hidden = true; }); }
  function openLayer(name) {
    document.querySelectorAll('.win-layer').forEach(function (layer) { layer.hidden = layer.id !== 'layer-' + name; });
  }
  var pendingSwitch = null;
  function confirmSwitch(callback) {
    if (!state.dirty) { callback(); return; }
    pendingSwitch = callback;
    document.querySelector('#layer-unsaved .dlg-msg').innerHTML = '是否保存更改？<br>如果不保存，您的更改将会丢失。';
    openLayer('unsaved');
  }
  function loadDoc(index) {
    instant.finish(); state.undo = []; state.redo = [];
    clearTimeout(state.pending);
    state.doc = index; state.selected = null; state.collapsed.clear(); state.dirty = false; state.mapVisited = false;
    input.value = docs[index].pendingText ?? docs[index].text; state.dirty = input.value !== docs[index].text; $('document-name').textContent = docs[index].name; $('node-inspector').hidden = true;
    input.readOnly = !!docs[index].readOnly; document.body.classList.toggle('builtin-readonly',input.readOnly);
    input.setSelectionRange(0, 0); document.querySelector('.source-scroll').scrollTop = 0;
    document.querySelector('.reading-scroll').scrollTop = 0;
    document.querySelector('.instant-scroll').scrollTop = 0;
    renderFiles(); refresh(); requestAnimationFrame(function () { fit(true); });
    window.dispatchEvent(new CustomEvent('vex-document-loaded'));
  }
  function renderFiles() {
    $('folder-name').textContent = workspaceFolder;
    $('file-list-toggle').innerHTML = icon(fileListMode === 'tree' ? 'list' : 'map');
    $('file-list-toggle').title = $('file-list-toggle').ariaLabel = fileListMode === 'tree' ? '切换为列表视图' : '切换为树视图';
    var visibleDocs = docs.map(function (doc, index) { return index === state.doc ? Object.assign({}, doc, {text:input.value}) : doc; });
    VexWriting.renderFiles({container:$('file-list'), docs:visibleDocs, current:visibleDocs[state.doc], folder:workspaceFolder, mode:fileListMode, descending:fileDescending, query:$('file-filter').value, icon:icon,
      onOpen:function (_, index) { if (index !== state.doc) confirmSwitch(function () { loadDoc(index); }); }});
    $('file-empty').hidden = true;
    var collapseFiles = $('collapse-files');
    if (collapseFiles) {
      collapseFiles.disabled = fileListMode !== 'tree' || !document.querySelectorAll('#file-list details.file-directory[open]').length;
    }
  }
  function filterFiles() {
    renderFiles();
  }
  $('file-filter').oninput = filterFiles;
  $('outline-filter').oninput = renderOutline;

  document.addEventListener('pointerdown', function (event) { if (!event.target.closest('.file-navigation-footer')) $('file-navigation-menu').hidden = true; });
  document.addEventListener('keydown', function (event) { if (event.key === 'Escape') $('file-navigation-menu').hidden = true; });
  var fileContextMenu = document.createElement('div'), fileContextTarget = null;
  fileContextMenu.className = 'file-context-menu'; fileContextMenu.hidden = true; fileContextMenu.setAttribute('role', 'menu');
  document.body.appendChild(fileContextMenu);
  function closeFileContextMenu() { fileContextMenu.hidden = true; fileContextTarget = null; }
  function showFileContextMenu(target, event) {
    fileContextTarget = target;
    fileContextMenu.innerHTML = '<button type="button" role="menuitem" data-file-context="open-window">在新窗口打开</button><button type="button" role="menuitem" data-file-context="reveal">打开文件位置</button>';
    fileContextMenu.hidden = false;
    var width = fileContextMenu.offsetWidth || 168, height = fileContextMenu.offsetHeight || 72;
    fileContextMenu.style.left = Math.max(8, Math.min(event.clientX, innerWidth - width - 8)) + 'px';
    fileContextMenu.style.top = Math.max(8, Math.min(event.clientY, innerHeight - height - 8)) + 'px';
    fileContextMenu.querySelector('button').focus({ preventScroll: true });
  }
  fileContextMenu.addEventListener('click', function (event) {
    var action = event.target.closest('[data-file-context]'); if (!action || !fileContextTarget) return;
    var target = fileContextTarget, act = action.dataset.fileContext; closeFileContextMenu();
    if (act === 'reveal') {
      if (target.kind === 'folder') VexProto.toast('文件夹位置：' + (target.path || '演示文档'));
      else {
        var reveal = docs[target.index];
        VexProto.toast('文件位置：' + ((reveal && (reveal.path || reveal.name)) || '演示文档'));
      }
      return;
    }
    if (target.kind === 'folder') {
      if (!VexDocumentWindow.open({ intent: 'open-folder' })) VexProto.toast('请允许弹出窗口后重试');
      return;
    }
    var doc = docs[target.index];
    if (!doc || !VexDocumentWindow.open({ document: { name: doc.name, text: target.index === state.doc ? input.value : doc.text, readOnly: !!doc.readOnly, path: doc.path } })) VexProto.toast('请允许弹出窗口后重试');
  });
  document.addEventListener('contextmenu', function (event) {
    var row = event.target.closest('#file-list .file-row'), folder = event.target.closest('#file-list .file-directory > summary');
    if (!row && !folder) return;
    event.preventDefault(); event.stopPropagation();
    if (row) showFileContextMenu({ kind: 'file', index: Number(row.dataset.fileIndex) }, event);
    else showFileContextMenu({ kind: 'folder', path: folder.dataset.folderPath || '' }, event);
  });
  document.addEventListener('pointerdown', function (event) { if (!fileContextMenu.contains(event.target)) closeFileContextMenu(); });
  document.addEventListener('keydown', function (event) { if (event.key === 'Escape') closeFileContextMenu(); });
  function inline(text) {
    return VexRendering.inline(text);
  }
  function renderPreview() {
    var html = '', blocks = state.parsed.blocks;
    function listMeta(block) {
      var match = /^(\s*)([-+*]|\d+[.)])\s+(?:\[([ xX])\]\s+)?(.*)$/.exec(block.raw.split('\n')[0]);
      return match ? { indent: block.indent || match[1].replace(/\t/g, '    ').length, ordered: /^\d/.test(match[2]), checked: match[3], text: match[4] } : null;
    }
    function renderListAt(index, indent) {
      var first = listMeta(blocks[index]), ordered = first.ordered, tag = ordered ? 'ol' : 'ul', items = [], current = null;
      while (index < blocks.length && blocks[index].kind === 'list') {
        var meta = listMeta(blocks[index]);
        if (!meta || meta.indent < indent || meta.indent === indent && meta.ordered !== ordered) break;
        if (meta.indent > indent) {
          if (!current) break;
          var nested = renderListAt(index, meta.indent); current.html += nested.html; index = nested.end; continue;
        }
        current = { html: '<li data-line="' + blocks[index].line + '">' + (meta.checked === undefined ? '' : meta.checked.toLowerCase() === 'x' ? '☑ ' : '☐ ') + inline(meta.text) + '</li>' };
        items.push(current); index++;
      }
      return { html: '<' + tag + '>' + items.map(function (item) { return item.html; }).join('') + '</' + tag + '>', end: index };
    }
    var lastEndLine = 0;
    for (var blockIndex = 0; blockIndex < blocks.length;) {
      var block = blocks[blockIndex];
      // 空行规则（与 Typora 相符）：第一个空行不产生额外间距，每多一个空行补一行正文高度。
      if (blockIndex > 0) {
        var prev = blocks[blockIndex - 1];
        var blanks = block.line - (prev.line - 1 + prev.raw.split('\n').length) - 1;
        for (var gap = Math.max(0, blanks - 1); gap > 0; gap--) html += '<div class="md-blank-gap"></div>';
      }
      var attr = ' data-line="' + block.line + '"';
      if (block.kind === 'list') {
        var list = renderListAt(blockIndex, block.indent || 0); html += list.html; blockIndex = list.end; continue;
      }
      if (VexRendering.special(block)) html += VexRendering.renderSpecial(block);
      else if (block.kind === 'rule') html += '<hr' + attr + '>';
      else if (block.kind === 'toc') html += block.html;
      else if (block.kind === 'paragraph' && block.raw.trim() === '[TOC]') {
        html += '<nav class="md-toc" data-line="' + block.line + '" aria-label="目录"><strong>目录</strong>' + state.nodes.filter(function (node) { return node.kind === 'heading' && node.level > 0; }).map(function (node) { return '<a href="#heading-' + (node.line - 1) + '" style="padding-left:' + (node.level - 1) * 14 + 'px">' + inline(node.text) + '</a>'; }).join('') + '</nav>';
      }
      else if (block.kind === 'heading') html += '<h' + block.level + ' id="heading-' + (block.line - 1) + '"' + attr + '>' + inline(block.raw.split('\n')[0].replace(/^ {0,3}#{1,6}\s+/, '').replace(/\s+#+\s*$/, '')) + '</h' + block.level + '>';
      else if (block.kind === 'code') {
        html += '<section class="md-code-block"' + attr + '><pre><code>' + escape(block.text) + '</code></pre></section>';
      }
      else if (block.kind === 'callout') html += block.html;
      else if (block.kind === 'footnote') html += block.html;
      else if (block.kind === 'quote' && /^\s*>\s*\[!(INFO|WARNING)\]/i.test(block.raw)) {
        var callout = /^\s*>\s*\[!(INFO|WARNING)\]/i.exec(block.raw);
        html += '<aside class="md-callout ' + callout[1].toLowerCase() + '"' + attr + '><strong>' + (callout[1].toUpperCase() === 'WARNING' ? '警告' : '信息') + '</strong><div>' + inline(block.raw.replace(/^\s*>\s*\[!(?:INFO|WARNING)\]\s*/i, '').replace(/^\s*>\s?/gm, '').replace(/\n/g, ' ')) + '</div></aside>';
      }
      else if (block.kind === 'paragraph' && /^ {0,3}\[\^([^\]\r\n]+)\]:/.test(block.raw)) {
        var footnote = /^ {0,3}\[\^([^\]\r\n]+)\]:\s*(.*)$/.exec(block.raw);
        html += '<div class="md-footnote" id="vex-footnote-' + encodeURIComponent(footnote[1]) + '"' + attr + '><sup>[' + escape(footnote[1]) + ']</sup> ' + inline(footnote[2]) + ' <a href="#vex-footnote-ref-' + encodeURIComponent(footnote[1]) + '" aria-label="返回正文">↩</a></div>';
      }
      else if (block.kind === 'quote') html += '<blockquote' + attr + '>' + inline(block.raw.replace(/^\s*>\s?/gm, '').replace(/\n/g, ' ')) + '</blockquote>';
      else if (block.kind === 'table') {
        var table = VexDocumentOps.table(block.raw), rows = table?.rows || [];
        html += '<table' + attr + '>' + rows.map(function (row, index) {
          var tag = index === 0 ? 'th' : 'td';
          return '<tr>' + row.map(function (cell,col) { return '<' + tag + ' data-align="' + (table.align[col] || 'left') + '" style="text-align:' + (table.align[col] || 'left') + '">' + inline(cell.replace(/\\\|/g,'|')) + '</' + tag + '>'; }).join('') + '</tr>';
        }).join('') + '</table>';
      } else html += '<p' + attr + '>' + inline(block.raw.replace(/\n/g, ' ')) + '</p>';
      blockIndex++;
    }
    $('markdown-preview').innerHTML = html || '<p class="empty-state">输入 Markdown，开始写作。</p>';
  }
  var activeOutlineLine = 1, outlineSyncFrame = 0;
  function activateOutlineAtLine(line, ensureVisible) {
    if (!Number.isFinite(Number(line))) return;
    activeOutlineLine = Math.max(1, Number(line));
    var headings = state.nodes.filter(function (node) { return node.kind === 'heading' && node.level > 0; });
    var active = headings[0] || null;
    headings.forEach(function (node) { if (node.line <= activeOutlineLine) active = node; });
    var activeButton = null;
    $('outline-body').querySelectorAll('.structure-item').forEach(function (item) {
      var selected = !!active && Number(item.dataset.sourceLine) === active.line;
      item.classList.toggle('on', selected);
      item.setAttribute('aria-current', selected ? 'location' : 'false');
      if (selected) activeButton = item;
    });
    if (ensureVisible && activeButton) {
      var list = $('outline-body'), top = activeButton.offsetTop, bottom = top + activeButton.offsetHeight;
      if (top < list.scrollTop) list.scrollTop = top;
      else if (bottom > list.scrollTop + list.clientHeight) list.scrollTop = bottom - list.clientHeight;
    }
  }
  function syncOutlineFromDocumentScroll(scroller, article) {
    if (!scroller || !article || scroller.hidden || !article.isConnected) return;
    if (outlineSyncFrame) cancelAnimationFrame(outlineSyncFrame);
    outlineSyncFrame = requestAnimationFrame(function () {
      outlineSyncFrame = 0;
      var headings = state.nodes.filter(function (node) { return node.kind === 'heading' && node.level > 0; });
      if (!headings.length) return;
      var threshold = scroller.getBoundingClientRect().top + 76, chosen = headings[0];
      headings.forEach(function (node) {
        var element = article.querySelector('[data-line="' + node.line + '"]');
        if (element && element.getBoundingClientRect().top <= threshold) chosen = node;
      });
      activateOutlineAtLine(chosen.line, true);
      syncPeerViewsToLine(chosen.line, scroller, false);
    });
  }
  var syncingPeerScroll = false, peerScrollTimer = 0, lastPeerLine = 0;
  function scrollArticleToLine(scroller, article, line) {
    if (!scroller || !article || !scroller.getClientRects().length) return;
    var target = article.querySelector('[data-line="' + line + '"]');
    if (!target) {
      var candidates = article.querySelectorAll('[data-line]');
      for (var i = 0; i < candidates.length; i++) {
        if (Number(candidates[i].dataset.line) <= line) target = candidates[i];
        else break;
      }
    }
    if (!target) return;
    var delta = target.getBoundingClientRect().top - scroller.getBoundingClientRect().top - 14;
    if (Math.abs(delta) > 8) scroller.scrollTop += delta;
  }
  function revealAndCenterMapNode(node) {
    if (!node || !$('map-pane').getClientRects().length) return;
    var expanded = false;
    function reveal(current, ancestors) {
      if (current.id === node.id) {
        ancestors.forEach(function (id) { if (state.collapsed.has(id)) { state.collapsed.delete(id); expanded = true; } });
        return true;
      }
      for (var i = 0; i < current.children.length; i++) {
        if (reveal(current.children[i], ancestors.concat(current.id))) return true;
      }
      return false;
    }
    reveal(state.parsed.root, []);
    if (expanded) renderMap();
    var element = mapElements.get(node.id);
    if (!element) return;
    mapElements.forEach(function (item, id) { item.classList.toggle('selected', id === node.id); });
    state.selected = node.id;
    state.x = canvas.clientWidth / 2 - (node.x + node.width / 2) * state.scale;
    state.y = canvas.clientHeight / 2 - (node.y + node.height / 2) * state.scale;
    transform(true);
  }
  function syncPeerViewsToLine(line, sourceScroller, force) {
    line = Math.max(1, Number(line) || 1);
    if (!force && (syncingPeerScroll || line === lastPeerLine)) return;
    lastPeerLine = line;
    syncingPeerScroll = true;
    if (peerScrollTimer) clearTimeout(peerScrollTimer);
    var instantScroll = document.querySelector('.instant-scroll');
    var readingScroll = document.querySelector('.reading-scroll');
    var sourceScroll = document.querySelector('.source-scroll');
    if (sourceScroller !== instantScroll) scrollArticleToLine(instantScroll, $('instant-content'), line);
    if (sourceScroller !== readingScroll) scrollArticleToLine(readingScroll, $('markdown-preview'), line);
    if (sourceScroller !== sourceScroll) {
      var lineHeight = parseFloat(getComputedStyle(input).lineHeight) || 23;
      input.scrollTop = Math.max(0, (line - 1) * lineHeight);
      sourceScroll.scrollTop = Math.max(0, (line - 1) * lineHeight);
    }
    var node = state.nodes.find(function (item) { return item.kind === 'heading' && item.line === line; });
    if (!node) {
      state.nodes.forEach(function (item) { if (item.kind === 'heading' && item.line <= line && (!node || item.line > node.line)) node = item; });
    }
    if (node) revealAndCenterMapNode(node);
    peerScrollTimer = setTimeout(function () { syncingPeerScroll = false; peerScrollTimer = 0; }, 100);
  }
  function syncOutlineFromSource() {
    var line = input.value.slice(0, input.selectionStart || 0).split('\n').length;
    activateOutlineAtLine(line, true);
    syncPeerViewsToLine(line, document.querySelector('.source-scroll'), false);
  }
  function syncOutlineFromInstantSelection() {
    var selection = window.getSelection && window.getSelection();
    var node = selection && selection.anchorNode;
    var element = node && (node.nodeType === 1 ? node : node.parentElement);
    var block = element && element.closest ? element.closest('[data-line]') : null;
    if (block) activateOutlineAtLine(Number(block.dataset.line), true);
  }
  function bindOutlineViewSync() {
    var instantScroll = document.querySelector('.instant-scroll');
    var readingScroll = document.querySelector('.reading-scroll');
    var sourceScroll = document.querySelector('.source-scroll');
    instantScroll.addEventListener('scroll', function () { if (!syncingPeerScroll) syncOutlineFromDocumentScroll(instantScroll, $('instant-content')); }, { passive: true });
    readingScroll.addEventListener('scroll', function () { if (!syncingPeerScroll) syncOutlineFromDocumentScroll(readingScroll, $('markdown-preview')); }, { passive: true });
    sourceScroll.addEventListener('scroll', function () {
      if (syncingPeerScroll) return;
      var lineHeight = parseFloat(getComputedStyle(input).lineHeight) || 23;
      var line = Math.floor(Math.max(sourceScroll.scrollTop, input.scrollTop) / lineHeight) + 1;
      activateOutlineAtLine(line, true);
      syncPeerViewsToLine(line, sourceScroll, false);
    }, { passive: true });
    input.addEventListener('scroll', function () {
      if (syncingPeerScroll) return;
      var lineHeight = parseFloat(getComputedStyle(input).lineHeight) || 23;
      var line = Math.floor(input.scrollTop / lineHeight) + 1;
      activateOutlineAtLine(line, true);
      syncPeerViewsToLine(line, sourceScroll, false);
    }, { passive: true });
    ['click', 'keyup', 'select', 'input'].forEach(function (eventName) {
      input.addEventListener(eventName, syncOutlineFromSource);
    });
    ['click', 'keyup', 'input'].forEach(function (eventName) {
      $('instant-content').addEventListener(eventName, syncOutlineFromInstantSelection);
    });
  }
  function renderOutline() {
    $('outline-body').innerHTML = '';
    var query = $('outline-filter').value.trim().toLowerCase();
    var headings = state.nodes.filter(function (node) { return node.kind === 'heading' && node.level > 0 && node.text.toLowerCase().includes(query); });
    var counters = [0, 0, 0, 0, 0, 0];
    headings.forEach(function (node) {
      counters[node.level - 1]++; for (var i = node.level; i < 6; i++) counters[i] = 0;
      var number = counters.slice(0, node.level).join('.');
      var button = document.createElement('button'); button.className = 'structure-item'; button.dataset.level = String(node.level);
      button.dataset.sourceLine = node.line;
      button.style.paddingLeft = (Math.max(0, node.level - 1) * 12) + 'px';
      button.innerHTML = '<span class="structure-marker"></span><span class="structure-num">' + number + '</span><span class="structure-text"></span>';
      button.querySelector('.structure-text').textContent = node.text;
      button.onclick = function () {
        if (state.view === 'mindmap') {
          var ancestors = [];
          function search(current) { if (current.id === node.id) return true; for (var child of current.children) { if (search(child)) { ancestors.push(current.id); return true; } } return false; }
          search(state.parsed.root); ancestors.forEach(function (id) { state.collapsed.delete(id); }); renderMap(); selectNode(node);
          var element = mapElements.get(node.id); if (element) { state.x = canvas.clientWidth / 2 - (node.x + node.width / 2) * state.scale; state.y = canvas.clientHeight / 2 - (node.y + node.height / 2) * state.scale; transform(true); }
        } else if (state.view === 'read') {
          var target = $('markdown-preview').querySelector('[data-line="' + node.line + '"]');
          if (target) { target.scrollIntoView({ block: 'start', behavior: reducedMotion() ? 'auto' : 'smooth' }); target.classList.remove('located'); void target.offsetWidth; target.classList.add('located'); }
        } else locate(node);
        activateOutlineAtLine(node.line, true);
        syncPeerViewsToLine(node.line, null, true);
      };
      $('outline-body').appendChild(button);
    });
    if (!headings.length) $('outline-body').innerHTML = '<div class="empty-state">' + (query ? '没有匹配的标题' : '添加标题后，会在这里显示大纲。') + '</div>';
    activateOutlineAtLine(activeOutlineLine, false);
  }
  bindOutlineViewSync();
  function refresh() {
    if (state.parsed && state.lastText === input.value && state.lastDoc === state.doc) { updateMeta(); updateCursor(); return; }
    var collapsedKeys = new Set(state.nodes.filter(function (node) { return state.collapsed.has(node.id); }).map(function (node) { return node.key; }));
    state.parsed = MM.parse(input.value, docs[state.doc].name.replace(/\.[^.]+$/, ''));
    state.nodes = MM.flatten(state.parsed.root);
    state.collapsed = new Set(state.nodes.filter(function (node) { return collapsedKeys.has(node.key); }).map(function (node) { return node.id; }));
    state.lastText = input.value; state.lastDoc = state.doc;
    // 源码变化后关闭旧节点详情，防止重新编号后显示到其他段落。
    state.selected = null; $('node-inspector').hidden = true;
    $('line-numbers').innerHTML = state.parsed.lines.map(function (_, index) { return '<div>' + (index + 1) + '</div>'; }).join('');
    input.style.height = typewriter.sourceHeight() + 'px';
    updateMeta(); renderPreview(); instant.render(); VexRendering.diagrams(); renderOutline(); renderMap(); updateCursor();
    window.dispatchEvent(new CustomEvent('vex-content-changed'));
  }
  function updateMeta() {
    $('dirty-dot').hidden = !state.dirty;
    $('sb-wordcount').textContent = contentCount().toLocaleString() + ' 词';
  }
  function refreshNow() { clearTimeout(state.pending); refresh(); }
  input.addEventListener('input', function () {
    state.dirty = input.value !== docs[state.doc].text;
    $('dirty-dot').hidden = !state.dirty;
    clearTimeout(state.pending); state.pending = setTimeout(refresh, 180);
  });
  input.addEventListener('beforeinput', function () { remember(input.value); });
  function updateCursor() {
    if (state.typewriter) typewriter.request();
  }
  ['click', 'keyup', 'select'].forEach(function (event) { input.addEventListener(event, updateCursor); });
  input.addEventListener('keydown', function (event) {
    if (event.isComposing) return;
    if (event.key === 'Tab') { event.preventDefault(); insert('  ', false); }
    var pairs = { '(': ')', '[': ']', '{': '}', '"': '"', "'": "'", '`': '`' };
    if (state.autoPair && !event.ctrlKey && !event.metaKey && pairs[event.key]) {
      event.preventDefault(); remember(input.value);
      var start = input.selectionStart, selected = input.value.slice(start, input.selectionEnd);
      input.setRangeText(event.key + selected + pairs[event.key], start, input.selectionEnd, 'end');
      input.setSelectionRange(start + 1, start + 1 + selected.length); input.dispatchEvent(new Event('input')); updateCursor();
    }
  });
  function reducedMotion() { return !state.motion || matchMedia('(prefers-reduced-motion: reduce)').matches; }
  function applyPresentation() {
    var root = document.querySelector('.app-window');
    root.classList.toggle('presentation-mode', state.presentation);
    root.style.setProperty('--presentation-scale', state.presentationScale);
    $('presentation-tools').hidden = !state.presentation;
    if (state.presentation) setView('read');
  }
  function startPresentation() {
    if (window.VexPresentation) {
      VexPresentation.open({
        text: function () { return input.value; }, title: function () { return docs[state.doc].name; },
        finish: function () { instant.finish(); closeLayers(); }, language: function () { return state.language; },
        background: document.querySelector('.app-window'), mapMode: function () { return state.view === 'mindmap'; }, mapLayout: function () { return settings.layout; }
      });
      return;
    }
    if (state.presentation) return;
    state.presentation = true; state.presentationScale = 1.5;
    instant.finish(); applyPresentation();
  }
  function stopPresentation() {
    if (!state.presentation) return;
    state.presentation = false; applyPresentation(); setView('edit');
  }

  function setView(view) {
    if (!['edit', 'read', 'mindmap'].includes(view)) view = 'edit';
    if (view !== 'edit') instant.finish();
    refreshNow(); state.view = view; document.querySelector('.workspace').dataset.view = view;
    document.querySelector('.view-switch').dataset.active = view;
    document.querySelectorAll('[data-view]').forEach(function (button) {
      if (button.tagName === 'BUTTON') { button.setAttribute('aria-selected', String(button.dataset.view === view)); button.tabIndex = button.dataset.view === view ? 0 : -1; }
    });
    $('edit-options').hidden = view !== 'edit';
    $('instant-pane').hidden = view !== 'edit' || state.editMode !== 'instant';
    $('source-pane').hidden = !(view === 'edit' && state.editMode === 'source') && !(view === 'mindmap' && state.source);
    $('reading-pane').hidden = view !== 'read';
    $('map-pane').hidden = view !== 'mindmap';
    $('reading-title').textContent = view === 'read' ? '阅读' : '正文预览';
    $('edit-source').setAttribute('aria-pressed', String(state.editMode === 'source'));
    document.querySelector('.workspace').classList.toggle('source-only', view === 'edit' && state.editMode === 'source');
    document.querySelectorAll('.content-area > section').forEach(function (pane) { pane.classList.remove('pane-enter'); void pane.offsetWidth; if (!pane.hidden) pane.classList.add('pane-enter'); });
    $('map-settings').hidden = true; $('map-settings-button').setAttribute('aria-expanded', 'false');
    if (view === 'mindmap' && !state.mapVisited) { state.mapVisited = true; requestAnimationFrame(function () { fit(true); }); }
    window.dispatchEvent(new CustomEvent('vex-view-changed', { detail: { view: view, editMode: state.editMode } }));
  }
  function setEditMode(mode) {
    instant.finish(); state.editMode = mode;
    try { VexStorage.setItem('vex-design-edit-method', mode); } catch (_) {}
    setView('edit');
  }
  document.querySelectorAll('.view-switch button').forEach(function (button) { button.onclick = function () { setView(button.dataset.view); }; });
  document.querySelector('.view-switch').addEventListener('keydown', function (event) {
    if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return;
    event.preventDefault(); var views = ['edit', 'read', 'mindmap'], index = views.indexOf(state.view);
    index = event.key === 'Home' ? 0 : event.key === 'End' ? 2 : (index + (event.key === 'ArrowRight' ? 1 : 2)) % 3;
    setView(views[index]); $('view-' + views[index]).focus();
  });
  // 右侧“文档结构”栏：记忆展开状态，收起时箭头翻转。
  var structureSaved = '1';
  try { structureSaved = window.VexStorage ? (VexStorage.getItem('vex-design-structure') || '1') : '1'; } catch (_) {}
  if (structureSaved === '0') $('structure-sidebar').classList.add('collapsed');
  $('structure-sidebar').querySelector('.structure-toggle').setAttribute('aria-expanded', structureSaved !== '0');
  function visibleChildren(node) {
    return node.children.filter(function (child) {
      return child.kind === 'heading' || (['paragraph', 'quote'].includes(child.kind) && settings.paragraphs)
        || (child.kind === 'list' && settings.lists) || (['code', 'table'].includes(child.kind) && settings.blocks);
    });
  }
  function nodeText(node) { return node.kind === 'heading' ? node.text : MM.clip(node.text || node.label || '空内容', settings.length); }
  function height(node) {
    var content = nodeText(node), fontSize = node.kind === 'heading' ? 13 : 12, width = node.width - (node.kind === 'heading' && !node.isRoot ? 28 : 26);
    textMeasure.font = (node.kind === 'heading' ? '600 ' : '') + fontSize + 'px ' + getComputedStyle(document.body).fontFamily;
    var rows = 1, used = 0;
    MM.characters(content).forEach(function (char) { var charWidth = textMeasure.measureText(char).width; if (used + charWidth > width) { rows++; used = 0; } used += charWidth; });
    return (node.kind === 'heading' ? 40 : 22) + rows * 20;
  }
  function renderMap() {
    if (!state.parsed) return;
    var geometry = VexMapLayout.layout(state.parsed.root, {
      mode: settings.layout,
      children: function (node) { return node.visibleChildren = state.collapsed.has(node.id) ? [] : visibleChildren(node); },
      measure: function (node) { node.width = node.isRoot ? 214 : 224; node.height = height(node); }
    }), rendered = geometry.nodes;
    scene.dataset.layout = settings.layout;
    var visible = new Set(rendered.map(function (node) { return node.id; }));
    mapElements.forEach(function (element, id) { if (!visible.has(id)) { element.remove(); mapElements.delete(id); } });
    rendered.forEach(function (node, index) {
      var element = mapElements.get(node.id), isNew = !element;
      if (isNew) { element = document.createElement('div'); mapElements.set(node.id, element); $('map-nodes').appendChild(element); }
      element.className = 'map-node' + (node.isRoot ? ' root' : node.kind === 'heading' ? '' : ' content') + (state.selected === node.id ? ' selected' : '') + (isNew ? ' enter' : '');
      element.dataset.kind = node.kind; element.dataset.side = node.layoutSide; element.dataset.line = node.line; element.dataset.nodeId = node.id; element.style.left = node.x + 'px'; element.style.top = node.y + 'px';
      element.style.width = node.width + 'px'; element.style.minHeight = node.height + 'px';
      element.style.setProperty('--branch-color', branchColors[node.branch % branchColors.length]);
      element.style.setProperty('--delay', Math.min(index * 14, 180) + 'ms');
      var kind = node.isRoot ? '文档' : node.kind === 'heading' ? 'H' + node.level : node.label || labels[node.kind];
      element.innerHTML = '<button class="map-node-button" title="' + escape(node.text || kind) + '"><span class="map-node-type">' + escape(kind) + '</span><span class="map-node-text">' + escape(nodeText(node)) + '</span></button>';
      element.querySelector('button').onclick = function () { selectNode(node); };
      var children = visibleChildren(node);
      if (children.length) {
        var collapse = document.createElement('button'); collapse.className = 'map-collapse'; collapse.textContent = state.collapsed.has(node.id) ? '+' : '−';
        collapse.setAttribute('aria-label', (state.collapsed.has(node.id) ? '展开' : '折叠') + '：' + node.text); collapse.setAttribute('aria-expanded', String(!state.collapsed.has(node.id)));
        collapse.onclick = function () { if (state.collapsed.has(node.id)) state.collapsed.delete(node.id); else state.collapsed.add(node.id); $('node-inspector').hidden = true; renderMap(); };
        element.appendChild(collapse);
      }
    });
    $('map-links').innerHTML = geometry.links.map(function (link) { return '<path style="--branch-color:' + branchColors[link.node.branch % branchColors.length] + '" d="' + link.path + '"/>'; }).join('');
    state.bounds = { width: geometry.width, height: geometry.height };
    scene.style.width = state.bounds.width + 'px'; scene.style.height = state.bounds.height + 'px';
    $('map-links').setAttribute('width', state.bounds.width); $('map-links').setAttribute('height', state.bounds.height);
    $('map-count').textContent = state.nodes.filter(function (node) { return node.kind === 'heading'; }).length + ' 个标题 · ' + rendered.length + ' 个可见节点';
    $('collapse-all').innerHTML = icon('list') + (state.collapsed.size ? '展开全部' : '收起分支');
    transform();
    window.dispatchEvent(new CustomEvent('vex-map-rendered'));
  }
  function transform(animate) {
    scene.classList.toggle('animating', !!animate);
    scene.style.transform = 'translate(' + state.x + 'px,' + state.y + 'px) scale(' + state.scale + ')';
    $('zoom-value').textContent = Math.round(state.scale * 100) + '%';
  }
  function fit(readable) {
    if (settings.layout !== 'right') readable = false;
    if (window.VexWorkspace?.current === 'three') readable = false;
    if (state.guideRestoring || $('map-pane').hidden || !state.bounds || !canvas.clientWidth) return;
    state.scale = Math.min(1, Math.max(readable === true ? .75 : .01, Math.min((canvas.clientWidth - 64) / state.bounds.width, (canvas.clientHeight - 84) / state.bounds.height)));
    state.x = (canvas.clientWidth - state.bounds.width * state.scale) / 2;
    state.y = (canvas.clientHeight - state.bounds.height * state.scale) / 2;
    if (readable === true) state.x = Math.max(24, state.x);
    transform(true);
  }
  function zoom(factor, anchor) {
    anchor = anchor || { x: canvas.clientWidth / 2, y: canvas.clientHeight / 2 };
    var previous = state.scale; state.scale = Math.min(2, Math.max(.01, state.scale * factor));
    state.x = anchor.x - (anchor.x - state.x) * state.scale / previous; state.y = anchor.y - (anchor.y - state.y) * state.scale / previous;
    transform(!anchor.pointer);
  }
  var drag = null;
  canvas.addEventListener('pointerdown', function (event) {
    if (event.target.closest('button, input, textarea, [draggable="true"]') || event.button !== 0) return;
    drag = { x: event.clientX, y: event.clientY, startX: state.x, startY: state.y }; canvas.setPointerCapture(event.pointerId); canvas.classList.add('panning');
  });
  canvas.addEventListener('pointermove', function (event) { if (drag) { state.x = drag.startX + event.clientX - drag.x; state.y = drag.startY + event.clientY - drag.y; transform(); } });
  ['pointerup', 'pointercancel', 'lostpointercapture'].forEach(function (event) { canvas.addEventListener(event, function () { drag = null; canvas.classList.remove('panning'); }); });
  canvas.addEventListener('wheel', function (event) {
    event.preventDefault();
    if (event.ctrlKey || event.metaKey) { var rect = canvas.getBoundingClientRect(); zoom(event.deltaY < 0 ? 1.1 : 1 / 1.1, { x: event.clientX - rect.left, y: event.clientY - rect.top, pointer: true }); }
    else { state.x -= event.deltaX; state.y -= event.deltaY; transform(); }
  }, { passive: false });
  var lastCanvasSize = { width: 0, height: 0 };
  new ResizeObserver(function () {
    if ($('map-pane').hidden || !canvas.clientWidth) return;
    if (state.guideRestoring) { lastCanvasSize = { width: canvas.clientWidth, height: canvas.clientHeight }; return; }
    if (lastCanvasSize.width !== canvas.clientWidth || lastCanvasSize.height !== canvas.clientHeight) {
      if (lastCanvasSize.width && lastCanvasSize.height) {
        state.x += (canvas.clientWidth - lastCanvasSize.width) / 2;
        state.y += (canvas.clientHeight - lastCanvasSize.height) / 2;
        transform();
      } else fit(true);
      lastCanvasSize = { width: canvas.clientWidth, height: canvas.clientHeight };
    }
  }).observe(canvas);
  function selectNode(node) {
    state.selected = node.id;
    activateOutlineAtLine(node.line, true);
    mapElements.forEach(function (element, id) { element.classList.toggle('selected', id === node.id); });
    $('inspector-kind').textContent = node.isRoot ? '文档' : labels[node.kind];
    $('inspector-title').textContent = node.kind === 'heading' ? node.text : '完整' + labels[node.kind];
    $('inspector-content').textContent = node.kind === 'heading' ? (node.children.filter(function (child) { return child.kind !== 'heading'; }).map(function (child) { return child.text; }).join('\n\n') || '此标题下没有直接内容，展开分支查看子章节。') : node.text;
    $('inspector-line').textContent = '第 ' + node.line + (node.endLine > node.line ? '–' + node.endLine : '') + ' 行';
    $('node-inspector').hidden = false; $('map-settings').hidden = true; $('map-settings-button').setAttribute('aria-expanded', 'false');
    if (state.source) highlightSource(node, false);
    window.dispatchEvent(new CustomEvent('vex-node-selected', { detail: node }));
  }
  function highlightSource(node, focus) {
    var start = state.parsed.lines.slice(0, node.line - 1).join('\n').length + (node.line > 1 ? 1 : 0);
    var length = state.parsed.lines.slice(node.line - 1, node.endLine).join('\n').length;
    input.setSelectionRange(start, start + length);
    document.querySelector('.source-scroll').scrollTo({ top: Math.max(0, (node.line - 1) * 23 - 90), behavior: reducedMotion() ? 'auto' : 'smooth' });
    if (focus) input.focus({ preventScroll: true }); updateCursor();
  }
  function locate(node) {
    if (window.VexWorkspace) { VexWorkspace.navigate(node.line); return; }
    if (state.view === 'mindmap') { state.source = true; applySource(); highlightSource(node, true); }
    else if (state.editMode === 'instant') { setView('edit'); instant.focusAt(node.line); }
    else { setView('edit'); highlightSource(node, true); }
  }
  function applySource() {
    $('source-pane').hidden = !state.source; $('map-source-toggle').classList.toggle('on', state.source);
    $('map-source-toggle').setAttribute('aria-pressed', String(state.source));
    window.dispatchEvent(new CustomEvent('vex-source-toggled', { detail: state.source }));
    requestAnimationFrame(function () { fit(true); });
  }
  function syncSettings() {
    $('map-layout').value = settings.layout;
    $('summary-length').value = settings.length; $('show-paragraphs').checked = settings.paragraphs;
    $('show-lists').checked = settings.lists; $('show-blocks').checked = settings.blocks;
    $('summary-label').textContent = !settings.paragraphs && !settings.lists && !settings.blocks ? '仅标题' : '摘要 ' + settings.length + ' 字';
    $('summary-example').textContent = MM.clip('把注意力留给内容。写作时保留必要工具，阅读和梳理结构时让文档占据更多空间。', settings.length);
    try { VexStorage.setItem('vex-design-mindmap', JSON.stringify(settings)); } catch (_) {}
    renderMap(); requestAnimationFrame(function () { fit(settings.layout === 'right'); });
  }
  $('map-layout').innerHTML = VexMapLayout.items.map(function (item) { return '<option value="' + item.key + '">' + item.label + '</option>'; }).join('');
  $('map-layout').onchange = function () { settings.layout = this.value; syncSettings(); };
  $('summary-length').addEventListener('input', function () {
    var value = Number(this.value); if (!Number.isInteger(value) || value < 1 || value > 120) { this.setCustomValidity('请输入 1–120 之间的整数'); return; }
    this.setCustomValidity(''); settings.length = value; syncSettings();
  });
  $('summary-length').addEventListener('blur', function () { this.value = settings.length; this.setCustomValidity(''); });
  [['show-paragraphs', 'paragraphs'], ['show-lists', 'lists'], ['show-blocks', 'blocks']].forEach(function (pair) { $(pair[0]).onchange = function () { settings[pair[1]] = this.checked; syncSettings(); }; });
  function download(content, name, type) {
    var url = URL.createObjectURL(new Blob([content], { type: type || 'text/plain;charset=utf-8' }));
    var link = document.createElement('a'); link.href = url; link.download = name; link.click(); setTimeout(function () { URL.revokeObjectURL(url); }, 1000);
  }
  function save() {
    instant.finish();
    refreshNow(); download(input.value, docs[state.doc].name); docs[state.doc].text = input.value; delete docs[state.doc].pendingText; state.dirty = false; refresh();
    VexProto.toast('已下载 Markdown 副本');
  }
  function insert(text, activate) {
    if (activate !== false && state.view !== 'edit') setView('edit');
    if (state.view === 'edit' && state.editMode === 'instant') {
      if (instant.insert(text)) return;
      remember(input.value);
      input.setRangeText(text, input.selectionStart, input.selectionEnd, 'end');
      input.dispatchEvent(new Event('input')); refreshNow();
      instant.focusAt(input.value.slice(0, input.selectionEnd).split('\n').length); return;
    }
    input.focus();
    if (!document.execCommand('insertText', false, text)) input.setRangeText(text, input.selectionStart, input.selectionEnd, 'end');
    input.dispatchEvent(new Event('input'));
  }
  function contentCount() { return VexWriting.metrics(input.value).count; }
  function findNext() {
    var term = $('find-input').value;
    if (!term) return;
    setEditMode('source'); var index = input.value.indexOf(term, input.selectionEnd); if (index < 0) index = input.value.indexOf(term);
    if (index < 0) { $('find-count').textContent = '没有匹配内容'; return; }
    input.setSelectionRange(index, index + term.length); input.focus();
    var line = input.value.slice(0, index).split('\n').length;
    document.querySelector('.source-scroll').scrollTop = Math.max(0, (line - 1) * 23 - 90); updateCursor();
  }
  function updateFind() {
    var term = $('find-input').value; $('find-count').textContent = term ? input.value.split(term).length - 1 + ' 处匹配' : '输入查找内容';
  }
  $('find-input').oninput = updateFind; $('find-input').onkeydown = function (event) { if (event.key === 'Enter') findNext(); };
  $('open-file-input').onchange = async function () {
    var file = this.files[0]; if (!file) return;
    try {
      var text = await file.text();
      confirmSwitch(function () { docs.push({ name: file.name, text: text }); loadDoc(docs.length - 1); VexProto.toast('已打开 ' + file.name); });
    } catch (_) { VexProto.toast('无法读取文件，请重新选择'); }
    this.value = '';
  };
  $('open-folder-input').onchange = async function () {
    var files = Array.from(this.files || []).filter(function (file) { return /\.(md|markdown|mdown|txt)$/i.test(file.name); });
    if (!files.length) { VexProto.toast('文件夹中没有可打开的 Markdown 文件'); this.value = ''; return; }
    try {
      var loaded = await Promise.all(files.map(async function (file) { return { name: file.name, path: file.webkitRelativePath.split('/').slice(1).join('/'), text: await file.text() }; }));
      var folder = (files[0].webkitRelativePath || '').split('/')[0] || 'Markdown';
      confirmSwitch(function () {
        docs = loaded; state.doc = 0; state.dirty = false; workspaceFolder = folder;
        loadDoc(0); VexProto.toast('已打开文件夹 · ' + loaded.length + ' 个 Markdown 文件');
      });
    } catch (_) { VexProto.toast('无法读取文件夹中的 Markdown 文件'); }
    this.value = '';
  };
  var snippets = { paragraph: '\n\n新段落\n\n', heading: '\n## 新章节\n\n', list: '\n- 列表项\n', ordered: '\n1. 列表项\n', task: '\n- [ ] 待办事项\n', quote: '\n> 引用内容\n', code: '\n```\n代码内容\n```\n', math: '\n$$\nx^2 + y^2 = z^2\n$$\n', rule: '\n\n---\n\n', 'inline-code': '`代码`', table: '\n| 列一 | 列二 |\n| --- | --- |\n| 内容 | 内容 |\n', link: '[链接文字](https://example.com)', bold: '**文字**', italic: '*文字*', image: '![图片描述](image.png)' };
  Object.assign(snippets,{mermaid:'\n```mermaid\nflowchart LR\n  A[写下想法] --> B[看见脉络]\n```\n',footnote:'[^1]\n\n[^1]: 脚注内容\n',strike:'~~文字~~',highlight:'==文字==',superscript:'^上标^',subscript:'~下标~'});
  VexMermaid.items.forEach(function (item) { snippets['mermaid-' + item.key] = VexMermaid.snippet(item.key); });
  [1,2,3,4,5,6].forEach(function (level) { snippets['heading' + level] = '\n' + '#'.repeat(level) + ' 新章节\n\n'; });
  document.getElementById('format-toolbar').addEventListener('mousedown', function (event) { if (event.target.closest('.format-button')) event.preventDefault(); });
  VexProto.handleAction = function (action, item) {
    if (elementMenu && elementMenu.handleAction(action === 'insert-table' ? 'element-insert-table' : action)) return true;
    if (action === 'preferences' || action === 'preferences-mcp' || action === 'mcp-audit' || action === 'dlg-mcp') { VexPreferences.open(action === 'preferences' ? 'general' : 'mcp'); if (action === 'mcp-audit') document.querySelector('[data-mcp-tab=audit]')?.click(); return true; }
    if (input.readOnly && (action.startsWith('insert-') || ['save','save-all','undo','redo','cut','paste','replace-all','clear-format','rename','delete-chapter','add-child','add-sibling','move-up','move-down','promote','demote'].includes(action))) { VexProto.toast('此文档为只读'); return true; }
    if (window.VexWorkspace && VexWorkspace.handleAction(action, item)) return true;
    if (action.startsWith('insert-')) { if (state.editMode === 'instant' && instant.format(action.slice(7))) return true; insert(snippets[action.slice(7)] || ''); return true; }
    if (action.startsWith('view-')) { setView(action.slice(5)); return true; }
    if (action === 'edit-instant' || action === 'edit-source') { setEditMode(action.slice(5)); return true; }
    if (action.startsWith('dlg-')) {
      if (action === 'dlg-statistics') {
        refreshNow();
        var stats = document.querySelectorAll('#layer-statistics .stat-card .num');
        if (stats[0]) stats[0].textContent = contentCount().toLocaleString();
        if (stats[1]) stats[1].textContent = MM.characters(input.value).length.toLocaleString();
        document.querySelectorAll('#layer-statistics .stat-card .lbl')[0].textContent = '正文字符';
        document.querySelectorAll('#layer-statistics .stat-card .lbl')[1].textContent = '源码字符';
        var metrics = [['行数', state.parsed.lines.length], ['段落', state.parsed.blocks.filter(function (block) { return block.kind === 'paragraph'; }).length], ['标题', state.parsed.blocks.filter(function (block) { return block.kind === 'heading'; }).length], ['阅读时间', '约 ' + Math.max(1, Math.ceil(contentCount() / 350)) + ' 分钟'], ['编码', 'UTF-8'], ['状态', state.dirty ? '已修改' : '未修改']];
        document.querySelector('#layer-statistics .stat-rows').innerHTML = metrics.map(function (metric) { return '<div class="stat-row"><span class="k">' + metric[0] + '</span><span class="v">' + metric[1] + '</span></div>'; }).join('');
      }
      if (action === 'dlg-properties') {
        refreshNow();
        document.querySelector('#layer-properties .prop-name').textContent = docs[state.doc].name;
        var properties = [['状态', state.dirty ? '已修改 · 尚未保存' : '未修改'], ['格式', 'Markdown'], ['编码', 'UTF-8'], ['大小', new Blob([input.value]).size.toLocaleString() + ' 字节']];
        document.querySelector('#layer-properties .prop-rows').innerHTML = properties.map(function (property) { return '<div class="prop-row"><span class="k">' + property[0] + '</span><span class="v">' + property[1] + '</span></div>'; }).join('');
      }
      if (action === 'dlg-delete') {
        document.querySelector('#layer-delete .dlg-title').textContent = '从工作区移除「' + docs[state.doc].name + '」？';
        document.querySelector('#layer-delete .dlg-msg').textContent = '原型仅移除工作区中的文档，原文件不会改动。';
        document.querySelector('#layer-delete .dlg-path').textContent = docs[state.doc].name;
      }
      if (action === 'dlg-doc') {
        if (!VexDocumentWindow.open({builtin:item && item.arg === '鸣谢' ? 'thanks' : 'changelog'})) VexProto.toast('请允许弹出窗口后重试');
      } else openLayer(action.slice(4));
      return true;
    }
    switch (action) {
      case 'toggle-source': setEditMode(state.editMode === 'source' ? 'instant' : 'source'); break;
      case 'clear-file-search': $('file-filter').value = ''; renderFiles(); $('file-filter').focus(); break;
      case 'clear-outline-search': $('outline-filter').value = ''; renderOutline(); $('outline-filter').focus(); break;
      case 'toggle-structure': {
        var structurePanel = $('structure-sidebar');
        structurePanel.classList.toggle('collapsed');
        var collapsedNow = structurePanel.classList.contains('collapsed');
        structurePanel.querySelector('.structure-toggle').setAttribute('aria-expanded', String(!collapsedNow));
        structurePanel.querySelector('.structure-toggle').title = collapsedNow ? '展开文档结构' : '收起文档结构';
        try { VexStorage.setItem('vex-design-structure', collapsedNow ? '0' : '1'); } catch (_) {}
        break;
      }
      case 'file-list-toggle': fileListMode = fileListMode === 'tree' ? 'list' : 'tree'; if (!bundledDocument) VexStorage.setItem('vex-design-file-list-mode', fileListMode); renderFiles(); break;
      case 'file-actions': $('file-navigation-menu').hidden = !$('file-navigation-menu').hidden; document.querySelector('[data-action=file-actions]').setAttribute('aria-expanded', String(!$('file-navigation-menu').hidden)); break;
      case 'refresh-files': renderFiles(); $('file-navigation-menu').hidden = true; break;
      case 'collapse-files': document.querySelectorAll('#file-list details.file-directory[open]').forEach(function (group) { group.open = false; }); renderFiles(); break;
      case 'sort-files': fileDescending = !fileDescending; renderFiles(); $('file-navigation-menu').hidden = true; break;
      case 'new': if (!VexDocumentWindow.open({document:{name:'未命名文档.md',text:''}})) VexProto.toast('请允许弹出窗口后重试'); break;
      case 'new-window': if (!VexDocumentWindow.open({document:{name:'未命名文档.md',text:''}})) VexProto.toast('请允许弹出窗口后重试'); break;
      case 'document-window': instant.finish(); if (!VexDocumentWindow.open({document:{name:docs[state.doc].name,text:input.value,readOnly:!!docs[state.doc].readOnly}})) VexProto.toast('请允许弹出窗口后重试'); break;
      case 'exit-app': exitGuard.open(); break;
      case 'open': if (!VexDocumentWindow.open({intent:'open-file'})) VexProto.toast('请允许弹出窗口后重试'); break;
      case 'open-folder': if (!VexDocumentWindow.open({intent:'open-folder'})) VexProto.toast('请允许弹出窗口后重试'); break;
      case 'open-sample': confirmSwitch(function () { loadDoc(Math.min(item.arg, docs.length - 1)); }); break;
      case 'quick-open': if (!state.sidebar) VexProto.handleAction('toggle-sidebar'); VexProto.handleAction('pane-files'); $('file-filter').focus(); break;
      case 'save': save(); break;
      case 'save-all': save(); break;
      case 'copy-wechat': case 'copy-zhihu': case 'copy-juejin':
        instant.finish(); refreshNow();
        VexSocialCopy.copy({platform:action.slice(5),text:input.value,html:TexEditor.render(input.value),typography:VexTypography.state.key,compact:VexTypography.state.compact,toast:VexProto.toast}); break;
      case 'export-html': instant.finish(); refreshNow(); download('<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>' + escape(docs[state.doc].name) + '</title><style>body{max-width:780px;margin:50px auto;font:16px/1.9 system-ui;padding:0 24px;color:#242933;background:#fff}pre{padding:16px;background:#f4f5f7;overflow:auto}table{border-collapse:collapse}td,th{border:1px solid #ddd;padding:6px 12px}blockquote{border-left:3px solid #888;padding-left:16px;color:#666}' + VexTypography.exportStyles() + VexWatermark.exportStyles + '</style><body>' + $('markdown-preview').innerHTML + VexWatermark.exportMark() + '</body></html>', docs[state.doc].name.replace(/\.[^.]+$/, '') + '.html', 'text/html;charset=utf-8'); break;
      case 'export-pdf': instant.finish(); refreshNow(); VexWatermark.preview('PDF · ' + docs[state.doc].name,$('markdown-preview').innerHTML); break;
      case 'toggle-watermark': VexPreferences.set('watermarkPreview',!VexPreferences.values.watermarkPreview); break;
      case 'toggle-sidebar': state.sidebar = !state.sidebar; document.querySelector('.sidebar').classList.toggle('closed', !state.sidebar); if (!state.sidebar) sidebar.style.removeProperty('width'); $('sidebar-toggle').classList.toggle('on', state.sidebar); $('sidebar-toggle').setAttribute('aria-pressed', String(state.sidebar)); break;
      case 'pane-outline': { if (!state.sidebar) VexProto.handleAction('toggle-sidebar'); var structure = $('structure-sidebar'); structure.classList.remove('collapsed'); try { VexStorage.setItem('vex-design-structure', '1'); } catch (_) {} renderOutline(); break; }
      case 'pane-files': if (!state.sidebar) VexProto.handleAction('toggle-sidebar'); break;
      case 'map-source': state.source = !state.source; applySource(); break;
      case 'map-settings': var opened = !$('map-settings').hidden; if (state.view !== 'mindmap') setView('mindmap'); $('map-settings').hidden = opened; $('map-settings-button').setAttribute('aria-expanded', String(!opened)); $('node-inspector').hidden = true; break;
      case 'close-settings': $('map-settings').hidden = true; $('map-settings-button').setAttribute('aria-expanded', 'false'); break;
      case 'reset-settings': settings = { length: 30, paragraphs: true, lists: true, blocks: false, layout: 'right' }; syncSettings(); break;
      case 'map-collapse': if (state.collapsed.size) state.collapsed.clear(); else state.nodes.filter(function (node) { return !node.isRoot && visibleChildren(node).length; }).forEach(function (node) { state.collapsed.add(node.id); }); $('node-inspector').hidden = true; renderMap(); fit(); break;
      case 'map-fit': fit(); break;
      case 'zoom-in': zoom(1.2); break;
      case 'zoom-out': zoom(1 / 1.2); break;
      case 'close-inspector': state.selected = null; $('node-inspector').hidden = true; renderMap(); break;
      case 'locate-source': var node = state.nodes.find(function (node) { return node.id === state.selected; }); if (node) locate(node); break;
      case 'find': case 'replace': $('findbar').hidden = false; $('replace-input').hidden = action !== 'replace'; $('replace-all').hidden = action !== 'replace'; $('find-input').focus(); updateFind(); break;
      case 'close-find': $('findbar').hidden = true; break;
      case 'find-next': findNext(); break;
      case 'replace-all': var term = $('find-input').value; if (term) { input.value = input.value.split(term).join($('replace-input').value); input.dispatchEvent(new Event('input')); updateFind(); setView('edit'); } break;
      case 'toggle-lines': document.querySelector('.source-scroll').classList.toggle('no-lines'); break;
      case 'toggle-pairs': state.autoPair = !state.autoPair; break;
      case 'toggle-focus': state.focus = !state.focus; document.querySelector('.app-window').classList.toggle('focus-mode', state.focus); break;
      case 'toggle-typewriter': VexPreferences.set('typewriter', !state.typewriter); break;
      case 'toggle-motion': state.motion = !state.motion; document.documentElement.dataset.motion = String(state.motion); break;
      case 'presentation': startPresentation(); break;
      case 'presentation-larger': state.presentationScale = Math.min(2.5, +(state.presentationScale + .1).toFixed(1)); applyPresentation(); break;
      case 'presentation-smaller': state.presentationScale = Math.max(1, +(state.presentationScale - .1).toFixed(1)); applyPresentation(); break;
      case 'presentation-exit': stopPresentation(); break;
      case 'format-more': document.querySelector('.tb-menuitem[data-menu="格式(O)"]')?.click(); break;
      case 'typography': VexTypography.toggle(Array.from(document.querySelectorAll('[data-action="typography"]')).find(function(button){return button.getClientRects().length&&!button.hidden;})); break;
      case 'typography-select': VexTypography.choose(item.arg); break;
      case 'toggle-compact': VexTypography.toggleCompact(); break;
      case 'language': state.language = item.arg; VexL.set(item.arg); break;
      case 'toggle-word-count': VexPreferences.set('wordCountVisible', !VexPreferences.values.wordCountVisible); break;
      case 'maximize': document.querySelector('.app-window').classList.toggle('expanded'); break;
      case 'toggle-fullscreen': document.querySelector('.app-window').classList.toggle('expanded'); break;
      case 'toggle-topmost': state.topmost = !state.topmost; VexProto.toast(state.topmost ? '窗口置顶（桌面版操作演示）' : '取消置顶（桌面版操作演示）'); break;
      case 'minimize': VexProto.toast('最小化由桌面窗口提供（原型演示）'); break;
      case 'close': confirmSwitch(function () { VexProto.toast('文档已关闭（原型演示）'); }); break;
      case 'theme': document.querySelector('#vex-theme-panel button').focus(); break;
      case 'refresh': refreshNow(); break;
      case 'undo': case 'redo':
        instant.finish();
        var from = action === 'undo' ? state.undo : state.redo, to = action === 'undo' ? state.redo : state.undo;
        if (from.length) { to.push(input.value); input.value = from.pop(); input.dispatchEvent(new Event('input')); refreshNow(); }
        break;
      case 'copy': case 'copy-plain': case 'cut':
        var selected = input.value.slice(input.selectionStart, input.selectionEnd), copied = selected || input.value;
        if (action === 'copy-plain') copied = MM.plain(copied);
        navigator.clipboard.writeText(copied).then(function () { if (action === 'cut' && selected) insert('', false); VexProto.toast('已复制文本'); }).catch(function () { VexProto.toast('请在编辑区使用系统复制快捷键'); }); break;
      case 'paste': navigator.clipboard.readText().then(function (text) { insert(text); }).catch(function () { VexProto.toast('请在编辑区使用 Ctrl+V 粘贴'); }); break;
      case 'select-all': setEditMode('source'); input.focus(); input.select(); break;
      case 'clear-format': var selection = input.value.slice(input.selectionStart, input.selectionEnd); if (selection) insert(MM.plain(selection)); else VexProto.toast('先选择需要清除格式的文字'); break;
      case 'guide': if (window.VexGuide) VexGuide.start(); break;
      case 'print': VexProto.toast('桌面版提供打印预览（原型演示）'); break;
      default: return false;
    }
    return true;
  };
  VexProto.isSidebarVisible = function () { return state.sidebar; };
  // 原型的布局与章节操作共用此文档接口；正文仍只有一份。
  window.VexWorkbench = {
    get state() { return state; }, get settings() { return settings; },
    get text() { return input.value; }, get documents() { return docs; },
    get name() { return docs[state.doc].name; },
    finish: function () { instant.finish(); refreshNow(); },
    setView: setView, setEditMode: setEditMode, fit: fit, renderMap: renderMap,
    selectNode: selectNode, locate: locate, highlightSource: highlightSource,
    focusLine: function (line) {
      var node = state.nodes.find(function (candidate) { return candidate.line === line; });
      if (!node) return;
      if (state.editMode === 'instant') instant.focusAt(line); else highlightSource(node, true);
    },
    loadDocument: function (index) { confirmSwitch(function () { loadDoc(index); }); },
    applyText: function (text, options) {
      if (input.readOnly) return;
      options = options || {}; instant.finish();
      if (text === input.value) return;
      if (options.history !== false) remember(input.value);
      input.value = text; input.dispatchEvent(new Event('input')); refreshNow();
      if (options.line) {
        var node = state.nodes.find(function (candidate) { return candidate.kind === 'heading' && candidate.line === options.line; });
        if (node) selectNode(node);
      }
    },
    history: function (action) {
      if (input.readOnly) return;
      instant.finish(); var from = action === 'undo' ? state.undo : state.redo;
      var to = action === 'undo' ? state.redo : state.undo;
      if (!from.length) return;
      to.push(input.value); input.value = from.pop(); input.dispatchEvent(new Event('input')); refreshNow();
    },
    snapshot: function () { return { name: docs[state.doc].name, text: input.value, savedText: docs[state.doc].text, index: state.doc, dirty: state.dirty }; },
    receive: function (snapshot) {
      var changedDocument = docs[state.doc].name !== snapshot.name || state.remoteDocumentIndex !== snapshot.index;
      state.remoteDocumentIndex = snapshot.index;
      if (!changedDocument && input.value === snapshot.text) {
        docs[state.doc].text = snapshot.savedText; state.dirty = snapshot.dirty; updateMeta(); return;
      }
      instant.finish(); clearTimeout(state.pending);
      docs = [{ name: snapshot.name, text: snapshot.savedText }]; state.doc = 0;
      input.value = snapshot.text; state.dirty = snapshot.dirty;
      $('document-name').textContent = snapshot.name;
      if (changedDocument) {
        state.lastDoc = -1; state.collapsed.clear(); state.selected = null; state.undo = []; state.redo = [];
        input.setSelectionRange(0, 0);
        ['.source-scroll', '.reading-scroll', '.instant-scroll'].forEach(function (selector) { document.querySelector(selector).scrollTop = 0; });
      }
      renderFiles(); refreshNow();
      if (changedDocument) requestAnimationFrame(function () { fit(true); });
    }
  };
  // 引导演练使用临时文档；结束时还原进入前的内容、视图和显示偏好。
  VexProto.beginGuideSession = function () {
    instant.finish(); refreshNow(); closeLayers(); VexProto.closeMenu();
    var snapshot = {
      // Keep the complete in-memory workspace so the guide's temporary
      // document and any in-memory changes are fully restored on exit.
      documents: docs.map(function (doc) { return Object.assign({}, doc); }),
      workspaceFolder: workspaceFolder,
      doc: state.doc, text: input.value, dirty: state.dirty, view: state.view, editMode: state.editMode,
      sidebar: state.sidebar, focus: state.focus, source: state.source,

      fileFilter: $('file-filter').value,
      countHidden: $('sb-wordcount').hidden, findHidden: $('findbar').hidden,
      typography: Object.assign({}, VexTypography.state), settings: Object.assign({}, settings),
      undo: state.undo.slice(), redo: state.redo.slice(), selection: [input.selectionStart, input.selectionEnd],
      scrolls: ['.instant-scroll', '.reading-scroll', '.source-scroll'].map(function (selector) { return document.querySelector(selector).scrollTop; }),
      collapsed: new Set(state.collapsed), selected: state.selected, map: { x: state.x, y: state.y, scale: state.scale, visited: state.mapVisited },
      editPreference: VexStorage.getItem('vex-design-edit-method')
    };
    state.focus = false; document.querySelector('.app-window').classList.remove('focus-mode');
    $('sb-wordcount').hidden = false; $('findbar').hidden = true;
    if (!state.sidebar) VexProto.handleAction('toggle-sidebar');
    $('file-filter').value = ''; filterFiles();
    VexProto.handleAction('pane-files'); state.source = false; state.editMode = 'instant';
    settings = { length: 30, paragraphs: true, lists: true, blocks: false, layout: 'right' };
    snapshot.demo = { name: '一分钟上手 · 演练.md', text: '# 让一个想法，长成一篇文章\n\n我想把零散的想法写下来，再用结构把它们连成一条清晰的线索。先写内容，之后慢慢整理。\n\n## 写下想法\n\n点击这段文字试着修改，也可以用 **加粗** 标记重点。\n\n## 看清结构\n\n标题成为导图的主干，段落提供摘要。显示文字可以变短，完整内容一直保留。\n\n## 准备分享\n\n选择舒服的排版，确认保存状态，再把文章导出给读者。' };
    docs.push(snapshot.demo); loadDoc(docs.length - 1); syncSettings(); setView('edit');
    return snapshot;
  };
  VexProto.endGuideSession = function (snapshot) {
    state.guideRestoring = true; document.querySelector('.app-window').classList.add('guide-restoring');
    instant.finish(); VexProto.closeMenu(); closeLayers();
    docs = snapshot.documents.map(function (doc) { return Object.assign({}, doc); });
    workspaceFolder = snapshot.workspaceFolder;
    loadDoc(Math.max(0, Math.min(snapshot.doc, docs.length - 1))); input.value = snapshot.text; state.dirty = snapshot.dirty;
    $('file-filter').value = snapshot.fileFilter; filterFiles();
    state.editMode = snapshot.editMode; state.source = snapshot.source;
    state.focus = snapshot.focus; document.querySelector('.app-window').classList.toggle('focus-mode', snapshot.focus);
    if (state.sidebar !== snapshot.sidebar) VexProto.handleAction('toggle-sidebar');

    $('sb-wordcount').hidden = snapshot.countHidden; $('findbar').hidden = snapshot.findHidden;
    settings = snapshot.settings; syncSettings();
    VexTypography.state.compact = snapshot.typography.compact; VexTypography.choose(snapshot.typography.key);
    try { if (snapshot.editPreference === null) VexStorage.removeItem('vex-design-edit-method'); else VexStorage.setItem('vex-design-edit-method', snapshot.editPreference); } catch (_) {}
    refreshNow(); state.collapsed = snapshot.collapsed; state.undo = snapshot.undo; state.redo = snapshot.redo;
    state.mapVisited = snapshot.map.visited; setView(snapshot.view);
    $('typography-panel').hidden = true; $('node-inspector').hidden = true;
    requestAnimationFrame(function () {
      state.x = snapshot.map.x; state.y = snapshot.map.y; state.scale = snapshot.map.scale; renderMap();
      lastCanvasSize = { width: canvas.clientWidth, height: canvas.clientHeight }; transform();
      input.setSelectionRange(snapshot.selection[0], snapshot.selection[1]); updateCursor();
      ['.instant-scroll', '.reading-scroll', '.source-scroll'].forEach(function (selector, scrollIndex) { document.querySelector(selector).scrollTop = snapshot.scrolls[scrollIndex]; });
      requestAnimationFrame(function () {
        lastCanvasSize = { width: canvas.clientWidth, height: canvas.clientHeight };
        state.guideRestoring = false; document.querySelector('.app-window').classList.remove('guide-restoring');
      });
    });
  };
  VexProto.arrangeGuideMap = function () {
    if (state.view !== 'mindmap') return;
    var element = document.querySelector('.map-node[data-kind="paragraph"]');
    var panel = !$('map-settings').hidden ? $('map-settings') : !$('node-inspector').hidden ? $('node-inspector') : null;
    if (!element || !panel) return;
    var rect = element.getBoundingClientRect(), popover = panel.getBoundingClientRect(), bounds = canvas.getBoundingClientRect();
    var desired = Math.max(bounds.left + 20, popover.left - rect.width - 36);
    if (Math.abs(desired - rect.left) > 1) { state.x += desired - rect.left; transform(); }
  };
  VexProto.isActionChecked = function (action, item) {
    var checks = {
      'edit-instant': state.editMode === 'instant', 'edit-source': state.editMode === 'source',
      'toggle-pairs': state.autoPair, 'toggle-focus': state.focus,
      'toggle-typewriter': state.typewriter, 'toggle-motion': state.motion, 'toggle-topmost': state.topmost,
      'toggle-fullscreen': document.querySelector('.app-window').classList.contains('expanded'),
      'toggle-compact': VexTypography.state.compact, 'typography-select': !!item && VexTypography.state.key === item.arg,
      'toggle-watermark': VexPreferences.values.watermarkPreview,
      'language': !!item && state.language === item.arg
    };
    if (Object.prototype.hasOwnProperty.call(checks, action)) return checks[action];
    return action.startsWith('view-') ? state.view === action.slice(5) : action === 'toggle-sidebar' ? state.sidebar
      : action === 'toggle-lines' ? !document.querySelector('.source-scroll').classList.contains('no-lines')
      : action === 'toggle-word-count' ? !$('sb-wordcount').hidden : false;
  };
  document.addEventListener('click', function (event) {
    var button = event.target.closest('[data-action]'); if (button) { event.stopPropagation(); VexProto.handleAction(button.dataset.action); }
    else if (!$('map-settings').contains(event.target)) { $('map-settings').hidden = true; $('map-settings-button').setAttribute('aria-expanded', 'false'); }
  });
  document.addEventListener('click', function (event) {
    var link = event.target.closest('#markdown-preview a[href^="#"]');
    if (!link) return;
    var href = link.getAttribute('href') || '', target = document.getElementById(href.slice(1));
    if (!target) return;
    event.preventDefault();
    target.scrollIntoView({ block: 'start', behavior: reducedMotion() ? 'auto' : 'smooth' });
    target.classList.remove('located'); void target.offsetWidth; target.classList.add('located');
  });
  document.querySelectorAll('.win-layer').forEach(function (layer) {
    layer.onclick = function (event) { if (event.target === layer) { closeLayers(); pendingSwitch = null; } };
    layer.querySelectorAll('[data-close]').forEach(function (button) {
      button.onclick = function () {
        if (layer.id === 'layer-delete' && button.classList.contains('danger')) {
          closeLayers(); docs.splice(state.doc, 1);
          if (!docs.length) docs.push({ name: '未命名文档.md', text: '' });
          state.lastDoc = -1; state.lastText = null; state.dirty = false; loadDoc(Math.min(state.doc, docs.length - 1)); return;
        }
        if (layer.id === 'layer-unsaved' && pendingSwitch) {
          var next = pendingSwitch; pendingSwitch = null;
          if (button.classList.contains('caption-btn') || button.textContent.trim() === '取消') { closeLayers(); return; }
          if (button.textContent.trim() === '保存') save();
          closeLayers(); next(); return;
        }
        closeLayers(); if (button.dataset.close) VexProto.toast(button.dataset.close);
      };
    });
  });
  // 保留对话框的可点击演示。
  if ($('err-toggle')) $('err-toggle').onclick = function () { $('err-detail').style.display = $('err-detail').style.display === 'none' ? '' : 'none'; };
  ['mcp-copy-token', 'mcp-copy-endpoint'].forEach(function (id) { if ($(id)) $(id).onclick = function () { navigator.clipboard.writeText(id.endsWith('token') ? $('mcp-token').value : $('mcp-endpoint') ? $('mcp-endpoint').textContent : 'http://127.0.0.1:17891/mcp/').catch(function () { VexProto.toast('请手动复制'); }); }; });
  if ($('mcp-switch')) $('mcp-switch').onclick = function () { this.classList.toggle('on'); $('mcp-form').style.opacity = this.classList.contains('on') ? '' : '.45'; $('mcp-status-text').textContent = this.classList.contains('on') ? '服务运行中（演示）' : '服务已停止（演示）'; };
  if ($('mcp-save')) $('mcp-save').onclick = function () { closeLayers(); VexProto.toast('MCP 设置已保存（演示）'); };
  if ($('mcp-gen')) $('mcp-gen').onclick = function () { $('mcp-token').value = 'vx_' + crypto.randomUUID().replace(/-/g, ''); };
  document.addEventListener('keydown', function (event) {
    if (event.key === 'F5' && !event.isComposing) { event.preventDefault(); startPresentation(); return; }
    if (event.key === 'Escape') { if (state.presentation) { stopPresentation(); return; } closeLayers(); pendingSwitch = null; $('findbar').hidden = true; $('node-inspector').hidden = true; $('map-settings').hidden = true; $('map-settings-button').setAttribute('aria-expanded', 'false'); }
    if ((event.ctrlKey || event.metaKey) && ['s', 'f', 'h', 'o', 'n', 'w', 'p'].includes(event.key.toLowerCase())) {
      event.preventDefault(); VexProto.handleAction(event.key.toLowerCase() === 'p' ? (event.shiftKey ? 'print' : 'quick-open') : event.key.toLowerCase() === 'n' && event.shiftKey ? 'new-window' : { s: 'save', f: 'find', h: 'replace', o: 'open', n: 'new', w: 'close' }[event.key.toLowerCase()]);
    }
    if (event.key === 'F5') { event.preventDefault(); refreshNow(); }
    if (event.key === 'F8') { event.preventDefault(); VexProto.handleAction('toggle-focus'); }
    if (event.key === 'F11') { event.preventDefault(); VexProto.handleAction('toggle-fullscreen'); }
    if (event.altKey && event.key === 'Enter') { event.preventDefault(); VexProto.handleAction('dlg-properties'); }
    if (!event.ctrlKey && !event.metaKey && event.key === '/' && !event.target.closest('input, textarea, [contenteditable="true"]')) { event.preventDefault(); if (!state.sidebar) VexProto.handleAction('toggle-sidebar'); VexProto.handleAction('pane-files'); $('file-filter').focus(); }
  });
  VexProto.attachMenuBar(document.querySelector('.tb-menu'));
  var closedWindow = document.createElement('section');closedWindow.className='prototype-window-closed';closedWindow.hidden=true;
  closedWindow.innerHTML='<img src="assets/vex-logo.svg" alt=""><h2>窗口已关闭</h2><button class="btn primary">重新打开</button>';
  document.querySelector('.window-body').appendChild(closedWindow);
  var exitGuard = VexExitDialog.create({
    parent:document.querySelector('.window-body'),
    beforeOpen:function(){instant.finish();refreshNow();closeLayers();VexProto.closeMenu();VexTypography.close();window.VexWorkspace?.closeAppearance();},
    documents:function(){return docs.map(function(doc,index){return {index:index,name:doc.name,path:doc.path,text:index===state.doc?input.value:doc.pendingText??doc.text,savedText:doc.text};}).filter(function(doc){return doc.text!==doc.savedText;});},
    edit:function(doc){docs[state.doc].pendingText=input.value;if(doc.index!==state.doc)loadDoc(doc.index);if(window.VexWorkspace)VexWorkspace.setLayout('instant');else setView('edit');},
    save:function(changed){changed.forEach(function(doc){download(doc.text,doc.name);docs[doc.index].text=doc.text;delete docs[doc.index].pendingText;});state.dirty=false;VexStorage.removeItem('vex-design-exit-drafts');refreshNow();},
    keepDrafts:function(changed){var value=JSON.stringify(changed);VexStorage.setItem('vex-design-exit-drafts',value);if(VexStorage.getItem('vex-design-exit-drafts')!==value)throw new Error('Draft storage unavailable');},
    discard:function(changed){changed.forEach(function(doc){delete docs[doc.index].pendingText;});input.value=docs[state.doc].text;state.dirty=false;VexStorage.removeItem('vex-design-exit-drafts');refreshNow();},
    close:function(){closedWindow.hidden=false;closedWindow.querySelector('button').focus({preventScroll:true});}
  });
  closedWindow.querySelector('button').onclick=function(){
    closedWindow.hidden=true;
    var stored=VexStorage.getItem('vex-design-exit-drafts');
    if(stored){try{var recovered=JSON.parse(stored);recovered.forEach(function(doc){if(docs[doc.index])docs[doc.index].pendingText=doc.text;});input.value=docs[state.doc].pendingText??docs[state.doc].text;state.dirty=input.value!==docs[state.doc].text;refreshNow();VexProto.toast('恢复草稿已载入');}catch(_){VexProto.toast('草稿无法读取，请保留浏览器数据并重试');}}
  };
  VexProto.previewUnsavedExit=function(){
    docs=[{name:'产品构想.md',path:'写作手记 / 产品构想.md',text:'# 产品构想\n',pendingText:'# 产品构想\n\n让写作更轻松。\n'},{name:'一篇文章的诞生.md',path:'写作手记 / 一篇文章的诞生.md',text:'# 一篇文章的诞生\n',pendingText:'# 一篇文章的诞生\n\n记住这次灵感。\n'}];
    loadDoc(0);input.value=docs[0].pendingText;state.dirty=true;refreshNow();exitGuard.open();
  };
  syncSettings(); loadDoc(0); setView(new URLSearchParams(location.search).get('view') || 'edit');
  VexPreferences.configure({
    beforeOpen:function () { VexProto.closeMenu(); closeLayers(); instant.finish(); },
    currentAppearance:function () { return {theme:VexTheme.state.mode,palette:VexTheme.state.palette,typography:VexTypography.state.key,compact:VexTypography.state.compact}; },
    toast:VexProto.toast, getText:function () { return input.value; },
    replaceText:function (text) { if (input.readOnly) return; remember(input.value); input.value = text; input.dispatchEvent(new Event('input')); refreshNow(); },
    apply:function (key,value,all) {
      if (key === 'theme') VexTheme.setMode(value);
      if (key === 'palette') VexTheme.setPalette(value);
      if (key === 'typography') VexTypography.choose(value);
      if (key === 'compact' && VexTypography.state.compact !== value) VexTypography.toggleCompact();
      if (key === 'language') VexL.set(value);
      if (key === 'size') document.documentElement.style.setProperty('--vex-writing-size',value + 'px');
      if (key === 'font') document.documentElement.dataset.writingFont = value;
      if (key === 'zoom') document.documentElement.style.setProperty('--vex-content-zoom',value / 100);
      if (key === 'lineNumbers') document.querySelector('.source-scroll').classList.toggle('no-lines',!value);
      if (key === 'wordCountVisible') $('sb-wordcount').hidden = !value;
      if (key === 'autoPair') state.autoPair = value;
      if (key === 'typewriter') { state.typewriter = value; typewriter.refresh(); }
      if (key === 'focus') { state.focus = value; document.querySelector('.app-window').classList.toggle('focus-mode',value); }
      if (['math','chemistry','mermaid','highlight','subscript','softBreak'].includes(key)) { state.lastText = null; cancelAnimationFrame(state.prefRefresh); state.prefRefresh = requestAnimationFrame(refreshNow); }
    }
  });
  if (builtin || launched) document.title = docs[0].name + ' · 维刻 Vex';
  function platformShortcutLabels() {
    if (document.body.dataset.platform !== 'macos') return;
    document.querySelectorAll('[title],[aria-label]').forEach(function (element) {
      ['title','aria-label'].forEach(function (attribute) { var value = element.getAttribute(attribute); if (value && value.includes('Ctrl')) element.setAttribute(attribute,value.replace(/Ctrl\+/g,'⌘').replace(/Ctrl/g,'⌘')); });
    });
  }
  var elementMenu = VexElementMenu.mount({
    source:input, roots:[{element:$('instant-content')},{element:$('markdown-preview'),readOnly:true}],
    getText:function () { return input.value; }, getIdentity:function () { return state.doc + ':' + docs[state.doc].name; },
    blocks:function () { return state.parsed.blocks; }, readOnly:function () { return input.readOnly; }, touch:function () { return false; },
    finish:function () { instant.finish(); }, applyText:function (text) { VexWorkbench.applyText(text); },
    beforeOpen:function () { VexProto.closeMenu(); }, toast:VexProto.toast,
    entries:[document.getElementById('edit-options'),document.querySelector('#reading-pane .ph-right')],
    findBlock:function (line) { return Array.from($('instant-content').children).find(function (el) { return state.parsed.blocks[Number(el.dataset.blockIndex)]?.line === line; }); },
    focus:function (line,sourceActive) { if(sourceActive)input.focus({preventScroll:true}); else document.querySelector('#instant-content [data-line="' + line + '"]')?.closest('.instant-block')?.focus({preventScroll:true}); },
    editSource:function (line) { VexWorkspace.locateEditor(line); }
  });
  var launchIntent = new URLSearchParams(location.search).get('intent');
  if (launchIntent === 'open-file' || launchIntent === 'open-folder') {
    setTimeout(function () {
      var picker = $(launchIntent === 'open-file' ? 'open-file-input' : 'open-folder-input');
      if (picker) picker.click();
    }, 320);
  }
  platformShortcutLabels(); window.addEventListener('vex-language-changed',platformShortcutLabels);
})();
