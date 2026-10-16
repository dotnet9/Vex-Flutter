/* Prototype-only Markdown renderer and editable blocks. No external dependencies. */
(() => {
  'use strict';
  const esc = s => String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const safeURL = (value, image = false) => /^(https?:|mailto:|#)/i.test(value) || (image && /^data:image\/(png|jpeg|gif|webp);base64,/i.test(value)) ? value : '#';
  function inline(value) {
    const tokens = [];
    const token = html => { tokens.push(html); return `\u0001${tokens.length - 1}\u0002`; };
    let s = esc(value);
    s = s.replace(/`([^`]+)`/g, (_, code) => token(`<code>${code}</code>`));
    s = s.replace(/!\[([^\]]*)\]\(([^\s)]+)\)/g, (_, alt, url) => token(`<img src="${esc(safeURL(url.replace(/&amp;/g,'&'), true))}" alt="${alt}" loading="lazy">`));
    s = s.replace(/\[([^\]]+)\]\(([^\s)]+)\)/g, (_, label, url) => token(`<a href="${esc(safeURL(url.replace(/&amp;/g,'&')))}" target="_blank" rel="noopener noreferrer">${label}</a>`));
    s = s.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>').replace(/__(.+?)__/g, '<strong>$1</strong>').replace(/\*([^*\n]+)\*/g, '<em>$1</em>').replace(/~~(.+?)~~/g, '<del>$1</del>');
    return s.replace(/\u0001(\d+)\u0002/g, (_, n) => tokens[n]);
  }
  function parse(text) {
    const lines = text.split('\n'), offsets = []; let position = 0;
    lines.forEach(line => { offsets.push(position); position += line.length + 1; });
    const blocks = [], headings = [];
    const add = (type, start, end, html, extra = {}) => {
      const block = { type, start: offsets[start], end: end < lines.length ? offsets[end] - 1 : text.length, line: start + 1, endLine: end, raw: lines.slice(start, end).join('\n'), html, ...extra };
      blocks.push(block); if (type === 'heading') headings.push(block);
    };
    const special = l => /^(#{1,6}\s|```|~~~|>\s?|\s*[-*+]\s|\s*\d+[.)]\s|\s*(?:---+|\*\*\*+)\s*$)/.test(l);
    for (let i = 0; i < lines.length;) {
      const start = i, line = lines[i]; let match;
      if (!line.trim()) { i++; continue; }
      if ((match = /^(#{1,6})\s+(.+?)\s*#*\s*$/.exec(line))) {
        const level = match[1].length, title = match[2];
        add('heading', i, ++i, `<h${level}>${inline(title)}</h${level}>`, { level, title, id: `heading-${start}` }); continue;
      }
      if ((match = /^ {0,3}(`{3,}|~{3,})(.*)/.exec(line))) {
        const marker = match[1], language = match[2].trim(); i++;
        const closing = new RegExp('^ {0,3}' + marker[0] + '{' + marker.length + ',}\\s*$');
        while (i < lines.length && !closing.test(lines[i])) i++;
        const code = lines.slice(start + 1, i).join('\n'); if (i < lines.length) i++;
        add('code', start, i, `<pre data-language="${esc(language)}"><code>${esc(code)}</code></pre>`, { language }); continue;
      }
      if (/^\s*(---+|\*\*\*+)\s*$/.test(line)) { add('hr', i, ++i, '<hr>'); continue; }
      if (i + 1 < lines.length && line.includes('|') && /^\s*\|?\s*:?-{3,}/.test(lines[i + 1])) {
        const cells = row => row.trim().replace(/^\||\|$/g,'').split('|').map(x => x.trim());
        let rows = `<thead><tr>${cells(line).map(x => `<th>${inline(x)}</th>`).join('')}</tr></thead><tbody>`; i += 2;
        while (i < lines.length && lines[i].trim() && lines[i].includes('|')) { rows += `<tr>${cells(lines[i++]).map(x => `<td>${inline(x)}</td>`).join('')}</tr>`; }
        add('table', start, i, `<table>${rows}</tbody></table>`); continue;
      }
      if (/^>/.test(line)) {
        while (i < lines.length && /^>/.test(lines[i])) i++;
        add('quote', start, i, `<blockquote><p>${lines.slice(start,i).map(x => inline(x.replace(/^>\s?/,''))).join('<br>')}</p></blockquote>`); continue;
      }
      if (/^\s*(?:[-*+]\s|\d+[.)]\s)/.test(line)) {
        const ordered = /^\s*\d/.test(line), task = /^\s*[-*+]\s\[[ xX]\]/.test(line); let html = '';
        while (i < lines.length && /^\s*(?:[-*+]\s|\d+[.)]\s)/.test(lines[i])) {
          const content = lines[i].replace(/^\s*(?:[-*+]|\d+[.)])\s/,''), check = /^\[([ xX])\]\s?(.*)/.exec(content);
          html += check ? `<li><input type="checkbox" data-task-line="${i}" ${check[1] !== ' ' ? 'checked' : ''} aria-label="${esc(check[2])}" contenteditable="false">${inline(check[2])}</li>` : `<li>${inline(content)}</li>`; i++;
        }
        const tag = ordered ? 'ol' : 'ul'; add('list', start, i, `<${tag}${task ? ' class="task-list"' : ''}>${html}</${tag}>`); continue;
      }
      i++;
      while (i < lines.length && lines[i].trim() && !special(lines[i]) && !(i + 1 < lines.length && lines[i].includes('|') && /^\s*\|?\s*:?-{3,}/.test(lines[i + 1]))) i++;
      add('paragraph', start, i, `<p>${lines.slice(start, i).map(inline).join('<br>')}</p>`);
    }
    return { blocks, headings };
  }
  function render(text, editable = false) {
    const data = parse(text);
    return data.blocks.map((b, n) => `<div class="md-block" data-block="${n}" data-line="${b.line}" ${b.id ? `id="${editable ? 'edit-' : 'read-'}${b.id}"` : ''} ${editable && !['hr', 'code'].includes(b.type) ? 'contenteditable="true" spellcheck="false"' : ''}>${editable && b.type === 'code' ? b.html.replace('<pre ', '<pre contenteditable="plaintext-only" spellcheck="false" role="textbox" aria-label="代码正文" ') : editable ? b.html : b.html.replace(/<input /g,'<input disabled ')}</div>`).join('') || (editable ? '<div class="md-block" data-block="0" contenteditable="true"><p><br></p></div>' : '<p class="muted">空白的一页，等待你的想法。</p>');
  }
  function toMarkdown(node) {
    if (node.nodeType === Node.TEXT_NODE) return node.nodeValue.replace(/\u00a0/g,' ');
    if (node.nodeType !== Node.ELEMENT_NODE) return '';
    if (node.classList.contains('md-code-footer')) return '';
    const tag = node.tagName.toLowerCase(), inner = () => [...node.childNodes].map(toMarkdown).join('');
    if (/^h[1-6]$/.test(tag)) return '#'.repeat(Number(tag[1])) + ' ' + inner() + '\n\n';
    if (tag === 'br') return '\n';
    if (tag === 'strong' || tag === 'b') return '**' + inner() + '**';
    if (tag === 'em' || tag === 'i') return '*' + inner() + '*';
    if (tag === 'del' || tag === 's') return '~~' + inner() + '~~';
    if (tag === 'a') return `[${inner()}](${safeURL(node.getAttribute('href') || '')})`;
    if (tag === 'img') return `![${node.alt || ''}](${safeURL(node.getAttribute('src') || '', true)})`;
    if (tag === 'pre') return '```' + (node.dataset.language || '') + '\n' + node.textContent.replace(/\n$/,'') + '\n```\n\n';
    if (tag === 'code') return '`' + node.textContent + '`';
    if (tag === 'blockquote') return inner().trim().split('\n').map(x => '> ' + x).join('\n') + '\n\n';
    if (tag === 'li') { const box = node.querySelector('input'); const ordered = node.parentElement.tagName === 'OL'; return (ordered ? [...node.parentElement.children].indexOf(node) + 1 + '. ' : '- ') + (box ? `[${box.checked ? 'x' : ' '}] ` : '') + inner().trim() + '\n'; }
    if (tag === 'ul' || tag === 'ol') return inner() + '\n';
    if (tag === 'input') return '';
    if (tag === 'table') {
      const rows = [...node.querySelectorAll('tr')].map(row => '| ' + [...row.children].map(cell => toMarkdown(cell).trim().replace(/\n/g,' ')).join(' | ') + ' |');
      if (rows.length) rows.splice(1, 0, '| ' + [...node.querySelector('tr').children].map(() => '---').join(' | ') + ' |');
      return rows.join('\n') + '\n\n';
    }
    if (tag === 'p' || tag === 'div') return inner() + '\n\n';
    return inner();
  }
  function mount(host, options) {
    let active = null, composing = false;
    const clearActive = () => {
      if (!active) return;
      active.element.classList.remove('is-editing');
      active.element.querySelector('.md-code-footer')?.remove();
      active = null;
    };
    const repaint = () => { active = null; host.innerHTML = render(options.getText(), true); };
    const begin = el => {
      if (active?.element === el) return;
      clearActive();
      const block = parse(options.getText()).blocks[Number(el.dataset.block)] || { start: 0, end: 0, raw: '' };
      active = { element: el, before: options.getText().slice(0, block.start), after: options.getText().slice(block.end), raw: block.raw, changed: false };
      el.classList.add('is-editing');
      if (block.type === 'code') {
        active.fence = TexweftCodeFence.parse(block.raw);
        el.append(TexweftCodeFence.footer(active.fence?.language || block.language || ''));
      }
    };
    const sync = () => {
      if (!active || composing) return;
      const raw = active.fence
        ? active.fence.write(active.element.querySelector('pre').innerText, active.element.querySelector('.md-code-language').value)
        : toMarkdown(active.element).trimEnd();
      active.changed = true;
      options.onChange(active.before + raw + active.after, true);
    };
    host.addEventListener('focusin', event => { const el = event.target.closest('.md-block'); if (el) begin(el); });
    host.addEventListener('compositionstart', () => { composing = true; });
    host.addEventListener('compositionend', () => { composing = false; sync(); });
    host.addEventListener('input', () => { if (!composing) sync(); });
    host.addEventListener('focusout', () => setTimeout(() => { if (active && !active.element.contains(document.activeElement)) { if (active.changed) repaint(); else clearActive(); } }, 0));
    host.addEventListener('paste', event => { if (event.target.matches('input')) return; event.preventDefault(); document.execCommand('insertText', false, event.clipboardData.getData('text/plain')); });
    host.addEventListener('change', event => {
      if (!event.target.matches('[data-task-line]')) return;
      const lines = options.getText().split('\n'), n = Number(event.target.dataset.taskLine);
      lines[n] = lines[n].replace(/\[[ xX]\]/, event.target.checked ? '[x]' : '[ ]');
      active = null; options.onChange(lines.join('\n')); repaint();
    });
    host.addEventListener('keydown', event => {
      if (composing || event.isComposing) return;
      if (active && event.target.matches('.md-code-language') && event.key === 'Enter') { event.preventDefault(); active.element.querySelector('pre').focus(); return; }
      if (event.key === 'Escape' && active) { const original = active.before + active.raw + active.after; active = null; options.onChange(original); repaint(); }
      if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') { event.preventDefault(); sync(); document.activeElement.blur(); }
    });
    repaint();
    return { repaint, flush: () => { if (active?.changed) sync(); clearActive(); }, format(command) { document.execCommand(command, false); sync(); }, get active() { return active; } };
  }
  window.TexEditor = { esc, inline, parse, render, mount, toMarkdown, safeURL };
})();
