"""All changes to all.spawn, applied to the decompiled vanilla spawn by build_spawn.py.
Every removal carries a reason; REMOVED.md (next to this file) is regenerated on each build.
Object names/sections: python list_objects.py <level> [section ...]. Levels: l01_escape, l02_garbage...
"""

# level -> {section_name: reason}: every object of these sections is removed
REMOVE_SECTIONS = {
    # "l01_escape": {
    #     "stalker": "clean slate: the mod repopulates the level",
    #     "helicopter": "vanilla helicopter attack",
    # },
}

# level -> list of (object name, reason)
REMOVE = {
    # "l01_escape": [
    #     ("esc_tutorial_trigger", "vanilla tutorial start"),
    # ],
}

# level -> list of (object name, reason): kept as plain zones/landmarks, vanilla [logic] removed
STRIP_LOGIC = {
    # "l01_escape": [("esc_zombie_ambush", "rebuilt by mod scripts")],
}

# level -> {object name: {key: value}}; key "custom_data" replaces the heredoc (None removes it)
MODIFY = {
    # The actor start: the engine places the actor from its UPDATE packet, not from "position".
    # Set position + upd:position, direction + upd:o_torso (yaw first; sign opposite to
    # set_actor_direction), and both vertex ids (get them in game: moddev.pos()).
    # "l01_escape": {
    #     "level_prefix_actor_0001": {
    #         "position": "-211.4, -23.2, -127.3",
    #         "direction": "0, 0.697, 0",
    #         "upd:position": "-211.4, -23.2, -127.3",
    #         "upd:o_torso": "0.697, 0, 0",
    #         "level_vertex_id": "41969",
    #         "game_vertex_id": "59",
    #         "custom_data": "[dont_spawn_character_supplies]\n\n[spawn]\ndevice_torch\n",
    #     },
    # },
}


# level -> list of objects to add: {"template": <vanilla object name to clone>, "name": ..., key: value}
# Clone something of the same class and override keys (position, visual_name, ...).

def prop(name, visual, x, y, z, yaw=0.0):
    """Static decoration (single-bone OGF from stalker-soc-art): clone of a fixed physic_object."""
    return {"template": "door0001", "name": name, "position": "%g, %g, %g" % (x, y, z),
            "direction": "0, %g, 0" % yaw, "visual_name": visual, "custom_data": None,
            "fixed_bones": "link", "mass": "40"}


def lamp(name, x, y, z, color="0xffffb060", rng="7"):
    """Warm flickering hanging lamp (switch with get_hanging_lamp():turn_on/off from script)."""
    return {"template": "lights_white_glass_0003", "name": name, "position": "%g, %g, %g" % (x, y, z),
            "main_color": color, "main_color_animator": "koster", "main_range": rng,
            "main_brightness": "1.3", "ambient_power": "0.4"}


ADD = {
    # "l01_escape": [
    #     prop("mymod_banner", r"mymod\props\mymod_banner", -214.0, -20.4, -147.7, 0.0),
    #     lamp("mymod_lamp_1", -219.0, -16.6, -144.3),
    # ],
}
