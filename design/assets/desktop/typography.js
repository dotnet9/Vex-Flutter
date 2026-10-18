/* Six reading structures shared with mobile; compact spacing is independent. */
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
  panel.setAttribute('aria-label', 'Markdown 排版主题');
  panel.innerHTML = '<div class="popover-title">Markdown 排版<button class="icon-button" id="typography-close" aria-label="关闭排版主题">×</button></div><p class="typography-note">六种阅读结构 · 与界面配色分别设置</p><div class="typography-grid">' + items.map(function (item) {
    return '<button class="typography-card" data-typography-key="' + item.key + '">' + VexTypePreview(item.key) + '<strong>' + item.label + '</strong></button>';
  }).join('') + '</div><label class="typography-compact">紧凑布局<input type="checkbox" id="typography-compact"></label>';
  document.querySelector('.window-body').appendChild(panel);
  function apply() {
    var theme = items.find(function (item) { return item.key === state.key; }), root = document.documentElement;
    root.dataset.typography = theme.key; root.dataset.typographyVariant = theme.variant; root.dataset.compact = String(state.compact);
    root.style.setProperty('--typography-accent', root.dataset.theme === 'dark' ? theme.dark : theme.light);
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
  document.getElementById('typography-close').onclick = function () { panel.hidden = true; };
  document.getElementById('typography-compact').onchange = function () { state.compact = this.checked; apply(); };
  function choose(key) { key=VexTypeKey(key);if (items.some(function (item) { return item.key === key; })) { state.key = key; apply(); } }
  document.addEventListener('click', function (event) {
    if (!panel.contains(event.target) && !event.target.closest('[data-action="typography"]') && !event.target.closest('.menu-flyout')) panel.hidden = true;
  });
  document.addEventListener('keydown', function (event) { if (event.key === 'Escape') panel.hidden = true; });
  new MutationObserver(apply).observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
  window.VexTypography = {
    items: items, state: state, apply: apply, choose: choose,
    toggleCompact: function () { state.compact = !state.compact; apply(); },
    toggle: function () { panel.hidden = !panel.hidden; },
    exportStyles: function () { return VexTypeExport(state.key,state.compact); }
  };
  apply();
})();
