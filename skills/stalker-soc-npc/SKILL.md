---
name: stalker-soc-npc
description: Add NPCs to a S.T.A.L.K.E.R. Shadow of Chernobyl mod - spawn section, npc_profile, specific_character (character_desc), logic .ltx (stand/remark, walker, kamp campfire, sleeper, sitting trader), trade config, communities and relations, voice muting, spawning from script, and keeping script-spawned NPCs out of vanilla smart terrains. Use when creating or changing any SoC stalker/trader NPC or its behaviour.
---
> `<skills>` below = the folder that contains this skill family (e.g. `%USERPROFILE%\.claude\skills` for a manual install, or the plugin's `skills` folder).


# SoC NPCs

## Generate the boilerplate

```powershell
& "<skills>\stalker-soc-npc\scripts\new_npc.ps1" -Root C:\stalker-mymod `
    -Id bob -Name "Боб" -Bio "Сталкер-одиночка." -Logic stand `
    -Visual actors\neytral\stalker_neytral_balon_1 -Supplies "wpn_pm=1,ammo_9x18_fmj=2,bread=1" `
    [-StartDialog mymod_bob_start] [-ActorDialogs mymod_bob_job] [-Community stalker] [-Rank 300] [-Mute]
```
Writes into `src\mod` (then run `build.ps1`), refusing to overwrite an existing id:

| File | Entry |
|---|---|
| `config\<p>\<p>_system.ltx` | `[<p>_bob]:<p>_npc_base` with `character_profile`, `custom_data` (logic), `$spawn` |
| `config\gameplay\<p>_npc_profile.xml` | `<character id>` -> class + specific_character |
| `config\gameplay\<p>_character_desc.xml` | `<specific_character>`: name/bio string ids, icon, community, rank, visual, supplies, dialogs |
| `config\scripts\<p>\<p>_npc_bob.ltx` | logic from `templates\logic\<Logic>.ltx` |
| `config\text\rus\<p>_main.xml` | `<p>_name_bob`, `<p>_bio_bob` |
| `config\misc\<p>_trade_bob.ltx` | traders only (`-Logic trader`) |

`-Logic`: `stand` (remark: stand, face the player), `walker` (patrol path), `kamp` (campfire; an NPC
with `guitar_a` in supplies plays it), `sleeper`, `trader` (Sidorovich desk animations, section
inherits `m_trader`, class `Trader`/`trader`, community `trader`). Walker/kamp/sleeper need patrol
path names (replace `CHANGE_ME`); vanilla ones can be reused - check with
`level.patrol_path_exists("name")`; new ones are added in all.spawn's `way_<level>.ltx`
(`stalker-soc-spawn`).

## Spawning

- **From script** (most flexible): `alife():create(section, pos, lv, gv)`; get pos/lv/gv from
  `<p>_nav.point_near(x, z)` or `spawn_near(section, x, z)`. Do it once per new game, store the id
  with `<p>_story.set`. `custom_data` in the section gives the NPC its logic.
- **In all.spawn** (static world population): `stalker-soc-spawn`.
- Test: `game.ps1 cmd "moddev.spawn_ahead('<p>_bob', 4)"`.

## Must-knows (verified)

- **`[smart_terrains] none = true`** in the logic file, or the nearest smart terrain gives the NPC a
  vanilla gulag job (with vanilla dialogs/barks) that overrides your logic. Templates include it.
- **Explosions/shots nearby = danger**: NPCs crouch and run for cover. Templates add
  `danger = <p>_no_danger` (`ignore_types = grenade, corpse, hit, sound`, `ignore_distance = 0`)
  to every scheme. Remove it for NPCs that should react.
- **Empty `<text></text>`** for a name/bio crashes the game at startup (the generator defaults the bio
  to the name; `build.ps1` rejects empty strings).
- A kamp center has a fixed number of places: **<= 4 NPCs per kamp**, or xr_kamp throws when one leaves.
- `snd_config` is the prefix for engine barks (hit, death, alarm). To mute an NPC entirely point it to
  a folder with no voice files (`-Mute` -> `characters_voice\<p>\`) and filter script barks by
  patching `sound_theme.script` (`load_sound_from_ltx`: return early for non-whitelisted themes).
  The vanilla mob_trader logic plays Sidorovich's voice via `sound_phrase` - the trader template omits it.
- Community goodwill decides hostility (`config\creatures\game_relations.ltx`,
  `[communities_relations]`): stalker/ecolog/dolg/trader are neutral to the actor, monolith/military/
  bandit/killer/zombied hostile. Community display names are string ids (`stalker`, `ecolog`,
  `trader`, ...) - override them in your string file to rename factions.
- Talking: the player must be within ~3 m and aim at the NPC's body/head. Sitting kamp NPCs: aim low.
- Key quest NPCs should not die: heal in the update loop (`o.health = 1 - o.health` - the setter adds
  a delta) and/or high immunities in the section.
- Scripted non-combat encounters with hostile NPCs: `npc:enable_memory_object(db.actor, false)` each
  update plus a `combat_ignore_cond = {=<p>_cond}` in the scheme with a condition registered in
  `xr_conditions` (see `stalker-soc-lua` patterns).
- Custom NPC visuals: `stalker-soc-art` (reskin a vanilla stalker OGF, keep its skeleton).
- Dialog wiring (`start_dialog` / `actor_dialog`): `stalker-soc-quests`.

## Useful vanilla visuals and icons

Visuals: `actors\neytral\stalker_neytral_balon_1..8`, `stalker_neytral_hood_1..9`,
`actors\novice\green_stalker_1..11` (rookies, faces visible), `actors\ecolog\stalker_ecolog`,
`actors\bandit\...`, `actors\militari\...`, `actors\monolit\...`, `actors\trader\trader`.
Icons: `ui_npc_u_stalker_neytral_balon_1`, `ui_npc_u_trader`, ... (see `config\ui\ui_npc_unique.xml`,
`ui_icons_npc.xml`).
