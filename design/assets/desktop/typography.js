/* Reading structures shared with mobile; compact spacing is independent. */
(function () {
  'use strict';
  var items = VexTypes;
  var state = { key: 'Simple', compact: false };
  try {
    var saved = JSON.parse(VexStorage.getItem('vex-design-typography') || '{}');
    if (items.some(function (item) { return item.key === VexTypeKey(saved.key); })) state.key = VexTypeKey(saved.key);
    if (typeof saved.compact === 'boolean') state.compact = saved.compact;
  } catch (_) {}
  var requested = new URLSearchParams(location.search).get('typography');requested=VexTypeKey(requested);
  if (items.some(function (item) { return item.key === requested; })) state.key = requested;
  var panel = document.createElement('section'); panel.id = 'typography-panel'; panel.className = 'typography-popover'; panel.hidden = true;
  panel.setAttribute('aria-label', '正文排版'); panel.setAttribute('role', 'dialog');
  panel.innerHTML = '<div class="popover-title">正文排版<button class="icon-button" id="typography-close" aria-label="关闭排版"><svg class="ico" aria-hidden="true"><use href="#i-x"/></svg></button></div><div class="typography-workspace"><div class="typography-grid" role="group" aria-label="排版样式">' + items.map(function (item) {
    return '<button class="typography-card" data-typography-key="' + item.key + '"><strong>' + item.label + '</strong><span>' + item.en + '</span></button>';
  }).join('') + '</div><div class="typography-reading" tabindex="0" role="region" aria-label="文章排版效果预览">' + VexTypePreview(state.key, true) + '</div></div><label class="typography-compact">紧凑布局<input type="checkbox" id="typography-compact"></label>';
  document.querySelector('.window-body').appendChild(panel);
  var previewSource = document.createElement('div'); previewSource.className = 'typography-preview-source';
  previewSource.innerHTML = '<label>预览内容 <select id="typography-preview-source"><option value="current">当前文章</option><option value="sample">示例文章</option></select></label><span>排版影响正文与 HTML 副本，不改变 Markdown 内容。</span>';
  panel.querySelector('.popover-title').after(previewSource);
  function renderCurrentPreview() {
    var reading = panel.querySelector('.typography-reading'), scroll = reading.scrollTop;
    reading.innerHTML = VexTypePreview(state.key, true);
    if (document.getElementById('typography-preview-source').value === 'current' && window.VexWorkbench) {
      var previewArticle = reading.querySelector('.type-document');
      previewArticle.innerHTML = VexWorkbench.text.trim() ? TexEditor.render(VexWorkbench.text) : '<p>当前文章还是空白。写下一段内容后，可在这里比较排版。</p>';
      previewArticle.querySelectorAll('[id]').forEach(function (element) { element.removeAttribute('id'); });
    }
    reading.scrollTop = scroll;
  }
  document.getElementById('typography-preview-source').onchange = renderCurrentPreview;
  panel.querySelector('.typography-reading').addEventListener('click', function (event) { if (event.target.closest('a')) event.preventDefault(); });
  function apply() {
    var theme = items.find(function (item) { return item.key === state.key; }), root = document.documentElement;
    root.dataset.typography = theme.key; root.dataset.typographyVariant = theme.variant; root.dataset.compact = String(state.compact);
    root.style.setProperty('--typography-accent', 'var(--accent)');
    panel.querySelector('[data-preview-type]').dataset.previewType = state.key;
    document.querySelectorAll('[data-typography-label]').forEach(function (label) { label.textContent = theme.label; });
    panel.querySelectorAll('[data-typography-key]').forEach(function (button) {
      button.setAttribute('aria-pressed', String(button.dataset.typographyKey === state.key));
    });
    document.getElementById('typography-compact').checked = state.compact;
    try { VexStorage.setItem('vex-design-typography', JSON.stringify(state)); } catch (_) {}
  }
  panel.querySelector('.typography-grid').onclick = function (event) {
    var button = event.target.closest('[data-typography-key]'); if (button) choose(button.dataset.typographyKey);
  };
  var trigger;
  function close(restoreFocus) { var wasOpen = !panel.hidden; panel.hidden = true; document.querySelectorAll('[data-action="typography"]').forEach(function (button) { button.setAttribute('aria-expanded', 'false'); }); if (restoreFocus && wasOpen && trigger) trigger.focus({preventScroll:true}); }
  document.getElementById('typography-close').onclick = function () { close(true); };
  document.getElementById('typography-compact').onchange = function () { state.compact = this.checked; apply(); };
  function choose(key) { key=VexTypeKey(key);if (items.some(function (item) { return item.key === key; })) { state.key = key; apply(); } }
  document.addEventListener('click', function (event) {
    if (!panel.contains(event.target) && !event.target.closest('[data-action="typography"]') && !event.target.closest('.menu-flyout')) close();
  });
  document.addEventListener('keydown', function (event) { if (event.key === 'Escape') close(true); });
  document.addEventListener('vex-layout-rendered', function () { if (!document.querySelector('[data-action="typography"]:not([hidden])')) close(); });
  window.VexTypography = {
    items: items, state: state, apply: apply, choose: choose,
    toggleCompact: function () { state.compact = !state.compact; apply(); },
    close: close,
    toggle: function (anchor) {
      if (!panel.hidden) { close(); return; }
      panel.hidden = false;
      renderCurrentPreview();
      trigger = anchor || document.querySelector('[data-action="typography"]');
      var host = panel.parentElement.getBoundingClientRect(), rect = trigger.getBoundingClientRect();
      var below=host.bottom-rect.bottom-16,above=rect.top-host.top-16,flip=below<320&&above>below;
      panel.style.maxHeight=Math.max(180,flip?above:below)+'px';
      panel.style.left = Math.max(8,Math.min(host.width-panel.offsetWidth-8,rect.right-host.left-panel.offsetWidth))+'px';panel.style.right='auto';
      panel.style.top=(flip?Math.max(8,rect.top-host.top-panel.offsetHeight-8):Math.max(8,rect.bottom-host.top+8))+'px';
      document.querySelectorAll('[data-action="typography"]').forEach(function (button) { button.setAttribute('aria-expanded', 'true'); });
    },
    exportStyles: function () { return VexTypeExport(state.key,state.compact); }
  };
  apply();
})();
