/* Optional browser checks. Uses an existing Playwright installation; no app dependency. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {chromium} = require('playwright');
const base = process.env.VEX_PREVIEW_URL || 'http://127.0.0.1:4317/design/';
const output = path.resolve(__dirname, '../../.dart_tool/prototype-usability');
fs.mkdirSync(output, {recursive:true});

(async () => {
  const browser = await chromium.launch({headless:true});
  const context = await browser.newContext({viewport:{width:1440,height:900},acceptDownloads:false});
  const page = await context.newPage(), errors = [];
  page.on('pageerror', error => errors.push(error.message));
  async function open(query = '') {
    await page.goto(base + 'Vex.html?preview=1&' + query);
    await page.waitForFunction(() => window.VexWorkspace && window.VexChapters && document.querySelector('#workspace-welcome'));
    await page.waitForTimeout(180);
  }
  async function text(selector) { return page.locator(selector).innerText(); }
  try {
    await open();
    assert.equal(await page.locator('#vex-guide').isVisible(), false, 'Writing starts without a blocking guide');
    assert.equal(await text('#current-layout-label'), '即时编辑');
    assert.equal(await page.locator('#outline-toggle').getAttribute('aria-pressed'), 'false');
    assert.equal(await page.locator('.studio-palettes').isVisible(), false);
    await page.locator('#vex-appearance-menu summary').click();
    assert.equal(await page.locator('.studio-palettes').isVisible(), true);
    await page.locator('#vex-theme-panel [data-palette=ocean]').click();
    assert.equal(await page.locator('html').getAttribute('data-palette'), 'ocean');
    await page.locator('#vex-appearance-menu summary').click();
    await page.locator('#workspace-layout').click();
    await page.locator('[data-layout=source-render]').click();
    assert.equal(await text('#current-layout-label'), '源码 + 预览');
    assert.equal(await page.locator('#workspace-layout-menu').isVisible(), false, 'Choosing a view closes the menu');
    await page.locator('#markdown-input').focus();
    assert.equal(await page.locator('.view-panel[data-document=editor]').evaluate(el => el.classList.contains('active-view')), true);

    const original = await page.evaluate(() => VexWorkbench.text);
    await page.evaluate(() => VexWorkbench.applyText(VexWorkbench.text + '\n\n保存状态检查。'));
    assert.match(await text('#document-save-status'), /未保存修改/);
    await page.locator('#document-save-status').click();
    assert.match(await text('#save-source-location'), /演示文档/);
    assert.match(await text('#document-save-details'), /不写回来源文件/);
    await page.screenshot({path:path.join(output,'save-details.png')});
    const download = page.waitForEvent('download');
    await page.locator('#save-details-retry').click(); await download;
    assert.match(await text('#document-save-status'), /副本下载已发起/);
    assert.equal(await page.evaluate(() => VexWorkbench.state.dirty), false);
    await page.locator('[aria-label="关闭保存详情"]').click();

    await page.locator('#file-filter').fill('找不到的文件名');
    assert.match(await text('#file-list'), /不搜索正文/);
    await page.locator('#file-list .empty-state button').filter({hasText:'查找当前正文'}).click();
    assert.equal(await page.locator('#find-input').isVisible(), true);
    await page.locator('#find-input').fill('正文中没有这句话');
    assert.equal(await text('#find-count'), '当前正文无匹配');
    await page.locator('#file-list .empty-state button').filter({hasText:'清除文件名筛选'}).click();
    assert.ok(await page.locator('#file-list .file-row').count() > 0);
    await page.evaluate(() => VexWorkspace.setLayout('read'));
    await page.locator('#find-input').fill('写作');
    await page.locator('[data-action=find-next]').click();
    assert.equal(await page.evaluate(() => VexWorkspace.current), 'read', 'Find preserves the current layout');
    await page.evaluate(() => VexProto.handleAction('replace'));
    await page.locator('#replace-input').fill('写作验证');
    const beforeReplace = await page.evaluate(() => VexWorkbench.text);
    await page.locator('#replace-all').click();
    assert.notEqual(await page.evaluate(() => VexWorkbench.text), beforeReplace);
    assert.equal(await page.evaluate(() => VexWorkspace.current), 'read', 'Replace preserves the current layout');
    await page.evaluate(() => VexWorkbench.history('undo'));
    assert.equal(await page.evaluate(() => VexWorkbench.text), beforeReplace, 'Replace all is one undoable change');

    await open('scenario=save-error&layout=source');
    await page.evaluate(() => VexWorkbench.applyText(VexWorkbench.text + '\n\n失败后必须保留这段内容。'));
    const failedText = await page.evaluate(() => VexWorkbench.text);
    await page.locator('.save-button').click();
    assert.equal(await page.evaluate(() => VexWorkbench.text), failedText);
    assert.equal(await page.evaluate(() => VexWorkbench.state.dirty), true);
    assert.match(await text('#document-save-status'), /下载失败/);
    await page.locator('#document-save-status').click();
    const retry = page.waitForEvent('download'); await page.locator('#save-details-retry').click(); await retry;
    assert.match(await text('#save-last-export'), /已发起/);

    await open('scenario=long-document&layout=source-render');
    await page.evaluate(() => {
      const input = document.querySelector('#markdown-input'); input.focus();
      input.setSelectionRange(25,25); input.dispatchEvent(new Event('select'));
    });
    const anchor = await page.evaluate(() => VexWorkbench.state.editingLine);
    await page.locator('#view-follow-toggle').click();
    assert.equal(await page.evaluate(() => VexWorkbench.state.followViews), false);
    const sourceTop = await page.locator('.source-scroll').evaluate(el => el.scrollTop);
    await page.locator('.reading-scroll').evaluate(el => { el.scrollTop = 1800; });
    await page.waitForTimeout(180);
    assert.ok(Math.abs(await page.locator('.source-scroll').evaluate(el => el.scrollTop) - sourceTop) < 1, 'Free browsing does not move the editor');
    assert.equal(await page.evaluate(() => VexWorkbench.state.editingLine), anchor);
    await page.locator('#return-to-editing').click();
    await page.waitForTimeout(100);
    assert.ok(await page.locator('.reading-scroll').evaluate(el => el.scrollTop) < 500, 'Return locates the writing anchor');
    assert.equal(await page.evaluate(() => VexWorkbench.state.followViews), false, 'Returning does not silently enable sync');
    await page.locator('#view-follow-toggle').click();
    assert.equal(await page.evaluate(() => VexWorkbench.state.followViews), true);

    await open('layout=map');
    assert.equal(await page.locator('#chapter-headings-only').getAttribute('aria-pressed'), 'true');
    const chapterText = '# 文章\n\n## 甲章\n\n甲的正文。\n\n### 子节\n\n子节的正文。\n\n## 乙章\n\n乙的正文。\n';
    await page.evaluate(value => {
      VexWorkbench.applyText(value); VexWorkbench.fit();
      VexWorkbench.selectNode(VexWorkbench.state.nodes.find(node => node.text === '甲章'));
    }, chapterText);
    await page.locator('[data-chapter-command=down]').click();
    const moved = await page.evaluate(() => VexWorkbench.text);
    assert.ok(moved.indexOf('## 乙章') < moved.indexOf('## 甲章'));
    assert.ok(moved.includes('### 子节\n\n子节的正文。'));
    await page.locator('.chapter-feedback button').click();
    assert.equal(await page.evaluate(() => VexWorkbench.text), chapterText);
    await page.evaluate(() => {
      VexWorkbench.fit();
      const nodes = VexWorkbench.state.nodes;
      const a = document.querySelector('[data-node-id="' + nodes.find(n => n.text === '甲章').id + '"]');
      const b = document.querySelector('[data-node-id="' + nodes.find(n => n.text === '乙章').id + '"]');
      const transfer = new DataTransfer(), rect = b.getBoundingClientRect();
      a.dispatchEvent(new DragEvent('dragstart', {bubbles:true,dataTransfer:transfer}));
      b.dispatchEvent(new DragEvent('dragover', {bubbles:true,dataTransfer:transfer,clientY:rect.top+rect.height/2}));
    });
    assert.match(await text('.chapter-drop-preview'), /H3.*正文和 1 个子章节/);
    await page.screenshot({path:path.join(output,'chapter-drop.png')});
    await page.evaluate(() => {
      const node = VexWorkbench.state.nodes.find(n => n.text === '乙章');
      document.querySelector('[data-node-id="' + node.id + '"]').dispatchEvent(new DragEvent('drop', {bubbles:true,dataTransfer:new DataTransfer()}));
    });
    assert.match(await page.evaluate(() => VexWorkbench.text), /### 甲章[\s\S]*#### 子节/);
    await page.locator('.chapter-feedback button').click();
    assert.equal(await page.evaluate(() => VexWorkbench.text), chapterText);

    await page.evaluate(() => VexWorkspace.setLayout('instant'));
    await page.locator('.view-panel[data-document=editor] [data-action=typography]').click();
    assert.match(await text('.typography-reading'), /甲的正文/);
    await page.screenshot({path:path.join(output,'article-typography.png')});
    await page.locator('#typography-preview-source').selectOption('sample');
    assert.match(await text('.typography-reading'), /在文字之间/);
    await page.locator('#typography-close').click();
    await page.evaluate(() => {
      VexWorkspace.setLayout('source');
      const input = document.querySelector('#markdown-input'); input.focus(); input.setSelectionRange(2,4); input.dispatchEvent(new Event('select'));
    });
    assert.match(await text('#sb-wordcount'), /选中 2/);
    await page.locator('#sb-wordcount').click();
    assert.match(await text('#auxiliary-info'), /中文按字，英文按词/);

    await open('scenario=empty');
    assert.equal(await page.locator('#workspace-welcome').isVisible(), true);
    await page.locator('#workspace-welcome [data-action=new]').click();
    assert.equal(await page.locator('#workspace-welcome').isVisible(), false);
    assert.equal(await page.evaluate(() => VexWorkbench.text), '');
    assert.equal(await page.locator('.blank-document-note').isVisible(), true);
    await page.locator('#instant-content [contenteditable=true]').first().fill('从空白开始写作。');
    await page.locator('#document-name').click();
    await page.waitForTimeout(250);
    assert.match(await page.evaluate(() => VexWorkbench.text), /从空白开始写作/);
    assert.match(await text('#document-save-status'), /未保存/);

    await open('scenario=no-headings&layout=map');
    assert.equal(await page.locator('.map-empty-hint').isVisible(), true);
    await page.locator('.map-empty-hint button').click();
    assert.equal(await page.evaluate(() => VexWorkspace.current), 'instant');

    await open('scenario=draft');
    assert.match(await text('.prototype-draft'), /排版与写作.md/);
    await page.locator('.prototype-draft button').filter({hasText:'恢复示例草稿'}).click();
    assert.match(await text('#document-save-status'), /未保存/);
    await page.locator('#document-save-status').click();
    assert.match(await text('#save-draft-state'), /恢复不等于已保存/);

    for (const viewport of [{width:1440,height:900},{width:1024,height:768},{width:800,height:480}]) {
      await page.setViewportSize(viewport);
      for (const layout of ['instant','three']) {
        await open('layout=' + layout);
        const bounds = await page.evaluate(() => {
          const bar = document.querySelector('.document-statusbar'), content = document.querySelector('.content-area');
          const r = bar.getBoundingClientRect(), c = content.getBoundingClientRect();
          return {bar:r.toJSON(),content:c.toJSON(),overflow:bar.scrollWidth-bar.clientWidth};
        });
        assert.ok(bounds.bar.bottom <= viewport.height + 1, 'Status bar stays inside the viewport');
        assert.ok(bounds.content.bottom <= bounds.bar.top + 1, 'Controls do not overlap document content');
        assert.ok(bounds.overflow <= 1, 'Status controls fit the window');
        if (layout === 'three') {
          const map = await page.evaluate(() => {
            const W = VexWorkbench, canvas = document.querySelector('#map-viewport');
            return {scale:W.state.scale,x:W.state.x,y:W.state.y,
              width:W.state.bounds.width*W.state.scale,height:W.state.bounds.height*W.state.scale,
              canvasWidth:canvas.clientWidth,canvasHeight:canvas.clientHeight};
          });
          assert.ok(map.scale >= .2, 'The default map remains visible in a short window');
          assert.ok(map.x >= 0 && map.y >= 0 && map.x+map.width <= map.canvasWidth+1 && map.y+map.height <= map.canvasHeight+1, 'The initial map fits inside its pane');
        }
        if (layout === 'three' && viewport.width < 1250) {
          assert.equal(await page.evaluate(() => VexWorkbench.state.sidebar), false);
          await page.locator('#sidebar-toggle').click();
          assert.equal(await page.evaluate(() => VexWorkbench.state.sidebar), true, 'Auto-hidden navigation can be reopened');
          await page.locator('#sidebar-toggle').click();
          await page.locator('#outline-toggle').click();
          assert.equal(await page.locator('#outline-toggle').getAttribute('aria-pressed'), 'true', 'Outline can be explicitly reopened');
          await page.locator('#outline-toggle').click();
        }
        await page.screenshot({path:path.join(output, `${layout}-${viewport.width}.png`)});
      }
    }
    await page.setViewportSize({width:1440,height:900});
    await open('theme=dark&layout=three');
    await page.screenshot({path:path.join(output,'three-dark.png')});
    await open('scenario=empty'); await page.screenshot({path:path.join(output,'empty.png')});
    await open('scenario=long-files');
    assert.ok((await page.locator('.file-row').first().getAttribute('title')).includes('/'));
    await page.screenshot({path:path.join(output,'long-files.png')});
    await page.goto(base + 'Usability-Review.html');
    assert.equal(await page.locator('.card').count(), 8);
    assert.equal(await page.locator('.primary').getAttribute('href'), 'Vex.html?preview=1');
    await page.screenshot({path:path.join(output,'review.png'),fullPage:true});
    assert.deepEqual(errors, [], 'Browser runtime errors');
    console.log('PASS: layout state, appearance, saving/retry, search scopes, sync control, chapter move/undo, current-article preview, selections, empty/draft scenarios and 800–1440px layouts.');
    console.log('Screenshots: ' + output);
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
