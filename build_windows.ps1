# 玄机 · 六爻卦象 — Windows 构建脚本
#
# Flutter 的 Windows(MSVC/CMake)工具链无法读取包含非 ASCII 字符的项目路径。
# 本项目所在目录含中文,故先复制到纯 ASCII 的临时目录再构建,产物拷回本目录。
#
# 用法(在项目根目录执行):
#   powershell -ExecutionPolicy Bypass -File .\build_windows.ps1

$ErrorActionPreference = 'Stop'

$src = (Get-Location).Path
$needsAsciiCopy = $src -match '[^\u0000-\u007F]'

if (-not $needsAsciiCopy) {
    Write-Host "路径为纯 ASCII,直接构建。"
    flutter build windows --release
    exit $LASTEXITCODE
}

$dst = Join-Path $env:TEMP ("liuyao_build_" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
Write-Host "检测到非 ASCII 路径,复制到临时目录:$dst"
New-Item -ItemType Directory -Force -Path $dst | Out-Null

# 复制源码,排除构建缓存与符号链接目录(会重新生成)。
robocopy $src $dst /E /XD build .dart_tool .idea .git windows\flutter\ephemeral /XF *.iml /NFL /NDL /NJH /NJS /NP | Out-Null

Push-Location $dst
try {
    Remove-Item -Recurse -Force windows\flutter\ephemeral -ErrorAction SilentlyContinue
    flutter pub get
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw "构建失败,退出码 $LASTEXITCODE" }

    $out = Join-Path $dst 'build\windows\x64\runner\Release'
    $localOut = Join-Path $src 'build\windows\x64\runner\Release'
    New-Item -ItemType Directory -Force -Path $localOut | Out-Null
    robocopy $out $localOut /E /NFL /NDL /NJH /NJS /NP | Out-Null
    Write-Host "构建完成,产物已拷回:$localOut\liuyao.exe"
}
finally {
    Pop-Location
    Remove-Item -Recurse -Force $dst -ErrorAction SilentlyContinue
}

