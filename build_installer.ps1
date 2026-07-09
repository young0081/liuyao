# Xuanji Liuyao - Windows installer build script
#
# Builds a self-contained single-file installer (.exe) whose GUI is a Flutter
# app (installer/app), matching the main app's art style. The main app's
# release files are carried as an uncompressed `payload\` folder, and the whole
# staging folder is wrapped into one self-extracting exe via the 7-Zip SFX
# module.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\build_installer.ps1
#   powershell -ExecutionPolicy Bypass -File .\build_installer.ps1 -SkipAppBuild
#
#   -SkipAppBuild   Reuse an existing build\windows\x64\runner\Release payload.

param(
    [Alias('SkipBuild')]
    [switch]$SkipAppBuild
)

$ErrorActionPreference = 'Stop'

$root = (Get-Location).Path
$appName = '玄机 · 六爻卦象'
$appExe = 'liuyao.exe'
$publisher = 'young0081'
$regKey = 'Software\XuanjiLiuyao'
$appId = '{8F2C4A6E-3B1D-4E7A-9C5F-6D2A1B3C4D5E}'

function Get-AppVersion {
    $line = Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(.+)$' | Select-Object -First 1
    if (-not $line) { throw 'Cannot find version in pubspec.yaml' }
    $raw = $line.Matches[0].Groups[1].Value.Trim()
    return ($raw -split '\+')[0]
}

function Get-SevenZip {
    $candidates = @(
        "$env:ProgramFiles\7-Zip\7z.exe",
        "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
    )
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    $cmd = Get-Command 7z -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw '7-Zip (7z.exe) was not found. Install 7-Zip first.'
}

function Get-SfxModule {
    $candidates = @(
        "$env:ProgramFiles\7-Zip\7z.sfx",
        "${env:ProgramFiles(x86)}\7-Zip\7z.sfx"
    )
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    throw '7-Zip SFX module (7z.sfx) was not found next to 7z.exe.'
}

# Build a Flutter Windows release in an ASCII temp dir (toolchain cannot handle
# non-ASCII project paths) and return the Release folder path.
function Build-FlutterWindows {
    param(
        [string]$ProjectDir,
        [string]$Tag,
        [string[]]$DartDefines
    )
    $needsAscii = $ProjectDir -match '[^\u0000-\u007F]'
    $defineArgs = @()
    foreach ($d in $DartDefines) { $defineArgs += "--dart-define=$d" }

    if (-not $needsAscii) {
        Push-Location $ProjectDir
        try {
            flutter pub get
            flutter build windows --release @defineArgs
            if ($LASTEXITCODE -ne 0) { throw "Build failed ($Tag) with exit code $LASTEXITCODE" }
        } finally { Pop-Location }
        return (Join-Path $ProjectDir 'build\windows\x64\runner\Release')
    }

    $tmp = Join-Path $env:TEMP ("liuyao_" + $Tag + "_" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    robocopy $ProjectDir $tmp /E /XD build .dart_tool .idea .git windows\flutter\ephemeral /XF *.iml /NFL /NDL /NJH /NJS /NP | Out-Null
    Push-Location $tmp
    try {
        Remove-Item -Recurse -Force windows\flutter\ephemeral -ErrorAction SilentlyContinue
        flutter pub get
        flutter build windows --release @defineArgs
        if ($LASTEXITCODE -ne 0) { throw "Build failed ($Tag) with exit code $LASTEXITCODE" }
    } finally { Pop-Location }
    return (Join-Path $tmp 'build\windows\x64\runner\Release')
}

$version = Get-AppVersion
Write-Host "Building installer for version $version"

# 1. Main app release (the payload).
if (-not $SkipAppBuild) {
    Write-Host '== Building main app (payload) =='
    powershell -ExecutionPolicy Bypass -File .\build_windows.ps1
}
$payloadSrc = Join-Path $root 'build\windows\x64\runner\Release'
if (-not (Test-Path (Join-Path $payloadSrc $appExe))) {
    throw "Main app release not found: $payloadSrc"
}

# 2. Installer GUI app.
Write-Host '== Building installer GUI app =='
$defines = @(
    "APP_NAME=$appName",
    "APP_EXE=$appExe",
    "APP_VERSION=$version",
    "APP_PUBLISHER=$publisher",
    "APP_REGKEY=$regKey",
    "APP_ID=$appId"
)
$installerReleaseOutput =
    @(Build-FlutterWindows -ProjectDir (Join-Path $root 'installer\app') -Tag 'inst' -DartDefines $defines)
$installerRelease = [string]($installerReleaseOutput | Select-Object -Last 1)
if (-not (Test-Path (Join-Path $installerRelease 'liuyao_installer.exe'))) {
    throw "Installer app release not found: $installerRelease"
}

# 3. Assemble staging folder: installer runtime + payload subfolder.
Write-Host '== Assembling package =='
$stage = Join-Path $env:TEMP ("liuyao_stage_" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $stage | Out-Null
robocopy $installerRelease $stage /E /NFL /NDL /NJH /NJS /NP | Out-Null
if (-not (Test-Path (Join-Path $stage 'liuyao_installer.exe'))) {
    throw "Installer GUI was not copied into staging: $stage"
}
$payloadDst = Join-Path $stage 'payload'
New-Item -ItemType Directory -Force -Path $payloadDst | Out-Null
robocopy $payloadSrc $payloadDst /E /NFL /NDL /NJH /NJS /NP | Out-Null
if (-not (Test-Path (Join-Path $payloadDst $appExe))) {
    throw "Main app payload was not copied into staging: $payloadDst"
}

# 4. Wrap into a single self-extracting exe.
Write-Host '== Building self-extracting exe =='
New-Item -ItemType Directory -Force -Path (Join-Path $root 'dist') | Out-Null
$sevenZip = Get-SevenZip
$sfx = Get-SfxModule

$archive = Join-Path $env:TEMP ("liuyao_pkg_" + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '.7z')
Push-Location $stage
try {
    $items = Get-ChildItem -LiteralPath $stage -Force | ForEach-Object { ".\$($_.Name)" }
    & $sevenZip a -t7z -mx=9 -r $archive @items | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "7z archive failed with exit code $LASTEXITCODE" }
} finally { Pop-Location }

$listing = (& $sevenZip l $archive) -join [Environment]::NewLine
if (($listing -notmatch 'liuyao_installer\.exe') -or
    ($listing -notmatch 'payload\\liuyao\.exe')) {
    throw '7z archive verification failed: installer GUI or payload exe is missing.'
}

# SFX config: extract to a temp dir and run the installer GUI.
$cfgPath = Join-Path $env:TEMP ("liuyao_sfx_" + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '.txt')
$cfg = @'
;!@Install@!UTF-8!
Title="玄机 · 六爻卦象 安装向导"
RunProgram="liuyao_installer.exe"
GUIMode="2"
;!@InstallEnd@!
'@
# Write config as UTF-8 with BOM (required by the SFX module for UTF-8 configs).
[System.IO.File]::WriteAllText($cfgPath, $cfg, (New-Object System.Text.UTF8Encoding($true)))

$outExe = Join-Path $root ("dist\liuyao-setup-$version.exe")
$fs = [System.IO.File]::Open($outExe, [System.IO.FileMode]::Create)
try {
    foreach ($part in @($sfx, $cfgPath, $archive)) {
        $bytes = [System.IO.File]::ReadAllBytes($part)
        $fs.Write($bytes, 0, $bytes.Length)
    }
} finally { $fs.Close() }

# Cleanup temp artifacts.
Remove-Item $archive, $cfgPath -Force -ErrorAction SilentlyContinue
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue

$sizeMb = [math]::Round((Get-Item $outExe).Length / 1MB, 1)
Write-Host "Installer built: $outExe ($sizeMb MB)"
