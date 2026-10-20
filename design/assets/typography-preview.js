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
    return '<span class="type-swatch" data-preview-type="' + key + '" aria-hidden="true"><span class="type-document"><h1>在文字之间，理清思路</h1><p class="type-lead">一篇文章，从一个想法开始。让结构清晰，也让阅读舒适。</p><h2>写作，让想法有迹可循</h2><p>先记录观察，再整理线索。标题、段落与留白共同构成阅读节奏。</p><blockquote><p>好的工具，让注意力回到内容本身。</p></blockquote><h3>今天的小计划</h3><ul><li>梳理章节结构</li><li>保留必要的留白</li></ul></span></span>';
  };
})();
