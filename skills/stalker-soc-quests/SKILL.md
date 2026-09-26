---
name: stalker-soc-quests
description: Write dialogs, info portions, PDA tasks, PDA encyclopedia articles, news messages, map marks and Russian string tables for a S.T.A.L.K.E.R. Shadow of Chernobyl mod, with the file registrations they need and the crash rules (lone task objective, empty strings, tasks from inventory callbacks, NPC release in dialog actions). Use for any SoC quest, dialog, task or player-facing text work.
---
> `<skills>` below = the folder that contains this skill family (e.g. `%USERPROFILE%\.claude\skills` for a manual install, or the plugin's `skills` folder).


# SoC quests, dialogs and text

## Files (all under `src\mod\config\`, registered by the project-setup overrides)

| What | File | Registered in |
|---|---|---|
| dialogs | `gameplay\<p>_dialogs.xml` (`<game_dialogs>`) | system.ltx `[dialogs] files` |
| info portions (story flags) | `gameplay\<p>_info.xml` | system.ltx `[info_portions] files` |
| tasks | `gameplay\<p>_tasks.xml` (fragment, **no root element**) | `#include` in `game_tasks.xml` |
| PDA articles | `gameplay\<p>_encyclopedia.xml` | system.ltx `[encyclopedia] files` |
| strings | `text\rus\<p>_*.xml` (`<string_table>`) | `localization.ltx` string file list |
| NPC -> dialogs | `<start_dialog>` / `<actor_dialog>` in `gameplay\<p>_character_desc.xml` | (stalker-soc-npc) |

Adding a new file = add its name (without .xml) to the list in the matching override patch.

## Tasks - use the generator

```powershell
& "<skills>\stalker-soc-quests\scripts\new_task.ps1" -Root C:\stalker-mymod `
    -Id bob_job -Title "Посылка для Боба" -Summary "Помочь Бобу" -Objectives "Найти посылку","Отнести посылку Бобу"
```
Creates the task, info portions `<p>_bob_job_given` (carries `<task>`, gives the task),
`<p>_bob_job_1..N` (objective done), `<p>_bob_job_done` (task done), and all strings.
- **A task with only objective 0 crashes the game when given** - the generator always adds the
  objectives after the summary objective 0.
- Objective 0's `infoportion_complete` completes the whole task.
- Icons: `ui_iconsTotal_find_item`, `ui_iconsTotal_kill_stalker` (see `config\ui\ui_iconstotal.xml`).
- **Never give task info portions (or add map spots) inside `actor_binder:on_item_take`** - crash.
  Queue and give on the next update.

## Dialogs - start from `templates\dialogs.xml`

- Speaker alternates by depth. **start_dialog: phrase 0 = NPC**, children = actor choices, next level
  = NPC (the NPC takes its **first valid** reply). **actor_dialog: phrase 0 = the actor's menu line.**
- actor_dialogs show in the menu after the start dialog ends. If no start-dialog branch applies, the
  player must pick its last line to reach the menu - make that line neutral ("Есть разговор."), not
  "bye".
- Gating: `<has_info>`, `<dont_has_info>`, `<precondition>module.func</precondition>` per phrase or per
  dialog (dialog-level = whether it appears in the menu). Effects: `<give_info>`, `<disable_info>`,
  `<action>module.func</action>`. Script functions receive `(npc, actor)`-style args (first/second
  speaker); return booleans from preconditions.
- Inside an `<action>` don't release/teleport the NPC being talked to, start fades, time skips or
  `level.disable_input()` - script updates are paused while the window is open. Set a flag; act when
  `db.actor:is_talking()` is false.
- Vanilla traders get a "Торговать" button from their trade config; any NPC with a trade section/
  profile shows it.
- Testing in game: `moddev.tp_face(id, 1.4)`, `game.ps1 keys "f"`, `game.ps1 click "350,589"` (first
  answer line at 1280x720; lines are ~18 px apart), screenshot, repeat. Verify flags with
  `game.ps1 cmd "moddev.out(has_alife_info('x'))"`.

## Info portions

```xml
<info_portion id="<p>_bob_met"></info_portion>
<info_portion id="<p>_intro_done"><task>...</task></info_portion>          <!-- gives a task -->
<info_portion id="<p>_saw_ring"><article>p_art_ring</article></info_portion> <!-- adds a PDA article -->
```
Give from Lua: `db.actor:give_info_portion(id)` (guard with `has_alife_info`); from logic condlists:
`%+id%`; test in logic: `{+id}` / `{-id}`. Info portions are saved by the engine.

## PDA articles

```xml
<article id="<p>_art_ring" name="<p>_art_ring_name" group="<p>_art_group">
	<ltx>item_section_for_icon</ltx>
	<text><p>_art_ring_text</text>
</article>
```

## Strings and fonts

- UTF-8 in `src\mod`, built to windows-1251 (build refuses non-cp1251 characters).
- **An empty `<text></text>` crashes the game at startup** (build.ps1 refuses it).
- Game fonts lack em/en dashes and guillemets (build converts them to `-` and `"`).
- `\n` inside `<text>` is a line break. `%s` works with `string.format` in `news(id, ...)`.
- Later string files override vanilla ids: rename the player (`actor_name`), factions (`stalker`,
  `ecolog`, `monolith`, `trader`...), UI labels (`ui_st_your_items` = "Вещи Меченого").
- Keep proper names as `{N:key}` tokens (`src\names.txt`) so a translation choice lives in one place.
- No Russian text inside scripts: always string ids + `game.translate_string`.

## News and map marks (`<p>_hud.script`)

- `news("id")` splits text: **a HUD news line over ~100 characters is silently dropped**.
- `news_later(ms, "id")` spaces out tutorial messages.
- `mark(obj_id, "hint_string_id"[, "green_location"])` / `unmark(obj_id)` - unmark before releasing.
