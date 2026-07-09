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
$apkName = if ($Debug) { 'app-debug.apk' } else { 'app-release.apk' }

$src = (Get-Location).Path
$needsAsciiCopy = $src -match '[^\u0000-\u007F]'

if (-not $needsAsciiCopy) {
    Write-Host "ASCII path detected, building in place."
    flutter build apk $mode
    exit $LASTEXITCODE
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
    Copy-Item -Path $out -Destination $localOut -Force
    Write-Host "Build done. APK copied back to: $localOut"
}
finally {
    Pop-Location
    Remove-Item -Recurse -Force $dst -ErrorAction SilentlyContinue
}
