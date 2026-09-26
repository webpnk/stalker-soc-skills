# Adds a complete NPC to a SoC mod workspace (see ..\SKILL.md): spawn section, npc_profile entry,
# specific_character (character_desc), logic .ltx, name/bio strings, and a trade .ltx for traders.
#   new_npc.ps1 -Root C:\stalker-mymod -Id bob -Name "Боб" [-Bio "..."] [-Logic stand|walker|kamp|sleeper|trader]
#               [-Visual actors\neytral\stalker_neytral_balon_1] [-Icon ui_npc_u_stalker_neytral_balon_1]
#               [-Community stalker] [-Rank 300] [-Supplies "wpn_pm=1,ammo_9x18_fmj=2,bread=1"]
#               [-StartDialog <id>] [-ActorDialogs a,b] [-Mute] [-Prefix <p>]
# Files are edited in src\mod (UTF-8); run build.ps1 afterwards. Refuses to overwrite an existing NPC.
param(
    [Parameter(Mandatory)][string]$Root,
    [Parameter(Mandatory)][ValidatePattern('^[a-z][a-z0-9_]*$')][string]$Id,
    [Parameter(Mandatory)][string]$Name,
    [string]$Bio = "",
    [ValidateSet("stand", "walker", "kamp", "sleeper", "trader")][string]$Logic = "stand",
    [string]$Visual = "actors\neytral\stalker_neytral_balon_1",
    [string]$Icon = "ui_npc_u_stalker_neytral_balon_1",
    [string]$Community = "stalker",
    [int]$Rank = 300,
    [string]$Supplies = "bread=1",
    [string]$StartDialog,
    [string[]]$ActorDialogs = @(),
    [switch]$Mute,
    [string]$Prefix
)
$ErrorActionPreference = "Stop"
$skill = Split-Path $PSScriptRoot -Parent
$utf8 = New-Object Text.UTF8Encoding $false
$mod = Join-Path $Root "src\mod"
if (-not $Prefix) {
    $cands = Get-ChildItem (Join-Path $mod "config") -Directory | Where-Object { Test-Path (Join-Path $_.FullName "$($_.Name)_system.ltx") }
    if (@($cands).Count -ne 1) { throw "cannot detect the mod prefix; pass -Prefix" }
    $Prefix = @($cands)[0].Name
}
$sec = "${Prefix}_$Id"
if (-not $Bio) { $Bio = $Name }   # an empty <text></text> in a string table crashes the game at startup
function T($s) { $s.Replace("__PREFIX__", $Prefix).Replace("__ID__", $Id) }   # PREFIX first (see trade.ltx keys)
function Read-U($p) { [IO.File]::ReadAllText($p, $utf8) }
function Write-U($p, $t) { New-Item -ItemType Directory -Force (Split-Path $p) | Out-Null; [IO.File]::WriteAllText($p, $t, $utf8) }
function Insert-Before($path, $closing, $block) {
    $t = Read-U $path
    $i = $t.LastIndexOf($closing)
    if ($i -lt 0) { throw "$path has no $closing" }
    Write-U $path ($t.Substring(0, $i) + $block + $t.Substring($i))
    "  edit  $path"
}
function Esc($s) { [Security.SecurityElement]::Escape($s) }

$sys = Join-Path $mod "config\$Prefix\${Prefix}_system.ltx"
if ((Read-U $sys) -match "(?m)^\[$([regex]::Escape($sec))\]") { throw "section [$sec] already exists in $sys" }
$trader = $Logic -eq "trader"

# 1. spawn section
$parent = if ($trader) { "m_trader" } else { "${Prefix}_npc_base" }
$lines = @("", "[$sec]:$parent", "`$spawn              = `"$Prefix\$Id`"", "character_profile   = $sec",
           "custom_data         = scripts\$Prefix\${Prefix}_npc_$Id.ltx")
if ($trader) { $lines += "visual              = $Visual" }
elseif ($Community -ne "stalker") { $lines += "community           = $Community" }
Write-U $sys ((Read-U $sys).TrimEnd() + "`r`n" + ($lines -join "`r`n") + "`r`n")
"  edit  $sys"

# 2. npc_profile
$cls = if ($trader) { "Trader" } else { $sec }
Insert-Before (Join-Path $mod "config\gameplay\${Prefix}_npc_profile.xml") "</xml>" `
    "`t<character id=`"$sec`"><class>$cls</class><specific_character>$sec</specific_character></character>`r`n"

# 3. specific_character
$snd = if ($Mute) { "characters_voice\$Prefix\" } else { "characters_voice\human_01\$Community\" }
$sup = ($Supplies -split "," | Where-Object { $_ } | ForEach-Object { $kv = $_ -split "="; "`t`t`t$($kv[0].Trim()) = $($kv[1].Trim()) \n" }) -join "`r`n"
$dlg = @()
if ($StartDialog) { $dlg += "`t`t<start_dialog>$StartDialog</start_dialog>" }
foreach ($a in $ActorDialogs) { $dlg += "`t`t<actor_dialog>$a</actor_dialog>" }
$c = @(
    "`t<specific_character id=`"$sec`" no_random=`"1`">",
    "`t`t<name>${Prefix}_name_$Id</name>",
    "`t`t<icon>$Icon</icon>",
    "`t`t<bio>${Prefix}_bio_$Id</bio>",
    "`t`t<class>$(if ($trader) { 'trader' } else { $sec })</class>",
    "`t`t<community>$(if ($trader) { 'trader' } else { $Community })</community> <terrain_sect>stalker_terrain</terrain_sect>",
    "`t`t<rank>$Rank</rank>",
    "`t`t<reputation>0</reputation>",
    "`t`t<money min=`"50`" max=`"200`" infinitive=`"$(if ($trader) { 1 } else { 0 })`"/>",
    "`t`t<snd_config>$snd</snd_config>",
    "`t`t<crouch_type>0</crouch_type>",
    "`t`t<visual>$Visual</visual>",
    "`t`t<supplies>",
    "`t`t`t[spawn] \n",
    $sup,
    "`t`t</supplies>") + $dlg + @("`t</specific_character>", "")
Insert-Before (Join-Path $mod "config\gameplay\${Prefix}_character_desc.xml") "</xml>" ($c -join "`r`n")

# 4. logic
$logicPath = Join-Path $mod "config\scripts\$Prefix\${Prefix}_npc_$Id.ltx"
if (Test-Path $logicPath) { throw "$logicPath exists" }
Write-U $logicPath (T (Read-U (Join-Path $skill "templates\logic\$Logic.ltx")))
"  new   $logicPath"

# 5. strings
Insert-Before (Join-Path $mod "config\text\rus\${Prefix}_main.xml") "</string_table>" `
    ("`t<string id=`"${Prefix}_name_$Id`"><text>$(Esc $Name)</text></string>`r`n" +
     "`t<string id=`"${Prefix}_bio_$Id`"><text>$(Esc $Bio)</text></string>`r`n")

# 6. trade
if ($trader) {
    $tr = Join-Path $mod "config\misc\${Prefix}_trade_$Id.ltx"
    if (-not (Test-Path $tr)) { Write-U $tr (T (Read-U (Join-Path $skill "templates\trade.ltx"))); "  new   $tr" }
}

""
"Spawn it from Lua (e.g. in a setup step, once per new game; keep the id in story state):"
"  ${Prefix}_story.set(`"npc_$Id`", ${Prefix}_nav.spawn_near(`"$sec`", x, z).id)"
"or place it in all.spawn (stalker-soc-spawn). Then: build.ps1, game.ps1 start, game.ps1 cmd `"moddev.spawn_ahead('$sec', 4)`""
if ($Logic -in "walker", "kamp", "sleeper") { "Edit CHANGE_ME path names in $logicPath." }
if ($Mute) { "Muted: snd_config points to sounds\characters_voice\$Prefix\ (keep it empty, or copy only music there via `$Copies)." }
