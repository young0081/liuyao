# Xuanji Liuyao - Windows installer build script
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\build_installer.ps1
#   powershell -ExecutionPolicy Bypass -File .\build_installer.ps1 -SkipBuild

param(
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

function Get-AppVersion {
    $line = Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(.+)$' | Select-Object -First 1
    if (-not $line) {
        throw 'Cannot find version in pubspec.yaml'
    }
    $raw = $line.Matches[0].Groups[1].Value.Trim()
    return ($raw -split '\+')[0]
}

function Get-IsccPath {
    $candidates = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles(x86)}\Inno Setup 5\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 5\ISCC.exe"
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }
    $cmd = Get-Command iscc -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }
    throw 'Inno Setup compiler ISCC.exe was not found. Install Inno Setup 6 first.'
}

$version = Get-AppVersion

if (-not $SkipBuild) {
    powershell -ExecutionPolicy Bypass -File .\build_windows.ps1
}

$sourceDir = Join-Path (Get-Location).Path 'build\windows\x64\runner\Release'
if (-not (Test-Path (Join-Path $sourceDir 'liuyao.exe'))) {
    throw "Windows release output not found: $sourceDir"
}

New-Item -ItemType Directory -Force -Path dist | Out-Null

$iscc = Get-IsccPath
& $iscc "/DAppVersion=$version" "/DSourceDir=..\build\windows\x64\runner\Release" "/DOutputDir=..\dist" installer\liuyao_installer.iss
if ($LASTEXITCODE -ne 0) {
    throw "Installer build failed with exit code $LASTEXITCODE"
}

$installer = Join-Path (Get-Location).Path "dist\liuyao-setup-$version.exe"
Write-Host "Installer built: $installer"
