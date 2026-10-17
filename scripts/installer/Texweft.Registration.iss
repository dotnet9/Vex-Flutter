[Code]
// Adapted from Vex (MIT), Copyright (c) 2026 码坊 CodeWF.
// See VEX-LICENSE.txt. Only this product's exact registration is read.
type
  TCWMRegistration = record
    RootKey: Integer;
    ScopeName, AppPath, UninstallCommand, Uninstaller: String;
  end;

var
  CWMRegistrations: array[0..3] of TCWMRegistration;
  CWMRegistrationCount: Integer;
  CWMRepairPath: String;

function CWMUninstallKey: String;
begin
  // 仅还原 Inno 的 {{ 转义一次；保留真实 AppId 的右花括号，不猜测或模糊匹配 GUID。
  Result := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\' +
    ExpandConstant('{#SetupSetting("AppId")}') + '_is1';
end;

function CWMIsLocalAbsolutePath(const Value: String): Boolean;
var Drive: String;
begin
  Result := False;
  if Length(Value) < 4 then exit;
  Drive := Uppercase(Copy(Value, 1, 1));
  Result := (Drive >= 'A') and (Drive <= 'Z') and
    (Copy(Value, 2, 2) = ':\') and (Pos('"', Value) = 0) and
    (Pos(#13, Value) = 0) and (Pos(#10, Value) = 0) and (Pos(#0, Value) = 0);
end;

function CWMNormalizePath(const Value: String): String;
begin
  Result := '';
  if not CWMIsLocalAbsolutePath(Value) then exit;
  try
    Result := RemoveBackslashUnlessRoot(ExpandFileName(Value));
  except
    Result := '';
  end;
  // 根目录不是可接受的本产品安装目录。
  if Length(Result) <= 3 then Result := '';
end;

function CWMParseUninstaller(const Command, RegisteredPath: String; var Executable: String): Boolean;
var Name, Digits, Candidate, Directory: String; I: Integer;
begin
  Result := False;
  Executable := '';
  Candidate := Trim(Command);
  if Candidate = '' then exit;
  if Copy(Candidate, 1, 1) = '"' then begin
    // 标准 Inno UninstallString 只有带引号的可执行路径，不接受尾参或 shell 命令。
    if (Length(Candidate) < 3) or (Copy(Candidate, Length(Candidate), 1) <> '"') then exit;
    Candidate := Copy(Candidate, 2, Length(Candidate) - 2);
  end;
  Candidate := CWMNormalizePath(Candidate);
  Directory := CWMNormalizePath(RegisteredPath);
  if (Candidate = '') or (Directory = '') then exit;
  if CompareText(RemoveBackslashUnlessRoot(ExtractFileDir(Candidate)), Directory) <> 0 then exit;
  Name := Lowercase(ExtractFileName(Candidate));
  if (Copy(Name, 1, 5) <> 'unins') or (ExtractFileExt(Name) <> '.exe') then exit;
  Digits := Copy(Name, 6, Length(Name) - 9);
  if Digits = '' then exit;
  for I := 1 to Length(Digits) do
    if (Digits[I] < '0') or (Digits[I] > '9') then exit;
  Executable := Candidate;
  Result := True;
end;

function CWMReadRegistration(RootKey: Integer; const ScopeName: String; var Entry: TCWMRegistration): Boolean;
var Key, Location, InnoPath: String;
begin
  Result := False;
  Entry.RootKey := RootKey;
  Entry.ScopeName := ScopeName;
  Entry.AppPath := '';
  Entry.UninstallCommand := '';
  Entry.Uninstaller := '';
  // 所有开发夹具在编译时移除真实注册探测，不能由命令行重新启用。
  #ifndef CodeWFSetupFixture
    try
      Key := CWMUninstallKey;
      if not RegKeyExists(RootKey, Key) then exit;
      Result := True;
      RegQueryStringValue(RootKey, Key, 'UninstallString', Entry.UninstallCommand);
      RegQueryStringValue(RootKey, Key, 'InstallLocation', Location);
      RegQueryStringValue(RootKey, Key, 'Inno Setup: App Path', InnoPath);
      Entry.AppPath := CWMNormalizePath(InnoPath);
      if Entry.AppPath = '' then Entry.AppPath := CWMNormalizePath(Location);
      // 非空位置异常或两个位置不一致时只允许修复，不启动卸载器。
      if (InnoPath <> '') and (CWMNormalizePath(InnoPath) = '') then exit;
      if (Location <> '') and ((CWMNormalizePath(Location) = '') or
        (CompareText(CWMNormalizePath(Location), Entry.AppPath) <> 0)) then exit;
      CWMParseUninstaller(Entry.UninstallCommand, Entry.AppPath, Entry.Uninstaller);
    except
      Log('CodeWF maintenance: registration could not be read.');
    end;
  #endif
end;

procedure CWMAddRegistration(RootKey: Integer; const ScopeName: String; CurrentScope: Boolean);
var Entry: TCWMRegistration; I: Integer;
begin
  if CWMRegistrationCount >= 4 then exit;
  if not CWMReadRegistration(RootKey, ScopeName, Entry) then exit;
  // 32/64 位视图可能指向同一卸载器；同一作用域不重复展示。
  for I := 0 to CWMRegistrationCount - 1 do
    if (Entry.ScopeName = CWMRegistrations[I].ScopeName) and
      (Entry.AppPath <> '') and (CompareText(Entry.AppPath, CWMRegistrations[I].AppPath) = 0) and
      (CompareText(Entry.UninstallCommand, CWMRegistrations[I].UninstallCommand) = 0) then exit;
  CWMRegistrations[CWMRegistrationCount] := Entry;
  CWMRegistrationCount := CWMRegistrationCount + 1;
  if CurrentScope and (CWMRepairPath = '') and (Entry.AppPath <> '') then
    CWMRepairPath := Entry.AppPath;
end;

procedure CWMReadScope(MachineScope, CurrentScope: Boolean);
var ScopeName: String;
begin
  if MachineScope then ScopeName := CustomMessage('CWMAllUsers')
  else ScopeName := CustomMessage('CWMCurrentUser');
  if IsWin64 and Is64BitInstallMode then begin
    if MachineScope then CWMAddRegistration(HKLM64, ScopeName, CurrentScope)
    else CWMAddRegistration(HKCU64, ScopeName, CurrentScope);
  end;
  if MachineScope then CWMAddRegistration(HKLM32, ScopeName, CurrentScope)
  else CWMAddRegistration(HKCU32, ScopeName, CurrentScope);
  if IsWin64 and not Is64BitInstallMode then begin
    if MachineScope then CWMAddRegistration(HKLM64, ScopeName, CurrentScope)
    else CWMAddRegistration(HKCU64, ScopeName, CurrentScope);
  end;
end;

function CWMDisplayPath(const Value: String): String;
begin
  if Value = '' then Result := CustomMessage('CWMUnknownLocation')
  else Result := Value;
end;

