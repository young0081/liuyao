# Xuanji Liuyao - Windows installer build script
#
# Builds a Windows installer package whose entry point is a Flutter GUI app
# (installer/app), matching the main app's art style. The main app's release
# files are carried in a `payload\` folder beside the installer executable.
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

# 4. Package the Flutter installer app + payload as a zip. The first executable
# users run is the Flutter GUI installer, not an extractor shell.
Write-Host '== Building installer package =='
New-Item -ItemType Directory -Force -Path (Join-Path $root 'dist') | Out-Null
$outZip = Join-Path $root ("dist\liuyao-installer-windows-x64-v$version.zip")
if (Test-Path $outZip) {
    Remove-Item -Force $outZip
}
$packageItems = Get-ChildItem -LiteralPath $stage -Force | Select-Object -ExpandProperty FullName
Compress-Archive -LiteralPath $packageItems -DestinationPath $outZip -Force

$verifyDir = Join-Path $env:TEMP ("liuyao_verify_" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
Expand-Archive -LiteralPath $outZip -DestinationPath $verifyDir -Force
if (-not (Test-Path (Join-Path $verifyDir 'liuyao_installer.exe')) -or
    -not (Test-Path (Join-Path $verifyDir "payload\$appExe"))) {
    Remove-Item $verifyDir -Recurse -Force -ErrorAction SilentlyContinue
    throw 'Installer package verification failed: installer GUI or payload exe is missing.'
}
Remove-Item $verifyDir -Recurse -Force -ErrorAction SilentlyContinue

# Cleanup temp artifacts.
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue

$sizeMb = [math]::Round((Get-Item $outZip).Length / 1MB, 1)
Write-Host "Installer package built: $outZip ($sizeMb MB)"
