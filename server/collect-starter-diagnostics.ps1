param(
    [string]$GameDirectory = $PSScriptRoot,
    [string]$OutputDirectory = [Environment]::GetFolderPath('Desktop')
)

# Read-only collection; never launches, updates or modifies the installed game.
# PCK directory layout: Godot core/io/file_access_pack.cpp (formats 2, 3, 4).
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$utf8 = New-Object Text.UTF8Encoding($false)
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$work = Join-Path ([IO.Path]::GetTempPath()) ('tyrants-starters-' + $stamp)
$null = New-Item -ItemType Directory -Path $work
$metadata = [ordered]@{
    date = (Get-Date).ToString('o')
    os = [Environment]::OSVersion.VersionString
    culture = [Globalization.CultureInfo]::CurrentCulture.Name
    gameDirectory = [IO.Path]::GetFullPath($GameDirectory)
    files = @()
    extracted = @()
    errors = @()
}

try {
    $packs = @(Get-ChildItem -LiteralPath $GameDirectory -Filter '*.pck' -File)
    if ($packs.Count -eq 0) { throw 'No .pck found. Put both diagnostic files beside the game .exe and .pck.' }
    foreach ($pack in $packs) {
        $metadata.files += @{ name = $pack.Name; size = $pack.Length; sha256 = (Get-FileHash -LiteralPath $pack.FullName -Algorithm SHA256).Hash }
        $stream = [IO.File]::Open($pack.FullName, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        $reader = New-Object IO.BinaryReader($stream)
        try {
            if ($reader.ReadUInt32() -ne 0x43504447) { throw ('Not a standalone PCK: ' + $pack.Name) }
            $version = $reader.ReadUInt32()
            if ($version -notin 2, 3, 4) { throw ('Unsupported PCK format: ' + $version) }
            $engine = '{0}.{1}.{2}' -f $reader.ReadUInt32(), $reader.ReadUInt32(), $reader.ReadUInt32()
            $flags = $reader.ReadUInt32()
            if ($flags -band 1) { throw 'Encrypted PCK directory is unsupported.' }
            $fileBase = $reader.ReadUInt64()
            if ($version -ge 3) { $stream.Position = $reader.ReadUInt64() }
            else { $stream.Position = 96 }
            $count = $reader.ReadUInt32()
            if ($count -gt 1000000) { throw 'Invalid PCK entry count.' }
            $entries = @()
            for ($i = 0; $i -lt $count; $i++) {
                $length = $reader.ReadUInt32()
                if ($length -gt 65536) { throw 'Invalid PCK path length.' }
                $name = [Text.Encoding]::UTF8.GetString($reader.ReadBytes($length)).TrimEnd([char]0)
                $offset = $reader.ReadUInt64()
                $size = $reader.ReadUInt64()
                $md5 = $reader.ReadBytes(16)
                $entryFlags = $reader.ReadUInt32()
                $relative = $name -replace '^res://', ''
                if ([IO.Path]::IsPathRooted($relative) -or $relative -match '(^|/)\.\.(/|$)' -or $relative.Contains(':') -or $relative.Contains('\')) { throw 'Unsafe PCK path.' }
                if ($relative -match '\.(gdc|gd|remap)$|^data/.*\.json$|^project\.binary$|^\.godot/(global_script_class_cache\.cfg|uid_cache\.bin)$') {
                    if ($size -gt 8MB -or $entryFlags -ne 0 -or ($fileBase + $offset + $size) -gt $stream.Length) { throw ('Unsupported PCK entry: ' + $name) }
                    $entries += @{ name = $relative; offset = ($fileBase + $offset); size = $size; md5 = $md5 }
                }
            }
            $total = 0L
            foreach ($entry in $entries) {
                $total += $entry.size
                if ($total -gt 64MB) { throw 'Diagnostic extraction exceeds 64 MiB.' }
                $stream.Position = $entry.offset
                $bytes = $reader.ReadBytes([int]$entry.size)
                if ($bytes.Length -ne $entry.size) { throw 'Truncated PCK entry.' }
                $hash = [Security.Cryptography.MD5]::Create()
                try { $actual = [BitConverter]::ToString($hash.ComputeHash($bytes)) }
                finally { $hash.Dispose() }
                $expected = [BitConverter]::ToString($entry.md5)
                $metadata.extracted += @{ pack = $pack.Name; name = $entry.name; md5Ok = ($actual -eq $expected) }
                $target = Join-Path (Join-Path $work $pack.BaseName) $entry.name
                $null = New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($target))
                [IO.File]::WriteAllBytes($target, $bytes)
            }
            $metadata.files[-1].engine = $engine
            $metadata.files[-1].pckFormat = $version
        } finally { $reader.Dispose(); $stream.Dispose() }
    }
    foreach ($exe in Get-ChildItem -LiteralPath $GameDirectory -Filter '*.exe' -File) {
        $metadata.files += @{ name = $exe.Name; size = $exe.Length; sha256 = (Get-FileHash -LiteralPath $exe.FullName -Algorithm SHA256).Hash }
    }
    $userData = Join-Path $env:APPDATA 'Godot/app_userdata/Tyrants of the Underdark'
    foreach ($folder in 'logs', 'bot_games') {
        $source = Join-Path $userData $folder
        if (-not (Test-Path -LiteralPath $source)) { continue }
        foreach ($file in Get-ChildItem -LiteralPath $source -File | Sort-Object LastWriteTime -Descending | Select-Object -First 3) {
            if ($file.Extension -notin '.log', '.replay', '.json') { continue }
            if ($file.Length -gt 8MB) { continue }
            $destination = Join-Path $work $folder
            $null = New-Item -ItemType Directory -Force -Path $destination
            Copy-Item -LiteralPath $file.FullName -Destination $destination
        }
    }
} catch {
    $metadata.errors += $_.Exception.Message
    Write-Warning $_.Exception.Message
} finally {
    [IO.File]::WriteAllText((Join-Path $work 'diagnostics.json'), ($metadata | ConvertTo-Json -Depth 8), $utf8)
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { $OutputDirectory = [IO.Path]::GetTempPath() }
$null = New-Item -ItemType Directory -Force -Path $OutputDirectory
$zip = Join-Path $OutputDirectory ('tyrants-starters-' + $stamp + '.zip')
Compress-Archive -Path (Join-Path $work '*') -DestinationPath $zip
Write-Host ('Saved: ' + $zip)
if ($metadata.errors.Count) { exit 1 }
