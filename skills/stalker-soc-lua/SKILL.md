---
name: stalker-soc-lua
description: Write and debug Lua scripts for S.T.A.L.K.E.R. Shadow of Chernobyl (X-Ray 1.0, retail 1.0006) - actor binder hooks, story state (pstor/info portions), HUD news and PDA map marks, spawning/releasing objects, navigation, time skips, effects, and the engine's many silent traps (uncatchable luabind errors, swallowed binder errors, delta setters, crashes in inventory callbacks). Use for any .script work in a SoC mod, or when a SoC script silently does nothing, hangs or crashes the game.
---

# SoC Lua scripting

Read `reference\gotchas.md` before writing non-trivial code - every entry there cost a debugging
session. `reference\patterns.md` has copy-ready snippets (spawn, release, inventory, time skip,
effects, sounds, conditions for logic). The authoritative API list is `unpacked\scripts\lua_help.script`
(grep it for a class or function before assuming it exists).

## Framework templates (`templates\scripts\`, `__PREFIX__` -> your prefix)

Installed into `src\mod\scripts\` by `stalker-soc-project-setup`:

| File | Role |
|---|---|
| `<p>_main.script` | entry points called from `bind_stalker.script`: `on_actor_spawn`, `on_actor_update`, `on_item_take/drop`, `on_take_from_box`; each hook wrapped in `pcall` and reported via `moddev.out` |
| `<p>_story.script` | persistent key/value (`get/set` over actor pstor), info portions (`has/give/take`), stage, `on_new_game` |
| `<p>_hud.script` | `news(string_id, ...)` with automatic splitting (HUD drops lines > ~100 chars), `news_later`, `mark/unmark` PDA map spots |
| `<p>_nav.script` | `point_near(x, z)` -> pos, lv, gv for `alife():create`; `spawn_near` |
| `<p>_props.script` | binder pinning physics of script-spawned static props |

The bind_stalker hooks themselves are patches in `src\tools\overrides.ps1`.

## Rules of thumb

- **Environment:** Lua 5.1 + luabind. No `io`, `os.*` mostly absent, `log()`/`printf` are no-ops.
  Output = `moddev.out()` (console trick). Test by running code in the live game with
  `game.ps1 cmd` (`stalker-soc-test-loop`).
- **Scripts are modules by file name**: `foo.script` is the global table `foo`, loaded on first use.
  Module-level `local` state resets on game load - persist through `<p>_story.set`.
- **Per-frame hook:** `on_actor_update` runs every frame; throttle (`if t < next_t then return end`).
- **Wrap every hook in pcall**: errors inside binder callbacks are swallowed with no log line.
- **Defer anything risky out of engine callbacks** (inventory take/drop, dialog actions): queue it and
  handle it in the next `on_actor_update` (and when `db.actor:is_talking()` is false for anything that
  touches the NPC being talked to or opens/closes UI).
- **Server vs client objects:** `alife():object(id)` (server, exists while in the game world, online
  or offline) vs `level.object_by_id(id)` (client, only when online, nil otherwise). NPC behaviour,
  health, positions for effects -> client object; creating/releasing -> server.
- **Strings:** every player-facing text is a string id (`game.translate_string`). Files are UTF-8 in
  `src\mod`, built to cp1251; no em dash / guillemets in game fonts (the build replaces them).
- **Prefix** every global, section, info portion and string id.

## Debugging workflow

1. `build.ps1`, `game.ps1 start`, reproduce with `game.ps1 cmd`.
2. Nothing happens and `cmd` still answers -> an error inside a guarded hook: look for
   `mod:error|in|...` lines (`game.ps1 log`).
3. `cmd` stops answering while the game renders -> Lua VM killed by a luabind exception, or an
   endless loop (check CPU). Bisect with `moddev.step("name")` markers; restart the game each run.
4. Crash with no message -> check the known engine traps in `reference\gotchas.md` first.
5. Record every new engine fact you verify in the project's own notes (e.g. `src\ENGINE_NOTES.md`).
