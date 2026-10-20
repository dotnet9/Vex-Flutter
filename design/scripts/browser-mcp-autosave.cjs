/* Optional headless browser checks; requires Playwright and a running preview server. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {chromium} = require('playwright');
const base = process.env.VEX_PREVIEW_URL || 'http://127.0.0.1:4317/design/';
const output = path.resolve(__dirname, '../../.dart_tool/prototype-mcp');
fs.mkdirSync(output, {recursive:true});

(async () => {
  const browser = await chromium.launch({headless:true});
  const context = await browser.newContext({viewport:{width:1280,height:900}});
  const page = await context.newPage(), errors = [];
  page.on('pageerror', error => errors.push(error.message));
  const toggle = page.locator('[data-mcp-field=mcpEnabled]');
  const status = page.locator('.vex-mcp-status');
  const port = page.locator('[data-mcp-field=mcpPort]');
  async function open(query = 'preview=1') {
    await page.goto(base + 'Vex.html?' + query);
    await page.waitForFunction(() => window.VexPreferences && window.VexWorkbench);
    await page.evaluate(() => VexPreferences.open('mcp'));
    await page.waitForTimeout(220);
  }
  async function waitState(state) {
    await page.waitForFunction(state => document.querySelector('.vex-mcp-status')?.dataset.state === state, state);
  }
  try {
    await open();
    assert.equal(await page.locator('[data-mcp-action=apply],[data-mcp-action=stop]').count(), 0);
    assert.match(await status.innerText(), /服务已停止/);
    const switchBounds = await toggle.locator('..').boundingBox();
    const statusBounds = await status.boundingBox();
    assert(statusBounds.y >= switchBounds.y + switchBounds.height, 'Status follows the service switch');
    await page.screenshot({path:path.join(output,'stopped.png')});
    await toggle.check();
    await waitState('starting');
    await page.evaluate(() => VexPreferences.close());
    await page.waitForTimeout(500);
    await page.evaluate(() => VexPreferences.open('mcp'));
    await page.waitForTimeout(220);
    await waitState('running');
    assert.equal(await toggle.isChecked(), true);
    assert.match(await status.innerText(), /http:\/\/127\.0\.0\.1:17891\/mcp\//);
    await page.screenshot({path:path.join(output,'running.png')});
    // Debounced text updates retain focus and restart on the new port.
    await port.fill('18921');
    await page.waitForTimeout(900);
    assert.equal(await page.evaluate(() => document.activeElement.dataset.mcpField), 'mcpPort');
    await waitState('running');
    assert.match(await status.innerText(), /18921/);
    await port.fill('99');
    await page.waitForTimeout(450);
    assert.equal(await page.evaluate(() => VexPreferences.values.mcpPort), 18921);
    assert.match(await page.locator('#vex-mcp-error').innerText(), /1024/);
    await toggle.uncheck();
    await waitState('stopped');
    assert.equal(await page.evaluate(() => VexPreferences.values.mcpEnabled), false);
    await port.fill('18922');
    await page.evaluate(() => VexPreferences.close());
    assert.equal(await page.evaluate(() => VexPreferences.values.mcpPort), 18922);
    // Disabled settings still persist in the regular preview across reloads.
    await open('');
    await page.locator('[data-mcp-action=token]').click();
    const token = await page.locator('[data-mcp-field=mcpToken]').inputValue();
    await page.reload();
    await page.waitForFunction(() => window.VexPreferences && window.VexWorkbench);
    await page.evaluate(() => VexPreferences.open('mcp'));
    await page.waitForTimeout(220);
    assert.equal(await page.locator('[data-mcp-field=mcpToken]').inputValue(), token);
    await toggle.check();
    await waitState('running');
    await page.reload();
    await page.waitForFunction(() => window.VexPreferences && window.VexWorkbench);
    await page.evaluate(() => VexPreferences.open('mcp'));
    await page.waitForTimeout(220);
    await waitState('running');
    assert.equal(await toggle.isChecked(), true);
    // Text preferences persist before blur, including closing with Escape.
    await page.locator('[data-vex-section=images]').click();
    await page.locator('[data-vex-pref=imageFolder]').fill('media/images');
    await page.keyboard.press('Escape');
    assert.equal(await page.evaluate(() => VexPreferences.values.imageFolder), 'media/images');
    await open('preview=1&mcpScenario=port-busy');
    await toggle.check();
    await waitState('error');
    assert.equal(await toggle.isChecked(), false);
    assert.match(await status.innerText(), /端口已被占用/);
    assert.match(await page.locator('.vex-settings-status').innerText(), /设置已保存/);
    await page.screenshot({path:path.join(output,'port-busy.png')});
    await open();
    await toggle.check(); await toggle.uncheck();
    await page.waitForTimeout(550);
    await waitState('stopped');
    for (const width of [800,1024,1440]) {
      await page.setViewportSize({width,height:900});
      assert.equal(await page.evaluate(() => document.querySelector('.vex-settings-content').scrollWidth > document.querySelector('.vex-settings-content').clientWidth + 1), false);
      await page.screenshot({path:path.join(output,`mcp-${width}.png`)});
    }
    assert.deepEqual(errors, []);
    console.log('PASS: direct start/stop, status placement, close while starting, automatic saving, invalid input, token reload, port failure and rapid switching.');
    console.log('Screenshots: ' + output);
  } finally { await context.close(); await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
