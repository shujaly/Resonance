#define AppName "One More Bell: Resonance"
#define AppVersion "1.0.0"
#define AppExe "OneMoreBell-Resonance.exe"
#define ShortcutName "One More Bell - Resonance"

[Setup]
AppId={{FDB76B35-AAFE-4B5A-93D8-0F8073E2E466}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisherURL=https://github.com/shujaly/Resonance
AppSupportURL=https://github.com/shujaly/Resonance
DefaultDirName={autopf}\One More Bell Resonance
DefaultGroupName=One More Bell Resonance
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=exports
OutputBaseFilename=OneMoreBell-Resonance-Setup
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes
WizardStyle=modern
SetupIconFile=art\icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "exports\windows\{#AppExe}"; DestDir: "{app}"; Flags: ignoreversion
Source: "art\Alegreya-OFL.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#ShortcutName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#ShortcutName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "Play {#AppName}"; Flags: nowait postinstall skipifsilent
