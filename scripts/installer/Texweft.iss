; Compile through scripts/package_windows.ps1. AppId stays stable across upgrades.
#ifndef AppVersion
  #error AppVersion is required
#endif
#ifndef SourceDir
  #error SourceDir is required
#endif
#ifndef OutputDir
  #error OutputDir is required
#endif

[Setup]
AppId={{51E79E85-AD4C-4D48-92EC-C1EA09FB4E56}
AppName=Texweft
AppVersion={#AppVersion}
AppPublisher=CodeWF
AppPublisherURL=https://codewf.com
AppSupportURL=https://github.com/dotnet9/texweft/issues
AppUpdatesURL=https://github.com/dotnet9/texweft/releases
DefaultDirName={localappdata}\Programs\Texweft
DefaultGroupName=Texweft
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
DisableProgramGroupPage=yes
WizardStyle=modern
SetupIconFile=..\..\logo.ico
LicenseFile=..\..\LICENSE
UninstallDisplayIcon={app}\texweft.exe
OutputDir={#OutputDir}
OutputBaseFilename=Texweft-v{#AppVersion}-windows-x64-setup
Compression=lzma2
SolidCompression=yes
CloseApplications=yes
CloseApplicationsFilter=texweft.exe
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "Languages\ChineseSimplified.isl"
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Excludes: "*.pdb,*.lib,*.exp"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Texweft"; Filename: "{app}\texweft.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\Texweft"; Filename: "{app}\texweft.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\texweft.exe"; Description: "{cm:LaunchProgram,Texweft}"; Flags: nowait postinstall skipifsilent
