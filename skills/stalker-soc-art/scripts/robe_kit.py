"""Robe kit: dresses a vanilla stalker OGF in procedural cloth (robe, skirt, sleeves, hood) on the
stock skeleton, so vanilla animations and AI keep working. No faces, no skeleton changes.

Usage: blender -b --factory-startup -P robe_kit.py -- <preset> [--preview]
Presets are in PRESETS below; each writes meshes\\<OUT_DIR>\\<preset>.ogf (+ a preview PNG in
src\\art\\previews with --preview).

Geometry is built in the bind pose (T-pose, Z up, facing -Y). Weights are computed per part from
bone segments (max 2 bones per vertex: the SoC OGF limit):
  torso  -> spine chain by height        skirt  -> pelvis blending into the thighs/calves by side
  sleeve -> clavicle/upperarm/forearm    hood   -> head (neck at the rim)
Body vertices hidden under the cloth are deleted so they can't poke through.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
import xrlib  # noqa: E402

PREVIEWS = os.path.join(xrlib.ROOT, "src", "art", "previews")

# ---------------------------------------------------------------------------------------------
# presets
# ---------------------------------------------------------------------------------------------
# Set PREFIX to your mod prefix. Models go to gamedata\meshes\<PREFIX>\npc\; cloth textures are
# textures\<PREFIX>\<PREFIX>_cloth_<colour>.dds (texlib.ps1 Cloth names them so; the <PREFIX>_ file
# prefix is required for blender-xray to write the folder into the OGF texture name).
PREFIX = "mod"
OUT_DIR = PREFIX + "\\npc"
TEX = PREFIX + "\\" + PREFIX + "_"

PRESETS = {
    # hooded black robe with an empty face (a wraith): tattered hem, deep hood, face replaced by a void
    "npc_wraith": dict(
        base=r"actors\monolit\stalker_mo_hood_9",
        robe_texture=TEX + "cloth_black", hood_texture=TEX + "cloth_black",
        robe_length=0.02, flare=0.34, sleeve_flare=0.13, hood="deep", face="void",
        tatters=True, head_scale=1.0,
    ),
    # wizard: long grey robe and a pointed hat over the trader model (face kept)
    "npc_wizard": dict(
        base=r"actors\trader\trader",
        robe_texture=TEX + "cloth_grey", hood_texture=None, hat_texture=TEX + "cloth_grey",
        robe_length=0.05, flare=0.30, sleeve_flare=0.12, hood=None, hat=True, face="keep",
        tatters=False, head_scale=1.0,
    ),
    # ranger: a cloak only (no sleeves), deep hood, over a stalker suit
    "npc_ranger": dict(
        base=r"actors\neytral\stalker_neytral_balon_1",
        robe_texture=TEX + "cloth_ranger", hood_texture=TEX + "cloth_ranger",
        robe_length=0.35, flare=0.26, sleeve_flare=0.0, hood="deep", face="keep",
        tatters=True, head_scale=1.0, cloak_only=True,
    ),
    # villager: knee-length tunic with a soft hood over a rookie (faces visible), bigger head, hunched
    "npc_villager": dict(
        base=r"actors\novice\green_stalker_1",
        robe_texture=TEX + "cloth_brown", hood_texture=TEX + "cloth_brown",
        robe_length=0.45, flare=0.22, sleeve_flare=0.03, hood="soft", face="keep",
        tatters=False, head_scale=1.25, hunch=0.06,
    ),
    # pale full-length robe (elves, priests)
    "npc_robed": dict(
        base=r"actors\novice\green_stalker_2",
        robe_texture=TEX + "cloth_pale", hood_texture=TEX + "cloth_pale",
        robe_length=0.08, flare=0.28, sleeve_flare=0.08, hood="soft", face="keep",
        tatters=False, head_scale=1.0,
    ),
}
# ---------------------------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------------------------

def bone_heads(arm):
    H = {b.name: b.head_local.copy() for b in arm.data.bones}
    # some skeletons (trader) have no spine2: use a point between spine1 and the neck
    if "bip01_spine2" not in H:
        H["bip01_spine2"] = H["bip01_spine1"].lerp(H["bip01_neck"], 0.85)
        H["_no_spine2"] = Vector((0, 0, 0))
    # which world side is the character's left (the trader skeleton is mirrored)
    H["_lsign"] = Vector((1 if H["bip01_l_upperarm"].x > 0 else -1, 0, 0))
    return H


def side_of(H, x):
    return "l" if x * H["_lsign"].x > 0 else "r"


def spine2(H):
    return "bip01_spine1" if "_no_spine2" in H else "bip01_spine2"


def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def top2(weights):
    """Keep the two strongest influences and normalise (SoC OGF: max 2 bones per vertex)."""
    items = sorted(((w, b) for b, w in weights.items() if w > 1e-4), reverse=True)[:2]
    s = sum(w for w, _ in items) or 1.0
    return {b: w / s for w, b in items}


def lathe(bm, rings, segments, uv_layer, open_front=None, v_scale=1.0):
    """Build a tube from rings [(z, cx, cy, rx, ry)] top to bottom. open_front=(start_angle, end)
    leaves a gap (radians, 0 = -Y front). Returns list of rows of BMVerts."""
    rows = []
    for (z, cx, cy, rx, ry) in rings:
        row = []
        for s in range(segments + 1):
            a = 2 * math.pi * s / segments
            # angle 0 at the front (-Y), growing to the character's left (+X)
            x = cx + math.sin(a) * rx
            y = cy - math.cos(a) * ry
            row.append(bm.verts.new((x, y, z)))
        rows.append(row)
    for r in range(len(rows) - 1):
        for s in range(segments):
            a = 2 * math.pi * (s + 0.5) / segments
            if open_front and (a < open_front[0] or a > 2 * math.pi - open_front[0]):
                continue
            f = bm.faces.new((rows[r][s], rows[r][s + 1], rows[r + 1][s + 1], rows[r + 1][s]))
            for loop, (u, v) in zip(f.loops, ((s, r), (s + 1, r), (s + 1, r + 1), (s, r + 1))):
                loop[uv_layer].uv = (u / segments * 2.0, v / max(1, len(rows) - 1) * v_scale)
    return rows


def new_object(name, bm, material):
    me = bpy.data.meshes.new(name)
    # merge the duplicated seam vertices of lathed rings (smooth shading across the seam)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(material)
    for p in me.polygons:
        p.use_smooth = True
    return ob


def assign_weights(ob, arm, weight_fn):
    groups = {}
    for v in ob.data.vertices:
        for bone, w in top2(weight_fn(v.co)).items():
            if bone not in groups:
                groups[bone] = ob.vertex_groups.new(name=bone)
            groups[bone].add([v.index], w, "REPLACE")
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    ob.parent = arm


def cloth_material(name, texture, twosided=True):
    import proplib
    return proplib.material(name, texture, twosided=twosided)


# ---------------------------------------------------------------------------------------------
# parts
# ---------------------------------------------------------------------------------------------

def build_torso_skirt(H, p, mat):
    """One mesh: torso tube (shoulders to hips) + skirt (hips to robe_length)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("Texture")
    sh = H["bip01_spine2"].z + 0.02         # shoulder line
    hip = H["bip01_pelvis"].z
    ankle = p["robe_length"]
    hunch = p.get("hunch", 0.0)
    cy0 = H["bip01_pelvis"].y + 0.02
    neck = H["bip01_neck"].z
    # collar and sloping shoulders close the top of the tube around the neck
    arm_z = H["bip01_l_upperarm"].z
    rings = [(neck + 0.04, 0.0, cy0 + hunch, 0.08, 0.08),
             (neck - 0.01, 0.0, cy0 + hunch, 0.13, 0.12),
             (arm_z + 0.03, 0.0, cy0 + hunch, 0.20, 0.155)]
    chest = arm_z - 0.03
    # torso: chest wide and deep enough to cover clavicles and a vest
    for i, t in enumerate((0.0, 0.25, 0.5, 0.75, 1.0)):
        z = chest + (hip - chest) * t
        rx = 0.20 + 0.05 * math.sin(t * math.pi) + (0.02 if t < 0.1 else 0)
        ry = 0.17 + 0.02 * math.sin(t * math.pi)
        rings.append((z, 0.0, cy0 + hunch * (1 - t), rx, ry))
    # skirt: flares out towards the hem
    n = 7
    for i in range(1, n + 1):
        t = i / n
        z = hip + (ankle - hip) * t
        r = 0.23 + (p["flare"] - 0.23) * t ** 1.3
        rings.append((z, 0.0, cy0, r, r * 0.85))
    rows = lathe(bm, rings, 24, uv, open_front=None, v_scale=3.0)
    if p.get("tatters"):
        # ragged hem: jitter the last ring downwards
        import random
        rnd = random.Random(7)
        for v in rows[-1]:
            v.co.z -= rnd.random() * 0.07
    obj = new_object("robe", bm, mat)
    return obj, rows


def torso_weights(H):
    sp, sp1, sp2, pel = (H["bip01_spine"].z, H["bip01_spine1"].z, H["bip01_spine2"].z, H["bip01_pelvis"].z)

    def fn(co):
        z, x = co.z, co.x
        if z >= pel:
            # spine chain by height (+ clavicles near the shoulder line, to the side)
            if z > sp2 + 0.04:
                return {"bip01_neck": 0.6, spine2(H): 0.4}
            if z > sp2 - 0.05:
                side = side_of(H, x)
                w = smoothstep(0.08, 0.2, abs(x))
                return {spine2(H): 1 - w, "bip01_%s_clavicle" % side: w}
            if z > sp1:
                t = (z - sp1) / (sp2 - sp1)
                return {spine2(H): t, "bip01_spine1": 1 - t} if spine2(H) != "bip01_spine1" else {"bip01_spine1": 1.0}
            t = (z - pel) / (sp1 - pel)
            return {"bip01_spine1": t, "bip01_spine": 1 - t}
        # skirt: pelvis at the top, blending into the legs by side and depth
        depth = (pel - z) / max(0.01, pel - 0.1)
        side = side_of(H, x)
        leg = smoothstep(0.02, 0.14, abs(x)) * smoothstep(0.0, 0.5, depth)
        knee = H["bip01_l_calf"].z
        legbone = "bip01_%s_thigh" % side if z > knee else "bip01_%s_calf" % side
        return {"bip01_pelvis": 1 - leg * 0.85, legbone: leg * 0.85}
    return fn


def build_sleeves(H, p, mat):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("Texture")
    for side, sgn in (("l", 1), ("r", -1)):
        a = H["bip01_%s_upperarm" % side]
        f = H["bip01_%s_forearm" % side]
        h = H["bip01_%s_hand" % side]
        # tube along +X (T-pose): cross-section in YZ
        pts = [(a, 0.085), ((a + f) / 2, 0.075), (f, 0.07), ((f + h) / 2, 0.075 + p["sleeve_flare"] * 0.5),
               (h + (h - f).normalized() * 0.02, 0.08 + p["sleeve_flare"])]
        segs = 14
        rows = []
        for c, r in pts:
            row = []
            for s in range(segs + 1):
                ang = 2 * math.pi * s / segs
                row.append(bm.verts.new((c.x, c.y + math.cos(ang) * r, c.z + math.sin(ang) * r * 0.95)))
            rows.append(row)
        for i in range(len(rows) - 1):
            for s in range(segs):
                fc = bm.faces.new((rows[i][s], rows[i][s + 1], rows[i + 1][s + 1], rows[i + 1][s]))
                for loop, (u, v) in zip(fc.loops, ((s, i), (s + 1, i), (s + 1, i + 1), (s, i + 1))):
                    loop[uv].uv = (u / segs, v / (len(rows) - 1))
    return new_object("sleeves", bm, mat)


def sleeve_weights(H):
    def fn(co):
        side = side_of(H, co.x)
        a = H["bip01_%s_upperarm" % side].x
        f = H["bip01_%s_forearm" % side].x
        x = abs(co.x)
        a, f = abs(a), abs(f)
        if x < a + 0.03:
            return {"bip01_%s_clavicle" % side: 0.4, "bip01_%s_upperarm" % side: 0.6}
        if x < f:
            t = smoothstep(f - 0.06, f + 0.02, x)
            return {"bip01_%s_upperarm" % side: 1 - t, "bip01_%s_forearm" % side: t}
        t = smoothstep(f + 0.15, f + 0.24, x)
        return {"bip01_%s_forearm" % side: 1 - t * 0.5, "bip01_%s_hand" % side: t * 0.5}
    return fn


def build_hood(H, p, mat):
    """Hood: a shell around the head, open at the face, with a point at the back."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("Texture")
    c = H["bip01_head"] + Vector((0, 0.01, 0.09)) * p.get("head_scale", 1.0)
    r = 0.155 * p.get("head_scale", 1.0)
    style = p["hood"]
    deep = style in ("deep", "soft")
    point = 0.07 if style == "deep" else 0.0
    pull = 0.06 if style == "deep" else 0.035
    segs_u, segs_v = 20, 12
    grid = []
    for j in range(segs_v + 1):
        v = j / segs_v                          # 0 = top, 1 = bottom rim
        el = math.pi * (0.5 - v * (0.72 if deep else 0.62))   # elevation
        row = []
        for i in range(segs_u + 1):
            az = 2 * math.pi * i / segs_u       # 0 = front (-Y)
            x = math.cos(el) * math.sin(az) * r
            y = -math.cos(el) * math.cos(az) * r * 1.1
            z = math.sin(el) * r
            back = max(0.0, -math.cos(az))      # 1 at the back
            y += back * pull * (1 - v)                               # pull the back out
            z += back * point * max(0.0, 1 - v * 2)                  # point on top/back
            row.append(bm.verts.new((c.x + x, c.y + y, c.z + z)))
        grid.append(row)
    face_open = {"deep": 0.62, "soft": 0.9}.get(style, 0.75)  # half-width of the face opening (radians)
    for j in range(segs_v):
        for i in range(segs_u):
            az = 2 * math.pi * (i + 0.5) / segs_u
            v = (j + 0.5) / segs_v
            if (az < face_open or az > 2 * math.pi - face_open) and v > 0.25:
                continue                          # face opening
            f = bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
            for loop, (uu, vv) in zip(f.loops, ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))):
                loop[uv].uv = (uu / segs_u * 2, vv / segs_v)
    return new_object("hood", bm, mat), c, r


def hood_weights(H):
    neck = H["bip01_neck"].z

    def fn(co):
        t = smoothstep(neck + 0.01, neck + 0.08, co.z)
        return {"bip01_head": t, "bip01_neck": 1 - t}
    return fn


def build_face_void(center, r, mat):
    """Black disc filling the hood opening, a little inside the rim (no face)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("Texture")
    ring = []
    for i in range(16):
        a = 2 * math.pi * i / 16
        ring.append(bm.verts.new((center.x + math.cos(a) * r * 0.75, center.y - r * 0.55,
                                  center.z - 0.03 + math.sin(a) * r * 0.9)))
    f = bm.faces.new(ring)
    for loop in f.loops:
        loop[uv].uv = (0.5, 0.5)
    return new_object("face_void", bm, mat)


def build_hat(H, mat):
    """Gandalf's tall pointed hat with a wide brim."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("Texture")
    c = H["bip01_head"] + Vector((0, 0.005, 0.13))
    rings = [(c.z + 0.001, 0, 0, 0.26, 0.26), (c.z, 0, 0, 0.11, 0.11), (c.z + 0.12, 0, 0.01, 0.085, 0.085),
             (c.z + 0.26, 0, 0.04, 0.05, 0.05), (c.z + 0.40, 0, 0.09, 0.012, 0.012)]
    rings = [(z, c.x + cx, c.y + cy, rx, ry) for (z, cx, cy, rx, ry) in rings]
    lathe(bm, rings, 20, uv)
    return new_object("hat", bm, mat)


# ---------------------------------------------------------------------------------------------
# body trimming and head scale
# ---------------------------------------------------------------------------------------------

HIDDEN_UNDER_ROBE = {"bip01_spine", "bip01_spine1", "bip01_spine2", "bip01_pelvis",
                     "bip01_l_thigh", "bip01_r_thigh", "bip01_l_clavicle", "bip01_r_clavicle",
                     "bip01_l_upperarm", "bip01_r_upperarm", "bip01_l_forearm", "bip01_r_forearm",
                     "bip01_tail"}   # tail = belt pouches


def trim_body(body, p):
    hidden = set(HIDDEN_UNDER_ROBE)
    if p["robe_length"] < 0.2:
        hidden |= {"bip01_l_calf", "bip01_r_calf"}
    if p.get("cloak_only"):
        hidden = {"bip01_spine1", "bip01_spine2"}   # a cloak over normal clothes
    if p.get("face") == "void":
        # some bodies (Monolith, masks) carry the head in the body mesh
        hidden |= {"bip01_head", "bip01_neck", "jaw_1", "eye_left", "eye_right", "eyelid_1"}
    idx = {g.index: g.name for g in body.vertex_groups}
    bm = bmesh.new()
    bm.from_mesh(body.data)
    deform = bm.verts.layers.deform.active
    kill = []
    for v in bm.verts:
        best, bw = None, 0
        for gi, w in v[deform].items():
            if w > bw:
                best, bw = idx.get(gi), w
        if best in hidden:
            kill.append(v)
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bm.to_mesh(body.data)
    bm.free()


def scale_head(head_obj, H, s):
    if abs(s - 1.0) < 1e-3:
        return
    c = H["bip01_neck"]
    for v in head_obj.data.vertices:
        v.co = c + (v.co - c) * s


# ---------------------------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------------------------

def build(preset_name, preview=False):
    p = PRESETS[preset_name]
    xrlib.reset_scene()
    objs = xrlib.import_ogf(os.path.join(xrlib.UNPACKED, "meshes", p["base"] + ".ogf"))
    arm = xrlib.root_of(objs)
    H = bone_heads(arm)
    meshes = [o for o in objs if o.type == "MESH"]
    # the head mesh is the one dominated by bip01_head; the body is the largest
    body = max(meshes, key=lambda o: len(o.data.vertices))
    heads = [o for o in meshes if o is not body]

    robe_mat = cloth_material("robe", p["robe_texture"])
    parts = []
    if not p.get("cloak_only"):
        robe, _ = build_torso_skirt(H, p, robe_mat)
        assign_weights(robe, arm, torso_weights(H))
        parts.append(robe)
        sleeves = build_sleeves(H, p, robe_mat)
        assign_weights(sleeves, arm, sleeve_weights(H))
        parts.append(sleeves)
    else:
        # ranger cloak: open at the front, from the shoulders down
        robe, _ = build_torso_skirt(H, dict(p, flare=p["flare"]), robe_mat)
        bm = bmesh.new()
        bm.from_mesh(robe.data)
        # open only in a strip at the front, below the chest: the mantle covers the shoulders
        cy = H["bip01_pelvis"].y
        chest_z = H["bip01_spine1"].z + 0.1
        front = [f for f in bm.faces if f.calc_center_median().y < cy - 0.05
                 and f.calc_center_median().z < chest_z and abs(f.calc_center_median().x) < 0.15]
        bmesh.ops.delete(bm, geom=front, context="FACES")
        bm.to_mesh(robe.data)
        bm.free()
        assign_weights(robe, arm, torso_weights(H))
        parts.append(robe)

    if p.get("hood"):
        hood, hc, hr = build_hood(H, p, cloth_material("hood", p["hood_texture"]))
        assign_weights(hood, arm, hood_weights(H))
        parts.append(hood)
        if p.get("face") == "void":
            void = build_face_void(hc, hr, cloth_material("void", TEX + "void", twosided=True))
            assign_weights(void, arm, lambda co: {"bip01_head": 1.0})
            parts.append(void)
    if p.get("hat"):
        hat = build_hat(H, cloth_material("hat", p["hat_texture"]))
        assign_weights(hat, arm, lambda co: {"bip01_head": 1.0})
        parts.append(hat)

    trim_body(body, p)
    for h in heads:
        if p.get("face") == "void":
            bpy.data.objects.remove(h, do_unlink=True)
        else:
            scale_head(h, H, p.get("head_scale", 1.0))

    out = os.path.join(xrlib.MOD, "meshes", OUT_DIR, preset_name + ".ogf")
    xrlib.export_ogf(arm, out)
    print("EXPORTED", out, os.path.getsize(out))
    if preview:
        render_preview(preset_name)
    return out


def render_preview(name):
    """Front and 3/4 views of the bind pose (to check the cloth before going in game)."""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 24
    sc.render.resolution_x, sc.render.resolution_y = 480, 640
    sc.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.58, 0.62, 1)
    sc.world = world
    L = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    L.data.energy = 3.5
    L.rotation_euler = (math.radians(50), 0, math.radians(30))
    sc.collection.objects.link(L)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2.2
    sc.camera = cam
    os.makedirs(PREVIEWS, exist_ok=True)
    for tag, ang in (("front", 0), ("side", 60), ("back", 180)):
        a = math.radians(ang)
        cam.location = (math.sin(a) * 5, -math.cos(a) * 5, 1.0)
        cam.rotation_euler = (math.radians(90), 0, a)
        sc.render.filepath = os.path.join(PREVIEWS, "%s_%s.png" % (name, tag))
        bpy.ops.render.render(write_still=True)
    print("PREVIEW", os.path.join(PREVIEWS, name + "_*.png"))


if __name__ == "__main__":
    args = xrlib.script_args()
    build(args[0], preview="--preview" in args)
