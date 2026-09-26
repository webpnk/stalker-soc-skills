# SoC 1.0006 engine gotchas (all verified in game)

## Lua environment
- No `io` library; `log()` and vanilla `printf` do nothing in retail. Log output: 
  `get_console():execute("tag:text_without_spaces")` -> `! Unknown command: tag:...` (only the first
  token is echoed, so encode spaces). `get_console():execute("flush")` writes the log now.
- **Luabind errors are C++ exceptions: `pcall` cannot catch them, and they kill the Lua VM for the
  whole session** (no callback runs afterwards, the game keeps rendering). Known triggers:
  - calling an overload that doesn't exist: `reader:r_eof()`, `fs:r_close(r)` (takes `reader*&`);
  - `alife():create(section, pos, lv, gv, nil)` - a nil 5th argument; omit it instead;
  - stalker script control `npc:move(move.standing, move.walk, move.line, vec)`;
  - reading some server-object fields: `se.m_level_vertex_id` came back nil - keep the lv you used.
  Plain Lua errors (nil index, `error()`) are caught by pcall normally.
- **Errors inside binder callbacks are swallowed silently** (the rest of the callback is skipped every
  frame). Always pcall + report.
- `fs:exist()` never sees files created after startup (FS list cache); `fs:r_open(<abs path>)` does.
  Use `r:r_elapsed()` for the byte count.

## Crashes without a message (stack in xrGame.dll)
- **An empty `<text></text>` in any string table** -> crash at startup, before the main menu, no message.
- `alife():create()` with a **section name that does not exist**.
- A model bone with a **gamemtl missing from gamemtl.xr** (crash when the object spawns).
- **Giving an info portion that starts a task, or adding a map spot, inside
  `actor_binder:on_item_take`** -> queue and do it next update.
- A **game task with only objective 0** crashes as soon as it's given: every task needs objective 0
  plus at least one sub-objective.
- **Releasing the NPC you are talking to from its own dialog action** -> "pure virtual function call".
  Set a flag in the action; release once `db.actor:is_talking()` is false.
- Releasing a corpse in the same frame it died (inventory transfer in progress): hide it
  (`npc:set_invisible(true)`), release a few seconds later.

## Hangs
- `while #q > 0 do handle(table.remove(q, 1)) end` where handling triggers the same callback that
  fills `q` -> never ends (game stuck on the loading screen). Swap: `local old = q; q = {}` then
  iterate `old`.

## Values and timing
- `obj.health = x`, `obj.psy_health = x`, `obj.power = x`, `obj.radiation = x` **add x (a delta)**,
  applied on the next update. Full heal: `a.health = 1 - a.health`.
- `obj:hit(h)` is also applied next update; measure results one tick later.
- Condition speeds in configs (`*_restore_speed`, `psy_health_v`) are per **game** second; the clock
  runs 10x real time by default (0.001 in config ~ 0.01 per real second).
- `db.actor:direction()` is **not** the view direction. Use `device().cam_dir` (flatten y).
- `set_actor_direction(yaw)`: face (x, z) with `-vector():set(dx, 0, dz):getH()`.
- `game.time()` is game ms; `time_global()` is real ms since start (not saved - never store it).
- Server objects (`alife():object`) have `position`, `id`, `parent_id`, `m_game_vertex_id`, `online`,
  `section_name()`, `name()`; no `angle`/direction.
- Script updates (actor binder) **stop while any UI window is open** (dialog, trade, inventory, PDA
  map). Queue follow-ups; don't start fades/time skips/`disable_input` from a dialog action - start
  them after the dialog closes.
- Time of day: 19:00 in summer is still daylight; night effects need ~22:00+.

## HUD / UI
- `give_game_news` silently drops a line longer than ~100 characters -> split (hud template).
- Game fonts lack em dash, en dash and « » (blank glyphs).
- A map spot on a released object logs `SMapLocation binded to non-existent object` every frame:
  unmark before releasing.
- String ids defined in later string files override vanilla ones (e.g. `actor_name`, community names
  `stalker`, `trader`, UI labels like `ui_st_your_items` = "Вещи Меченого").

## NPC behaviour (see stalker-soc-npc)
- Explosion sounds played at a position (even with the actor as owner) are **danger**: NPCs crouch or
  run for cover. Scheme key `danger = <sect>` with `ignore_types = grenade, corpse, hit, sound` and
  `ignore_distance = 0`.
- More NPCs on a kamp (campfire) than it has places -> Lua error in xr_kamp when one leaves.
- A script-spawned NPC without `[smart_terrains] none = true` in its logic gets a vanilla gulag job.
- `npc:enable_memory_object(db.actor, false)` makes an NPC forget the actor (for scripted non-combat).

## Effects
- `particles_object` and `sound_object` stop when garbage-collected: keep references in a table.
- `level.add_pp_effector("x.ppe", id, loop)` + `level.set_pp_effector_factor(id, f)`;
  `psy_antenna.ppe` at factor 1 bleaches the whole screen - 0.15 is a readable hint.
- Useful vanilla ppe: agr_u_fade (black fade), teleport, fire_hit, controller_hit, alcohol,
  psy_antenna, radiation, snd_shock, dead_zone.
- `level.add_cam_effector("camera_effects\\earthquake.anm", id, false, "")` shakes the camera.
- Particles far overhead are out of view: place shows in front of the player (cam_dir) ~45 m away,
  14-26 m up.

## Items / boxes (see stalker-soc-items)
- A script-created `inventory_box` opens only with `custom_data = scripts\treasure_inventory_box.ltx`
  in its section; `physics\box\box_metall_01` as a box visual has no use prompt (box_wood_01 works).
- `actor_binder:take_item_from_box(box, item)` fires per item, including Take All.
- Ammo into a box: `se_respawn.create_ammo(section, pos, lv, gv, box_id, count)`.

## Config / LTX
- A section missing a key the engine reads is fatal on spawn: `Can't find variable <key> in [<section>]`
  (e.g. an `af_base` artefact without `satiety_restore_speed`). Copy full key sets from vanilla.
- Textures referenced by a model must exist: `Can't find texture 'x'` (see stalker-soc-art: blender-xray
  texture naming).
- LTX parents must be defined before children: include mod sections at the END of system.ltx.
- `custom_data = <ltx path>` in a spawn section is read by `alife():create` (logic for script spawns).
