; Compile through scripts/packaging/win-x64/package.ps1. AppId stays stable across upgrades.
#ifndef AppVersion
  #error AppVersion is required
#endif
#ifndef SourceDir
  #error SourceDir is required
#endif
#ifndef OutputDir
  #error OutputDir is required
#endif
#ifdef InstallerTest
  #ifndef InstallerTestId
    #define InstallerTestId "Vex.Installer.Test"
  #endif
#endif

[Setup]
#ifdef InstallerTest
AppId={#InstallerTestId}
AppName=Vex Installer Test
UninstallDisplayName=Vex Installer Test
#else
AppId={{51E79E85-AD4C-4D48-92EC-C1EA09FB4E56}
AppName=维刻 Vex
UninstallDisplayName=维刻 Vex
#endif
AppVersion={#AppVersion}
AppPublisher=CodeWF
AppPublisherURL=https://codewf.com
AppSupportURL=https://github.com/dotnet9/Vex-Flutter/issues
AppUpdatesURL=https://github.com/dotnet9/Vex-Flutter/releases
#ifdef InstallerTest
DefaultDirName={localappdata}\Temp\{#InstallerTestId}
#else
DefaultDirName={localappdata}\Programs\Vex
#endif
DefaultGroupName=Vex
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
DisableProgramGroupPage=yes
WizardStyle=modern
SetupIconFile=..\..\logo.ico
LicenseFile=..\..\LICENSE
UninstallDisplayIcon={app}\vex.exe
OutputDir={#OutputDir}
OutputBaseFilename=Vex-v{#AppVersion}-windows-x64-setup
Compression=lzma2
SolidCompression=yes
#ifdef InstallerTest
CloseApplications=no
#else
CloseApplications=yes
#endif
CloseApplicationsFilter=vex.exe
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "Languages\ChineseSimplified.isl"
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "markdownassociation"; Description: "{cm:TWAssociation}"

[Registry]
#ifndef InstallerTest
Root: HKCU; Subkey: "Software\Classes\Vex.Markdown"; ValueType: string; ValueData: "Markdown"; Flags: uninsdeletekey; Tasks: markdownassociation
Root: HKCU; Subkey: "Software\Classes\Vex.Markdown\DefaultIcon"; ValueType: string; ValueData: """{app}\vex.exe"",0"; Tasks: markdownassociation
Root: HKCU; Subkey: "Software\Classes\Vex.Markdown\shell\open\command"; ValueType: string; ValueData: """{app}\vex.exe"" ""%1"""; Tasks: markdownassociation
Root: HKCU; Subkey: "Software\Classes\.md\OpenWithProgids"; ValueType: none; ValueName: "Vex.Markdown"; Flags: uninsdeletevalue; Tasks: markdownassociation
#endif

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Excludes: "*.pdb,*.lib,*.exp"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
#ifndef InstallerTest
Name: "{autoprograms}\Vex"; Filename: "{app}\vex.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\Vex"; Filename: "{app}\vex.exe"; WorkingDir: "{app}"; Tasks: desktopicon
#endif

[Run]
#ifndef InstallerTest
Filename: "{app}\vex.exe"; Description: "{cm:LaunchProgram,Vex}"; Flags: nowait postinstall skipifsilent
#endif

#include "Vex.Setup.iss"
