/* 本地 KaTeX / mhchem / Mermaid：离线演示及源码修改后的重新渲染。 */
(function () {
  'use strict';
  function escape(value) { return String(value).replace(/[&<>"']/g, function (char) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]; }); }
  function safeURL(value, image) {
    if (/^https?:\/\//i.test(value) || (!image && /^(mailto:|#)/i.test(value))) return value;
    if (image && /^(?:\.\/)?assets\/[\w./-]+$/i.test(value) && !value.split('/').includes('..')) return value;
    if (value === '../design/Third-Party-Licenses.html') return value;
    return '';
  }
  function math(source, display) {
    var raw = (display ? '$$\n' : '$') + source + (display ? '\n$$' : '$');
    if (window.VexPreferences && (!VexPreferences.values.math || (!VexPreferences.values.chemistry && /\\ce\{|\\pu\{/.test(source)))) return '<code>' + escape(raw) + '</code>';
    try {
      return '<span class="md-math" contenteditable="false" data-markdown="' + escape(raw) + '">' + katex.renderToString(source, { displayMode: display, throwOnError: true, trust: false, output: 'htmlAndMathml' }) + '</span>';
    } catch (_) {
      return '<code class="md-render-error" data-markdown="' + escape(raw) + '">' + escape(source) + '</code>';
    }
  }
  function inline(value) {
    var tokens = [];
    var source = String(value).replace(/\[\^([^\]\n]+)\]/g, function (raw, label) {
      tokens.push('<a class="md-footnote-ref" id="vex-footnote-ref-' + encodeURIComponent(label) + '" href="#vex-footnote-' + encodeURIComponent(label) + '"><sup>[' + escape(label) + ']</sup></a>');
      return '\u0001' + (tokens.length - 1) + '\u0002';
    }).replace(/`([^`]+)`|\$([^$\n]+)\$|(!?)\[([^\]]*)\]\(([^\s)]+)\)/g, function (raw, code, formula, image, label, url) {
      var html;
      if (code !== undefined) html = '<code>' + escape(code) + '</code>';
      else if (formula !== undefined) html = math(formula, false);
      else {
        var safe = safeURL(url, !!image);
        html = !safe ? escape(raw) : image ? '<img src="' + escape(safe) + '" alt="' + escape(label) + '">' : '<a href="' + escape(safe) + '" target="_blank" rel="noopener noreferrer">' + escape(label) + '</a>';
      }
      tokens.push(html); return '\u0001' + (tokens.length - 1) + '\u0002';
    });
    var html = escape(source).replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>').replace(/\*([^*]+)\*/g, '<em>$1</em>').replace(/~~([^~]+)~~/g, '<del>$1</del>');
    if (window.VexPreferences?.values.highlight !== false) html = html.replace(/==([^=]+)==/g,'<mark>$1</mark>');
    if (window.VexPreferences?.values.subscript !== false) html = html.replace(/\^([^\s^]+)\^/g,'<sup>$1</sup>').replace(/(?<!~)~([^\s~]+)~(?!~)/g,'<sub>$1</sub>');
    return html
      .replace(/\u0001(\d+)\u0002/g, function (_, index) { return tokens[index]; });
  }
  var serial = 0, pending = false, requested = false, initialized = false;
  // Mermaid needs literal colors while calculating its theme. Replace these unique
  // seed colors with CSS tokens once, so mode/palette changes retain the same SVG.
  var diagramTokens = {
    '#d1e2f3': '--accent-soft', '#253647': '--fg', '#456789': '--accent',
    '#e2d3c4': '--code-bg', '#f3e4d5': '--panel', '#647586': '--muted', '#b4c5d6': '--border'
  };
  function themedSVG(svg) {
    return svg.replace(/#[\da-f]{6}\b/gi, function (color) {
      return diagramTokens[color.toLowerCase()] ? 'var(' + diagramTokens[color.toLowerCase()] + ')' : color;
    }).replace(/rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*([\d.]+))?\s*\)/g, function (color, r, g, b, alpha) {
      var hex = '#' + [r,g,b].map(function (value) { return Number(value).toString(16).padStart(2,'0'); }).join('');
      var token = diagramTokens[hex];
      return token ? alpha && Number(alpha) < 1 ? 'color-mix(in srgb, var(' + token + ') ' + Number(alpha) * 100 + '%, transparent)' : 'var(' + token + ')' : color;
    });
  }
  function diagrams() {
    requested = true;
    if (pending) return;
    pending = true;
    requestAnimationFrame(async function () {
      requested = false;
      var elements = Array.from(document.querySelectorAll('.md-diagram:not([data-rendered])'));
      if (elements.length && !initialized) {
        mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', theme: 'base', suppressErrorRendering: true,
          themeVariables: { darkMode: false, fontFamily: 'Microsoft YaHei UI, Segoe UI, sans-serif', fontSize: '14px',
            primaryColor: '#d1e2f3', primaryTextColor: '#253647', primaryBorderColor: '#456789',
            secondaryColor: '#e2d3c4', tertiaryColor: '#f3e4d5', lineColor: '#647586', textColor: '#253647',
            mainBkg: '#d1e2f3', nodeBorder: '#456789', clusterBkg: '#f3e4d5', clusterBorder: '#b4c5d6',
            edgeLabelBackground: '#f3e4d5', actorBkg: '#d1e2f3', actorBorder: '#456789', actorTextColor: '#253647',
            actorLineColor: '#647586', signalColor: '#253647', signalTextColor: '#253647', labelBoxBkgColor: '#f3e4d5', labelTextColor: '#253647' }
        });
        initialized = true;
      }
      for (var element of elements) {
        if (!element.isConnected || element.dataset.rendered) continue;
        element.dataset.rendered = 'pending';
        try {
          var result = await mermaid.render('vex-diagram-' + (++serial), element.dataset.source);
          if (!element.isConnected) continue;
          element.innerHTML = themedSVG(result.svg); element.dataset.rendered = 'true';
          var svg = element.querySelector('svg'); svg.setAttribute('role', 'img'); svg.setAttribute('aria-label', element.dataset.label || 'Markdown 图表');
        } catch (_) {
          if (element.isConnected) { element.dataset.rendered = 'error'; element.innerHTML = '<p class="md-render-error">图表语法有误，请切换源码检查。</p><pre><code>' + escape(element.dataset.source) + '</code></pre>'; }
        }
      }
      pending = false;
      if (requested) diagrams();
    });
  }
  function special(block) { return block.kind === 'math' || (block.kind === 'code' && block.language.toLowerCase() === 'mermaid'); }
  function renderSpecial(block) {
    var attr = ' data-line="' + block.line + '"';
    if (block.kind === 'math') return '<div class="md-math-block"' + attr + '>' + math(block.text, true) + '</div>';
    if (window.VexPreferences?.values.mermaid === false) return '<pre' + attr + '><code>' + escape(block.raw || block.text) + '</code></pre>';
    return '<div class="md-diagram"' + attr + ' data-source="' + escape(block.text) + '" data-label="' + escape(VexMermaid.label(block.text)) + '"><pre><code>' + escape(block.text) + '</code></pre></div>';
  }
  window.VexRendering = { inline: inline, special: special, renderSpecial: renderSpecial, diagrams: diagrams };
})();
