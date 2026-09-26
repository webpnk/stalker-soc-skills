---
name: stalker-soc-test-loop
description: Run, drive and observe S.T.A.L.K.E.R. Shadow of Chernobyl from Claude's (Session 0) shell - launch/load the game in the user's desktop session, keep it focused, capture screenshots, send keys and UI clicks, run Lua inside the running game through a dev command channel, read logs and crash dumps. Use whenever testing a SoC mod in game, reproducing a bug, checking visuals, or when the game "does nothing"/hangs/crashes during a test.
---

# SoC in-game test loop

Tools (in `scripts\`, copied into `<root>\src\tools\` by `stalker-soc-project-setup`; they locate the
workspace as two folders up from themselves):

| Script | What |
|---|---|
| `game.ps1` | the one entry point: `start [-Load save] [-NoFocus]`, `shot`, `cmd "<lua>"`, `keys`, `click`, `log`, `stop` |
| `run_interactive.ps1` | run any exe in the user's desktop session (scheduled-task trick) |
| `capture_game.ps1` | PrintWindow capture (DPI-aware), works while occluded |
| `focus_game.ps1` / `keep_focus.ps1` | force the game window to the foreground (once / every 2 s) |
| `sendkeys.ps1` | DirectInput-compatible scan-code keys; `w:3000` holds W for 3 s; `_` pauses |
| `mouse_move.ps1` | relative mouse deltas in small steps (camera look, UI cursor) |
| `click_game.ps1` | closed-loop UI click: finds SoC's yellow cursor in a capture and corrects |

Lua side: `templates\moddev.script` -> `src\mod\scripts\moddev.script`, enabled by
`[moddev] enabled = true` in the mod's system include, called from the actor binder
(`moddev.on_spawn()` in net_spawn, `moddev.update(time_global())` every update - the
`stalker-soc-lua` main-script template does this). `fsgame.ltx` needs
`$mod_ipc$ = true| true| $app_data_root$| mod_ipc\`.

## Why it works this way (facts verified by testing)

- Claude's shell is **Session 0**: the game crashes creating its input device there, and windows
  can't be captured/focused. `run_interactive.ps1` registers a one-off scheduled task
  (`LogonType Interactive`, current user), starts it and deletes it.
- **SoC pauses while its window is inactive** - no script updates, no command replies.
  `game.ps1 start` launches `keep_focus.ps1`. When the *user* is going to play, use `-NoFocus`
  (otherwise the helper keeps stealing focus) and tell them to click the taskbar icon.
- The engine `screenshot` command refuses to work windowed -> PrintWindow capture. Windowed mode comes
  from `appdata\user.ltx` (`rs_fullscreen off`, `vid_mode 1280x720`). A capture of ~199x34 means
  the window is minimized.
- **Display scaling**: the working-copy exe needs the `HIGHDPIAWARE` compatibility flag
  (`HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers`, value name = exe path;
  project-setup sets it). Without it at 125% scaling captures come out 1608x936 with black bars and
  click coordinates are off. Expected capture at 1280x720 windowed: 1286x755.
- Keyboard needs hardware scan codes (DirectInput ignores VK events).
- Mouse: SoC reads relative DirectInput deltas, ignores the OS cursor, and drops large bursts ->
  steps of <=20 counts. ~0.78 x 0.71 window px per count for the UI cursor at 1280x720, ~2.7 px of
  camera turn per count. The first click after a focus change is often lost: click, capture, verify.
- The log is only written on exit unless flushed: moddev flushes every 5 s and after each command.
- Script updates stop while a dialog/trade/inventory window is open -> `cmd` times out. Close UI
  (`keys "esc"`) first.

## Typical session

```powershell
$g = "<root>\src\tools\game.ps1"
& "<root>\src\tools\build.ps1"            # always rebuild first
& $g start                                   # new game; waits for "mod:actor spawned"
& $g cmd "moddev.god = true; moddev.tp_near(-200, -140); moddev.face(-205, -150)"
& $g shot                                    # then Read <root>\appdata\game.png to look at it
& $g cmd "moddev.out('state', level.get_time_hours(), has_alife_info('mymod_started'))"
& $g keys "f"                                # use/talk
& $g click "400,589"                         # first dialog answer line
& $g log -Tail 80
```

`cmd` runs any Lua (multi-line via a here-string) with `pcall`; runtime and compile errors are
printed. Output only via `moddev.out(...)`. Globals persist between commands (`test_id = ...`).

Dev helpers in moddev: `out, pos, tp, tp_near(x,z), face(x,z), look_dir(), tp_face(id[,dist]),
spawn_ahead(section[,dist]), give(section[,n]), find(name), tp_to(name), near(r), god, step(name),
point_near(x,z)`.

Also useful: `get_console():execute('save my_dev_save')` for dev saves (load with
`start -Load my_dev_save`); `level.set_time_factor(n)`; `db.actor:give_money(n)`.

## Diagnosing "nothing happens"

1. `Get-Process XR_3DA | select Responding` + CPU over 5 s. **0 CPU** = paused (unfocused, or a UI
   window open). High CPU + no replies = a script loop that never ends (seen: a queue refilled while
   draining). Render frozen = engine hang.
2. `cmd` times out but the game renders and is focused -> **the Lua VM is dead** for this session:
   an uncatchable luabind error (wrong overload / bad argument) killed it. Restart the game; bisect with
   `moddev.step("marker")` calls (one-shot `modstep_<marker>` log lines) around suspect code.
3. Crash: newest `appdata\logs\*.mdmp.log` (or the `FATAL ERROR` block in `xray_<user>.log`).
   Read the lines *before* `stack trace:`; `[error]Arguments : LUA error: <file>:<line>` names Lua
   crashes. A bare stack in xrGame.dll with no message = engine-side trap (see `stalker-soc-lua`
   gotchas: missing section, bad gamemtl, lone task objective, releasing a talking NPC...).
4. `***FATAL***: Too many lmap-textures` in the log is harmless noise on this build.
5. Errors raised inside binder callbacks are **silently swallowed** - wrap hooks in pcall and report
   through `moddev.out` (the main-script template does).

## PowerShell pitfalls in this loop

- Piping into `Select-Object -First N` **stops the upstream command** after N objects (PS 5.1) - never
  pipe a build script into it; use `-Last N` or `Out-Null`.
- Variable names are case-insensitive: a local `$logic` overwrites a `[ValidateSet]` parameter `$Logic`.
- The Claude harness may refuse to delete top-level folders on C:; overwrite files instead.

## Aiming at NPCs / objects for "use"

`moddev.tp_face(id, 1.4)` places you in front of the object; then adjust with
`mouse_move.ps1 -DX .. -DY ..` via `run_interactive` and `keys "f"`. Screenshot after each step.
Sitting/lying NPCs (kamp) need the camera pointed down (`-DY 100..160`).
