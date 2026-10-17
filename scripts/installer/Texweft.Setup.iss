; Texweft native installer UI. Geometry and colors follow design/assets/installer.css.
; Vex native controls stay accessible and DPI-scaled at runtime.
; Inno Setup owns copying, registration, cancel/rollback and uninstall tracking.
[Setup]
DisableWelcomePage=no
DisableReadyPage=yes
DisableFinishedPage=no
ShowLanguageDialog=no
LanguageDetectionMethod=uilanguage
ChangesAssociations=yes

[Files]
Source: "assets\hero-*.bmp"; Flags: dontcopy
Source: "..\..\LICENSE"; DestName: "Texweft-License.txt"; Flags: dontcopy

[CustomMessages]
english.TWAssociation=Add Vex as an opening option for .md files
chinesesimplified.TWAssociation=在 .md 的打开方式中添加维刻
japanese.TWAssociation=.md ファイルの「プログラムから開く」に追加
english.CWMUnknownLocation=Registered location unavailable
english.CWMCurrentUser=Current user
english.CWMAllUsers=All users
chinesesimplified.CWMUnknownLocation=无法确定已注册的安装位置
chinesesimplified.CWMCurrentUser=当前用户
chinesesimplified.CWMAllUsers=所有用户
japanese.CWMUnknownLocation=登録されたインストール先が見つかりません
japanese.CWMCurrentUser=現在のユーザー
japanese.CWMAllUsers=すべてのユーザー

#include "Texweft.Win32.iss"
#include "Texweft.Registration.iss"

[Code]
var
  TWBackground, TWLogo, TWBrandLogo, TWHero, TWProgress: TBitmapImage;
  TWTitle, TWBrandName, TWBrandLabel, TWSlogan, TWSlogan2, TWBrandBottom, TWBrandAuthor, TWCaption, TWHeading,
    TWDescription, TWVersion, TWPlatform, TWBits, TWTerms, TWFooter,
    TWPathLabel, TWProgressLabel, TWPercent, TWProgressNote, TWWait,
    TWFile, TWCard, TWDescription2: TLabel;
  TWButtons: array[0..10] of TNewButton;
  TWButtonProcs, TWButtonFonts: array[0..10] of LongWord;
  TWPreviousProc, TWSurfaceBrush: LongWord;
  TWCheckProcs: array[0..1] of LongWord;
  TWCheckFont: LongWord;
  TWDesktop, TWAssociation: TNewCheckBox;
  TWLicense: TRichEditViewer;
  TWInitialized, TWExpanded, TWDark, TWMaintenance, TWRepair,
    TWModal, TWExitAllowed, TWRemoving, TWRemoved: Boolean;
  TWHeight, TWProgressValue, TWHover, TWModalAction: Integer;
  TWError, TWInstalledVersion: String;
  TWSyncCancel: Boolean;
  TWSurface, TWText, TWMuted, TWSubtle, TWLine, TWAccent,
    TWBrand, TWPanel, TWChrome, TWBrandText, TWPrimaryText: TColor;

function TWTextFor(const Chinese, English, Japanese: String): String;
begin
  if ActiveLanguage='chinesesimplified' then Result:=Chinese
  else if ActiveLanguage='japanese' then Result:=Japanese else Result:=English;
end;

function TWColor(Value: LongWord): TColor;
begin Result:=((Value and $FF) shl 16) or (Value and $FF00) or ((Value shr 16) and $FF); end;

procedure TWBounds(Control: TControl; X,Y,W,H: Integer);
begin Control.SetBounds(ScaleX(X),ScaleY(Y),ScaleX(W),ScaleY(H)); end;

procedure TWFont(Font: TFont; Pixels: Integer; Strong: Boolean);
begin
  Font.Name:='Segoe UI'; Font.Style:=[];
  if Strong then Font.Name:='Segoe UI Semibold';
  if ActiveLanguage='chinesesimplified' then begin
    Font.Name:='Microsoft YaHei UI'; if Strong then Font.Style:=[fsBold];
  end;
  Font.Height:=-ScaleY(Pixels);
end;

function TWLabel(X,Y,W,H,Size: Integer; Text: String): TLabel;
begin
  Result:=TLabel.Create(WizardForm); Result.Parent:=WizardForm;
  Result.AutoSize:=False; Result.Transparent:=True; Result.Caption:=Text;
  TWFont(Result.Font,Size,False); TWBounds(Result,X,Y,W,H);
end;

procedure TWRound(DC: LongWord; X,Y,W,H,Radius: Integer; Color: TColor; Outline: Boolean);
var Region,Brush: LongWord;
begin
  Region:=VRoundedRegion(X,Y,X+W+1,Y+H+1,ScaleX(Radius*2),ScaleY(Radius*2));
  Brush:=VBrush(Color);
  if Outline then VFrameRegion(DC,Region,Brush,ScaleX(1),ScaleY(1))
  else VFillRegion(DC,Region,Brush);
  VDeleteObject(Brush); VDeleteObject(Region);
end;

procedure TWLayout; forward;
procedure TWShowModal(Action: Integer); forward;

procedure TWToggle(Sender: TObject);
begin TWExpanded:=not TWExpanded; TWLayout; end;

procedure TWShowLicense(Sender: TObject);
begin TWShowModal(1); end;

procedure TWCancel(Sender: TObject);
begin
  if TWRemoving then exit;
  if TWModal then begin TWModal:=False; TWLayout; exit; end;
  if TWRemoved then begin
    TWExitAllowed:=True;
    WizardForm.CancelButton.OnClick(WizardForm.CancelButton); exit;
  end;
  if WizardForm.CurPageID=wpFinished then begin
    if WizardForm.RunList.Items.Count>0 then WizardForm.RunList.Checked[0]:=False;
    WizardForm.NextButton.OnClick(WizardForm.NextButton);
  end else if WizardForm.CancelButton.Enabled then WizardForm.CancelButton.OnClick(WizardForm.CancelButton);
end;

procedure TWWebsite(Sender: TObject);
var Code: Integer;
begin ShellExec('open','https://codewf.com','','',SW_SHOWNORMAL,ewNoWait,Code); end;

procedure TWPrimary(Sender: TObject);
var Code: Integer;
begin
  if TWRemoved then begin TWExitAllowed:=True; WizardForm.Close; exit; end;
  if TWMaintenance and not TWRepair then begin
    if FileExists(AddBackslash(CWMRepairPath)+'texweft.exe') then
      ShellExec('open',AddBackslash(CWMRepairPath)+'texweft.exe','',CWMRepairPath,SW_SHOWNORMAL,ewNoWait,Code);
    exit;
  end;
  if TWError<>'' then begin TWError:=''; TWLayout; end;
  WizardForm.NextButton.OnClick(WizardForm.NextButton);
end;

procedure TWRepairClick(Sender: TObject);
begin TWRepair:=True; TWPrimary(Sender); end;

procedure TWRemoveClick(Sender: TObject);
begin if not TWRemoving then TWShowModal(3); end;

procedure TWModalBack(Sender: TObject);
begin
  TWModal:=False; TWLayout;
  if TWButtons[0].Visible then WizardForm.ActiveControl:=TWButtons[0]
  else if TWButtons[5].Visible then WizardForm.ActiveControl:=TWButtons[5];
end;

procedure TWModalAccept(Sender: TObject);
var Current: TCWMRegistration; Code: Integer; Started: Boolean;
begin
  TWModal:=False;
  if TWModalAction=2 then begin
    TWExitAllowed:=True;
    if not TWSyncCancel then WizardForm.CancelButton.OnClick(WizardForm.CancelButton);
    exit;
  end;
  if TWModalAction=3 then begin
    if (CWMRegistrationCount<>1) or
      not CWMReadRegistration(CWMRegistrations[0].RootKey,CWMRegistrations[0].ScopeName,Current) or
      (Current.AppPath<>CWMRegistrations[0].AppPath) or
      (Current.UninstallCommand<>CWMRegistrations[0].UninstallCommand) or
      (Current.Uninstaller='') or not FileExists(Current.Uninstaller) then begin
      TWError:=TWTextFor('安装记录已变更，请重新打开安装器后重试。','Installation registration changed. Reopen setup.','登録情報が変わりました。セットアップを再起動してください。'); TWLayout; exit;
    end;
    TWRemoving:=True; TWLayout;
    Started:=Exec(Current.Uninstaller,'/VERYSILENT /SUPPRESSMSGBOXES /NORESTART',Current.AppPath,SW_HIDE,ewWaitUntilTerminated,Code);
    TWRemoving:=False;
    TWRemoved:=Started and (Code=0) and not RegKeyExists(Current.RootKey,CWMUninstallKey);
    if not TWRemoved then TWError:=TWTextFor('未能完成卸载。请关闭维刻后重新尝试。','Uninstall did not complete. Close Vex and retry.','アンインストールできませんでした。Vex を閉じて再試行してください。');
  end;
  TWLayout;
end;

function TWNewButton(Text: String; Handler: TNotifyEvent): TNewButton;
begin
  Result:=TNewButton.Create(WizardForm); Result.Parent:=WizardForm;
  Result.Caption:=Text; Result.OnClick:=Handler; Result.Cursor:=crHand;
end;

procedure TWPaint;
var C: TCanvas; Region,Brush: LongWord; X,Y: Integer;
begin
  TWBackground.Bitmap.Width:=WizardForm.ClientWidth; TWBackground.Bitmap.Height:=WizardForm.ClientHeight;
  C:=TWBackground.Bitmap.Canvas; C.Brush.Color:=TWSurface; C.Pen.Color:=TWSurface;
  C.Rectangle(0,0,TWBackground.Width,TWBackground.Height);
  C.Brush.Color:=TWBrand; C.Pen.Color:=TWBrand;
  C.Rectangle(0,0,ScaleX(181),ScaleY(360));
  C.Brush.Style:=bsClear; C.Pen.Color:=TWColor($D8E4DB);
  if TWDark then C.Pen.Color:=TWColor($304B3B);
  C.Ellipse(ScaleX(-179),ScaleY(150),ScaleX(261),ScaleY(590));
  C.Brush.Style:=bsSolid; C.Brush.Color:=TWSurface; C.Pen.Color:=TWSurface;
  C.Rectangle(ScaleX(181),0,WizardForm.ClientWidth,WizardForm.ClientHeight);
  if TWButtons[1].Visible then begin
    Y:=45; if TWExpanded then Y:=176;
    TWRound(C.Handle,ScaleX(209),ScaleY(82),ScaleX(402),ScaleY(Y),7,TWLine,True);
    if TWExpanded then begin
      C.Pen.Color:=TWLine; C.MoveTo(ScaleX(209),ScaleY(126));
      C.LineTo(ScaleX(611),ScaleY(126));
      TWRound(C.Handle,WizardForm.DirEdit.Left-ScaleX(8),WizardForm.DirEdit.Top-ScaleY(8),
        WizardForm.DirEdit.Width+ScaleX(16),ScaleY(37),7,TWLine,True);
    end;
  end;
  if TWCard.Visible then begin
    TWRound(C.Handle,TWCard.Left-ScaleX(12),TWCard.Top-ScaleY(12),
      TWCard.Width+ScaleX(24),TWCard.Height+ScaleY(24),8,TWPanel,False);
    TWRound(C.Handle,TWCard.Left-ScaleX(12),TWCard.Top-ScaleY(12),
      TWCard.Width+ScaleX(24),TWCard.Height+ScaleY(24),8,TWLine,True);
  end;
  if not TWModal and ((WizardForm.CurPageID=wpFinished) or TWRemoved or (TWError<>'')) then begin
    X:=392; Y:=80; if TWError<>'' then begin X:=209; Y:=46; end;
    C.Brush.Color:=TWColor($E5F0E9); if TWDark then C.Brush.Color:=TWColor($283E33);
    if TWError<>'' then C.Brush.Color:=TWColor($FAECE8);
    C.Pen.Color:=C.Brush.Color; C.Ellipse(ScaleX(X),ScaleY(Y),ScaleX(X+36),ScaleY(Y+36));
    TWFont(C.Font,20,False); C.Font.Color:=TWAccent;
    if TWError<>'' then C.TextOut(ScaleX(X+15),ScaleY(Y+4),'!') else begin
      C.Pen.Color:=TWAccent; C.Pen.Width:=ScaleX(2);
      C.MoveTo(ScaleX(X+10),ScaleY(Y+18)); C.LineTo(ScaleX(X+16),ScaleY(Y+24));
      C.LineTo(ScaleX(X+26),ScaleY(Y+12)); C.Pen.Width:=1;
    end;
  end;
  if TWModal then begin
    Y:=30; X:=300;
    if TWModalAction<>1 then begin Y:=80; X:=200; end;
    TWRound(C.Handle,ScaleX(100),ScaleY(Y),ScaleX(440),ScaleY(X),8,TWSurface,False);
    TWRound(C.Handle,ScaleX(100),ScaleY(Y),ScaleX(440),ScaleY(X),8,TWLine,True);
  end;
  Region:=VRoundedRegion(0,0,WizardForm.ClientWidth,WizardForm.ClientHeight,ScaleX(16),ScaleY(16));
  Brush:=VBrush(TWLine); VFrameRegion(C.Handle,Region,Brush,ScaleX(1),ScaleY(1));
  VDeleteObject(Brush); VDeleteObject(Region); TWBackground.Repaint;
end;

procedure TWDrawProgress;
var C: TCanvas; W,H,Center: Integer;
begin
  TWPercent.Caption:=IntToStr(TWProgressValue)+'%';
  Center:=TWProgress.Width*TWProgressValue div 100;
  if Center<TWPercent.Width div 2 then Center:=TWPercent.Width div 2;
  if Center>TWProgress.Width-TWPercent.Width div 2 then Center:=TWProgress.Width-TWPercent.Width div 2;
  TWPercent.Left:=TWProgress.Left+Center-TWPercent.Width div 2;
  W:=TWProgress.Width; H:=TWProgress.Height;
  TWProgress.Bitmap.Width:=W; TWProgress.Bitmap.Height:=H;
  C:=TWProgress.Bitmap.Canvas; C.Brush.Color:=TWSurface; C.Pen.Color:=TWSurface;
  C.Rectangle(0,0,W,H);
  TWRound(C.Handle,0,0,W-1,H-1,3,TWLine,False);
  if TWProgressValue>0 then TWRound(C.Handle,0,0,(W-1)*TWProgressValue div 100,H-1,3,TWAccent,False);
  TWProgress.Repaint;
end;

procedure TWLayout;
var Home,Installing,Finished,Main,Options,ErrorPage: Boolean; I: Integer; Region: LongWord;
begin
  if not TWInitialized then exit;
  Installing:=WizardForm.CurPageID=wpInstalling;
  Finished:=(WizardForm.CurPageID=wpFinished) or TWRemoved;
  ErrorPage:=TWError<>'';
  Home:=not Installing and not Finished and not TWMaintenance and not ErrorPage;
  Options:=Home and TWExpanded; Main:=not TWModal;
  TWHeight:=360;
  WizardForm.ClientWidth:=ScaleX(640); WizardForm.ClientHeight:=ScaleY(TWHeight);
  Region:=VRoundedRegion(0,0,WizardForm.ClientWidth,WizardForm.ClientHeight,ScaleX(16),ScaleY(16));
  if VSetRegion(WizardForm.Handle,Region,True)=0 then VDeleteObject(Region);
  TWBackground.SetBounds(0,0,WizardForm.ClientWidth,WizardForm.ClientHeight);
  WizardForm.OuterNotebook.Visible:=False; WizardForm.BackButton.Visible:=False;
  WizardForm.NextButton.Visible:=False;
  { Keep Inno's cancel query active without adding a second visible exit control. }
  { Inno checks this native button before allowing CloseQuery, even when the
    uninstall success page is drawn by us while CurPageID is still wpWelcome. }
  WizardForm.CancelButton.Visible:=WizardForm.CurPageID<>wpFinished;
  TWBounds(WizardForm.CancelButton,-200,-100,80,30); WizardForm.CancelButton.TabStop:=False;
  TWButtons[0].Visible:=Main and not Installing and not TWRemoving and not TWRemoved;
  TWButtons[0].Enabled:=True;
  TWButtons[1].Visible:=Main and Home;
  TWButtons[2].Visible:=Main and Home;
  TWButtons[3].Visible:=Main and not TWRemoving; TWButtons[4].Visible:=False;
  TWButtons[5].Visible:=Main and not TWRemoving and not Home and not Finished;
  TWButtons[5].Enabled:=not Installing or WizardForm.CancelButton.Enabled;
  TWButtons[6].Visible:=Main and Options;
  TWButtons[7].Visible:=Main and TWMaintenance and not ErrorPage and not Installing and not Finished;
  TWButtons[8].Visible:=TWButtons[7].Visible;
  TWButtons[7].Enabled:=not TWRemoving; TWButtons[8].Enabled:=not TWRemoving;
  TWButtons[9].Visible:=TWModal and (TWModalAction<>1);
  TWButtons[10].Visible:=TWModal;
  TWButtons[0].Caption:=TWTextFor('立即安装','Install now','インストール');
  if TWMaintenance then TWButtons[0].Caption:=TWTextFor('打开','Open','開く');
  if Finished then TWButtons[0].Caption:=TWTextFor('写点什么','Start writing','書き始める');
  if ErrorPage then TWButtons[0].Caption:=TWTextFor('重试','Retry','再試行');
  TWButtons[5].Caption:=TWTextFor('关闭','Close','閉じる');
  if Installing then TWButtons[5].Caption:=TWTextFor('取消安装','Cancel setup','中止');
  TWCaption.Visible:=Main and TWMaintenance and not Installing and not Finished and not ErrorPage;
  TWHeading.Visible:=Main;
  TWDescription.Visible:=Main and (Installing or Finished or ErrorPage);
  TWVersion.Visible:=False;
  TWCard.Visible:=Main and ((TWMaintenance and not Finished and not Installing) or ErrorPage);
  TWPathLabel.Visible:=False;
  TWDesktop.Visible:=Main and Options; TWAssociation.Visible:=TWDesktop.Visible;
  WizardForm.DirEdit.Visible:=TWDesktop.Visible;
  TWLicense.Visible:=TWModal and (TWModalAction=1);
  TWProgress.Visible:=Main and Installing;
  TWPercent.Visible:=TWProgress.Visible; TWProgressNote.Visible:=False; TWFile.Visible:=False;
  TWDescription2.Visible:=False; TWTerms.Visible:=False; TWPlatform.Visible:=False; TWBits.Visible:=False;
  TWFooter.Visible:=False; TWProgressLabel.Visible:=False; TWWait.Visible:=False;
  TWHeading.Caption:=TWTextFor('让想法，慢慢成形。','Room for your ideas.','想いを、かたちに。');
  TWHeading.Alignment:=taLeftJustify; TWDescription.Alignment:=taLeftJustify;
  TWBounds(TWHeading,209,29,402,33); TWBounds(TWDescription,209,75,402,51);
  TWBounds(TWCaption,209,29,402,20); TWBounds(TWCard,221,135,378,60);
  TWBounds(TWProgress,209,154,402,5); TWBounds(TWPercent,209,128,36,18);
  TWBounds(TWButtons[0],507,299,104,38); TWBounds(TWButtons[1],210,83,400,43);
  TWBounds(TWButtons[2],209,299,180,38); TWBounds(TWButtons[3],593,1,46,32);
  TWBounds(TWButtons[5],427,299,70,38); TWBounds(TWButtons[6],538,138,60,37);
  TWBounds(TWButtons[7],307,217,68,30); TWBounds(TWButtons[8],209,217,88,30);
  TWBounds(TWButtons[9],304,278,88,36); TWBounds(TWButtons[10],402,278,114,36);
  TWBounds(WizardForm.DirEdit,230,146,294,22);
  TWBounds(TWDesktop,222,189,376,24); TWBounds(TWAssociation,222,221,376,24);
  if Installing then begin
    TWBounds(TWHeading,209,34,402,33); TWBounds(TWButtons[5],521,304,90,38);
    TWHeading.Caption:=TWTextFor('正在安装','Installing','インストール中');
    if TWRepair then TWHeading.Caption:=TWTextFor('正在修复','Repairing','修復中');
    TWDescription.Caption:=TWTextFor('稍等片刻，即可开始写作。','Just a moment, then start writing.','まもなく、書き始められます。');
  end;
  if TWMaintenance and not Installing then begin
    TWBounds(TWHeading,209,63,402,33);
    TWCaption.Caption:=TWTextFor('已安装 · ','Installed · ','インストール済み · ')+TWInstalledVersion;
    TWHeading.Caption:=TWTextFor('继续你的写作。','Continue your writing.','執筆を続けましょう。');
    TWCard.Caption:=TWTextFor('安装位置','Installation folder','インストール先')+#13#10+CWMRepairPath;
  end;
  if Finished then begin
    TWHeading.Caption:=TWTextFor('一切就绪，'+#13#10+'让想法开始生长。','All set.'+#13#10+'Let your ideas grow.','準備ができました。'+#13#10+'想いを育てましょう。');
    TWDescription.Caption:=TWTextFor('你的专属 Markdown 空间已准备完毕。','Your Markdown space is ready.','あなたの Markdown 空間が整いました。');
    TWHeading.Alignment:=taCenter; TWDescription.Alignment:=taCenter;
    TWBounds(TWHeading,223,132,374,66); TWBounds(TWDescription,209,208,402,40);
    TWBounds(TWButtons[0],358,258,104,38);
    if TWRemoved then begin
      TWHeading.Caption:=TWTextFor('已移除','Removed','削除しました');
      TWDescription.Caption:=TWTextFor('你的文档保留在原来的位置。','Your documents remain in their original folders.','ドキュメントは元の場所に残ります。');
    end;
  end;
  if ErrorPage then begin
    TWBounds(TWHeading,209,98,402,33); TWBounds(TWDescription,209,139,402,51);
    TWBounds(TWCard,221,208,378,42);
    TWHeading.Caption:=TWTextFor('安装未完成','Setup did not finish','インストール未完了');
    TWDescription.Caption:=TWTextFor('检查安装位置和可用空间后重试。','Check the folder and free space, then retry.','保存先と空き容量を確認して再試行してください。');
    TWCard.Caption:=TWError;
  end;
  TWFont(TWHeading.Font,22,True); TWFont(TWDescription.Font,14,False);
  TWFont(TWCaption.Font,12,False); TWFont(TWVersion.Font,12,False);
  TWFont(TWPercent.Font,12,False); TWFont(TWProgressNote.Font,12,False);
  TWFont(TWFile.Font,12,False); TWFile.Font.Name:='Consolas';
  TWFont(TWCard.Font,14,False); TWFont(WizardForm.DirEdit.Font,14,False); TWFont(TWPathLabel.Font,14,False);
  TWLogo.Visible:=False; TWBrandLogo.Visible:=False; TWTitle.Visible:=False;
  TWBrandLabel.Visible:=False; TWSlogan.Visible:=False; TWSlogan2.Visible:=False;
  TWBrandBottom.Visible:=False; TWBrandAuthor.Visible:=False;
  TWHero.Visible:=Main; TWBrandName.Visible:=Main; TWSlogan.Visible:=Main;
  TWBounds(TWHero,63,113,56,56); TWBounds(TWBrandName,16,186,148,28);
  TWBounds(TWSlogan,16,231,148,22);
  TWBrandName.Caption:='维刻 Vex'; TWBrandName.Alignment:=taCenter; TWFont(TWBrandName.Font,20,True);
  TWSlogan.Caption:=TWTextFor('写下想法，看见脉络。','Write ideas. See connections.','想いを書き、つながりを見る。');
  TWSlogan.Alignment:=taCenter; TWFont(TWSlogan.Font,12,False); TWSlogan.Font.Color:=TWMuted;
  if ActiveLanguage<>'chinesesimplified' then TWFont(TWSlogan.Font,10,False);
  if Installing then TWDrawProgress;
  TWPaint;
  for I:=0 to 10 do if TWButtons[I].Visible then VInvalidate(TWButtons[I].Handle,0,True);
end;

procedure TWShowModal(Action: Integer);
var LicenseText: AnsiString; Format: TVCharFormat;
begin
  TWModal:=True; TWModalAction:=Action; TWLayout;
  TWCaption.Visible:=False; TWHeading.Visible:=True; TWDescription.Visible:=True;
  TWBounds(TWHeading,124,50,392,33); TWBounds(TWDescription,124,95,392,70);
  if Action<>1 then begin
    TWBounds(TWHeading,124,100,392,33); TWBounds(TWDescription,124,145,392,70);
    TWBounds(TWButtons[9],304,228,88,36); TWBounds(TWButtons[10],402,228,114,36);
  end;
  TWHeading.Alignment:=taLeftJustify; TWDescription.Alignment:=taLeftJustify;
  TWFont(TWHeading.Font,20,True);
  TWBounds(TWLicense,124,145,392,115);
  TWLicense.Visible:=Action=1;
  if Action=1 then begin
    ExtractTemporaryFile('Texweft-License.txt'); LoadStringFromFile(ExpandConstant('{tmp}\Texweft-License.txt'),LicenseText);
    TWLicense.Text:=UTF8Decode(LicenseText);
    Format[0]:=92; Format[1]:=$40000000; Format[2]:=0; Format[5]:=TWText;
    VSendCharFormat(TWLicense.Handle,$444,4,Format);
    VSend(TWLicense.Handle,$443,0,TWSurface);
    TWHeading.Caption:=TWTextFor('MIT 开源许可','MIT open source license','MIT オープンソースライセンス');
    TWDescription.Caption:=TWTextFor('允许使用、复制、修改及分发，请保留版权与许可声明。','You may use, copy, modify and distribute this software. Retain its copyright and license.','利用・複製・変更・配布ができます。著作権とライセンス表示を保持してください。');
  end else if Action=3 then begin
    TWHeading.Caption:=TWTextFor('移除维刻？','Remove Vex?','Vex をアンインストールしますか？');
    TWDescription.Caption:=TWTextFor('将移除应用程序。独立保存在文件夹中的文档将保留。','The application will be removed. Your documents will remain in their original folders.','アプリを削除します。フォルダー内のドキュメントは保持されます。');
  end else begin
    TWHeading.Caption:=TWTextFor('退出安装？','Exit setup?','セットアップを終了しますか？');
    TWDescription.Caption:=TWTextFor('当前操作将停止。你可以随时重新打开这个安装包。','The current operation will stop. You can run this installer again at any time.','現在の操作を中止します。このインストーラーはいつでも再実行できます。');
  end;
  TWButtons[10].Caption:=TWTextFor('知道了','Got it','閉じる');
  TWButtons[9].Caption:=TWTextFor('留下','Stay','続ける');
  if Action=2 then TWButtons[10].Caption:=TWTextFor('退出','Exit','終了');
  if (Action=2) and (WizardForm.CurPageID=wpInstalling) then begin
    TWButtons[9].Caption:=TWTextFor('继续','Continue','続ける');
    TWButtons[10].Caption:=TWTextFor('取消操作','Cancel operation','操作を中止');
  end;
  if Action=3 then TWButtons[10].Caption:=TWTextFor('确认移除','Remove','アンインストール');
  if Action=3 then TWButtons[9].Caption:=TWTextFor('取消','Cancel','キャンセル');
  WizardForm.ActiveControl:=TWButtons[10];
end;

function TWButtonProc(Window,Message,WParam,LParam: LongWord): Longint;
var I: Integer;
begin
  if Message=$00F4 then WParam:=(WParam and not $F) or $B;
  if Message=$000F then VSetLong(Window,-16,(VGetLong(Window,-16) and not $F) or $B);
  for I:=0 to 10 do if (TWButtons[I]<>nil) and (Window=TWButtons[I].Handle) then begin
    Result:=VCallProc(TWButtonProcs[I],Window,Message,WParam,LParam);
    if (Message=$0007) or (Message=$0008) then VInvalidate(Window,0,False);
    exit;
  end;
  Result:=0;
end;

function TWCheckProc(Window,Message,WParam,LParam: LongWord): Longint;
var Index: Integer; Check: TNewCheckBox; DC,Brush,Pen,Previous,Font: LongWord; Paint: TVPaint; Bounds: TVRect;
begin
  Index:=0; Check:=TWDesktop; if Window=TWAssociation.Handle then begin Index:=1; Check:=TWAssociation; end;
  if (Message=$000F) or (Message=$0317) or (Message=$0318) then begin
    if Message=$000F then DC:=VBeginPaint(Window,Paint) else DC:=WParam;
    Bounds.Left:=0; Bounds.Top:=0; Bounds.Right:=Check.Width; Bounds.Bottom:=Check.Height;
    Brush:=VBrush(TWSurface); VFill(DC,Bounds,Brush); VDeleteObject(Brush);
    TWRound(DC,0,ScaleY(5),ScaleX(14),ScaleY(14),2,TWSurface,False);
    TWRound(DC,0,ScaleY(5),ScaleX(14),ScaleY(14),2,TWMuted,True);
    if Check.Checked then begin
      TWRound(DC,0,ScaleY(5),ScaleX(14),ScaleY(14),2,TWAccent,False);
      Pen:=VCreatePen(0,ScaleX(2),TWPrimaryText); Previous:=VSelectObject(DC,Pen);
      VMove(DC,ScaleX(3),ScaleY(12),0); VLineTo(DC,ScaleX(6),ScaleY(15)); VLineTo(DC,ScaleX(11),ScaleY(9));
      VSelectObject(DC,Previous); VDeleteObject(Pen);
    end;
    VTextColor(DC,TWMuted); VTextMode(DC,1); Font:=VSelectObject(DC,TWCheckFont);
    Bounds.Left:=ScaleX(22); VDrawText(DC,Check.Caption,-1,Bounds,$24); VSelectObject(DC,Font);
    if VGetFocus=Window then TWRound(DC,1,1,Check.Width-3,Check.Height-3,3,TWAccent,True);
    if Message=$000F then VEndPaint(Window,Paint); Result:=0; exit;
  end;
  Result:=VCallProc(TWCheckProcs[Index],Window,Message,WParam,LParam);
end;

procedure TWDrawChevron(DC: LongWord; X,Y: Integer; Expanded: Boolean; Color: TColor);
var Pen,Previous: LongWord; Direction: Integer;
begin
  Direction:=1; if Expanded then Direction:=-1;
  Pen:=VCreatePen(0,ScaleX(2),Color); Previous:=VSelectObject(DC,Pen);
  VMove(DC,X-ScaleX(5),Y-ScaleY(2)*Direction,0);
  VLineTo(DC,X,Y+ScaleY(3)*Direction);
  VLineTo(DC,X+ScaleX(5),Y-ScaleY(2)*Direction);
  VSelectObject(DC,Previous); VDeleteObject(Pen);
end;

procedure TWDrawClose(DC: LongWord; X,Y: Integer; Color: TColor);
var Pen,Previous: LongWord;
begin
  Pen:=VCreatePen(0,ScaleX(1),Color); Previous:=VSelectObject(DC,Pen);
  VMove(DC,X-ScaleX(4),Y-ScaleY(4),0); VLineTo(DC,X+ScaleX(4),Y+ScaleY(4));
  VMove(DC,X+ScaleX(4),Y-ScaleY(4),0); VLineTo(DC,X-ScaleX(4),Y+ScaleY(4));
  VSelectObject(DC,Previous); VDeleteObject(Pen);
end;

function TWWindowProc(Window,Message,WParam,LParam: LongWord): Longint;
var Item: TVDrawItem; I,X,Y,Hover: Integer; Bounds: TVRect; Brush,Color,Foreground,Previous: LongWord; Point: TVPoint;
begin
  if (Message=$0112) and ((WParam and $FFF0)=$F060) then begin
    TWCancel(WizardForm); Result:=0; exit;
  end;
  if Message=$0084 then begin
    VGetRect(Window,Bounds); X:=LParam and $FFFF; if X>=$8000 then X:=X-$10000;
    Y:=(LParam shr 16) and $FFFF; if Y>=$8000 then Y:=Y-$10000;
    if (Y-Bounds.Top<ScaleY(28)) and (X-Bounds.Left<ScaleX(593)) then begin Result:=2; exit; end;
  end;
  if Message=$002B then begin
    VCopyItem(Item,LParam,48);
    for I:=0 to 10 do if (TWButtons[I]<>nil) and (Item.ItemWindow=TWButtons[I].Handle) then begin
      Bounds:=Item.Bounds; Color:=TWSurface; Foreground:=TWMuted;
      if I=3 then Color:=TWChrome;
      if (I=0) or (I=10) then begin Color:=TWAccent; Foreground:=TWPrimaryText; end;
      if I=2 then Foreground:=TWAccent;
      if (I=TWHover) or ((Item.ItemState and 1)<>0) then begin
        Color:=TWPanel;
        if (I=0) or (I=10) then begin
          Color:=TWColor($1C6158);
          if TWDark then Color:=TWColor($A9D7C8);
        end;
        if I=3 then begin Color:=TWColor($C42B1C); Foreground:=clWhite; end;
      end;
      Brush:=VBrush(TWSurface); if I=3 then begin VDeleteObject(Brush); Brush:=VBrush(TWChrome); end;
      VFill(Item.DC,Bounds,Brush); VDeleteObject(Brush);
      if I=1 then TWBitBlt(Item.DC,0,0,Bounds.Right,Bounds.Bottom,TWBackground.Bitmap.Canvas.Handle,TWButtons[I].Left,TWButtons[I].Top,$00CC0020);
      if I=3 then begin Brush:=VBrush(Color); VFill(Item.DC,Bounds,Brush); VDeleteObject(Brush); end
      else if I<>1 then TWRound(Item.DC,0,0,Bounds.Right-1,Bounds.Bottom-1,7,Color,False);
      if I=6 then TWRound(Item.DC,0,0,Bounds.Right-1,Bounds.Bottom-1,8,TWLine,True);
      VTextColor(Item.DC,Foreground); VTextMode(Item.DC,1); Previous:=VSelectObject(Item.DC,TWButtonFonts[I]);
      if I=1 then begin
        Bounds.Left:=ScaleX(14); VDrawText(Item.DC,TWButtons[I].Caption,-1,Bounds,$24);
        TWDrawChevron(Item.DC,Bounds.Right-ScaleX(28),Bounds.Bottom div 2,TWExpanded,TWMuted);
      end
      else if I=2 then VDrawText(Item.DC,TWButtons[I].Caption,-1,Bounds,$24)
      else if I=3 then TWDrawClose(Item.DC,Bounds.Right div 2,Bounds.Bottom div 2,Foreground)
      else if I=4 then VDrawText(Item.DC,TWButtons[I].Caption,-1,Bounds,$26)
      else VDrawText(Item.DC,TWButtons[I].Caption,-1,Bounds,$25);
      VSelectObject(Item.DC,Previous);
      if ((Item.ItemState and $10)<>0) and ((Item.ItemState and $200)=0) then
        TWRound(Item.DC,2,2,Bounds.Right-5,Bounds.Bottom-5,6,TWAccent,True);
      Result:=1; exit;
    end;
  end;
  if (Message=$0113) and (WParam=41) and TWInitialized then begin
    Hover:=-1;
    if VCursor(Point) then for I:=0 to 10 do if TWButtons[I].Visible and TWButtons[I].Enabled then begin
      VGetRect(TWButtons[I].Handle,Bounds);
      if (Point.X>=Bounds.Left) and (Point.X<Bounds.Right) and (Point.Y>=Bounds.Top) and (Point.Y<Bounds.Bottom) then Hover:=I;
    end;
    if Hover<>TWHover then begin I:=TWHover; TWHover:=Hover; if I>=0 then VInvalidate(TWButtons[I].Handle,0,False); if Hover>=0 then VInvalidate(TWButtons[Hover].Handle,0,False); end;
  end;
  Result:=VCallProc(TWPreviousProc,Window,Message,WParam,LParam);
end;

<event('InitializeWizard')>
procedure TWInitialize;
var I,Pixels,Weight: Integer; Face,Theme,Suffix: String; Light: Cardinal;
begin
  if WizardSilent then exit;
  TWDark:=False; Theme:=ExpandConstant('{param:THEME|system}');
  if Theme='dark' then TWDark:=True;
  if (Theme='system') and RegQueryDWordValue(HKCU,'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize','AppsUseLightTheme',Light) then TWDark:=Light=0;
  TWSurface:=clWhite; TWChrome:=TWColor($F8F9F6); TWBrand:=TWColor($E8EEE5); TWText:=TWColor($253831);
  TWMuted:=TWColor($617269); TWSubtle:=TWColor($A4AEA7); TWLine:=TWColor($E5EAE3);
  TWAccent:=TWColor($24766B); TWPanel:=TWColor($F3F5F1); TWBrandText:=TWColor($254536); TWPrimaryText:=clWhite;
  if TWDark then begin
    TWSurface:=TWColor($1C2923); TWChrome:=TWColor($17221E); TWBrand:=TWColor($243A2D); TWText:=TWColor($DCE6DE);
    TWMuted:=TWColor($90A196); TWSubtle:=TWColor($63796B); TWLine:=TWColor($2C3B32);
    TWAccent:=TWColor($8AC8B3); TWPanel:=TWColor($202D27); TWBrandText:=TWColor($C9DECF); TWPrimaryText:=TWColor($132820);
  end;
  CWMReadScope(False,True);
  TWMaintenance:=CWMRepairPath<>'';
  if TWMaintenance then begin
    WizardForm.DirEdit.Text:=CWMRepairPath;
    RegQueryStringValue(CWMRegistrations[0].RootKey,CWMUninstallKey,'DisplayVersion',TWInstalledVersion);
    if TWInstalledVersion<>'{#AppVersion}' then TWMaintenance:=False;
  end;
  WizardForm.BorderStyle:=bsNone; WizardForm.Position:=poScreenCenter;
  #ifdef InstallerTest
  #ifdef InstallerAutomation
  { Isolated screenshot checks must not take keyboard focus from the developer. }
  VSetLong(WizardForm.Handle,-20,VGetLong(WizardForm.Handle,-20) or $08000000);
  #endif
  #endif
  WizardForm.ClientWidth:=ScaleX(640); WizardForm.ClientHeight:=ScaleY(360);
  WizardForm.Color:=TWSurface; TWHover:=-1;
  VSetClassLong(WizardForm.Handle,-26,VGetClassLong(WizardForm.Handle,-26) or $20000);
  WizardForm.MainPanel.Visible:=False; WizardForm.Bevel.Visible:=False; WizardForm.Bevel1.Visible:=False;
  WizardForm.BeveledLabel.Visible:=False; WizardForm.WizardBitmapImage.Visible:=False; WizardForm.WizardBitmapImage2.Visible:=False;
  TWBackground:=TBitmapImage.Create(WizardForm); TWBackground.Parent:=WizardForm; TWBackground.SendToBack;
  TWLogo:=TBitmapImage.Create(WizardForm); TWLogo.Parent:=WizardForm; TWLogo.Stretch:=True; TWBounds(TWLogo,15,11,17,17);
  TWBrandLogo:=TBitmapImage.Create(WizardForm); TWBrandLogo.Parent:=WizardForm; TWBrandLogo.Stretch:=True; TWBounds(TWBrandLogo,37,79,28,28);
  TWHero:=TBitmapImage.Create(WizardForm); TWHero.Parent:=WizardForm; TWHero.Stretch:=True;
  Suffix:='light'; if TWDark then Suffix:='dark';
  ExtractTemporaryFile('hero-'+Suffix+'.bmp'); TWHero.Bitmap.LoadFromFile(ExpandConstant('{tmp}\hero-'+Suffix+'.bmp'));
  TWTitle:=TWLabel(40,13,600,16,10,'Vex'); TWTitle.Font.Color:=TWMuted;
  TWBrandName:=TWLabel(37,284,218,48,36,'Vex'); TWBrandName.Font.Color:=TWBrandText;
  TWBrandLabel:=TWLabel(75,87,180,20,12,'维刻 Vex'); TWBrandLabel.Font.Color:=TWBrandText;
  TWSlogan:=TWLabel(37,355,218,26,17,TWTextFor('落笔成文，','Words take shape.','ことばを紡ぎ、'));
  TWSlogan.Font.Name:='SimSun'; TWSlogan.Font.Color:=TWColor($56735E);
  TWSlogan2:=TWLabel(37,387,218,26,17,TWTextFor('思路成形。','Ideas find their way.','想いをかたちに。')); TWSlogan2.Font.Name:='SimSun'; TWSlogan2.Font.Color:=TWColor($56735E);
  TWBrandBottom:=TWLabel(37,453,218,20,9,TWTextFor('一个安静的 Markdown 写作空间','A quiet space for Markdown writing','静かな Markdown 執筆空間')); TWBrandBottom.Font.Color:=TWColor($7B9481);
  TWBrandAuthor:=TWLabel(37,471,218,20,9,'沙漠尽头的狼 / CodeWF'); TWBrandAuthor.Font.Color:=TWColor($7B9481);
  TWCaption:=TWLabel(348,82,447,15,9,''); TWCaption.Font.Color:=TWMuted;
  TWHeading:=TWLabel(335,121,460,40,25,''); TWFont(TWHeading.Font,25,True); TWHeading.Font.Color:=TWText;
  TWDescription:=TWLabel(335,174,350,49,12,''); TWDescription.WordWrap:=True; TWDescription.Font.Color:=TWMuted;
  TWDescription2:=TWLabel(335,201,350,20,12,''); TWDescription2.Font.Color:=TWMuted;
  TWPlatform:=TWLabel(345,249,74,15,9,'Windows 10 / 11'); TWPlatform.Font.Color:=TWMuted;
  TWBits:=TWLabel(439,249,34,15,9,TWTextFor('64 位','64-bit','64 ビット')); TWBits.Font.Color:=TWMuted;
  TWVersion:=TWLabel(487,249,60,15,9,'{#AppVersion}'); TWVersion.Font.Color:=TWMuted;
  TWTerms:=TWLabel(335,366,460,18,9,TWTextFor('安装即表示你已阅读','By installing you accept','インストールすると同意します：')); TWTerms.Font.Color:=TWSubtle;
  TWFooter:=TWLabel(335,492,250,16,9,'CodeWF · {#AppVersion}'); TWFooter.Font.Color:=TWSubtle;
  TWPathLabel:=TWLabel(351,360,400,14,10,TWTextFor('安装位置','Installation folder','インストール先')); TWPathLabel.Font.Color:=TWMuted;
  TWProgressLabel:=TWLabel(335,245,350,18,11,TWTextFor('正在安装','Installing','インストール中')); TWProgressLabel.Font.Color:=TWMuted;
  TWPercent:=TWLabel(209,128,36,18,12,'0%'); TWPercent.Alignment:=taCenter; TWPercent.Font.Color:=TWAccent;
  TWProgress:=TBitmapImage.Create(WizardForm); TWProgress.Parent:=WizardForm; TWBounds(TWProgress,335,271,460,5);
  TWProgressNote:=TWLabel(335,288,350,15,9,TWTextFor('准备应用文件','Preparing application files','アプリファイルを準備中')); TWProgressNote.Font.Color:=TWMuted;
  TWWait:=TWLabel(735,288,60,15,9,TWTextFor('请稍候','Please wait','しばらくお待ちください')); TWWait.Alignment:=taRightJustify; TWWait.Font.Color:=TWMuted;
  TWFile:=TWLabel(335,323,460,55,10,''); TWFile.WordWrap:=True; TWFile.Font.Name:='Consolas'; TWFile.Font.Color:=TWSubtle;
  TWCard:=TWLabel(350,272,430,56,11,''); TWCard.WordWrap:=True; TWCard.Font.Color:=TWMuted;
  TWButtons[0]:=TWNewButton('',@TWPrimary);
  TWButtons[1]:=TWNewButton(TWTextFor('自定义安装选项','Custom installation options','インストールオプション'),@TWToggle);
  TWButtons[2]:=TWNewButton(TWTextFor('基于 MIT 协议开源','Open source under MIT','MIT ライセンス'),@TWShowLicense);
  TWButtons[3]:=TWNewButton(TWTextFor('关闭','Close','閉じる'),@TWCancel); TWBounds(TWButtons[3],785,520,50,32);
  TWButtons[4]:=TWNewButton('codewf.com ↗',@TWWebsite);
  TWButtons[5]:=TWNewButton('',@TWCancel);
  TWButtons[6]:=WizardForm.DirBrowseButton; TWButtons[6].Parent:=WizardForm; TWButtons[6].Caption:=TWTextFor('浏览…','Browse…','参照…'); TWBounds(TWButtons[6],710,378,69,31);
  TWButtons[7]:=TWNewButton(TWTextFor('卸载','Uninstall','削除'),@TWRemoveClick);
  TWButtons[8]:=TWNewButton(TWTextFor('修复安装','Repair','修復'),@TWRepairClick);
  TWButtons[9]:=TWNewButton(TWTextFor('留下','Stay','続ける'),@TWModalBack); TWBounds(TWButtons[9],596,431,72,37);
  TWButtons[10]:=TWNewButton('',@TWModalAccept); TWBounds(TWButtons[10],676,431,119,37);
  WizardForm.DirEdit.Parent:=WizardForm; WizardForm.DirEdit.BorderStyle:=bsNone; TWFont(WizardForm.DirEdit.Font,10,False); TWBounds(WizardForm.DirEdit,360,386,335,17);
  TWDesktop:=TNewCheckBox.Create(WizardForm); TWDesktop.Parent:=WizardForm; TWDesktop.Caption:=TWTextFor('创建桌面快捷方式','Create desktop shortcut','デスクトップにショートカットを作成'); TWBounds(TWDesktop,351,430,425,20);
  TWAssociation:=TNewCheckBox.Create(WizardForm); TWAssociation.Parent:=WizardForm; TWAssociation.Caption:=CustomMessage('TWAssociation'); TWBounds(TWAssociation,351,459,425,20);
  TWDesktop.Color:=TWSurface; TWAssociation.Color:=TWSurface; TWFont(TWDesktop.Font,10,False); TWFont(TWAssociation.Font,10,False); TWDesktop.Font.Color:=TWMuted; TWAssociation.Font.Color:=TWMuted;
  TWDesktop.Checked:=True; TWAssociation.Checked:=True;
  TWLicense:=TRichEditViewer.Create(WizardForm); TWLicense.Parent:=WizardForm; TWLicense.ReadOnly:=True; TWLicense.ScrollBars:=ssVertical; TWLicense.BorderStyle:=bsNone; TWLicense.Color:=TWSurface; TWLicense.Font.Color:=TWText; TWFont(TWLicense.Font,11,False); TWBounds(TWLicense,335,225,460,175);
  TWPreviousProc:=VSetLong(WizardForm.Handle,-4,CreateCallback(@TWWindowProc));
  for I:=0 to 10 do begin
    Pixels:=13; Weight:=400; Face:='Segoe UI';
    if ActiveLanguage='chinesesimplified' then Face:='Microsoft YaHei UI';
    if (I=0) or (I=10) then Weight:=600;
    if (I=7) or (I=8) then Pixels:=12;
    if (I=2) or (I=4) then Pixels:=12;
    if I=3 then Pixels:=16;
    TWButtonFonts[I]:=VCreateFont(-ScaleY(Pixels),0,0,0,Weight,0,0,0,1,0,0,4,0,Face);
    VSetLong(TWButtons[I].Handle,-16,(VGetLong(TWButtons[I].Handle,-16) and not $F) or $B);
    TWButtonProcs[I]:=VSetLong(TWButtons[I].Handle,-4,CreateCallback(@TWButtonProc));
  end;
  TWCheckFont:=VCreateFont(-ScaleY(14),0,0,0,400,0,0,0,1,0,0,4,0,Face);
  TWCheckProcs[0]:=VSetLong(TWDesktop.Handle,-4,CreateCallback(@TWCheckProc));
  TWCheckProcs[1]:=VSetLong(TWAssociation.Handle,-4,CreateCallback(@TWCheckProc));
  TWSurfaceBrush:=VBrush(TWSurface); TWInitialized:=True; TWLayout; VSetTimer(WizardForm.Handle,41,50,0);
end;

<event('ShouldSkipPage')>
function TWSkip(PageID: Integer): Boolean;
var Tasks: String;
begin
  if TWInitialized and (PageID=wpSelectTasks) then begin
    Tasks:='!desktopicon'; if TWDesktop.Checked then Tasks:='desktopicon';
    if TWAssociation.Checked then Tasks:=Tasks+',markdownassociation' else Tasks:=Tasks+',!markdownassociation';
    WizardSelectTasks(Tasks);
  end;
  Result:=(PageID=wpLicense) or (PageID=wpSelectDir) or (PageID=wpSelectTasks);
end;

<event('NextButtonClick')>
function TWNext(PageID: Integer): Boolean;
var Path,WindowsPath,Probe: String;
begin
  Result:=True;
  if WizardSilent or (PageID<>wpWelcome) then exit;
  Path:=CWMNormalizePath(Trim(WizardForm.DirEdit.Text)); WindowsPath:=Lowercase(AddBackslash(ExpandConstant('{win}')));
  if (Path='') or (Pos(WindowsPath,Lowercase(AddBackslash(Path)))=1) then
    TWError:=TWTextFor('请选择有效的本地绝对路径，不能使用系统目录或磁盘根目录。','Choose a local absolute folder outside Windows and the drive root.','Windows フォルダーやドライブ直下以外の絶対パスを指定してください。')
  else if not ForceDirectories(Path) then TWError:=TWTextFor('目标文件夹无法创建，请更换安装位置。','Cannot create the destination folder. Choose another location.','インストール先を作成できません。別の場所を指定してください。')
  else begin
    SetLength(Probe,260);
    if TWTempFile(Path,'TW',0,Probe)=0 then TWError:=TWTextFor('目标文件夹不可写，请更换安装位置。','The destination is not writable. Choose another folder.','インストール先に書き込めません。別の場所を指定してください。')
    else begin SetLength(Probe,Pos(#0,Probe)-1); DeleteFile(Probe); end;
  end;
  if TWError<>'' then begin TWExpanded:=True; TWLayout; Result:=False; exit; end;
  WizardForm.DirEdit.Text:=Path;
end;

<event('CurPageChanged')>
procedure TWPageChanged(PageID: Integer);
begin if TWInitialized then TWLayout; end;

<event('CurInstallProgressChanged')>
procedure TWProgressChanged(Current,Maximum: Integer);
begin
  if not TWInitialized or (Maximum<=0) then exit;
  TWProgressValue:=Round(Current*100.0/Maximum);
  TWDrawProgress;
end;

<event('CancelButtonClick')>
procedure TWCancelQuery(PageID: Integer; var Cancel,Confirm: Boolean);
var Message: TWMessage;
begin
  if WizardSilent then exit;
  Confirm:=False;
  if TWRemoved or (TWError<>'') then begin Cancel:=True; exit; end;
  if TWExitAllowed then begin Cancel:=True; exit; end;
  if TWModal then begin TWModal:=False; TWLayout; Cancel:=False; exit; end;
  TWSyncCancel:=True; TWShowModal(2);
  { Keep the engine paused while the real native confirmation is displayed. }
  while TWModal do begin
    if TWPeekMessage(Message,0,0,0,1) then begin
      if not TWDialogMessage(WizardForm.Handle,Message) then begin
        TWTranslateMessage(Message); TWDispatchMessage(Message);
      end;
    end else TWWaitMessage;
  end;
  TWSyncCancel:=False; Cancel:=TWExitAllowed;
  if not Cancel then TWLayout;
end;

<event('DeinitializeSetup')>
procedure TWRelease;
var I: Integer;
begin
  if not TWInitialized then exit;
  TWInitialized:=False; VKillTimer(WizardForm.Handle,41);
  if TWPreviousProc<>0 then VSetLong(WizardForm.Handle,-4,TWPreviousProc);
  for I:=0 to 10 do begin
    if VIsWindow(TWButtons[I].Handle) then VSetLong(TWButtons[I].Handle,-4,TWButtonProcs[I]);
    if TWButtonFonts[I]<>0 then VDeleteObject(TWButtonFonts[I]);
  end;
  if TWSurfaceBrush<>0 then VDeleteObject(TWSurfaceBrush);
  if VIsWindow(TWDesktop.Handle) then VSetLong(TWDesktop.Handle,-4,TWCheckProcs[0]);
  if VIsWindow(TWAssociation.Handle) then VSetLong(TWAssociation.Handle,-4,TWCheckProcs[1]);
  if TWCheckFont<>0 then VDeleteObject(TWCheckFont);
end;
