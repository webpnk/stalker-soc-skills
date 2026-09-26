# Builds game\gamedata from sources:
#  1. src\mod\** (UTF-8, edited by hand) -> game\gamedata\**, text files transcoded to windows-1251
#     (the game's fonts and XML parser expect 1251 bytes; an encoding="UTF-8" header is rewritten).
#  2. apply_overrides.ps1: patched copies of vanilla files.
# Art/spawn outputs are written straight into game\gamedata by their own scripts and are left alone.
$ErrorActionPreference = "Stop"
$root = (Resolve-Path "$PSScriptRoot\..\..").Path
$src = "$root\src\mod"
$dst = "$root\game\gamedata"
$utf8 = New-Object Text.UTF8Encoding $false
$cp1251 = [Text.Encoding]::GetEncoding(1251)
$textExt = @(".xml", ".ltx", ".script", ".txt")

# name tokens {N:key} -> src\names.txt (proper names/translations in one place)
$names = @{}
if (Test-Path "$root\src\names.txt") {
    foreach ($line in [IO.File]::ReadAllLines("$root\src\names.txt", $utf8)) {
        if ($line -match '^\s*([a-z_0-9]+)\s*=\s*(.+?)\s*$') { $names[$Matches[1]] = $Matches[2] }
    }
}

$n = 0
Get-ChildItem $src -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($src.Length + 1)
    $out = Join-Path $dst $rel
    New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
    if ($textExt -contains $_.Extension.ToLower()) {
        $t = $utf8.GetString([IO.File]::ReadAllBytes($_.FullName)).TrimStart([char]0xFEFF)
        $t = $t -replace 'encoding\s*=\s*"UTF-8"', 'encoding="windows-1251"'
        $t = [regex]::Replace($t, '\{N:([a-z_0-9]+)\}', { param($m) if ($names.ContainsKey($m.Groups[1].Value)) { $names[$m.Groups[1].Value] } else { throw "$rel : unknown name token $($m.Value)" } })
        # an empty <text></text> in a string table crashes the game at startup (no message)
        if ($rel -like "config\text\*" -and $t -match "<text>\s*</text>") { throw "$rel has an empty <text></text> (crashes the game)" }
        # the game fonts have no em/en dash or guillemets: use a hyphen and plain quotes
        $t = $t.Replace([string][char]0x2014, '-').Replace([string][char]0x2013, '-').Replace([string][char]0x00AB, '"').Replace([string][char]0x00BB, '"')
        # refuse characters 1251 cannot hold instead of silently writing '?'
        $bytes = $cp1251.GetBytes($t)
        if ($cp1251.GetString($bytes) -ne $t) { throw "$rel contains characters outside windows-1251" }
        [IO.File]::WriteAllBytes($out, $bytes)
    } else {
        Copy-Item $_.FullName $out -Force
    }
    $n++
}
"copied $n files from src\mod"
& "$PSScriptRoot\apply_overrides.ps1"
