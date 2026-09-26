# Creates a SoC mod workspace (see ..\SKILL.md). Never touches the game install and never overwrites
# an existing file in the workspace, so it is safe to re-run.
#   new_workspace.ps1 -Root C:\stalker-mymod -Prefix mymod [-GameDir <SoC install>]
#                     [-ToolsFrom <dir>] [-UnpackedFrom <dir>]
# -ToolsFrom / -UnpackedFrom link (junction) an existing tools\ / unpacked\ folder instead of an
# empty one, so several mods can share one download and one unpacked vanilla copy.
param(
    [Parameter(Mandatory)][string]$Root,
    [Parameter(Mandatory)][ValidatePattern('^[a-z][a-z0-9]*$')][string]$Prefix,
    [string]$GameDir = "C:\Program Files (x86)\S.T.A.L.K.E.R. Shadow of Chernobyl",
    [string]$ToolsFrom,
    [string]$UnpackedFrom
)
$ErrorActionPreference = "Stop"
$skill = Split-Path $PSScriptRoot -Parent
$tpl = Join-Path $skill "templates"
$testLoop = Join-Path (Split-Path $skill -Parent) "stalker-soc-test-loop"
$utf8 = New-Object Text.UTF8Encoding $false
$cp1251 = [Text.Encoding]::GetEncoding(1251)

if (-not (Test-Path "$GameDir\bin\XR_3DA.exe")) { throw "not a SoC install: $GameDir (no bin\XR_3DA.exe)" }
if ((Resolve-Path $GameDir).Path.TrimEnd('\') -eq [IO.Path]::GetFullPath($Root).TrimEnd('\')) { throw "Root must not be the game install" }

function Ensure-Dir($p) { New-Item -ItemType Directory -Force $p | Out-Null }
function Put($path, $text) {
    # writes a UTF-8 text file unless it already exists; __PREFIX__ -> $Prefix
    if (Test-Path $path) { "  keep  $path"; return }
    Ensure-Dir (Split-Path $path)
    [IO.File]::WriteAllText($path, $text.Replace("__PREFIX__", $Prefix), $utf8)
    "  new   $path"
}
function PutTemplate($name, $dest) { Put $dest ([IO.File]::ReadAllText((Join-Path $tpl $name), $utf8)) }
function LinkOrDir($path, $from) {
    if (Test-Path $path) { return }
    if ($from) { New-Item -ItemType Junction -Path $path -Target (Resolve-Path $from).Path | Out-Null; "  link  $path -> $from" }
    else { Ensure-Dir $path }
}

"== folders"
foreach ($d in "game", "game\gamedata", "appdata\logs", "appdata\savedgames", "appdata\mod_ipc", "work", "downloads",
               "src\mod\config\$Prefix", "src\mod\config\gameplay", "src\mod\config\text\rus", "src\mod\config\scripts\$Prefix",
               "src\mod\scripts", "src\tools", "src\spawn", "src\art") { Ensure-Dir (Join-Path $Root $d) }
LinkOrDir (Join-Path $Root "tools") $ToolsFrom
LinkOrDir (Join-Path $Root "unpacked") $UnpackedFrom

"== working copy"
$game = Join-Path $Root "game"
if (-not (Test-Path "$game\bin\XR_3DA.exe")) {
    robocopy "$GameDir\bin" "$game\bin" /E /NFL /NDL /NJH /NJS /NP | Out-Null
    $global:LASTEXITCODE = 0   # robocopy returns 1 for "files copied"
    "  copied bin\"
}
foreach ($db in Get-ChildItem "$GameDir\gamedata.db*") {
    $dst = Join-Path $game $db.Name
    if (Test-Path $dst) { continue }
    try { New-Item -ItemType HardLink -Path $dst -Target $db.FullName | Out-Null; "  hardlink $($db.Name)" }
    catch { Copy-Item $db.FullName $dst; "  copied $($db.Name) (hard link failed: different volume?)" }
}
$fs = Join-Path $game "fsgame.ltx"
if (-not (Test-Path $fs)) {
    $t = $cp1251.GetString([IO.File]::ReadAllBytes("$GameDir\fsgame.ltx"))
    $t = [regex]::Replace($t, '(?m)^\$app_data_root\$.*$', ('$app_data_root$		= true|		false|	' + (Join-Path $Root "appdata")))
    if ($t -notmatch '\$mod_ipc\$') { $t = $t.TrimEnd() + "`r`n" + '$mod_ipc$       	= true|		true|	$app_data_root$|	mod_ipc\' + "`r`n" }
    [IO.File]::WriteAllBytes($fs, $cp1251.GetBytes($t))
    "  new   $fs (app data -> appdata\, `$mod_ipc`$ alias)"
}
# HIGHDPIAWARE compatibility flag for this copy's exe (per user, this exe path only). Without it, Windows
# display scaling (125%...) stretches the game window, and PrintWindow captures/click coordinates break.
$layers = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
$exe = Join-Path $game "bin\XR_3DA.exe"
if (-not (Test-Path $layers)) { New-Item -Path $layers -Force | Out-Null }
if (-not (Get-ItemProperty $layers -Name $exe -ErrorAction SilentlyContinue)) {
    New-ItemProperty -Path $layers -Name $exe -Value "HIGHDPIAWARE" -PropertyType String | Out-Null
    "  compat HIGHDPIAWARE for $exe"
}
# the dev command file must always exist (a missing file makes r_open throw an uncatchable error)
$cmd = Join-Path $Root "appdata\mod_ipc\cmd.lua"
if (-not (Test-Path $cmd)) { [IO.File]::WriteAllText($cmd, "--idle`n") }
$ul = Join-Path $Root "appdata\user.ltx"
if (-not (Test-Path $ul)) { Copy-Item (Join-Path $tpl "user.ltx") $ul; "  new   $ul (windowed 1280x720)" }

"== build tools"
PutTemplate "build.ps1" (Join-Path $Root "src\tools\build.ps1")
PutTemplate "apply_overrides.ps1" (Join-Path $Root "src\tools\apply_overrides.ps1")
PutTemplate "overrides.ps1" (Join-Path $Root "src\tools\overrides.ps1")
PutTemplate "names.txt" (Join-Path $Root "src\names.txt")
PutTemplate "gitignore.txt" (Join-Path $Root ".gitignore")

"== starter mod files"
$m = Join-Path $Root "src\mod"
foreach ($f in Get-ChildItem (Join-Path $tpl "mod") -Recurse -File) {
    $rel = $f.FullName.Substring((Join-Path $tpl "mod").Length + 1).Replace("__PREFIX__", $Prefix)
    Put (Join-Path $m $rel) ([IO.File]::ReadAllText($f.FullName, $utf8))
}

$luaSkill = Join-Path (Split-Path $skill -Parent) "stalker-soc-lua"
if (Test-Path $luaSkill) {
    "== Lua framework (stalker-soc-lua)"
    foreach ($f in Get-ChildItem (Join-Path $luaSkill "templates\scripts") -File) {
        Put (Join-Path $m ("scripts\" + $f.Name.Replace("__PREFIX__", $Prefix))) ([IO.File]::ReadAllText($f.FullName, $utf8))
    }
}

if (Test-Path $testLoop) {
    "== test-loop tools (stalker-soc-test-loop)"
    foreach ($f in Get-ChildItem (Join-Path $testLoop "scripts") -File) {
        $dst = Join-Path $Root "src\tools\$($f.Name)"
        if (-not (Test-Path $dst)) { Copy-Item $f.FullName $dst; "  new   $dst" }
    }
    Put (Join-Path $m "scripts\moddev.script") ([IO.File]::ReadAllText((Join-Path $testLoop "templates\moddev.script"), $utf8))
}

"== done. Next: fill unpacked\ (converter -unpack, see SKILL.md), then src\tools\build.ps1, then src\tools\game.ps1 start"
