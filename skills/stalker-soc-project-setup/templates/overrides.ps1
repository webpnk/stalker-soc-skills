# Patch list for apply_overrides.ps1: vanilla relative path -> list of @(find, replace).
# ASCII only in this file (it is read as the system code page). Anchors verified on SoC 1.0006.
# Mark every insertion with "__PREFIX__:" so it can be found later.
$Overrides = [ordered]@{

    "config\system.ltx" = @(
        # at the very end, so mod sections can inherit anything defined in system.ltx
        ,@("actors\monolit\stalker_mo_mask`nactors\monolit\stalker_mo_nauchniy",
           "actors\monolit\stalker_mo_mask`nactors\monolit\stalker_mo_nauchniy`n`n; __PREFIX__: mod sections`n#include `"__PREFIX__\__PREFIX___system.ltx`"`n")
        ,@("files =  npc_profile",
           "files =  npc_profile, __PREFIX___npc_profile ; __PREFIX__:")
        ,@("character_desc_kishka, character_desc_sarcofag",
           "character_desc_kishka, character_desc_sarcofag, __PREFIX___character_desc ; __PREFIX__:")
        ,@("dialogs_radar, dialogs_aes",
           "dialogs_radar, dialogs_aes, __PREFIX___dialogs ; __PREFIX__:")
        ,@("encyclopedia_equipment, encyclopedia_tutorial",
           "encyclopedia_equipment, encyclopedia_tutorial, __PREFIX___encyclopedia ; __PREFIX__:")
        ,@("info_l22warlab, info_stories",
           "info_l22warlab, info_stories, __PREFIX___info ; __PREFIX__:")
    )

    "config\localization.ltx" = @(
        # string table files (config\text\rus\<name>.xml), comma separated
        ,@("ui_st_other, stable_game_credits",
           "ui_st_other, stable_game_credits, __PREFIX___main ; __PREFIX__:")
    )

    "config\gameplay\game_tasks.xml" = @(
        # task fragment without a root element (like vanilla tasks_*.xml)
        ,@("#include `"gameplay\game_tasks_by_vendor.xml`"",
           "#include `"gameplay\game_tasks_by_vendor.xml`"`n#include `"gameplay\__PREFIX___tasks.xml`" <!-- __PREFIX__: -->")
    )

    "scripts\_g.script" = @(
        # log() is a no-op in the retail build, so printf only did string.format - which raises on a
        # missing argument deep inside vanilla code. Make it a real no-op.
        ,@("function printf(fmt,...)`n	log(string.format(fmt,...))`nend",
           "function printf(fmt,...) -- __PREFIX__: no-op (log() does nothing in the retail build)`nend")
    )

    "scripts\bind_stalker.script" = @(
        # actor binder hooks -> __PREFIX___main.script (see stalker-soc-lua)
        ,@("	death_manager.init_drop_settings()`n`n	return true",
           "	death_manager.init_drop_settings()`n`n	__PREFIX___main.on_actor_spawn(self) -- __PREFIX__:`n	return true")
        ,@("function actor_binder:update(delta)`n	object_binder.update(self, delta)",
           "function actor_binder:update(delta)`n	__PREFIX___main.on_actor_update(self, delta) -- __PREFIX__:`n	object_binder.update(self, delta)")
        ,@("function actor_binder:on_item_take (obj)`n    level_tasks.proceed(self.object)",
           "function actor_binder:on_item_take (obj)`n    level_tasks.proceed(self.object)`n    __PREFIX___main.on_item_take(obj) -- __PREFIX__:")
        ,@("function actor_binder:on_item_drop (obj)`n    level_tasks.proceed(self.object)",
           "function actor_binder:on_item_drop (obj)`n    level_tasks.proceed(self.object)`n    __PREFIX___main.on_item_drop(obj) -- __PREFIX__:")
        ,@("function actor_binder:take_item_from_box(box, item)`n	local story_id = box:story_id()",
           "function actor_binder:take_item_from_box(box, item)`n	__PREFIX___main.on_take_from_box(box, item) -- __PREFIX__:`n	local story_id = box:story_id()")
        # optional: no vanilla intro dream video on a new game
        # ,@("			_G.g_start_avi = true",
        #    "			-- _G.g_start_avi = true -- __PREFIX__: no vanilla start dream")
    )

    # optional: a custom logic scheme (xr_logic) registered next to vanilla ones
    # "scripts\modules.script" = @(
    #     ,@("load_scheme(`"xr_kamp`",        `"kamp`",        stype_stalker)",
    #        "load_scheme(`"xr_kamp`",        `"kamp`",        stype_stalker)`nload_scheme(`"__PREFIX___move`", `"__PREFIX___move`", stype_stalker) -- __PREFIX__:")
    # )

    # optional: drop the vanilla "kill Strelok" storyline task given at game start
    # "config\gameplay\info_portions.xml" = @(
    #     ,@("  <info_portion id=`"storyline_actor_start`">`n    <task>storyline_eliminate_gunslinger</task>",
    #        "  <info_portion id=`"storyline_actor_start`"> <!-- __PREFIX__: no vanilla task -->")
    # )
}

# Vanilla folders copied unchanged into the mod: destination (under gamedata) -> source (under unpacked)
$Copies = [ordered]@{
}
