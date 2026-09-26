---
name: stalker-soc-spawn
description: Edit a S.T.A.L.K.E.R. Shadow of Chernobyl all.spawn reproducibly - decompile the vanilla spawn with universal_acdc, describe removals/modifications/additions in a Python edit list, rebuild and install all.spawn; move the actor start, remove vanilla NPCs/story triggers, strip vanilla logic, place static props and lamps, list level objects. Use for any SoC all.spawn / level population / actor start position change.
---

# SoC all.spawn pipeline

Never hand-edit binaries or the decompiled text: all changes live in `src\spawn\spawn_edits.py`
and are re-applied to the pristine decompiled vanilla spawn on every build.

## Setup (once per workspace)

Copy `scripts\*` into `<root>\src\spawn\` and `templates\spawn_edits.py` there too, then:
```powershell
& <root>\src\spawn\decompile_spawn.ps1     # -> work\spawn_soc\all_soc\alife_<level>.ltx, way_<level>.ltx
```
Any Python 3 runs the scripts; Blender's bundled one works:
`"C:\Program Files\Blender Foundation\Blender 3.2\3.2\python\bin\python.exe"`.

## Workflow

1. Find objects: `python list_objects.py l01_escape` (section counts) /
   `python list_objects.py l01_escape stalker m_trader` (names, positions, story ids).
2. Describe the change in `spawn_edits.py`:
   - `REMOVE_SECTIONS[level][section] = reason` - all objects of a section (e.g. every vanilla
     `stalker`), `REMOVE[level] = [(name, reason)]` - single objects (story restrictors, respawners,
     level changers), `STRIP_LOGIC` - keep a zone but drop its vanilla `[logic]`,
   - `MODIFY[level][name] = {key: value}` - any key; `custom_data` replaces the heredoc,
   - `ADD[level] = [...]` - clone a vanilla object of the same class (`template`) and override keys;
     helpers `prop()` (static decoration) and `lamp()` (hanging light).
3. `python build_spawn.py` - applies edits (fails loudly if a name isn't found), compiles with ACDC,
   installs `game\gamedata\spawns\all.spawn`, writes `REMOVED.md` (every change with its reason).
4. **A new game is required** to see spawn changes (saves embed the spawn state).

## Verified facts

- **Actor start**: the engine uses `upd:position` / `upd:o_torso` (yaw first, sign opposite to
  `set_actor_direction`) from the actor's update packet, not `position`/`direction`. Set all of them
  plus `level_vertex_id` / `game_vertex_id` (read in game with `moddev.pos()` while standing there).
  Starting inventory = the actor's `custom_data` (`[spawn]` list; `[dont_spawn_character_supplies]`).
- ACDC recompiles faithfully (section numbers/spawn ids renumber; semantic compare is clean).
- Static props from script ignore `fixed_bones`; in all.spawn clones of a fixed `physic_object`
  (`door0001` on the Cordon) with `fixed_bones = link` stay put. Script-spawned props need the
  props binder (`stalker-soc-lua`).
- Removing all vanilla stalkers also removes vanilla dialogs/story; keep respawners of mutants/loot
  boxes if you want the level alive, remove human respawners (`*_respawn`) or they come back.
- Patrol paths (`way_<level>.ltx`) can be added the same way (clone + edit points) for NPC logic;
  vanilla paths are often reusable (`level.patrol_path_exists(name)` in game).
- Script spawning (`alife():create`) is often simpler than all.spawn for story NPCs and anything
  that appears later; use all.spawn for static decoration, lights, and removing vanilla content.
