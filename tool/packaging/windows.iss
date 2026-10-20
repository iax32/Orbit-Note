; Per-user installer. User Vaults and account/server state live outside this
; directory and are never removed by setup or uninstall.
#ifndef OrbitSource
  #error OrbitSource is required
#endif
#ifndef OrbitOutput
  #error OrbitOutput is required
#endif
#ifndef OrbitVersion
  #error OrbitVersion is required
#endif
#ifndef OrbitFileVersion
  #error OrbitFileVersion is required
#endif
#ifndef OrbitRoot
  #error OrbitRoot is required
#endif

[Setup]
AppId={{AE1DB51B-1EC8-474A-A683-E126FF1368FD}
AppName=Orbit Note
AppVersion={#OrbitVersion}
AppPublisher=Orbit Note contributors
AppPublisherURL=https://github.com/iax32/Orbit-Note
AppSupportURL=https://github.com/iax32/Orbit-Note/issues
DefaultDirName={localappdata}\Programs\Orbit Note
DefaultGroupName=Orbit Note
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OrbitOutput}
OutputBaseFilename=OrbitNote-Windows-x64-Setup
VersionInfoVersion={#OrbitFileVersion}
SetupIconFile={#OrbitRoot}\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\orbit_note.exe
LicenseFile={#OrbitRoot}\LICENSE
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
DisableProgramGroupPage=yes
CloseApplications=no
RestartApplications=no

[Files]
Source: "{#OrbitSource}\orbit_note.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#OrbitSource}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#OrbitSource}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#OrbitSource}\collaboration\OrbitNote-Server.exe"; DestDir: "{app}\collaboration"; Flags: ignoreversion
Source: "{#OrbitSource}\collaboration\Start Orbit Server.cmd"; DestDir: "{app}\collaboration"; Flags: ignoreversion
Source: "{#OrbitSource}\collaboration\README.md"; DestDir: "{app}\collaboration"; Flags: ignoreversion
Source: "{#OrbitRoot}\LICENSE"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Orbit Note"; Filename: "{app}\orbit_note.exe"

; Deliberately no [Run], autostart, service, file associations or user-data delete.
