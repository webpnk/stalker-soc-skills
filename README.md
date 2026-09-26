# S.T.A.L.K.E.R. Shadow of Chernobyl modding skills for Claude Code

A family of [Claude Code skills](https://docs.claude.com/en/docs/claude-code/skills) that take the
boilerplate out of modding **S.T.A.L.K.E.R.: Shadow of Chernobyl** (X-Ray 1.0, patch 1.0006) on
Windows: workspace setup, a build pipeline, driving the game from Claude's shell, NPCs, dialogs and
tasks, items and icons, all.spawn editing, and headless Blender art.

Everything here was extracted from a real story mod and **verified in game** (SoC 1.0006 GOG,
Russian, xrCore build 3312): every generator and pipeline was run on a fresh workspace and checked by
launching the game. The engine traps it documents (silent crashes, uncatchable Lua errors, ...) were
each found the hard way.

| Skill | What it gives you |
|---|---|
| [`stalker-soc-project-setup`](skills/stalker-soc-project-setup/SKILL.md) | `new_workspace.ps1`: a safe working copy of the game (the install is never touched; `.db` files hard-linked), UTF-8 sources built to cp1251 `gamedata`, a find/replace patch system for vanilla files with the standard hooks, starter configs, windowed dev settings, `.gitignore` |
| [`stalker-soc-test-loop`](skills/stalker-soc-test-loop/SKILL.md) | `game.ps1`: start/load the game in the desktop session from Claude's Session-0 shell, keep it focused, screenshots, scan-code keys, closed-loop UI clicks, **run Lua inside the running game** (`moddev.script` command channel), log/crash diagnosis |
| [`stalker-soc-lua`](skills/stalker-soc-lua/SKILL.md) | script framework templates (guarded binder hooks, persistent story state, HUD news with auto-splitting, PDA marks, navigation, props binder), a verified **gotchas** list and copy-ready patterns |
| [`stalker-soc-npc`](skills/stalker-soc-npc/SKILL.md) | `new_npc.ps1`: spawn section + profile + character + logic (stand, walker, campfire, sleeper, sitting trader) + strings + trade config in one command |
| [`stalker-soc-quests`](skills/stalker-soc-quests/SKILL.md) | `new_task.ps1` (PDA task + info portions + strings), dialog templates and rules, articles, text/font rules |
| [`stalker-soc-items`](skills/stalker-soc-items/SKILL.md) | item templates (quest item, food, artefact, trap weight, stash box), `build_atlas.ps1` for custom inventory icons |
| [`stalker-soc-spawn`](skills/stalker-soc-spawn/SKILL.md) | decompile all.spawn with universal_acdc, describe edits in Python (remove/modify/add), rebuild; actor start position |
| [`stalker-soc-art`](skills/stalker-soc-art/SKILL.md) | Blender 3.2 + blender-xray helpers: static props as single-bone OGFs, procedural robe/cloak/hood reskins of vanilla NPCs, procedural and Cyrillic text textures |

## Install

**As a plugin** (Claude Code; needs `git` on PATH):
```
/plugin marketplace add https://github.com/webpnk/stalker-soc-skills.git
/plugin install stalker-soc-modding@stalker-soc-skills
```
(The short form `webpnk/stalker-soc-skills` clones over SSH and only works with a GitHub SSH key set up.)

**Or copy** the folders in `skills\` into `%USERPROFILE%\.claude\skills\` (personal) or a project's
`.claude\skills\`. Keep the family together: `new_workspace.ps1` pulls templates from the sibling
`stalker-soc-lua` and `stalker-soc-test-loop` skills.

## Quick start

Ask Claude: *"Set up a new SoC mod called mymod"*, or run it yourself:
```powershell
& "<skills>\stalker-soc-project-setup\scripts\new_workspace.ps1" -Root C:\stalker-mymod -Prefix mymod
# unpack vanilla gamedata into C:\stalker-mymod\unpacked (converter.exe, see the skill), then:
& C:\stalker-mymod\src\tools\build.ps1
& C:\stalker-mymod\src\tools\game.ps1 start
& C:\stalker-mymod\src\tools\game.ps1 cmd "moddev.out('hello', moddev.pos())"
```
`<skills>` = wherever the skills are installed.

## Requirements

- Windows, Windows PowerShell 5.1, S.T.A.L.K.E.R.: Shadow of Chernobyl 1.0006
- Third-party tools, downloaded once into the workspace's `tools\` (the skills say where from):
  xray_re-tools `converter.exe` (unpack), universal_acdc (all.spawn), texconv (DDS),
  Blender 3.2 + blender-xray 2.46 (models), Python 3 (Blender's bundled one works), optionally MinGit.
- No game assets are included in this repository; the skills work on your own unpacked copy.

## Notes

- The test loop starts programs in the interactive desktop session through a short-lived scheduled
  task (Claude's shell runs in Session 0, where the game can't start), and sets the `HIGHDPIAWARE`
  compatibility flag for the *working copy's* `XR_3DA.exe` so captures work under display scaling.
- Clear Sky / Call of Pripyat are not covered; much of the Lua and config knowledge is SoC-specific.

## License

MIT - see [LICENSE](LICENSE).
