"""Prop kit: build static props from boxes/cylinders/quads with per-face materials, export them as
single-bone OGFs (proplib.finish_prop) into gamedata\meshes\<proplib.PROP_DIR>\.
Usage: blender -b --factory-startup -P propkit.py -- [name ...] [--preview]   (no names = all)
Add props as functions returning (object, collision_shape_or_None) and list them in PROPS.
Materials take gamedata texture names (vanilla, e.g. wood\\wood_plank6, or your own from texlib.ps1).
Spawn in game: a section inheriting <p>_prop_base (physic_object + props binder) with
visual = <PROP_DIR>\<name>.ogf, or an all.spawn prop() entry (stalker-soc-spawn).
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
import xrlib  # noqa: E402
import proplib  # noqa: E402
PREVIEWS = os.path.join(xrlib.ROOT, "src", "art", "previews")
_mats = {}


def mat(texture, twosided=False):
    key = (texture, twosided)
    if key not in _mats:
        _mats[key] = proplib.material(texture.replace("\\", "_"), texture, twosided=twosided)
    return _mats[key]


class Builder:
    """Accumulates geometry with per-face materials into one bmesh."""

    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("Texture")
        self.mats = []
        self.fixed = set()   # faces whose winding is deliberate (skip normal recalculation)

    def mi(self, material):
        if material not in self.mats:
            self.mats.append(material)
        return self.mats.index(material)

    def quad(self, pts, material, uvs=((0, 0), (1, 0), (1, 1), (0, 1)), fixed=False):
        vs = [self.bm.verts.new(p) for p in pts]
        f = self.bm.faces.new(vs)
        f.material_index = self.mi(material)
        for loop, uv in zip(f.loops, uvs):
            loop[self.uv].uv = uv
        if fixed:
            self.fixed.add(f)
        return f

    def tri(self, pts, material, uvs):
        vs = [self.bm.verts.new(p) for p in pts]
        f = self.bm.faces.new(vs)
        f.material_index = self.mi(material)
        for loop, uv in zip(f.loops, uvs):
            loop[self.uv].uv = uv

    def box(self, center, size, material, rot=None, uv_scale=1.0):
        cx, cy, cz = center
        sx, sy, sz = (s / 2 for s in size)
        corners = [Vector((x, y, z)) for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)]
        m = rot or Matrix.Identity(3)
        c = [m @ v + Vector(center) for v in corners]
        # faces: (-x, +x, -y, +y, -z, +z) with corner indices x*4 + y*2 + z
        faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        for fi in faces:
            u = uv_scale
            self.quad([c[i] for i in fi], material, ((0, 0), (u, 0), (u, u), (0, u)))

    def cylinder(self, base, top, r, material, segs=12, cap=True):
        base, top = Vector(base), Vector(top)
        axis = (top - base).normalized()
        a = axis.orthogonal().normalized()
        b = axis.cross(a)
        rb, rt = [], []
        for s in range(segs):
            ang = 2 * math.pi * s / segs
            off = (a * math.cos(ang) + b * math.sin(ang)) * r
            rb.append(base + off)
            rt.append(top + off)
        for s in range(segs):
            n = (s + 1) % segs
            self.quad([rb[s], rb[n], rt[n], rt[s]], material,
                      ((s / segs, 0), ((s + 1) / segs, 0), ((s + 1) / segs, 1), (s / segs, 1)))
        if cap:
            vs = [self.bm.verts.new(p) for p in rt]
            f = self.bm.faces.new(vs)
            f.material_index = self.mi(material)
            for loop in f.loops:
                loop[self.uv].uv = (0.5, 0.5)

    def object(self, name):
        me = bpy.data.meshes.new(name)
        bmesh.ops.recalc_face_normals(self.bm, faces=[f for f in self.bm.faces if f not in self.fixed])
        self.bm.to_mesh(me)
        self.bm.free()
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        for m in self.mats:
            ob.data.materials.append(m)
        return ob


WOOD = "wood\\wood_plank6"


def rot_z(a):
    return Matrix.Rotation(a, 3, "Z")


# ---------------------------------------------------------------------------------------------
# props (examples)
# ---------------------------------------------------------------------------------------------

def table():
    """2 x 0.9 m trestle table (furniture: collision box fitted to the whole mesh)."""
    b = Builder()
    wood = mat(WOOD)
    b.box((0, 0, 0.78), (2.0, 0.9, 0.05), wood)
    for x in (-0.85, 0.85):
        for y in (-0.35, 0.35):
            b.box((x, y, 0.38), (0.07, 0.07, 0.76), wood)
    return b.object("prop_table"), None


def signpost(texture="wood\\wood_plank6"):
    """Post with a board; the painted face is a separate one-sided quad (front = -Y). Decorations get a
    small collision box at the base so they don't block walking."""
    b = Builder()
    wood = mat(WOOD)
    b.box((0, 0, 0.7), (0.08, 0.08, 1.4), wood)
    b.box((0, -0.05, 1.25), (0.72, 0.03, 0.38), wood)
    face = mat(texture)
    b.quad([(-0.35, -0.071, 1.075), (0.35, -0.071, 1.075), (0.35, -0.071, 1.425), (-0.35, -0.071, 1.425)], face, fixed=True)
    return b.object("prop_signpost"), ((0, 0, 0.5), (0.06, 0.06, 0.5))


PROPS = {
    "prop_table": table,
    "prop_signpost": signpost,
}

def preview(name):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 16
    sc.render.resolution_x, sc.render.resolution_y = 400, 300
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.6, 0.62, 0.66, 1)
    sc.world = world
    L = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    L.data.energy = 3.0
    L.rotation_euler = (math.radians(50), 0, math.radians(30))
    sc.collection.objects.link(L)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    obs = [o for o in sc.objects if o.type == "MESH"]
    lo = Vector([min(v[i] for o in obs for v in o.bound_box) for i in range(3)])
    hi = Vector([max(v[i] for o in obs for v in o.bound_box) for i in range(3)])
    c = (lo + hi) / 2
    size = max((hi - lo).length, 0.5)
    cam.location = c + Vector((0.6, -1.0, 0.5)).normalized() * size * 1.3
    d = c - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    os.makedirs(PREVIEWS, exist_ok=True)
    sc.render.filepath = os.path.join(PREVIEWS, name + ".png")
    bpy.ops.render.render(write_still=True)


def main():
    args = xrlib.script_args()
    names = [a for a in args if not a.startswith("--")] or list(PROPS)
    for name in names:
        xrlib.reset_scene()
        _mats.clear()
        ob, shape = PROPS[name]()
        if "--preview" in args:
            preview(name)
        out = proplib.finish_prop(ob, name, mass=40, shape=shape)
        print("EXPORTED", out, os.path.getsize(out))


if __name__ == "__main__":
    main()