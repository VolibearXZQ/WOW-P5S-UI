@echo off
setlocal DisableDelayedExpansion
chcp 65001 >nul
set "P5S_RELEASE_SELF=%~f0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "try { $s = [IO.File]::ReadAllText($env:P5S_RELEASE_SELF, [Text.Encoding]::UTF8); & ([scriptblock]::Create(($s -split '(?m)^# POWERSHELL_PAYLOAD\r?$', 2)[1])) } catch { Write-Host $_ -ForegroundColor Red; exit 1 }"
set "P5S_RELEASE_RESULT=%ERRORLEVEL%"
echo.
pause
exit /b %P5S_RELEASE_RESULT%
# POWERSHELL_PAYLOAD
# Single-file launcher: keep the batch header ASCII and save as UTF-8 without BOM.
# Requires Windows PowerShell 5.1 and 7-Zip. No Python or extra script required.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
$sevenZip = 'C:\Program Files\7-Zip\7z.exe'
$root = [IO.Path]::GetDirectoryName($env:P5S_RELEASE_SELF)
$outputDir = Join-Path $root 'releases'
$work = $null
$result = 1

function Assert-RegularPath([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw "不支持链接或目录联接：$Path"
    }
}

# Explicit release allowlist: unknown files, developer tools and archives stay out.
# Keep the historical child TOCs unchanged. Only the root TOC loads this addon.
function Get-ReleaseFiles([string]$Directory) {
    foreach ($item in Get-ChildItem -LiteralPath $Directory -Force) {
        if ($item.Name.StartsWith('.') -or $item.Name -in @('screenshots', 'releases', 'tests', 'tools', '__pycache__', 'node_modules')) { continue }
        Assert-RegularPath $item.FullName
        $relative = $item.FullName.Substring($root.Length + 1).Replace('\', '/')
        if ($item.PSIsContainer) {
            Get-ReleaseFiles $item.FullName
        } elseif (
            $relative -match '^(P5S_UI|P5_Nameplate|P5_Voice)/[^/]+\.(lua|toc)$' -or
            $relative -match '^(P5S_UI|P5_Nameplate)/Media/.+\.(tga|blp)$' -or
            $relative -match '^P5S_UI/Font/[^/]+\.ttf$' -or
            $relative -match '^P5S_UI/Font/[^/]+/(OFL|LICENSE|NOTICE)\.txt$' -or
            $relative -match '^P5_Voice/(音频|结城理_Voice)/.+\.mp3$'
        ) {
            $item
        }
    }
}

function Read-Exact($Reader, [int]$Count) {
    $bytes = $Reader.ReadBytes($Count)
    if ($bytes.Length -ne $Count) { throw 'ZIP 头部不完整。' }
    return ,$bytes
}

# Inspect raw ZIP headers, not decoded `7z l` text. Bit 11 = UTF-8 / EFS.
# This addon uses classic ZIP. Reject ZIP64/multi-volume rather than silently skip.
function Test-ZipHeaders([string]$Path, $Expected) {
    $stream = [IO.File]::OpenRead($Path)
    $reader = New-Object IO.BinaryReader($stream)
    $utf8 = New-Object Text.UTF8Encoding($false, $true)
    try {
        $tailSize = [int][Math]::Min(65557, $stream.Length)
        $stream.Position = $stream.Length - $tailSize
        $tail = Read-Exact $reader $tailSize
        $end = -1
        for ($i = $tail.Length - 22; $i -ge 0; $i--) {
            if ([BitConverter]::ToUInt32($tail, $i) -eq 0x06054b50 -and
                $i + 22 + [BitConverter]::ToUInt16($tail, $i + 20) -eq $tail.Length) { $end = $i; break }
        }
        if ($end -lt 0) { throw '找不到 ZIP 中央目录结束记录。' }
        $count = [BitConverter]::ToUInt16($tail, $end + 10)
        $size = [BitConverter]::ToUInt32($tail, $end + 12)
        $offset = [BitConverter]::ToUInt32($tail, $end + 16)
        if ($count -eq 65535 -or $size -eq [uint32]::MaxValue -or $offset -eq [uint32]::MaxValue) {
            throw '发布包已达到 ZIP64 范围；请先升级本脚本的验证器。'
        }
        if ([BitConverter]::ToUInt16($tail, $end + 4) -ne 0 -or
            [BitConverter]::ToUInt16($tail, $end + 6) -ne 0 -or
            [BitConverter]::ToUInt16($tail, $end + 8) -ne $count -or
            [long]$offset + $size -ne $stream.Length - $tailSize + $end) { throw 'ZIP 中央目录或分卷结构异常。' }
        $stream.Position = $offset
        $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        $nonAscii = 0
        $files = 0
        for ($i = 0; $i -lt $count; $i++) {
            $header = Read-Exact $reader 46
            if ([BitConverter]::ToUInt32($header, 0) -ne 0x02014b50) { throw 'ZIP 中央文件头异常。' }
            $flags = [BitConverter]::ToUInt16($header, 8)
            $nameBytes = Read-Exact $reader ([BitConverter]::ToUInt16($header, 28))
            $name = $utf8.GetString($nameBytes)
            if ($name -cmatch '[^\x00-\x7f]') {
                if (($flags -band 0x0800) -eq 0) { throw "中央目录缺少 UTF-8 标志：$name" }
                $nonAscii++
            }
            if (($flags -band 1) -ne 0 -or $name -cnotmatch '^P5S/' -or
                $name -match '\\|(^|/)\.\.?(/|$)' -or -not $seen.Add($name)) { throw "ZIP 路径、加密或重复条目异常：$name" }
            if (-not $name.EndsWith('/')) {
                if (-not $Expected.ContainsKey($name) -or
                    [BitConverter]::ToUInt32($header, 24) -ne $Expected[$name]) { throw "ZIP 文件清单或大小不匹配：$name" }
                $files++
            }
            $stream.Position += [BitConverter]::ToUInt16($header, 30) + [BitConverter]::ToUInt16($header, 32)
            $next = $stream.Position
            $localOffset = [BitConverter]::ToUInt32($header, 42)
            if ($localOffset -ge $offset) { throw "ZIP 本地文件偏移异常：$name" }
            $stream.Position = $localOffset
            $local = Read-Exact $reader 30
            if ([BitConverter]::ToUInt32($local, 0) -ne 0x04034b50 -or
                [BitConverter]::ToUInt16($local, 6) -ne $flags) { throw "本地文件头或 UTF-8 标志不一致：$name" }
            $localName = Read-Exact $reader ([BitConverter]::ToUInt16($local, 26))
            if ([Convert]::ToBase64String($localName) -cne [Convert]::ToBase64String($nameBytes)) { throw "本地与中央目录文件名不同：$name" }
            $stream.Position = $next
        }
        if ($stream.Position -ne [long]$offset + $size -or $files -ne $Expected.Count -or
            -not $seen.Contains('P5S/P5S.toc')) { throw 'ZIP 安装结构或文件数量不匹配。' }
        Write-Host "验证通过：$files 个文件，$nonAscii 个非 ASCII 条目；两处文件头 UTF-8 标志均正确。" -ForegroundColor Green
    } finally {
        $reader.Dispose()
        $stream.Dispose()
    }
}

try {
    Write-Host 'P5S 一键发布打包' -ForegroundColor Cyan
    Write-Host '版本号仅用于 ZIP 文件名；插件内的 TOC 版本保持原样。'
    if (-not (Test-Path -LiteralPath $sevenZip -PathType Leaf)) { throw "找不到 7-Zip，请安装到 $sevenZip 或修改脚本中的 sevenZip 路径。" }
    Assert-RegularPath $root
    $tocPath = Join-Path $root 'P5S.toc'
    Assert-RegularPath $tocPath
    $toc = [IO.File]::ReadAllText($tocPath, [Text.Encoding]::UTF8)
    $tocVersion = [regex]::Match($toc, '(?m)^## Version:\s*(.+)').Groups[1].Value.Trim()
    Write-Host "当前 P5S.toc 版本：$tocVersion"
    $version = Read-Host '请输入发布版本号（例如 1.0.2 或 1.0.2-beta.1；留空取消）'
    if ([string]::IsNullOrWhiteSpace($version)) { Write-Host '已取消。'; exit 0 }
    $version = $version.Trim()
    if ($version.Length -gt 64 -or $version -cnotmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*)?$') { throw '版本号格式无效，请使用 1.0.2 或 1.0.2-beta.1 格式。' }
    $final = Join-Path $outputDir "P5S-$version.zip"
    if (Test-Path -LiteralPath $final) { throw "同版本文件已存在，不会覆盖：$final" }
    if (Test-Path -LiteralPath $outputDir) { Assert-RegularPath $outputDir }
    [void][IO.Directory]::CreateDirectory($outputDir)
    $work = Join-Path $outputDir ('.work-' + [Guid]::NewGuid().ToString('N'))
    $stage = Join-Path $work 'P5S'
    [void][IO.Directory]::CreateDirectory($stage)
    $files = @((Get-Item -LiteralPath $tocPath))
    foreach ($module in @('P5S_UI', 'P5_Nameplate', 'P5_Voice')) {
        $modulePath = Join-Path $root $module
        Assert-RegularPath $modulePath
        $files += @(Get-ReleaseFiles $modulePath)
    }
    $expected = New-Object 'System.Collections.Generic.Dictionary[string,long]' ([StringComparer]::Ordinal)
    foreach ($file in $files) {
        if ($file.Length -eq 0) { throw "发布文件为空：$($file.FullName)" }
        $relative = $file.FullName.Substring($root.Length + 1)
        $destination = Join-Path $stage $relative
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
        [IO.File]::Copy($file.FullName, $destination, $false)
        $expected.Add(('P5S/' + $relative.Replace('\', '/')), (Get-Item -LiteralPath $destination).Length)
    }
    foreach ($line in ($toc -split '\r?\n')) {
        $entry = $line.Trim()
        if ($entry -and -not $entry.StartsWith('#') -and -not $expected.ContainsKey('P5S/' + $entry.Replace('\', '/'))) {
            throw "TOC 引用未被打包（请检查文件及发布清单）：$entry"
        }
    }
    foreach ($required in @(
        'P5S_UI/Font/P5S-Showtime/OFL.txt', 'P5S_UI/Font/P5S-Rhythm/OFL.txt',
        'P5S_UI/Font/P5S-Bounce/LICENSE.txt', 'P5S_UI/Font/P5S-Bounce/NOTICE.txt',
        'P5S_UI/Media/P5S_Icon.tga'
    )) {
        if (-not $expected.ContainsKey('P5S/' + $required)) { throw "缺少必需发布文件：$required" }
    }
    foreach ($resourceDir in @('P5S_UI/Media/', 'P5S_UI/Font/', 'P5_Nameplate/Media/', 'P5_Voice/音频/', 'P5_Voice/结城理_Voice/')) {
        if (@($expected.Keys | Where-Object { $_.StartsWith('P5S/' + $resourceDir) }).Count -eq 0) { throw "资源目录为空：$resourceDir" }
    }
    $pending = Join-Path $work 'package.zip'
    Write-Host "正在打包 $($expected.Count) 个文件……"
    Push-Location -LiteralPath $work
    try {
        & $sevenZip a -tzip -mcu=on -mx=5 -bd $pending 'P5S'
        if ($LASTEXITCODE -ne 0) { throw "7-Zip 压缩失败或存在警告，退出码：$LASTEXITCODE" }
        & $sevenZip t -tzip -bd $pending
        if ($LASTEXITCODE -ne 0) { throw "7-Zip 完整性验证失败，退出码：$LASTEXITCODE" }
    } finally { Pop-Location }
    Test-ZipHeaders $pending $expected
    # File.Move refuses an existing destination, including a concurrent release.
    [IO.File]::Move($pending, $final)
    Write-Host "`n打包成功：$final" -ForegroundColor Green
    Write-Host '可以将此 ZIP 上传到 CurseForge；上传页面请自行选择适用游戏版本。'
    $result = 0
} catch {
    Write-Host "`n打包失败：$($_.Exception.Message)" -ForegroundColor Red
    Write-Host '未生成新的正式发布包。已有发布包与插件源码、资源保持不变。'
} finally {
    if ($work -and (Test-Path -LiteralPath $work)) {
        try {
            $resolved = [IO.Path]::GetFullPath($work)
            $safeParent = [IO.Path]::GetFullPath($outputDir).TrimEnd('\') + '\'
            if (-not $resolved.StartsWith($safeParent, [StringComparison]::OrdinalIgnoreCase) -or
                [IO.Path]::GetFileName($resolved) -notmatch '^\.work-[0-9a-f]{32}$') { throw '临时目录范围检查失败。' }
            Assert-RegularPath $resolved
            Remove-Item -LiteralPath $resolved -Recurse -Force
        } catch { Write-Warning "临时目录未清理：$work；$($_.Exception.Message)" }
    }
}
exit $result
