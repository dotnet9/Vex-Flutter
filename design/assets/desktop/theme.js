/* 标题栏统一提供三态、八色点和可扩展语言菜单。 */
(function () {
  var palettes=TexweftPalettes.map(function(p){return [p.key,p.label,p.light];});
  var modes=[['light','ThemeLight','☀'],['dark','ThemeDark','☾'],['system','ThemeSystem','◐']];
  var storeKey='texweft-design-appearance',system=matchMedia('(prefers-color-scheme: dark)'),state={mode:'light',palette:'weft'};
  try{Object.assign(state,JSON.parse(TexweftStorage.getItem(storeKey)||'{}'));}catch(_){}
  var query=new URLSearchParams(location.search),theme=query.get('theme');
  if(modes.some(item=>item[0]===theme))state.mode=theme;else if(palettes.some(item=>item[0]===theme))state.palette=theme;
  if(query.has('palette'))state.palette=query.get('palette');state.palette=TexweftPaletteKey(state.palette);
  function word(key){return window.TexweftL?TexweftL.get(key):key;}
  function apply(){
    if(!modes.some(item=>item[0]===state.mode))state.mode='system';if(!palettes.some(item=>item[0]===state.palette))state.palette='weft';
    document.documentElement.dataset.themeMode=state.mode;document.documentElement.dataset.theme=state.mode==='system'?(system.matches?'dark':'light'):state.mode;document.documentElement.dataset.palette=state.palette;
    try{TexweftStorage.setItem(storeKey,JSON.stringify(state));}catch(_){}
    var toggle=document.getElementById('texweft-mode-toggle');if(toggle){var selectedMode=modes.find(item=>item[0]===state.mode);toggle.dataset.mode=state.mode;toggle.dataset.resource=selectedMode[1];toggle.textContent=selectedMode[2];}
    document.querySelectorAll('#texweft-theme-panel [data-mode],#texweft-theme-panel [data-palette]').forEach(button=>{var active=button.dataset.mode?button.dataset.mode===state.mode:button.dataset.palette===state.palette;button.classList.toggle('on',active);button.setAttribute('aria-pressed',String(active));button.title=button.dataset.palette?(TexweftPalettes.find(function(p){return p.key===button.dataset.palette;})[window.TexweftL?.culture==='en-US'?'en':'label']):word(button.dataset.resource);button.setAttribute('aria-label',button.title);});
    document.querySelectorAll('#texweft-language-menu [data-language]').forEach(button=>{var active=button.dataset.language===window.TexweftL?.culture;button.setAttribute('aria-checked',String(active));button.classList.toggle('on',active);});
    var language=document.querySelector('#texweft-language-menu>summary');if(language){language.title=word('MenuLanguage');language.setAttribute('aria-label',language.title);}
  }
  window.TexweftTheme={state:state,setMode(value){state.mode=value;apply();},setPalette(value){state.palette=TexweftPaletteKey(value);apply();}};apply();
  system.addEventListener('change',()=>{if(state.mode==='system')apply();});
  window.addEventListener('storage',event=>{if(event.key===storeKey)try{Object.assign(state,JSON.parse(event.newValue||'{}'));apply();}catch(_){}});
  window.addEventListener('texweft-language-changed',apply);
  window.addEventListener('keydown',event=>{var index=Number(event.key)-1;if(event.altKey&&!event.ctrlKey&&index>=0&&index<palettes.length)TexweftTheme.setPalette(palettes[index][0]);if(event.key==='Escape'){var menu=document.getElementById('texweft-language-menu');if(menu)menu.open=false;}});
  document.addEventListener('DOMContentLoaded',()=>{
    var windowPanel=document.createElement('section');windowPanel.id='prototype-window-state';windowPanel.hidden=true;windowPanel.innerHTML='<p></p><button type="button" id="restore-window"></button>';document.body.append(windowPanel);
    windowPanel.querySelector('button').onclick=()=>{document.querySelector('.app-window').hidden=false;windowPanel.hidden=true;document.querySelector('#caption-btns button').focus();};
    document.getElementById('caption-btns').addEventListener('click',event=>{var button=event.target.closest('[data-action]');if(!button)return;event.stopImmediatePropagation();var app=document.querySelector('.app-window'),action=button.dataset.action;if(action==='maximize'){app.classList.toggle('expanded');return;}var words=({'zh-CN':['窗口已最小化','窗口已关闭','还原窗口','重新打开'],'zh-Hant':['視窗已最小化','視窗已關閉','還原視窗','重新開啟'],'en-US':['Window minimized','Window closed','Restore window','Reopen'],'ja-JP':['ウィンドウを最小化しました','ウィンドウを閉じました','ウィンドウを復元','もう一度開く']})[TexweftL.culture];app.hidden=true;windowPanel.dataset.state=action;windowPanel.querySelector('p').textContent=words[action==='close'?1:0];windowPanel.querySelector('button').textContent=words[action==='close'?3:2];windowPanel.hidden=false;windowPanel.querySelector('button').focus();},true);
    var panel=document.createElement('div');panel.id='texweft-theme-panel';panel.className='studio-title-controls';
    panel.innerHTML='<div class="studio-modes" role="group" aria-label="Theme mode">'+'<button type="button" id="texweft-mode-toggle" data-mode="system" data-resource="ThemeSystem">◐</button>'+'</div><div class="studio-palettes" role="group" aria-label="Palette">'+palettes.map(item=>'<button type="button" data-palette="'+item[0]+'" aria-label="'+item[1]+'"><i style="background:'+item[2]+'"></i></button>').join('')+'</div><details id="texweft-language-menu" class="studio-language"><summary>文<span aria-hidden="true">A</span></summary><div role="menu">'+Object.entries(TEXWEFT_DATA.languages).map(([code])=>'<button type="button" role="menuitemradio" data-language="'+code+'">'+({"zh-CN":"简体中文","zh-Hant":"繁體中文","en-US":"English","ja-JP":"日本語"}[code]||code)+'</button>').join('')+'</div></details>';
    document.getElementById('caption-btns').before(panel);
    panel.addEventListener('click',event=>{var button=event.target.closest('button');if(!button)return;if(button.dataset.mode)TexweftTheme.setMode(({system:'light',light:'dark',dark:'system'})[state.mode]);if(button.dataset.palette)TexweftTheme.setPalette(button.dataset.palette);if(button.dataset.language){TexweftL.set(button.dataset.language);document.getElementById('texweft-language-menu').open=false;}});
    document.addEventListener('click',event=>{if(!event.target.closest('#texweft-language-menu'))document.getElementById('texweft-language-menu').open=false;});apply();
  });
})();
