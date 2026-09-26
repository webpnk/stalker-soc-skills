# Test-loop helper for a SoC mod workspace (<root>\src\tools\game.ps1). Claude's shell runs in
# Session 0, so the game and window captures are started in the interactive session via run_interactive.ps1.
#   game.ps1 start [-Load <save>] [-NoFocus]  new game (or load a save), windowed; waits for the actor
#   game.ps1 shot [-Front]                    capture the game window to appdata\game.png
#   game.ps1 stop                             kill the game (and the focus keeper)
#   game.ps1 log [-Tail N]                    newest log (crash logs are *.mdmp.log / FATAL ERROR blocks)
#   game.ps1 cmd "<lua>" [-Wait s]            run Lua in the game (moddev channel), print its output
#   game.ps1 keys "w:3000,f"                  scan-code keys (sendkeys.ps1 names, comma separated)
#   game.ps1 click "640,590[,r|d]"            click in the game UI (window-relative, same frame as 'shot')
param(
    [Parameter(Position = 0, Mandatory)][ValidateSet("start", "shot", "stop", "log", "cmd", "keys", "click")][string]$Cmd,
    [Parameter(Position = 1)][string]$Lua,
    [int]$Wait = 20,
    [int]$Focus = 1800,
    [string]$Load,
    [switch]$NoFocus,
    [switch]$Front,
    [int]$Tail = 60
)
$root = (Resolve-Path "$PSScriptRoot\..\..").Path
$tools = $PSScriptRoot
$logf = "$root\appdata\logs\xray_$env:USERNAME.log"
$ipc = "$root\appdata\mod_ipc\cmd.lua"
function Hidden($inner) { "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command `"$inner`"" }
function StopFocus {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -match "keep_focus" } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}
switch ($Cmd) {
    "start" {
        Get-Process XR_3DA -ErrorAction SilentlyContinue | Stop-Process -Force
        StopFocus
        Start-Sleep -Milliseconds 1500   # let a killed game's last log write land before $before
        # the command file must always exist: r_open on a missing file throws an uncatchable error
        New-Item -ItemType Directory -Force (Split-Path $ipc) | Out-Null
        [IO.File]::WriteAllText($ipc, "--idle`n")
        $before = if (Test-Path $logf) { (Get-Item $logf).LastWriteTime } else { [datetime]::MinValue }
        if ($Load) { $srv = "server($Load/single/alife/load)" } else { $srv = "server(all/single/alife/new)" }
        & "$tools\run_interactive.ps1" -Exe "$root\game\bin\XR_3DA.exe" -Arguments "-noprefetch -nointro -start $srv client(localhost)" -WorkDir "$root\game"
        # SoC pauses while unfocused: keep the window focused for the session (skip when a human plays)
        if (-not $NoFocus) {
            & "$tools\run_interactive.ps1" -Exe powershell.exe -Arguments "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File $tools\keep_focus.ps1 -Seconds $Focus" | Out-Null
        }
        for ($i = 0; $i -lt 180; $i++) {
            Start-Sleep 1
            if (-not (Get-Process XR_3DA -ErrorAction SilentlyContinue)) { "game exited during load (see: game.ps1 log)"; return }
            if ((Test-Path $logf) -and (Get-Item $logf).LastWriteTime -gt $before -and
                (Select-String -Path $logf -Pattern "mod:actor\|spawned" -Quiet)) { "ready after $i s"; return }
        }
        "not ready after 180 s (no 'mod:actor spawned' line: is moddev.script enabled and hooked?)"
    }
    "shot" {
        $a = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File $tools\capture_game.ps1 -Out $root\appdata\game.png"
        if ($Front) { $a += " -Front" }
        Remove-Item "$root\appdata\game.png.txt" -ErrorAction SilentlyContinue
        & "$tools\run_interactive.ps1" -Exe powershell.exe -Arguments $a | Out-Null
        for ($i = 0; $i -lt 20 -and -not (Test-Path "$root\appdata\game.png.txt"); $i++) { Start-Sleep -Milliseconds 500 }
        Get-Content "$root\appdata\game.png.txt"
    }
    "cmd" {
        # run Lua through moddev's command channel and print what it logged
        $tag = "--" + [guid]::NewGuid().ToString("N").Substring(0, 8)
        [IO.File]::WriteAllText($ipc, "$tag`n$Lua`n")
        for ($i = 0; $i -lt $Wait * 4; $i++) {
            Start-Sleep -Milliseconds 250
            if (-not (Test-Path $logf)) { continue }
            $fs = [IO.File]::Open($logf, "Open", "Read", "ReadWrite")
            $all = (New-Object IO.StreamReader($fs, [Text.Encoding]::GetEncoding(1251))).ReadToEnd(); $fs.Close()
            $end = $all.IndexOf("mod:==|done|$tag", [StringComparison]::OrdinalIgnoreCase)
            if ($end -ge 0) {
                $prev = $all.LastIndexOf("mod:==|done", [Math]::Max(0, $end - 1), [StringComparison]::OrdinalIgnoreCase)
                $chunk = $all.Substring([Math]::Max(0, $prev), $end - [Math]::Max(0, $prev))
                ($chunk -split "`r?`n" | Where-Object { ($_ -match "mod:|error|^! " -and $_ -notmatch "==\|done") -and $_ -notmatch "^! Unknown command:\s+(modstep_|$)" } |
                    ForEach-Object { ($_ -replace "^! Unknown command:\s+mod:", "") -replace "\|", " " }) -join "`n"
                return
            }
        }
        "timeout: no reply in $Wait s (game not running, loading, paused/unfocused, a UI window open, or the Lua VM is dead)"
    }
    "keys" {
        & "$tools\run_interactive.ps1" -Exe powershell.exe -Arguments (Hidden "& $tools\focus_game.ps1; & $tools\sendkeys.ps1 -Keys $Lua") | Out-Null
        $total = 3; foreach ($k in $Lua -split ",") { if ($k -match ':(\d+)$') { $total += [int]$Matches[1] / 1000 } else { $total += 0.2 } }
        Start-Sleep -Seconds ([Math]::Ceiling($total))
        "sent $Lua"
    }
    "click" {
        $xy = $Lua -split ","
        $mode = if ($xy.Count -gt 2 -and $xy[2] -eq 'r') { '-Right' } elseif ($xy.Count -gt 2 -and $xy[2] -eq 'd') { '-Double' } else { '' }
        & "$tools\run_interactive.ps1" -Exe powershell.exe -Arguments (Hidden "& $tools\focus_game.ps1; & $tools\click_game.ps1 -X $($xy[0]) -Y $($xy[1]) $mode") | Out-Null
        Start-Sleep -Seconds 4
        "clicked $Lua"
    }
    "stop" {
        Get-Process XR_3DA -ErrorAction SilentlyContinue | Stop-Process -Force
        StopFocus
        "stopped"
    }
    "log" {
        $f = Get-ChildItem "$root\appdata\logs\*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        "== $($f.Name)"; Get-Content $f.FullName -Tail $Tail
    }
}
