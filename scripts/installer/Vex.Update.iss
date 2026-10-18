[Code]
var
  VexUpdateReady, VexUpdateProceed, VexUpdateCancel: LongWord;
  VexUpdatePending: Boolean;
  VexUpdateTicks: Integer;

function VexOpenEvent(Access: LongWord; Inherit: Boolean; Name: String): LongWord;
  external 'OpenEventW@kernel32.dll stdcall';
function VexSetEvent(Handle: LongWord): Boolean;
  external 'SetEvent@kernel32.dll stdcall';
function VexWaitEvent(Handle, Milliseconds: LongWord): LongWord;
  external 'WaitForSingleObject@kernel32.dll stdcall';
function VexCloseEvent(Handle: LongWord): Boolean;
  external 'CloseHandle@kernel32.dll stdcall';

function VexValidEventName(Name, Suffix: String): Boolean;
var Base, Token: String; I: Integer;
begin
  Base:='Local\Vex.Update.';
  Result:=False;
  if (Length(Name)<>Length(Base)+32+Length(Suffix)) or (Pos(Base,Name)<>1) then exit;
  if Copy(Name,Length(Name)-Length(Suffix)+1,Length(Suffix))<>Suffix then exit;
  Token:=Copy(Name,Length(Base)+1,32);
  for I:=1 to Length(Token) do if Pos(Token[I],'0123456789abcdef')=0 then exit;
  Result:=True;
end;

<event('InitializeSetup')>
function VexUpdateInitialize: Boolean;
var ReadyName,ProceedName,CancelName,Base: String;
begin
  ReadyName:=ExpandConstant('{param:VEXUPDATEREADY|}');
  ProceedName:=ExpandConstant('{param:VEXUPDATEPROCEED|}');
  CancelName:=ExpandConstant('{param:VEXUPDATECANCEL|}');
  Result:=True;
  if (ReadyName='') and (ProceedName='') and (CancelName='') then exit;
  Result:=False;
  if WizardSilent or not VexValidEventName(ReadyName,'.Ready') or
    not VexValidEventName(ProceedName,'.Proceed') or not VexValidEventName(CancelName,'.Cancel') then exit;
  Base:=Copy(ReadyName,1,Length(ReadyName)-6);
  if (ProceedName<>Base+'.Proceed') or (CancelName<>Base+'.Cancel') then exit;
  VexUpdateReady:=VexOpenEvent(2,False,ReadyName);
  VexUpdateProceed:=VexOpenEvent($100000,False,ProceedName);
  VexUpdateCancel:=VexOpenEvent($100002,False,CancelName);
  Result:=(VexUpdateReady<>0) and (VexUpdateProceed<>0) and (VexUpdateCancel<>0);
  VexUpdatePending:=Result;
end;

<event('PrepareToInstall')>
function VexUpdatePrepare(var NeedsRestart: Boolean): String;
begin
  Result:='';
  if VexUpdatePending then Result:='Vex is waiting for the document save decision.';
end;

<event('DeinitializeSetup')>
procedure VexUpdateRelease;
begin
  if VexUpdatePending and (VexUpdateCancel<>0) then VexSetEvent(VexUpdateCancel);
  if VexUpdateReady<>0 then VexCloseEvent(VexUpdateReady);
  if VexUpdateProceed<>0 then VexCloseEvent(VexUpdateProceed);
  if VexUpdateCancel<>0 then VexCloseEvent(VexUpdateCancel);
end;
