/* Vex 工作区的单窗口变体：固定视图组合，所有面板共用当前文档。 */
(function () {
  'use strict';
  var W = window.VexWorkbench, $ = function (id) { return document.getElementById(id); };
  var query = new URLSearchParams(location.search), current = 'instant', editorMode = W.state.editMode, tree, changing = false, guideActive = false;
  var panels = {}, area = document.querySelector('.content-area');
  var labels = { editor: '编辑', render: '阅读', map: '思维导图' }, icons = { editor: 'edit', render: 'eye', map: 'map' };
  var presets = [
    { id: 'instant', title: '即时编辑', note: '专注连续写作', mode: 'instant', tree: 'editor' },
    { id: 'source', title: '源码', note: '精确编辑 Markdown', mode: 'source', tree: 'editor' },
    { id: 'read', title: '阅读', note: '查看完整正文', tree: 'render' },
    { id: 'map', title: '思维导图', note: '先梳理章节结构', tree: 'map' },
    { id: 'source-render', title: '源码 + 渲染', note: '边写边检查排版', mode: 'source', tree: ['horizontal', 'editor', 'render'] },
    { id: 'source-map', title: '源码 + 导图', note: '用 Markdown 搭建结构', mode: 'source', tree: ['horizontal', 'editor', 'map'] },
    { id: 'instant-map', title: '即时编辑 + 导图', note: '写正文，也看全局', mode: 'instant', tree: ['horizontal', 'editor', 'map'] },
    { id: 'three', title: '源码 + 渲染 + 导图', note: '上方写作，下方梳理结构', mode: 'source', tree: ['vertical', ['horizontal', 'editor', 'render'], 'map'] }
  ];
  function icon(name) { return '<svg class="ico" aria-hidden="true"><use href="#i-' + name + '"/></svg>'; }
  function clone(value) { return JSON.parse(JSON.stringify(value)); }
  function leaves(node) { return typeof node === 'string' ? [node] : leaves(node[1]).concat(leaves(node[2])); }
  function saveLayout() { if (!guideActive && !W.state.guideRestoring) VexStorage.setItem('vex-design-layout', JSON.stringify({ current: current, mode: editorMode })); }
  function makePanel(id, sections) {
    var panel = document.createElement('section'); panel.className = 'view-panel'; panel.dataset.document = id; panel.setAttribute('aria-label', labels[id]);
    var head = document.createElement('div'); head.className = 'view-heading';
    head.innerHTML = '<span class="view-caption">' + icon(icons[id]) + '<span class="view-title"></span></span>';
    var body = document.createElement('div'); body.className = 'view-body';
    sections.forEach(function (section) { body.appendChild($(section)); });
    panel.append(head, body); panels[id] = panel; area.appendChild(panel);
  }
  makePanel('editor', ['source-pane', 'instant-pane']); makePanel('render', ['reading-pane']); makePanel('map', ['map-pane']);
  var parking = document.createElement('div'); parking.hidden = true; parking.id = 'view-parking'; area.appendChild(parking);
  var surface = document.createElement('div'); surface.className = 'view-surface'; surface.id = 'view-surface'; area.appendChild(surface);
  var workbar = document.querySelector('.workbar'), actions = document.querySelector('.work-actions');
  var layoutButton = document.createElement('button'); layoutButton.className = 'workspace-layout-button'; layoutButton.id = 'workspace-layout';
  layoutButton.setAttribute('aria-haspopup', 'dialog'); layoutButton.setAttribute('aria-expanded', 'false');
  layoutButton.innerHTML = icon('columns') + '<span>布局</span>' + icon('chevron-down');
  layoutButton.lastElementChild.classList.add('vex-expand-icon','layout-chevron'); workbar.insertBefore(layoutButton, actions);
  var layoutMenu = document.createElement('section'); layoutMenu.className = 'workspace-layout-menu'; layoutMenu.id = 'workspace-layout-menu'; layoutMenu.hidden = true;
  layoutMenu.setAttribute('role', 'dialog'); layoutMenu.setAttribute('aria-label', '工作区布局');
  layoutMenu.innerHTML = '<div class="workspace-menu-heading"><strong>视图组合</strong><button class="icon-button" aria-label="关闭布局菜单">' + icon('x') + '</button></div><p>当前只打开一份文档，切换文件时所有视图一起更新。</p><div class="layout-preset-grid"></div><div class="workspace-layout-footer"><span>点击试选，连续比较布局</span><button id="reset-workspace">默认视图</button></div>';
  document.querySelector('.window-body').appendChild(layoutMenu);
  function miniature(node) { return typeof node === 'string' ? '<i class="mini-pane mini-' + node + '"></i>' : '<span class="mini-split mini-' + node[0] + '">' + miniature(node[1]) + miniature(node[2]) + '</span>'; }
  presets.forEach(function (preset) { var button = document.createElement('button'); button.className = 'layout-preset'; button.dataset.layout = preset.id; button.innerHTML = '<span class="layout-miniature">' + miniature(preset.tree) + '</span><strong>' + preset.title + '</strong><small>' + preset.note + '</small><span class="preset-check">✓</span>'; button.onclick = function () { setLayout(preset.id); }; layoutMenu.querySelector('.layout-preset-grid').appendChild(button); });
  function closeMenus() { layoutMenu.hidden = true; layoutButton.setAttribute('aria-expanded', 'false'); }
  layoutButton.onclick = function () { var show = layoutMenu.hidden; closeMenus(); layoutMenu.hidden = !show; layoutButton.setAttribute('aria-expanded', String(show)); if (show) layoutMenu.querySelector('[data-layout="' + current + '"]').focus(); };
  layoutMenu.querySelector('.workspace-menu-heading button').onclick = closeMenus;
  $('reset-workspace').onclick = function () { setLayout('instant'); };
  function build(node) { if (typeof node === 'string') return panels[node]; var split = document.createElement('div'); split.className = 'view-split view-' + node[0]; split.append(build(node[1]), build(node[2])); return split; }
  function renderLayout() {
    var source = editorMode === 'source', displayed = leaves(tree);
    Object.values(panels).forEach(function (panel) { panel.style.flex = ''; parking.appendChild(panel); }); surface.replaceChildren(build(tree));
    $('source-pane').hidden = !source || !displayed.includes('editor'); $('instant-pane').hidden = source || !displayed.includes('editor');
    $('reading-pane').hidden = !displayed.includes('render'); $('map-pane').hidden = !displayed.includes('map');
    panels.editor.querySelector('.view-title').textContent = source ? '源码' : '即时编辑'; panels.render.querySelector('.view-title').textContent = '阅读'; panels.map.querySelector('.view-title').textContent = '思维导图';
    surface.dataset.single = String(displayed.length === 1); $('edit-options').hidden = !displayed.includes('editor');
    W.state.source = displayed.includes('editor') && source; $('map-source-toggle').setAttribute('aria-pressed', String(W.state.source)); $('map-source-toggle').classList.toggle('on', W.state.source);
    document.querySelector('.workspace').classList.toggle('source-only', source && displayed.length === 1); area.dataset.paneCount = displayed.length;
    $('edit-source').setAttribute('aria-pressed', String(source && displayed.includes('editor')));
    var single = displayed.length === 1 ? displayed[0] : null, quickView = single === 'editor' ? 'edit' : single === 'render' ? 'read' : single === 'map' ? 'mindmap' : 'custom';
    var quickSwitch = document.querySelector('.view-switch'); quickSwitch.dataset.active = quickView;
    quickSwitch.querySelectorAll('button').forEach(function (button) { button.setAttribute('aria-selected', String(button.dataset.view === quickView)); button.title = '单独打开' + button.textContent.trim() + '视图'; button.tabIndex = button.dataset.view === quickView || quickView === 'custom' && button.dataset.view === 'edit' ? 0 : -1; });
    layoutMenu.querySelectorAll('[data-layout]').forEach(function (button) { button.setAttribute('aria-pressed', String(button.dataset.layout === current)); });
    document.dispatchEvent(new CustomEvent('vex-layout-rendered'));
  }
  function setLayout(id) {
    if (id === 'source-read') id = 'source-render';
    var preset = presets.find(function (entry) { return entry.id === id; }); if (!preset) return;
    W.finish(); current = id; tree = clone(preset.tree); if (preset.mode) editorMode = preset.mode;
    var wanted = leaves(tree); changing = true;
    if (wanted.includes('editor')) W.setEditMode(editorMode); else W.setView(wanted.includes('map') ? 'mindmap' : 'read');
    changing = false; renderLayout(); saveLayout(); if (wanted.includes('map')) requestAnimationFrame(function () { W.fit(current !== 'three'); });
  }
  function openPanel(id) { if (leaves(tree).includes(id)) return; var wanted = new Set(leaves(tree).concat(id)); setLayout(wanted.size === 3 ? 'three' : wanted.has('map') ? (editorMode === 'source' ? 'source-map' : 'instant-map') : 'source-render'); }
  function switchEditorMode(mode) { var hasMap = leaves(tree).includes('map'), hasRender = leaves(tree).includes('render'); setLayout(mode === 'instant' ? hasMap ? 'instant-map' : 'instant' : hasMap ? hasRender ? 'three' : 'source-map' : hasRender ? 'source-render' : 'source'); }
  function locateEditor(line) { editorMode = 'source'; changing = true; W.setEditMode('source'); changing = false; openPanel('editor'); renderLayout(); saveLayout(); W.focusLine(line); }
  function navigate(line) { if (leaves(tree).includes('editor')) W.focusLine(line); else if (leaves(tree).includes('render')) $('markdown-preview').querySelector('[data-line="' + line + '"]')?.scrollIntoView({ block: 'start', behavior: 'smooth' }); }
  function handleAction(action) {
    if (action === 'undo' || action === 'redo') { W.history(action); return true; }
    if (action === 'map-source') { setLayout(leaves(tree).includes('editor') ? 'map' : 'source-map'); return true; }
    if (action === 'locate-source') { var node = W.state.nodes.find(function (candidate) { return candidate.id === W.state.selected; }); if (node) locateEditor(node.line); return true; }
    if (action === 'map-settings' && !$('map-pane').hidden) { var open = !$('map-settings').hidden; $('map-settings').hidden = open; $('map-settings-button').setAttribute('aria-expanded', String(!open)); $('node-inspector').hidden = true; return true; }
    return false;
  }
  window.VexWorkspace = { setLayout: setLayout, openPanel: openPanel, handleAction: handleAction, locateEditor: locateEditor, navigate: navigate, get current() { return current; }, get tree() { return clone(tree); }, get editorMode() { return editorMode; } };
  window.addEventListener('vex-view-changed', function (event) { if (changing) return; var view = event.detail.view, mode = event.detail.editMode; if (view === 'edit' && mode !== editorMode && leaves(tree).includes('editor')) switchEditorMode(mode); else setLayout(view === 'edit' ? mode : view === 'read' ? 'read' : 'map'); });
  document.addEventListener('keydown', function (event) { if (event.key === 'Escape') closeMenus(); if (event.isComposing || !(event.ctrlKey || event.metaKey) || !['z', 'y'].includes(event.key.toLowerCase())) return; var field = event.target.closest('input, textarea, [contenteditable="true"]'); if (field && field.id !== 'markdown-input' && !field.classList.contains('instant-block')) return; event.preventDefault(); W.finish(); handleAction(event.key.toLowerCase() === 'y' || event.shiftKey ? 'redo' : 'undo'); });
  document.addEventListener('pointerdown', function (event) { if (!layoutMenu.contains(event.target) && !layoutButton.contains(event.target)) closeMenus(); });
  var beginGuide = VexProto.beginGuideSession, endGuide = VexProto.endGuideSession;
  VexProto.beginGuideSession = function () { var layout = { current: current, tree: clone(tree), mode: editorMode }; guideActive = true; var result = beginGuide(); result.workspace = layout; return result; };
  VexProto.endGuideSession = function (snapshot) { endGuide(snapshot); if (snapshot?.workspace) { editorMode = snapshot.workspace.mode; tree = snapshot.workspace.tree; current = snapshot.workspace.current; renderLayout(); } guideActive = false; requestAnimationFrame(function () { requestAnimationFrame(saveLayout); }); };
  var savedLayout; try { savedLayout = JSON.parse(VexStorage.getItem('vex-design-layout') || 'null'); } catch (_) {}
  var requested = query.get('layout'); if (requested === 'source-read') requested = 'source-render';
  if (requested && presets.some(function (preset) { return preset.id === requested; })) setLayout(requested);
  else if (query.has('view') || query.has('edit')) setLayout(W.state.view === 'mindmap' ? 'map' : W.state.view === 'read' ? 'read' : W.state.editMode);
  else if (savedLayout && presets.some(function (preset) { return preset.id === savedLayout.current; })) setLayout(savedLayout.current);
  else setLayout(editorMode);
})();
