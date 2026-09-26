---
name: stalker-soc-art
description: Make 3D art and textures for a S.T.A.L.K.E.R. Shadow of Chernobyl mod headlessly with Blender 3.2 + the blender-xray add-on and Python - static props as single-bone OGFs, reskinned NPC visuals (procedural robes/cloaks/hoods/hats on the vanilla skeleton), procedural and text textures converted to DDS, inspecting vanilla OGFs. Use for any SoC model, prop, NPC visual, texture or icon-render work.
---

# SoC art pipeline (Blender 3.2 + blender-xray 2.46, headless)

Scripts (copy `scripts\*` into `<root>\src\art\`; they find the workspace two folders up):

| File | What |
|---|---|
| `xrlib.py` | enable blender-xray, point it at `unpacked\`; `reset_scene`, `import_ogf`, `export_ogf` (SoC format) |
| `proplib.py` | `material(name, texture)`, `finish_prop(mesh, name, mass, gamemtl, shape)` -> single-bone OGF with box collision; `PROP_DIR` |
| `propkit.py` | `Builder` (boxes, cylinders, quads/tris with per-face materials and UVs) + example props; `--preview` renders PNGs |
| `robe_kit.py` | dress a vanilla stalker OGF in procedural cloth on its own skeleton (animations/AI keep working); presets wraith, wizard, ranger, villager, robed; set `PREFIX` |
| `inspect_ogf.py` | print bones, shapes, mass, materials, flags of any OGF (learn vanilla conventions) |
| `texlib.ps1` | `Init-Tex <prefix>`, `Cloth`, `Metal`, `Solid`, `TextBoard` (Cyrillic text), `Save-Dds` via texconv |
| `build_textures_example.ps1` | example texture build (UTF-8 **with BOM** - Cyrillic in PS 5.1) |

Run: `& "C:\Program Files\Blender Foundation\Blender 3.2\blender.exe" -b --factory-startup -P <script.py> -- <args>`
(`--factory-startup` keeps user prefs out; xrlib re-enables the add-on each run). The message
`id_delete: Deleting IMRender Result which still has 1 users` after previews is harmless.

## Rules that crash the game if broken

- **Bone gamemtl must exist in gamemtl.xr** or the game crashes silently when the object spawns.
  Safe object materials: `objects\large_furniture`, `small_box`, `metal_box`, `barrel`, `bottle`,
  `glass`, `clothes`, `concrete_box`, `dead_body`, `fuel_can`, `large_metal_trash`,
  `small_metal_trash`, `tin_can` (full list: strings in `unpacked\gamemtl.xr`). NOT `objects\wood`.
- **Texture names in the OGF**: blender-xray writes paths relative to its textures folder (vanilla
  `unpacked\textures`). Mod textures live elsewhere, so it falls back to a heuristic that keeps the
  folder **only if the file name starts with `<folder>_`**. Name every mod texture
  `textures\<prefix>\<prefix>_<name>.dds` (texlib does it), or the OGF gets a bare name and the game
  dies with `Can't find texture '<name>'`. Check: `[Text.Encoding]::ASCII.GetString(bytes)` of the OGF
  and grep the texture strings.
- Max 2 bone weights per vertex in SoC OGFs (robe_kit computes weights accordingly).

## Static props

1. Build geometry with `propkit.Builder` (or any mesh), materials via `proplib.material(name,
   "wood\\wood_plank6")` or your textures. One-sided faces render from the front only; for text
   readable from both sides use two back-to-back quads with `fixed=True` (a two-sided material mirrors
   the text on the back).
2. `proplib.finish_prop(obj, name, mass, gamemtl, shape)` rigs bone `link` (box shape fitted to the
   bounds, or `shape=((cx,cy,cz),(hx,hy,hz))` - decorations get a small box at the base so they don't
   block walking) and exports `meshes\<PROP_DIR>\<name>.ogf`.
3. Place it: script spawn with a section `[<p>_prop_x]:<p>_prop_base` + `visual = <PROP_DIR>\x.ogf`
   (the props binder pins physics, because `fixed_bones` is ignored for script spawns), or an
   all.spawn `prop()` clone of a fixed physic_object (`stalker-soc-spawn`).

## NPC visuals (robe_kit)

- Pick a base whose silhouette/face you want: `actors\novice\green_stalker_N` (faces visible),
  `actors\neytral\stalker_neytral_*`, `actors\monolit\stalker_mo_hood_9` (hooded), `actors\trader\trader`.
- Preset keys: `robe_length` (0 = floor, 0.45 = knee), `flare`, `sleeve_flare`, `hood` (None/soft/deep),
  `face` (keep/void), `hat`, `tatters`, `head_scale`, `hunch`, `cloak_only`.
- Skeletons differ (trader lacks some spine bones): the kit is skeleton-agnostic via side detection and
  spine fallbacks; check new bases with a `--preview` render and in game from all sides and while
  running/crouching/sitting.
- Use the OGF as `<visual>` in the specific_character (`stalker-soc-npc`), path without `.ogf`.

## Textures

`texlib.ps1` draws PNGs with System.Drawing and converts with texconv (BC1 opaque / BC3 alpha, mips).
Fonts with Cyrillic: Georgia, Arial, Times New Roman. Keep sizes powers of two. Inventory icons:
`stalker-soc-items` (`build_atlas.ps1`).

## Known add-on quirks

- A second `bpy.ops.wm.read_factory_settings()` in one Blender session breaks blender-xray: xrlib
  clears data by hand after the first reset.
- Export with `fmt_version="soc"`, `texture_name_from_image_path=True`, `export_motions=False`.
- Round-trip check for new pipelines: import a vanilla OGF, export, spawn it in game.
