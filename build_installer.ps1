# Xuanji Liuyao - Windows installer build script
#
# Builds a single-file Windows installer executable. The exe carries the Flutter
# installer GUI as an embedded, uncompressed resource bundle and starts it
# silently, so the first visible window is the rounded Flutter GUI.
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

function New-PayloadBundle {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDir,
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    if (Test-Path $DestinationPath) {
        Remove-Item -Force $DestinationPath
    }

    $sourceRoot = [System.IO.Path]::GetFullPath($SourceDir).TrimEnd('\', '/')
    $sourcePrefix = $sourceRoot + [System.IO.Path]::DirectorySeparatorChar
    $sourceUri = [Uri]$sourcePrefix
    $archive = [System.IO.Compression.ZipFile]::Open(
        $DestinationPath,
        [System.IO.Compression.ZipArchiveMode]::Create
    )

    try {
        Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Force | ForEach-Object {
            $fileUri = [Uri]$_.FullName
            $entryName = [Uri]::UnescapeDataString($sourceUri.MakeRelativeUri($fileUri).ToString())
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive,
                $_.FullName,
                $entryName,
                [System.IO.Compression.CompressionLevel]::NoCompression
            ) | Out-Null
        }
    }
    finally {
        $archive.Dispose()
    }
}

function Expand-PayloadBundle {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BundlePath,
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($BundlePath, $DestinationPath)
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

# 4. Embed the staged Flutter installer app into a real single-file bootstrapper.
Write-Host '== Building single-file installer exe =='
New-Item -ItemType Directory -Force -Path (Join-Path $root 'dist') | Out-Null
$bootstrapperDir = Join-Path $root 'installer\bootstrapper'
$payloadBundle = Join-Path $bootstrapperDir 'payload.bundle'
New-PayloadBundle -SourceDir $stage -DestinationPath $payloadBundle

$verifyDir = Join-Path $env:TEMP ("liuyao_verify_" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $verifyDir | Out-Null
Expand-PayloadBundle -BundlePath $payloadBundle -DestinationPath $verifyDir
if (-not (Test-Path (Join-Path $verifyDir 'liuyao_installer.exe')) -or
    -not (Test-Path (Join-Path $verifyDir "payload\$appExe"))) {
    Remove-Item $verifyDir -Recurse -Force -ErrorAction SilentlyContinue
    throw 'Installer payload verification failed: installer GUI or payload exe is missing.'
}
Remove-Item $verifyDir -Recurse -Force -ErrorAction SilentlyContinue

$publishDir = Join-Path $env:TEMP ("liuyao_bootstrapper_" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
dotnet publish (Join-Path $bootstrapperDir 'liuyao_bootstrapper.csproj') `
    -c Release `
    -r win-x64 `
    --self-contained true `
    -o $publishDir `
    "-p:Version=$version" `
    "-p:AssemblyVersion=$version.0" `
    "-p:FileVersion=$version.0" `
    "-p:InformationalVersion=$version"
if ($LASTEXITCODE -ne 0) { throw "Bootstrapper publish failed with exit code $LASTEXITCODE" }

$publishedExe = Join-Path $publishDir 'liuyao-setup.exe'
if (-not (Test-Path $publishedExe)) {
    throw "Bootstrapper exe was not produced: $publishedExe"
}

$outExe = Join-Path $root ("dist\liuyao-setup-$version.exe")
Copy-Item -Path $publishedExe -Destination $outExe -Force

& $outExe --verify-payload
if ($LASTEXITCODE -ne 0) {
    throw "Bootstrapper embedded payload verification failed with exit code $LASTEXITCODE"
}

# Cleanup temp artifacts.
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $payloadBundle -Force -ErrorAction SilentlyContinue
Remove-Item $publishDir -Recurse -Force -ErrorAction SilentlyContinue

$sizeMb = [math]::Round((Get-Item $outExe).Length / 1MB, 1)
Write-Host "Installer built: $outExe ($sizeMb MB)"
