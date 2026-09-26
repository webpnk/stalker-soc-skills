# Decompiles the vanilla all.spawn into <root>\work\spawn_soc\all_soc\ (alife_<level>.ltx, way_<level>.ltx),
# the read-only base that build_spawn.py edits. Run once per workspace (lives in <root>\src\spawn\).
# Needs unpacked\spawns\all.spawn and unpacked\game.graph (ACDC wants game.graph next to all.spawn).
$ErrorActionPreference = "Stop"
$root = (Resolve-Path "$PSScriptRoot\..\..").Path
$acdc = Get-ChildItem "$root\tools" -Recurse -Filter universal_acdc.exe | Select-Object -First 1
if (-not $acdc) { throw "universal_acdc.exe not found under $root\tools (github.com/abramcumner/universal_acdc)" }
$work = "$root\work\spawn_soc"
if (Test-Path "$work\all_soc") { "already decompiled: $work\all_soc"; return }
New-Item -ItemType Directory -Force $work | Out-Null
Copy-Item "$root\unpacked\spawns\all.spawn", "$root\unpacked\game.graph" $work
foreach ($ini in "clsids.ini", "convert.ini", "way_prefixes.ini") { Copy-Item (Join-Path $acdc.DirectoryName $ini) $work }
Push-Location $work
try { & $acdc.FullName -d all.spawn -out all_soc -sort complex -nofatal | Select-Object -Last 3 }
finally { Pop-Location }
Get-ChildItem "$work\all_soc" -Filter "alife_*.ltx" | Measure-Object | ForEach-Object { "levels: $($_.Count)" }
