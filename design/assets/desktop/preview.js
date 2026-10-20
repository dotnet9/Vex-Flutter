/* 评审参数不进入产品菜单。 */
(function () {
  const query=new URLSearchParams(location.search);
  document.body.dataset.platform=query.get('platform')||'windows';
  const language={zh:'zh-CN',en:'en-US'}[query.get('lang')]||query.get('lang');
  if(language)VexL.set(language);
  if(query.get('scenario')==='guide')setTimeout(()=>VexGuide.start({automatic:true}),250);
  if(query.get('scenario')==='exit-unsaved')setTimeout(()=>VexProto.previewUnsavedExit(),100);
  if(query.get('scenario')==='draft'){
    const banner=document.createElement('div');banner.className='prototype-draft';
    banner.innerHTML='<span></span><button>保留当前内容</button><button>恢复示例草稿</button>';
    banner.querySelector('span').textContent='发现「'+VexWorkbench.name+'」的示例草稿 · 比当前内容多一个未完成章节；恢复后仍需保存副本。';
    const buttons=banner.querySelectorAll('button');buttons[0].onclick=()=>banner.remove();buttons[1].onclick=()=>{VexWorkbench.documents[VexWorkbench.state.doc].recovered=true;VexWorkbench.applyText(VexWorkbench.text+'\n\n## 尚未完成的想法\n\n把一闪而过的念头，留给下一次继续。\n');banner.remove();VexProto.toast('示例草稿已恢复，尚未保存副本；可撤销恢复操作');};
    document.querySelector('.workspace-main').prepend(banner);
  }
})();
