; Xuanji Liuyao - Windows official installer (Inno Setup 6)
;
; Features:
;   - GUI wizard, borderless rounded window, custom draggable title bar
;   - Detect any installed version, default install path points to it
;   - Show "fresh install / update / rollback / reinstall" per version compare
;
; Compile (Inno Setup 6 installed):
;   ISCC.exe /DAppVersion=1.0.0 /DSourceDir="..\build\windows\x64\runner\Release" installer\liuyao_installer.iss
;
; Overridable /D params: AppVersion, SourceDir, OutputDir

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

#ifndef SourceDir
  #define SourceDir "..\build\windows\x64\runner\Release"
#endif

#ifndef OutputDir
  #define OutputDir "..\dist"
#endif

#define AppName "玄机 · 六爻卦象"
#define AppDirName "Xuanji Liuyao"
#define AppExe "liuyao.exe"
#define AppPublisher "young0081"
#define AppGuid "{8F2C4A6E-3B1D-4E7A-9C5F-6D2A1B3C4D5E}"
#define AppId "{{8F2C4A6E-3B1D-4E7A-9C5F-6D2A1B3C4D5E}"
#define RegKey "Software\XuanjiLiuyao"
#define UninstallKey "Software\Microsoft\Windows\CurrentVersion\Uninstall\{#AppGuid}_is1"

[Setup]
AppId={#AppId}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
VersionInfoVersion={#AppVersion}
DefaultDirName={autopf}\{#AppDirName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
DisableWelcomePage=no
UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\{#AppExe}
OutputDir={#OutputDir}
OutputBaseFilename=liuyao-setup-{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "chinesesimplified"; MessagesFile: "languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\{#AppExe}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Registry]
Root: HKA; Subkey: "{#RegKey}"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Flags: uninsdeletekey
Root: HKA; Subkey: "{#RegKey}"; ValueType: string; ValueName: "Version"; ValueData: "{#AppVersion}"

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[Code]
const
  GWL_STYLE = -16;
  WS_CAPTION = $00C00000;
  WS_THICKFRAME = $00040000;

var
  InstalledVersion: string;
  InstalledPath: string;
  HasInstalled: Boolean;
  ActionKind: Integer;
  TitleBar: TPanel;
  TitleLabel: TLabel;
  CloseButton: TLabel;

function GetWindowLong(hWnd: HWND; nIndex: Integer): Longint;
  external 'GetWindowLongW@user32.dll stdcall';
function SetWindowLong(hWnd: HWND; nIndex: Integer; dwNewLong: Longint): Longint;
  external 'SetWindowLongW@user32.dll stdcall';
function CreateRoundRectRgn(x1, y1, x2, y2, w, h: Integer): THandle;
  external 'CreateRoundRectRgn@gdi32.dll stdcall';
function SetWindowRgn(hWnd: HWND; hRgn: THandle; bRedraw: Boolean): Integer;
  external 'SetWindowRgn@user32.dll stdcall';

procedure DetectInstalled;
begin
  HasInstalled := False;
  InstalledVersion := '';
  InstalledPath := '';

  // Prefer the app-owned key. Then fall back to Inno Setup uninstall metadata.
  if RegQueryStringValue(HKCU, '{#RegKey}', 'InstallPath', InstalledPath) then
  begin
    RegQueryStringValue(HKCU, '{#RegKey}', 'Version', InstalledVersion);
    HasInstalled := True;
    Exit;
  end;
  if RegQueryStringValue(HKLM, '{#RegKey}', 'InstallPath', InstalledPath) then
  begin
    RegQueryStringValue(HKLM, '{#RegKey}', 'Version', InstalledVersion);
    HasInstalled := True;
    Exit;
  end;
  if RegQueryStringValue(HKCU, '{#UninstallKey}', 'InstallLocation', InstalledPath) then
  begin
    RegQueryStringValue(HKCU, '{#UninstallKey}', 'DisplayVersion', InstalledVersion);
    HasInstalled := True;
    Exit;
  end;
  if RegQueryStringValue(HKLM, '{#UninstallKey}', 'InstallLocation', InstalledPath) then
  begin
    RegQueryStringValue(HKLM, '{#UninstallKey}', 'DisplayVersion', InstalledVersion);
    HasInstalled := True;
  end;
end;

function NextPart(var s: string): Integer;
var
  p: Integer;
  token: string;
begin
  // 取版本串下一段数字 (以 . 分隔), 忽略非数字后缀。
  p := Pos('.', s);
  if p > 0 then
  begin
    token := Copy(s, 1, p - 1);
    Delete(s, 1, p);
  end
  else
  begin
    token := s;
    s := '';
  end;
  Result := StrToIntDef(Trim(token), 0);
end;

function CompareVer(a, b: string): Integer;
var
  na, nb: Integer;
begin
  Result := 0;
  while (Length(a) > 0) or (Length(b) > 0) do
  begin
    na := NextPart(a);
    nb := NextPart(b);
    if na > nb then
    begin
      Result := 1;
      Exit;
    end
    else if na < nb then
    begin
      Result := -1;
      Exit;
    end;
  end;
end;

procedure ComputeAction;
var
  cmp: Integer;
begin
  if not HasInstalled then
  begin
    ActionKind := 0;
    Exit;
  end;
  cmp := CompareVer('{#AppVersion}', InstalledVersion);
  if cmp > 0 then
    ActionKind := 1
  else if cmp < 0 then
    ActionKind := 2
  else
    ActionKind := 3;
end;

function ActionTitle: string;
begin
  case ActionKind of
    1: Result := '更新 ' + InstalledVersion + ' -> {#AppVersion}';
    2: Result := '回退 ' + InstalledVersion + ' -> {#AppVersion}';
    3: Result := '重新安装 {#AppVersion}';
  else
    Result := '全新安装 {#AppVersion}';
  end;
end;

procedure MakeRoundBorderless(h: HWND);
var
  style: Longint;
  rgn: THandle;
begin
  style := GetWindowLong(h, GWL_STYLE);
  style := style and (not WS_CAPTION) and (not WS_THICKFRAME);
  SetWindowLong(h, GWL_STYLE, style);
  rgn := CreateRoundRectRgn(0, 0, WizardForm.Width + 1, WizardForm.Height + 1, 18, 18);
  SetWindowRgn(h, rgn, True);
end;

procedure CloseButtonClick(Sender: TObject);
begin
  WizardForm.Close;
end;

procedure BuildTitleBar;
begin
  TitleBar := TPanel.Create(WizardForm);
  TitleBar.Parent := WizardForm;
  TitleBar.Left := 0;
  TitleBar.Top := 0;
  TitleBar.Width := WizardForm.ClientWidth;
  TitleBar.Height := 40;
  TitleBar.BevelOuter := bvNone;
  TitleBar.Color := $00402A17;

  TitleLabel := TLabel.Create(WizardForm);
  TitleLabel.Parent := TitleBar;
  TitleLabel.AutoSize := True;
  TitleLabel.Left := 16;
  TitleLabel.Top := 12;
  TitleLabel.Caption := '{#AppName}';
  TitleLabel.Font.Color := clWhite;
  TitleLabel.Font.Size := 10;
  TitleLabel.Font.Style := [fsBold];

  CloseButton := TLabel.Create(WizardForm);
  CloseButton.Parent := TitleBar;
  CloseButton.AutoSize := False;
  CloseButton.Alignment := taCenter;
  CloseButton.Width := 40;
  CloseButton.Height := 40;
  CloseButton.Left := TitleBar.Width - 40;
  CloseButton.Top := 0;
  CloseButton.Anchors := [akTop, akRight];
  CloseButton.Caption := 'x';
  CloseButton.Font.Color := clWhite;
  CloseButton.Font.Size := 14;
  CloseButton.OnClick := @CloseButtonClick;
end;

procedure InitializeWizard;
begin
  DetectInstalled;
  ComputeAction;
  if HasInstalled and (InstalledPath <> '') then
    WizardForm.DirEdit.Text := InstalledPath;
  WizardForm.WelcomeLabel2.Caption :=
    '本向导将安装 {#AppName}。' + #13#10#13#10 + '当前操作：' + ActionTitle;
  if HasInstalled then
    WizardForm.WelcomeLabel2.Caption := WizardForm.WelcomeLabel2.Caption
      + #13#10 + '检测到已安装版本 ' + InstalledVersion + '，位置：' + #13#10 + InstalledPath;
  BuildTitleBar;
end;

function UpdateReadyMemo(Space, NewLine, MemoUserInfoInfo, MemoDirInfo, MemoTypeInfo,
  MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: string): string;
begin
  Result := '当前操作：' + ActionTitle + NewLine + NewLine + MemoDirInfo;
  if MemoTasksInfo <> '' then
    Result := Result + NewLine + NewLine + MemoTasksInfo;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  MakeRoundBorderless(WizardForm.Handle);
  if Assigned(TitleBar) then
  begin
    TitleBar.Width := WizardForm.ClientWidth;
    TitleBar.BringToFront;
  end;
end;

function InitializeSetup: Boolean;
begin
  Result := True;
end;
