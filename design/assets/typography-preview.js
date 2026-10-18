/* Use the same document rules for miniature previews and exported pages. */
(function () {
  'use strict';
  var style = document.createElement('style');
  style.textContent = VexTypes.map(function (item) {
    var scope = '.type-swatch[data-preview-type="' + item.key + '"] .type-document';
    var live = ['.content-area .md-body', '.markdown-body'].map(function (selector) {
      var target = ':root[data-typography="' + item.key + '"] ' + selector;
      return VexTypeRules(item.key, false).replaceAll('BODY', target) +
        VexTypeRules(item.key, true).replaceAll('BODY', ':root[data-compact="true"][data-typography="' + item.key + '"] ' + selector);
    }).join('\n');
    return live + VexTypeRules(item.key, false).replaceAll('BODY', scope) +
      scope + '{--typography-accent:' + item.light + '}' +
      ':root[data-theme=dark] ' + scope + '{--typography-accent:' + item.dark + '}';
  }).join('\n');
  document.head.appendChild(style);
  window.VexTypePreview = function (key) {
    return '<span class="type-swatch" data-preview-type="' + key + '" aria-hidden="true"><span class="type-document"><h1>落笔成文</h1><h2>第一章 · 灵感</h2><h3>1.1 看见脉络</h3><h4>1.1.1 记录想法</h4><p>让零散的想法，在文字里相遇。</p><blockquote><p>留一点空间，慢慢成形。</p></blockquote></span></span>';
  };
})();
