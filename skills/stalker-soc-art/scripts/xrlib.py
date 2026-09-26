"""Shared helpers for SoC art scripts (live in <root>\\src\\art\\). Run scripts with:
    blender -b --factory-startup -P <script.py> -- <args>
(factory-startup keeps the user's scene prefs out; we re-enable the add-on here.)
"""
import os
import sys

import addon_utils
import bpy

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UNPACKED = os.path.join(ROOT, "unpacked")
MOD = os.path.join(ROOT, "game", "gamedata")


def setup():
    """Enable blender-xray and point it at the vanilla gamedata for textures/meshes."""
    addon_utils.enable("io_scene_xray", default_set=True, persistent=True)
    prefs = bpy.context.preferences.addons["io_scene_xray"].preferences
    prefs.gamedata_folder = UNPACKED + "\\"
    prefs.textures_folder = os.path.join(UNPACKED, "textures") + "\\"
    prefs.meshes_folder = os.path.join(UNPACKED, "meshes") + "\\"
    return prefs


_ready = False


def reset_scene():
    """Empty scene. The first call loads factory settings; later calls clear data by hand, because a
    second read_factory_settings in one session breaks the blender-xray add-on."""
    global _ready
    if not _ready:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        setup()
        _ready = True
        return
    for coll in (bpy.data.objects, bpy.data.meshes, bpy.data.armatures, bpy.data.materials,
                 bpy.data.images, bpy.data.actions, bpy.data.cameras, bpy.data.lights, bpy.data.worlds):
        for block in list(coll):
            coll.remove(block)


def script_args():
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def import_ogf(path):
    before = set(bpy.data.objects)
    bpy.ops.xray_import.ogf(directory=os.path.dirname(path) + "\\",
                            files=[{"name": os.path.basename(path)}], import_motions=False)
    return [o for o in bpy.data.objects if o not in before]


def root_of(objs):
    """The armature (skinned) or top-level object that export should be run on."""
    for o in objs:
        if o.type == "ARMATURE":
            return o
    return next(o for o in objs if o.parent is None)


def export_ogf(obj, out_path):
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    res = bpy.ops.xray_export.ogf_file(filepath=out_path, fmt_version="soc",
                                       texture_name_from_image_path=True, export_motions=False,
                                       check_existing=False)
    if res != {"FINISHED"}:
        raise RuntimeError("OGF export failed: %s" % res)
    return out_path
