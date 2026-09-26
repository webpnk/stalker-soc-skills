---
name: stalker-soc-items
description: Create items for a S.T.A.L.K.E.R. Shadow of Chernobyl mod - quest/story items, food, belt artefacts with custom stats, heavy trap items, script-spawned stash boxes with loot, custom inventory icons composited into the ui_icon_equipment atlas, and item handling from Lua (give, take, count, box callbacks). Use when adding or changing any SoC inventory item, icon, stash or loot.
---

# SoC items, icons and stashes

## Item sections

Start from `templates\items.ltx` (`__PREFIX__` -> your prefix); put sections into
`config\<p>\<p>_system.ltx` (or a file `#include`d from it). Patterns:

| Kind | Parent | Notes |
|---|---|---|
| story/quest item | `quest_case_01` | `quest_item = true`, `can_trade = false`; pick a vanilla visual (`equipments\item_document_1/2`, `item_merger`, `item_flash_2`, `weapons\vodka\vodka`, `physics\box\expl_dinamit.ogf`...) |
| food | `bread` (or `kolbasa`, `conserva`) | `eat_health`, `eat_power`, `eat_satiety` |
| belt artefact | `af_base` + `class = ARTEFACT` | `*_restore_speed` are per game second (x10 real time); `hit_absorbation_sect` immunities scale incoming hits while worn |
| trap weight | `quest_case_01`, `inv_weight = 400` | carrying it = can't move (there's no walk-speed API) |
| stash box | `inventory_box` | **must** have `custom_data = scripts\treasure_inventory_box.ltx`; use `physics\box\box_wood_01` (box_metall_01 gets no use prompt) |

Strings: `inv_name`, `inv_name_short`, `description` are string ids (never empty - an empty
`<text></text>` crashes the game). A section that doesn't exist crashes `alife():create` silently -
double-check spelling (validate section names against `unpacked\config` + your configs).

## Icons

1. Render or draw a transparent PNG per item into `src\art\icons\png\<section>.png` (e.g. a Blender
   orthographic render of the item model on a transparent background, 50 px per cell).
2. List cells in `src\art\icons\icons.json`: `{"<section>": {"x": col, "y": row, "w": cells, "h": cells}}`.
3. Run `scripts\build_atlas.ps1` (copy into `src\tools\`): it composites into a copy of the vanilla
   atlas, refuses to cover vanilla icons, writes `textures\ui\ui_icon_equipment.dds` (BC3, 1 mip)
   and prints the `inv_grid_*` values to paste into the sections.
Free cells in the SoC 1.0006 atlas: rows 37-39 (all columns), row 36 except columns 3-4, rows 27-35
columns 12-19. Only one mod can own `ui_icon_equipment.dds` - merge if combining mods.

## From Lua (see stalker-soc-lua patterns for full snippets)

- Give: `alife():create(section, pos, lv, gv, db.actor:id())` (never a nil parent argument).
- Count/take: `db.actor:iterate_inventory(function(dummy, item) ... end, db.actor)`, release by id.
- Has: `db.actor:object("section") ~= nil`.
- Box with loot: create the box, then items with `parent = box.id`; ammo via
  `se_respawn.create_ammo(section, pos, lv, gv, box.id, count)` (sections with `box_size`).
- Callbacks (hooked in `<p>_main`): `on_item_take(obj)` - **never give task info portions or add
  map spots inside it (crash)**, queue and react next update; `on_take_from_box(box, item)` fires per
  item including "take all"; `on_item_drop(obj)`.
- Treasure-style stashes revealed on the PDA: mark the box with `<p>_hud.mark(box_id, "hint_id")`.

## Traders

A trader's stock and prices come from its trade .ltx (`[trader] buy_condition / sell_condition /
buy_supplies`, see stalker-soc-npc `templates\trade.ltx`): `section = min_factor, max_factor` for
buy/sell, `section = count, probability` for supplies.
