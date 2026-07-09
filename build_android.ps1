# Xuanji Liuyao - Android build script
#
# The Android (Gradle/AGP) toolchain cannot handle project paths that contain
# non-ASCII characters (error: "Your project path contains non-ASCII characters").
# This project lives under a path with Chinese characters, so we copy the
# sources into a pure-ASCII temp directory, build there, then copy the APK back.
#
# Usage (run from the project root):
#   powershell -ExecutionPolicy Bypass -File .\build_android.ps1
#   powershell -ExecutionPolicy Bypass -File .\build_android.ps1 -Debug

param(
    [switch]$Debug
)

$ErrorActionPreference = 'Stop'

$mode = if ($Debug) { '--debug' } else { '--release' }
$buildType = if ($Debug) { 'debug' } else { 'release' }
$apkName = "app-$buildType.apk"

$versionLine = Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(.+)$' | Select-Object -First 1
if (-not $versionLine) {
    throw 'Cannot find version in pubspec.yaml'
}
$appVersion = $versionLine.Matches[0].Groups[1].Value.Trim() -replace '\+', '-'
$namedApk = "liuyao-v$appVersion-android-$buildType.apk"

$src = (Get-Location).Path
$needsAsciiCopy = $src -match '[^\u0000-\u007F]'

if (-not $needsAsciiCopy) {
    Write-Host "ASCII path detected, building in place."
    flutter build apk $mode
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $out = Join-Path $src "build\app\outputs\flutter-apk\$apkName"
    $namedOut = Join-Path $src "build\app\outputs\flutter-apk\$namedApk"
    Copy-Item -Path $out -Destination $namedOut -Force
    Write-Host "Build done. Named APK: $namedOut"
    exit 0
}

$dst = Join-Path $env:TEMP ("liuyao_apk_" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
Write-Host "Non-ASCII path detected, copying to temp dir: $dst"
New-Item -ItemType Directory -Force -Path $dst | Out-Null

# Copy sources, excluding build caches / generated dirs (regenerated on build).
robocopy $src $dst /E /XD build .dart_tool .idea .git android\.gradle android\app\build /XF *.iml /NFL /NDL /NJH /NJS /NP | Out-Null

Push-Location $dst
try {
    flutter pub get
    flutter build apk $mode
    if ($LASTEXITCODE -ne 0) { throw "Build failed with exit code $LASTEXITCODE" }

    $out = Join-Path $dst "build\app\outputs\flutter-apk\$apkName"
    $localOut = Join-Path $src 'build\app\outputs\flutter-apk'
    New-Item -ItemType Directory -Force -Path $localOut | Out-Null
    $namedOut = Join-Path $localOut $namedApk
    Copy-Item -Path $out -Destination $namedOut -Force
    Write-Host "Build done. Named APK copied back to: $namedOut"
}
finally {
    Pop-Location
    Remove-Item -Recurse -Force $dst -ErrorAction SilentlyContinue
}
