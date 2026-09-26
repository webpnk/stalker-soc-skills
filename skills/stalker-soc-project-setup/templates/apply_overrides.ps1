# Builds every overridden vanilla file: copies it from unpacked\ and applies the patches listed in
# overrides.ps1 as exact find/replace edits in windows-1251, writing to game\gamedata\.
# Each patch anchor must match exactly once, or the build stops (vanilla text changed / anchor too short).
$ErrorActionPreference = "Stop"
$root = (Resolve-Path "$PSScriptRoot\..\..").Path
$enc = [Text.Encoding]::GetEncoding(1251)
. "$PSScriptRoot\overrides.ps1"   # defines $Overrides and $Copies

foreach ($file in $Overrides.Keys) {
    $src = Join-Path "$root\unpacked" $file
    $dst = Join-Path "$root\game\gamedata" $file
    $text = $enc.GetString([IO.File]::ReadAllBytes($src))
    foreach ($p in $Overrides[$file]) {
        $find = $p[0] -replace "`r`n", "`n"
        $norm = $text -replace "`r`n", "`n"
        $n = ([regex]::Matches($norm, [regex]::Escape($find))).Count
        if ($n -ne 1) { throw "$file : patch anchor found $n times: $($p[0].Substring(0, [Math]::Min(60, $p[0].Length)))" }
        $text = $norm.Replace($find, ($p[1] -replace "`r`n", "`n")) -replace "(?<!`r)`n", "`r`n"
    }
    New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
    [IO.File]::WriteAllBytes($dst, $enc.GetBytes($text))
    "patched $file ($($Overrides[$file].Count) edits)"
}

foreach ($dst in $Copies.Keys) {
    $s = Join-Path "$root\unpacked" $Copies[$dst]
    $d = Join-Path "$root\game\gamedata" $dst
    New-Item -ItemType Directory -Force $d | Out-Null
    Copy-Item "$s\*" $d -Recurse -Force
    "copied $($Copies[$dst]) -> $dst"
}
