# Adds a PDA task to a SoC mod workspace: the task (tasks fragment), the info portion that gives it,
# one completion info portion per objective, and all strings. Edits src\mod (UTF-8); run build.ps1.
#   new_task.ps1 -Root C:\stalker-mymod -Id bob_job -Title "Посылка для Боба" `
#       -Objectives "Найти посылку","Отнести посылку Бобу" [-Summary "Помочь Бобу"] [-Icon ui_iconsTotal_find_item] [-Prio 100]
# Result: give_info <p>_<id>_given (dialog <give_info> or <p>_story.give) starts the task;
#         <p>_<id>_1 .. _N complete the objectives; <p>_<id>_done completes the whole task.
# SoC crashes if a task has only objective 0, so objective 0 (the summary) is always followed by
# the listed objectives.
param(
    [Parameter(Mandatory)][string]$Root,
    [Parameter(Mandatory)][ValidatePattern('^[a-z][a-z0-9_]*$')][string]$Id,
    [Parameter(Mandatory)][string]$Title,
    [Parameter(Mandatory)][string[]]$Objectives,
    [string]$Summary,
    [string]$Icon = "ui_iconsTotal_find_item",
    [int]$Prio = 100,
    [string]$Prefix
)
$ErrorActionPreference = "Stop"
$utf8 = New-Object Text.UTF8Encoding $false
$mod = Join-Path $Root "src\mod"
if (-not $Prefix) {
    $cands = Get-ChildItem (Join-Path $mod "config") -Directory | Where-Object { Test-Path (Join-Path $_.FullName "$($_.Name)_system.ltx") }
    if (@($cands).Count -ne 1) { throw "cannot detect the mod prefix; pass -Prefix" }
    $Prefix = @($cands)[0].Name
}
if (-not $Summary) { $Summary = $Title }
$t = "${Prefix}_task_$Id"
$i = "${Prefix}_$Id"
function Read-U($p) { [IO.File]::ReadAllText($p, $utf8) }
function Write-U($p, $x) { [IO.File]::WriteAllText($p, $x, $utf8) }
function Esc($s) { if (-not $s.Trim()) { throw "empty text (an empty <text></text> crashes the game)" }; [Security.SecurityElement]::Escape($s) }
function Insert-Before($path, $closing, $block) {
    $x = Read-U $path; $k = $x.LastIndexOf($closing)
    if ($k -lt 0) { throw "$path has no $closing" }
    Write-U $path ($x.Substring(0, $k) + $block + $x.Substring($k)); "  edit  $path"
}

$tasks = Join-Path $mod "config\gameplay\${Prefix}_tasks.xml"
if ((Read-U $tasks) -match "game_task id=`"$t`"") { throw "task $t exists" }

# task (fragment: append at the end)
$o = @("`t<game_task id=`"$t`" prio=`"$Prio`">", "`t`t<title>$t</title>",
       "`t`t<objective>", "`t`t`t<text>${t}_0</text>", "`t`t`t<icon>$Icon</icon>",
       "`t`t`t<infoportion_complete>${i}_done</infoportion_complete>", "`t`t</objective>")
for ($n = 1; $n -le $Objectives.Count; $n++) {
    $o += "`t`t<objective>", "`t`t`t<text>${t}_$n</text>", "`t`t`t<infoportion_complete>${i}_$n</infoportion_complete>", "`t`t</objective>"
}
$o += "`t</game_task>"
Write-U $tasks ((Read-U $tasks).TrimEnd() + "`r`n`r`n" + ($o -join "`r`n") + "`r`n")
"  edit  $tasks"

# info portions
$inf = "`t<info_portion id=`"${i}_given`"><task>$t</task></info_portion>`r`n"
for ($n = 1; $n -le $Objectives.Count; $n++) { $inf += "`t<info_portion id=`"${i}_$n`"></info_portion>`r`n" }
$inf += "`t<info_portion id=`"${i}_done`"></info_portion>`r`n"
Insert-Before (Join-Path $mod "config\gameplay\${Prefix}_info.xml") "</game_information_portions>" $inf

# strings
$s = "`t<string id=`"$t`"><text>$(Esc $Title)</text></string>`r`n`t<string id=`"${t}_0`"><text>$(Esc $Summary)</text></string>`r`n"
for ($n = 1; $n -le $Objectives.Count; $n++) { $s += "`t<string id=`"${t}_$n`"><text>$(Esc $Objectives[$n - 1])</text></string>`r`n" }
Insert-Before (Join-Path $mod "config\text\rus\${Prefix}_main.xml") "</string_table>" $s

""
"Start:    <give_info>${i}_given</give_info> in a dialog, or ${Prefix}_story.give(`"${i}_given`")"
"Progress: ${Prefix}_story.give(`"${i}_1`") ... `"${i}_$($Objectives.Count)`";  finish: `"${i}_done`""
"NB: never give these from inside actor_binder:on_item_take (crash) - defer to the next update."
