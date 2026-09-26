"""Print the blender-xray properties of an imported OGF: bones, shapes, mass, materials, object flags.
Usage: blender -b --factory-startup -P inspect_ogf.py -- <path.ogf>"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import xrlib  # noqa: E402

path = xrlib.script_args()[0]
xrlib.reset_scene()
objs = xrlib.import_ogf(path)
for o in objs:
    print("OBJ", o.name, o.type, "parent", o.parent.name if o.parent else None,
          "flags_simple", o.xray.flags_simple, "userdata", repr(o.xray.userdata)[:120])
    if o.type == "ARMATURE":
        for b in o.data.bones:
            x = b.xray
            s = x.shape
            print("BONE", b.name, "head", tuple(round(v, 3) for v in b.head_local),
                  "tail", tuple(round(v, 3) for v in b.tail_local), "gamemtl", x.gamemtl,
                  "mass", round(x.mass.value, 3), "center", tuple(round(v, 3) for v in x.mass.center),
                  "shape", s.type, "hsz", tuple(round(v, 3) for v in s.box_hsz),
                  "trn", tuple(round(v, 3) for v in s.box_trn), "rot", tuple(round(v, 3) for v in s.box_rot),
                  "flags", s.flags, "ikjoint", x.ikjoint.type)
    if o.type == "MESH":
        dims = tuple(round(v, 3) for v in o.dimensions)
        print("MESH", o.name, len(o.data.vertices), "dims", dims, "groups", [g.name for g in o.vertex_groups])
        for m in o.data.materials:
            img = None
            if m.use_nodes:
                for n in m.node_tree.nodes:
                    if n.type == "TEX_IMAGE" and n.image:
                        img = n.image.filepath
            print("  MAT", m.name, m.xray.eshader, m.xray.cshader, m.xray.gamemtl, "img", img)
