/* 评审参数不进入产品菜单。 */
(function () {
  const query=new URLSearchParams(location.search);
  document.body.dataset.platform=query.get('platform')||'windows';
  const language={zh:'zh-CN',en:'en-US'}[query.get('lang')]||query.get('lang');
  if(language)TexweftL.set(language);
  if(query.get('scenario')==='guide')setTimeout(()=>TexweftGuide.start(),250);
  if(query.get('scenario')==='draft'){
    const banner=document.createElement('div');banner.className='prototype-draft';
    banner.innerHTML='<span>发现一份尚未保存的草稿</span><button>忽略</button><button>恢复草稿</button>';
    const buttons=banner.querySelectorAll('button');buttons[0].onclick=()=>banner.remove();buttons[1].onclick=()=>{TexweftWorkbench.applyText(TexweftWorkbench.text+'\n\n## 尚未完成的想法\n\n把一闪而过的念头，留给下一次继续。\n');banner.remove();TexweftProto.toast('示例草稿已恢复');};
    document.querySelector('.workspace-main').prepend(banner);
  }
})();
