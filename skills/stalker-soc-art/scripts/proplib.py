"""Builds static props as single-bone skeletal OGFs, the way vanilla physics props are made
(e.g. physics\\box\\box_wood_01: bone "link", box collision shape, spawned as a physic_object with
fixed_bones = link so it never moves).

Conventions copied from box_wood_01 (see inspect_ogf.py):
  bone.xray.shape.type '1' = box; box_trn is in X-Ray space (Y up); box_hsz half sizes;
  mass.center is in Blender space; root object flags_simple 'pd'.
"""
import os

import bmesh
import bpy

import xrlib

# default output folder under gamedata\meshes\ - set it to your prefix, e.g. "mymod\\props".
# Own textures must be named <folder>\<folder>_<name> (see texlib.ps1) or the OGF gets a bare texture name.
PROP_DIR = "mod\\props"


def material(name, texture, twosided=False, eshader="models\\model"):
    """Material whose image path makes the exporter write the texture name (e.g. wood\\wood_plank6).
    `texture` is a gamedata texture name; it's looked up in the mod first, then in unpacked."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    path = None
    for base in (os.path.join(xrlib.MOD, "textures"), os.path.join(xrlib.UNPACKED, "textures")):
        for ext in (".dds", ".png", ".tga"):
            p = os.path.join(base, texture + ext)
            if os.path.exists(p):
                path = p
                break
        if path:
            break
    if path is None:
        raise FileNotFoundError("texture not found: " + texture)
    tex.image = bpy.data.images.load(path, check_existing=True)
    bsdf = nt.nodes.get("Principled BSDF")
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    mat.xray.eshader = eshader
    mat.xray.cshader = "default"
    mat.xray.gamemtl = "default_object"
    mat.xray.flags_twosided = twosided
    return mat


def finish_prop(mesh_obj, name, mass=50.0, gamemtl="objects\\large_furniture", out_rel=None, shape=None):
    """Rig `mesh_obj` to a single bone 'link' with a box collision shape fitted to its bounds and
    export it to game\\gamedata\\meshes\\<out_rel>.ogf. Returns the output path.
    `gamemtl` MUST exist in gamemtl.xr (objects\\small_box, large_furniture, metal_box, barrel, glass...)
    or the game crashes when the prop spawns.
    shape = ((cx, cy, cz), (hx, hy, hz)) in Blender space overrides the collision box (decorations that
    must not block walking get a small box at their base)."""
    bpy.context.view_layer.update()
    xs = [(mesh_obj.matrix_world @ v.co) for v in mesh_obj.data.vertices]
    lo = [min(v[i] for v in xs) for i in range(3)]
    hi = [max(v[i] for v in xs) for i in range(3)]
    ctr = [(lo[i] + hi[i]) / 2 for i in range(3)]
    half = [max((hi[i] - lo[i]) / 2, 0.01) for i in range(3)]
    if shape:
        ctr, half = list(shape[0]), list(shape[1])

    arm_data = bpy.data.armatures.new(name)
    arm = bpy.data.objects.new(name, arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones.new("link")
    eb.head = (0, 0, 0)
    eb.tail = (0, 0, 0.02)
    bpy.ops.object.mode_set(mode="OBJECT")

    b = arm_data.bones["link"]
    b.xray.gamemtl = gamemtl
    b.xray.ikjoint.type = "0"                      # rigid, as in vanilla box_wood_01
    b.xray.mass.value = mass
    b.xray.mass.center = ctr
    s = b.xray.shape
    s.type = "1"
    s.box_hsz = (half[0], half[1], half[2])
    s.box_trn = (ctr[0], ctr[2], ctr[1])           # Blender (x, y, z) -> X-Ray (x, z, y)
    s.box_rot = (1, 0, 0, 0, 1, 0, 0, 0, 1)
    arm.xray.flags_simple = "pd"
    arm.xray.isroot = True

    mesh_obj.parent = arm
    mod = mesh_obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    vg = mesh_obj.vertex_groups.new(name="link")
    vg.add([v.index for v in mesh_obj.data.vertices], 1.0, "REPLACE")

    out = os.path.join(xrlib.MOD, "meshes", (out_rel or (PROP_DIR + "\\" + name)) + ".ogf")
    return xrlib.export_ogf(arm, out)


def new_mesh_obj(name):
    me = bpy.data.meshes.new(name)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def box(name, size=(1, 1, 1), mat=None):
    """Axis-aligned box standing on z=0, with per-face UVs."""
    ob = new_mesh_obj(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z = (v.co.z + 0.5) * size[2]
    uv = bm.loops.layers.uv.new("Texture")
    for f in bm.faces:
        for loop, (u, w) in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
            loop[uv].uv = (u, w)
    bm.to_mesh(ob.data)
    bm.free()
    if mat:
        ob.data.materials.append(mat)
    return ob
