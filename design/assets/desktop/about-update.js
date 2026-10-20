/* 原型使用离线状态演示；“检查更新”从帮助菜单打开，关于对话框只保留版本信息。 */
(function () {
  const $ = id => document.getElementById(id);
  let state = 'idle', scenario = 'available', retry = 'checking', timer, generation = 0;
  const failures = new Set();
  const labels = { idle:'AboutCheckUpdate', checking:'AboutCheckingUpdate', available:'AboutDownload', downloading:'AboutDownloading', downloaded:'AboutInstall', installing:'AboutInstalling', current:'AboutCheckUpdate', canceled:'AboutCheckUpdate', manual:'AboutOpenRelease', installed:'AboutCheckUpdate' };
  const failureMessages = { 'check-failed':'检查失败，请重试。', 'download-failed':'下载失败，请重试。', 'checksum-failed':'校验失败，请重新下载。', 'install-failed':'安装失败，请重试。' };

  // 版本与日期、更新日志正文全部取自内置《更新日志》文档（与更新日志.md 同源）。
  function releaseIndex() {
    const text = (window.VexDocuments && VexDocuments.changelog && VexDocuments.changelog.text) || '';
    const sections = [];
    const pattern = /^## V(\d+\.\d+\.\d+)（([^）\n]+)）\n([\s\S]*?)(?=\n## V\d+\.\d+\.\d+（|$)/gm;
    let match;
    while ((match = pattern.exec(text))) {
      sections.push({ version: match[1], date: match[2].trim(), body: match[3].trim() });
    }
    return sections;
  }
  function compareVersion(a, b) {
    const left = a.split('.').map(Number), right = b.split('.').map(Number);
    for (let i = 0; i < 3; i++) if ((left[i] || 0) !== (right[i] || 0)) return (left[i] || 0) - (right[i] || 0);
    return 0;
  }
  function currentVersion() { return (window.VexProject ? VexProject.version : '').split('+')[0]; }
  function releaseDate(version) {
    const found = releaseIndex().find(item => item.version === version);
    return found ? found.date : '';
  }

  function renderCurrent() {
    const version = currentVersion();
    $('update-current-version').textContent = version;
    $('update-current-date').textContent = releaseDate(version);
  }

  function renderList(sections) {
    const list = $('update-list');
    list.innerHTML = sections.map(item =>
      '<section class="update-item"><header><strong>V' + item.version + '</strong><span class="update-date">' + item.date + '</span></header><div class="update-log md-body">' + TexEditor.render(item.body) + '</div></section>'
    ).join('');
    list.hidden = sections.length === 0;
  }

  function render() {
    $('vex-update').textContent = state === 'failed' ? VexL.label('重试') : VexL.get(labels[state]);
    $('vex-update').disabled = ['checking','downloading','installing'].includes(state);
    $('layer-update').dataset.updateState = state;
    const key = { available:'AboutUpdateAvailable', downloading:'AboutDownloading', downloaded:'AboutDownloaded', installing:'AboutInstalling', canceled:'AboutCanceled' }[state];
    const message = state === 'failed' ? VexL.label(failureMessages[scenario]) : state === 'installed' ? VexL.label('更新已安装。') : state === 'manual' ? VexL.label('请前往发布页下载安装包。') : key ? VexL.get(key).replace('{0}', '99.0.0') : '';
    $('vex-update-status').textContent = message;
    $('vex-update-status').hidden = !message;
  }

  function reset() {
    clearTimeout(timer);
    state = 'idle';
    $('update-list').hidden = true;
    $('update-list').replaceChildren();
    renderCurrent();
    render();
  }

  function cancel() {
    generation++; clearTimeout(timer);
    if (['checking','downloading','installing'].includes(state)) state = 'canceled';
    render();
  }

  function operation(next) {
    retry = next; state = next; render(); const id = ++generation;
    timer = setTimeout(() => {
      if (id !== generation) return;
      const shouldFail = next === 'checking' && scenario === 'check-failed' || next === 'downloading' && ['download-failed','checksum-failed'].includes(scenario) || next === 'installing' && scenario === 'install-failed';
      if (shouldFail && !failures.has(scenario)) { failures.add(scenario); state = 'failed'; }
      else state = next === 'checking' ? scenario === 'current' ? 'current' : scenario === 'missing' ? 'manual' : 'available' : next === 'downloading' ? 'downloaded' : 'installed';
      render();
      if (state === 'current') VexProto.toast(VexL.get('AboutUpToDate'));
      if (state === 'available' && next === 'checking') {
        // 列出当前版本到最新版之间的所有版本（倒序），日志用自家 Markdown 渲染。
        const current = currentVersion();
        let newer = releaseIndex()
          .filter(item => compareVersion(item.version, current) > 0)
          .sort((a, b) => compareVersion(b.version, a.version));
        // 演示环境当前版本往往就是日志里最新的一版：合成一条示例新版，
        // 展示跨版本升级时“列出之间所有版本”的完整形态。
        if (!newer.length) {
          newer = [{
            version: '99.0.0',
            date: new Date().toISOString().slice(0, 10),
            body: '- 示例更新：跨版本升级时，这里列出当前版本之后的所有版本与更新日志。\n- 日志使用与正文一致的 Markdown 渲染，支持 **加粗**、[链接](https://github.com/dotnet9/Vex-Flutter/releases/latest) 与列表。',
          }];
        }
        renderList(newer);
      }
    }, 250);
  }

  $('vex-update').onclick = () => {
    if (state === 'failed') operation(retry);
    else if (state === 'available') operation('downloading');
    else if (state === 'downloaded') operation('installing');
    else if (state === 'manual') window.open('https://github.com/dotnet9/Vex-Flutter/releases/latest', '_blank', 'noopener,noreferrer');
    else operation('checking');
  };
  $('layer-update').querySelector('[data-close]').addEventListener('click', cancel);
  new MutationObserver(() => {
    if (!$('layer-update').hidden) reset();
    else cancel();
  }).observe($('layer-update'), {attributes:true,attributeFilter:['hidden']});
  window.addEventListener('vex-language-changed', () => { renderCurrent(); render(); });
  // 自动化验证可选择失败场景；演示开关不进入产品界面。
  window.VexUpdate = { setScenario(value) {
    if (!['available','current','missing','check-failed','download-failed','checksum-failed','install-failed'].includes(value)) return;
    cancel(); scenario = value; state = 'idle'; failures.clear(); render();
  } };
})();
