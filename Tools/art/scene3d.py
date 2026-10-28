"""A room of the game as a lit 3D diorama, in the same matte soft-vinyl world as the characters (ip3d.py, kb/mosto3d.py).

The map is built cell by cell (floor slabs, brick walls, water, lamps, plates, doors, shadows, the exit) and set in a
chapter landscape that runs past the screen edges, seen by the game camera: orthographic, looking down 35°, framed
for a portrait phone. Night light comes only from what is lit in the story: Otto's bulb, the lamps, Mosto's spark,
the moon.

  python3 Tools/art/scene3d.py ROOM_ID OUT.png [--w 603 --h 1311 --samples 48 --chapter 4 --cast pair]
"""
import json, math, os, random, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy
import ip3d as B                      # imported first, so mosto3d shares the same module and materials
sys.path.insert(0, os.path.join(HERE, "kb"))
import mosto3d as MO
from mathutils import Vector

ARGS = sys.argv[1:]
def arg(name, default):
    return type(default)(ARGS[ARGS.index(name) + 1]) if name in ARGS else default

ROOM, OUT = ARGS[0], os.path.abspath(ARGS[1])
BG = "--bg" in ARGS          # background only: everything that moves or changes is left out (the game draws it)
PC = arg("--pc", 90)       # pixels per cell in --bg mode
CW, CH = 15, 24             # --bg canvas in cells (screen units): covers phones and iPads around the room
S = 1.5            # world units per cell; the figures are about one unit wide
TILT = 48
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SPEC = json.load(open(os.path.join(ROOT, "Game", "Resources", "rooms.json")))["rooms"][ROOM]
GRID = SPEC["map"]
H, W = len(GRID), len(GRID[0])
rnd = random.Random(7)

def cell(x, y, z=0.0):
    return Vector(((x - (W - 1) / 2) * S, -(y - (H - 1) / 2) * S, z))

# ---------- materials ----------
def stone(name, base, dark, scale=6.0, rough=0.85, bump=0.25):
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; p = nt.nodes["Principled BSDF"]
    p.inputs["Roughness"].default_value = rough
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    n = nt.nodes.new("ShaderNodeTexNoise"); n.inputs["Scale"].default_value = scale * 0.1; n.inputs["Detail"].default_value = 8
    nt.links.new(geo.outputs["Position"], n.inputs["Vector"])
    r = nt.nodes.new("ShaderNodeValToRGB")
    r.color_ramp.elements[0].color = B.hexcol(dark); r.color_ramp.elements[1].color = B.hexcol(base)
    r.color_ramp.elements[0].position = 0.35; r.color_ramp.elements[1].position = 0.7
    nt.links.new(n.outputs["Fac"], r.inputs["Fac"]); nt.links.new(r.outputs["Color"], p.inputs["Base Color"])
    bm = nt.nodes.new("ShaderNodeBump"); bm.inputs["Strength"].default_value = bump
    n2 = nt.nodes.new("ShaderNodeTexNoise"); n2.inputs["Scale"].default_value = scale * 0.9; n2.inputs["Detail"].default_value = 10
    nt.links.new(geo.outputs["Position"], n2.inputs["Vector"])
    nt.links.new(n2.outputs["Fac"], bm.inputs["Height"]); nt.links.new(bm.outputs["Normal"], p.inputs["Normal"])
    return m

def strata(name, dark, light):
    """Layered rock for the sides of raised blocks: horizontal bands, broken by noise."""
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; p = nt.nodes["Principled BSDF"]
    p.inputs["Roughness"].default_value = 0.92
    tc = nt.nodes.new("ShaderNodeTexCoord")
    wv = nt.nodes.new("ShaderNodeTexWave"); wv.wave_type = "BANDS"; wv.bands_direction = "Z"
    wv.inputs["Scale"].default_value = 3.0; wv.inputs["Distortion"].default_value = 6; wv.inputs["Detail"].default_value = 4
    nt.links.new(tc.outputs["Object"], wv.inputs["Vector"])
    r = nt.nodes.new("ShaderNodeValToRGB"); r.color_ramp.elements[0].color = B.hexcol(dark); r.color_ramp.elements[1].color = B.hexcol(light)
    nt.links.new(wv.outputs["Fac"], r.inputs["Fac"]); nt.links.new(r.outputs["Color"], p.inputs["Base Color"])
    bm = nt.nodes.new("ShaderNodeBump"); bm.inputs["Strength"].default_value = 0.5
    nt.links.new(wv.outputs["Fac"], bm.inputs["Height"]); nt.links.new(bm.outputs["Normal"], p.inputs["Normal"])
    return m

def brick(name, base, mortar):
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; p = nt.nodes["Principled BSDF"]
    p.inputs["Roughness"].default_value = 0.9
    tc = nt.nodes.new("ShaderNodeTexCoord")
    b = nt.nodes.new("ShaderNodeTexBrick"); b.inputs["Scale"].default_value = 2.2; b.inputs["Mortar Size"].default_value = 0.025
    b.inputs["Color1"].default_value = B.hexcol(base); b.inputs["Color2"].default_value = B.hexcol(base)
    b.inputs["Mortar"].default_value = B.hexcol(mortar); b.offset = 0.5; b.squash = 1.0
    nt.links.new(tc.outputs["Object"], b.inputs["Vector"])
    n = nt.nodes.new("ShaderNodeTexNoise"); n.inputs["Scale"].default_value = 30
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"; mix.blend_type = "MULTIPLY"; mix.inputs["Factor"].default_value = 0.35
    nt.links.new(b.outputs["Color"], mix.inputs["A"]); nt.links.new(n.outputs["Color"], mix.inputs["B"])
    nt.links.new(mix.outputs["Result"], p.inputs["Base Color"])
    bm = nt.nodes.new("ShaderNodeBump"); bm.inputs["Strength"].default_value = 0.6
    nt.links.new(b.outputs["Fac"], bm.inputs["Height"]); nt.links.new(bm.outputs["Normal"], p.inputs["Normal"])
    return m

def emit(name, color, strength):
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    o = nt.nodes.new("ShaderNodeOutputMaterial"); e = nt.nodes.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = B.hexcol(color); e.inputs["Strength"].default_value = strength
    nt.links.new(e.outputs[0], o.inputs["Surface"]); return m

def water_mat():
    m = bpy.data.materials.new("water"); m.use_nodes = True; nt = m.node_tree; p = nt.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = B.hexcol("#0B1630"); p.inputs["Roughness"].default_value = 0.08
    p.inputs["Coat Weight"].default_value = 0.6
    n = nt.nodes.new("ShaderNodeTexNoise"); n.inputs["Scale"].default_value = 3.0
    bm = nt.nodes.new("ShaderNodeBump"); bm.inputs["Strength"].default_value = 0.25
    nt.links.new(n.outputs["Fac"], bm.inputs["Height"]); nt.links.new(bm.outputs["Normal"], p.inputs["Normal"])
    return m

LAND = {   # top, side, top mottle
    1: ("#7A7262", "#3E3830", "#6A6656"),
    2: ("#5A7E4E", "#2E3E2A", "#6A8A54"),
    3: ("#6A5A8A", "#2E2444", "#7A6A9E"),
    4: ("#B88A5A", "#5E3E26", "#8E6A48"),
}
THEMES = {
    1: dict(top=("#46506E", "#2C3248"), floor=("#A8A294", "#989284"), wall=("#4A5068", "#262A3A"), ground=("#2E3346", "#1C2030")),
    2: dict(top=("#5E7A4A", "#3A5030"), floor=("#A2AE8E", "#929E7E"), wall=("#4E5A48", "#283024"), ground=("#33402F", "#1E281C")),
    3: dict(top=("#6A5A8A", "#3E3458"), floor=("#9E94B4", "#8E84A4"), wall=("#4A4262", "#251F36"), ground=("#2E2840", "#1A1528")),
    4: dict(floor=("#E2C89A", "#D4B888"), wall=("#7A5A3E", "#3E2A1C"), top=("#C9A06A", "#8A6A44"), ground=("#9A8064", "#5E4C38")),
}

# ---------- shapes ----------
def box(name, center, size, material, bevel=0.06):
    bpy.ops.mesh.primitive_cube_add(location=center); o = bpy.context.object; o.name = name
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        m = o.modifiers.new("bevel", "BEVEL"); m.width = bevel; m.segments = 3
    o.data.materials.append(material)
    for p in o.data.polygons: p.use_smooth = True
    return o

def cyl(name, center, r, h, material, verts=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=center); o = bpy.context.object
    o.name = name; o.data.materials.append(material)
    for p in o.data.polygons: p.use_smooth = True
    return o

def blob(name, center, scale, material, noise=0.08, seed=0, sub=3):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, location=center); o = bpy.context.object; o.name = name
    o.scale = scale
    r = random.Random(seed)
    for v in o.data.vertices:
        v.co *= 1 + noise * (r.random() - 0.5)
    o.data.materials.append(material)
    for p in o.data.polygons: p.use_smooth = True
    m = o.modifiers.new("sub", "SUBSURF"); m.levels = 1; m.render_levels = 1
    return o

def point_light(loc, energy, color, radius=0.1):
    bpy.ops.object.light_add(type="POINT", location=loc); l = bpy.context.object
    l.data.energy = energy; l.data.color = B.hexcol(color)[:3]; l.data.shadow_soft_size = radius
    return l

def place(build, at, turn=0.0, **kw):
    """Build a figure about the origin and move it (every new top-level object) to a cell."""
    before = set(bpy.data.objects)
    build(**kw)
    bpy.ops.object.empty_add(location=(0, 0, 0)); pivot = bpy.context.object
    for o in set(bpy.data.objects) - before:
        if o is not pivot and o.parent is None and o.type != "CAMERA":
            o.parent = pivot
    pivot.rotation_euler = (math.radians(-(TILT - 22)), 0, math.radians(turn)); pivot.location = at
    return pivot

# ---------- the spark: the sun's last fire, a thing you can hold ----------
def flame_mat(name, root, mid, tip, strength):
    """A toy flame: opaque, glowing, yellow at the root through orange to a red tip (by height in the object)."""
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    o = nt.nodes.new("ShaderNodeOutputMaterial"); e = nt.nodes.new("ShaderNodeEmission")
    tc = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB"); cr = ramp.color_ramp
    cr.elements[0].position = 0.25; cr.elements[0].color = B.hexcol(root)
    cr.elements[1].position = 0.92; cr.elements[1].color = B.hexcol(tip)
    mid_el = cr.elements.new(0.55); mid_el.color = B.hexcol(mid)
    nt.links.new(tc.outputs["Generated"], sep.inputs[0]); nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], e.inputs["Color"]); e.inputs["Strength"].default_value = strength
    nt.links.new(e.outputs[0], o.inputs["Surface"])
    return m

def teardrop(name, at, r, h, material, lean=(0.0, 0.0)):
    """A flame tongue: round at the root, drawn up to a point, leaning a little."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=24, location=at); o = bpy.context.object; o.name = name
    for v in o.data.vertices:
        z = v.co.z                    # -1..1
        k = (z + 1) / 2               # 0 root .. 1 tip
        squeeze = ((1 - k) / 0.7) ** 0.55 if k > 0.3 else 1.0
        v.co.x *= squeeze; v.co.y *= squeeze
        v.co.z = z if z < 0 else z * 1.9
        v.co.x += lean[0] * k * k * 2; v.co.y += lean[1] * k * k * 2
    o.scale = (r, r, h / 3.4)
    o.data.materials.append(material); o.visible_shadow = False
    for p in o.data.polygons: p.use_smooth = True
    return o

def spark(at, scale=1.0):
    """The sun's last fire: a white-hot core inside a flame that licks upward, sparks spinning off it."""
    B.sphere("spark_core", at + Vector((0, -0.12 * scale, -0.02 * scale)), (0.06 * scale,) * 3, emit("sparkCore", "#FFF8E0", 12))
    teardrop("flame_in", at + Vector((0, -0.06 * scale, -0.02 * scale)), 0.1 * scale, 0.36 * scale, flame_mat("flameIn", "#FFE680", "#FFB820", "#FF8A10", 1.6))
    teardrop("flame_out", at + Vector((0, 0, -0.05 * scale)), 0.17 * scale, 0.62 * scale, flame_mat("flameOut", "#FFA010", "#FF5A00", "#D02000", 1.3), lean=(0.04, 0.0))
    for i, (dx, lean) in enumerate([(-0.09, (-0.05, 0)), (0.1, (0.06, 0.02))]):
        teardrop(f"flame_side{i}", at + Vector((dx * scale, 0.02, -0.04 * scale)), 0.07 * scale, 0.32 * scale, flame_mat(f"flameS{i}", "#FF9000", "#F04800", "#C01800", 1.2), lean=lean)
    me = emit("ember", "#FF8A2A", 4)
    for i in range(5):
        a = rnd.uniform(-0.6, 0.6); r = (0.1 + rnd.random() * 0.15) * scale
        B.sphere(f"ember{i}", at + Vector((math.sin(a) * r, -0.1 * scale, (0.45 + rnd.random() * 0.35) * scale)), (0.011 * scale,) * 3, me)
    point_light(at + Vector((0, -0.1, 0.15)), 110 * scale, "#FF9A3A", 0.15)

MATS = {}
WALLS = []
LANE_TOP = {}

def vinyl_land(name, top, side, top2=None):
    """The toy-box ground: matte soft vinyl, tops in one colour and slopes/sides in a deeper one, a soft large-scale
    mottling in world space so the land never repeats."""
    m = B.rubber(name, top, rough=0.62, sss=0.02); nt = m.node_tree; p = nt.nodes["Principled BSDF"]
    geo = nt.nodes.new("ShaderNodeNewGeometry"); sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], sep.inputs[0])
    mr = nt.nodes.new("ShaderNodeMapRange"); mr.inputs["From Min"].default_value = 0.55; mr.inputs["From Max"].default_value = 0.85
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 0.35; nz.inputs["Detail"].default_value = 3
    nt.links.new(geo.outputs["Position"], nz.inputs["Vector"])
    tops = nt.nodes.new("ShaderNodeMix"); tops.data_type = "RGBA"
    tops.inputs["A"].default_value = B.hexcol(top); tops.inputs["B"].default_value = B.hexcol(top2 or top)
    nt.links.new(nz.outputs["Fac"], tops.inputs["Factor"])
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"; mix.inputs["A"].default_value = B.hexcol(side)
    nt.links.new(tops.outputs["Result"], mix.inputs["B"]); nt.links.new(mr.outputs["Result"], mix.inputs["Factor"])
    nt.links.new(mix.outputs["Result"], p.inputs["Base Color"])
    return m

def remesh_join(objs, name, voxel=0.19, smooth=3):
    """Fuse blocks into one soft clay mass: join, voxel-remesh, relax the edges."""
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
        for mod in list(o.modifiers): o.modifiers.remove(mod)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join(); o = bpy.context.object; o.name = name
    rm = o.modifiers.new("remesh", "REMESH"); rm.mode = "VOXEL"; rm.voxel_size = voxel
    sm = o.modifiers.new("smooth", "LAPLACIANSMOOTH"); sm.iterations = smooth; sm.lambda_factor = 0.6; sm.use_volume_preserve = True
    for poly in o.data.polygons: poly.use_smooth = True
    o.data.materials.clear()
    return o

# ---------- room ----------
def build_room(ch):
    th = THEMES[ch]
    floor = stone("floor", *th["floor"])
    rockside = strata("rockside", th["wall"][1], th["wall"][0])
    toptile = stone("toptile", *th["top"], scale=3.5, bump=0.35)
    MATS.update(rockside=rockside, toptile=toptile, floor=floor)
    tileA = B.rubber("tileA", th["floor"][0], rough=0.55); tileB = B.rubber("tileB", th["floor"][1], rough=0.55)
    # sand between the slabs
    box("underlay", Vector((0, 0, -0.14)), (W * S, H * S, 0.04), stone("gap", *th["ground"], scale=3), bevel=0)
    cap = stone("cap", th["wall"][0], th["wall"][1], scale=10)
    water = water_mat()
    metal = B.mat("metal", "#3A3A44", rough=0.4)
    glass_off = B.mat("glassOff", "#2A2A30", rough=0.2, coat=0.6)
    gold = B.mat("gold", "#C9963E", rough=0.35, coat=0.3)
    plate_m = B.mat("plate", "#5A5E70", rough=0.5)
    boulder_m = stone("boulder", "#6A6A70", "#3A3A42", scale=4, bump=0.5)
    shadow_m = B.mat("shadowBody", "#050609", rough=0.9)
    eye_m = emit("shadowEye", "#CFD6FF", 3)
    for y, row in enumerate(GRID):
        for x, ch_ in enumerate(row):
            c = cell(x, y)
            if ch_ == "#":
                hgt = S * 0.42
                WALLS.append(box(f"block_{x}_{y}", c + Vector((0, 0, hgt / 2 - 0.15)), (S, S, hgt + 0.3), rockside, bevel=0))
                continue
            if ch_ == "~":
                box(f"water_{x}_{y}", c + Vector((0, 0, -0.08)), (S, S, 0.1), water, bevel=0)
                box(f"bed_{x}_{y}", c + Vector((0, 0, -0.45)), (S, S, 0.2), stone("bed", "#1A2238", "#0A0E18"), bevel=0)
                continue
            # a stone slab per cell, each a little different in height and tilt
            h = 0.12
            slab = box(f"slab_{x}_{y}", c + Vector((0, 0, -h / 2)), (S * 0.95, S * 0.95, h), tileA if (x + y) % 2 else tileB, bevel=0.1)
            slab.modifiers["bevel"].segments = 5
            slab.rotation_euler = (rnd.uniform(-0.01, 0.01), rnd.uniform(-0.01, 0.01), rnd.uniform(-0.02, 0.02))
            if ch_ in "Ll":
                cyl(f"post_{x}_{y}", c + Vector((0, 0.1, 0.6)), 0.05, 1.2, metal)
                lit = ch_ == "L"
                if not BG:
                    B.sphere(f"lantern_{x}_{y}", c + Vector((0, 0.1, 1.28)), (0.16, 0.16, 0.2), emit("lit", "#FFD27A", 18) if lit else glass_off)
                    cyl(f"lcap_{x}_{y}", c + Vector((0, 0.1, 1.5)), 0.17, 0.06, metal)
                    if lit: point_light(c + Vector((0, 0.0, 1.3)), 160, "#FFC46A", 0.15)
                cyl(f"lbase_{x}_{y}", c + Vector((0, 0.1, 0.05)), 0.14, 0.1, metal)
            elif ch_ == "P":
                cyl(f"plate_{x}_{y}", c + Vector((0, 0, 0.01)), S * 0.32, 0.04, plate_m, verts=6)
            elif ch_ == "D":
                for k in range(4 if not BG else 0):
                    cyl(f"bar_{x}_{y}_{k}", c + Vector(((k - 1.5) * S * 0.22, 0, 0.55)), 0.04, 1.1, metal, verts=12)
                box(f"lintel_{x}_{y}", c + Vector((0, 0, 1.12)), (S * 0.95, 0.12, 0.08), metal, bevel=0.01)
            elif ch_ == "B" and not BG:
                blob(f"boulder_{x}_{y}", c + Vector((0, 0, 0.42)), (0.5, 0.48, 0.42), boulder_m, seed=x * 31 + y)
            elif ch_ == "S" and not BG:
                body = blob(f"shadow_{x}_{y}", c + Vector((0, 0, 0.4)), (0.42, 0.36, 0.5), shadow_m, noise=0.12, seed=x + y * 7)
                for s in (-1, 1):
                    B.sphere(f"seye_{x}_{y}_{s}", c + Vector((s * 0.13, -0.33, 0.55)), (0.05, 0.02, 0.035), eye_m)
            elif ch_ == "E":
                pale_e = B.rubber("archstone", "#E6D2B0", rough=0.6)
                for sx in (-1, 1):
                    cyl(f"jamb_{x}_{y}_{sx}", c + Vector((sx * 0.55, 0.45, 0.55)), 0.12, 1.1, pale_e, verts=20)
                lt = box(f"arch_{x}_{y}", c + Vector((0, 0.45, 1.15)), (1.4, 0.3, 0.22), pale_e, bevel=0.08); lt.modifiers["bevel"].segments = 3
                if not BG: point_light(c + Vector((0, 0.1, 0.8)), 30, "#FFD27A", 0.3)
                cyl(f"rune_{x}_{y}", c + Vector((0, -0.05, 0.005)), 0.36, 0.012, emit("rune", "#FFC46A", 0.25 if BG else 1.2), verts=24)
            elif ch_ == "T":
                tab = B.rubber("tablet", "#9A9AA8", rough=0.65)
                t = box(f"tablet_{x}_{y}", c + Vector((0, 0.25, 0.5)), (0.8, 0.22, 1.0), tab, bevel=0.12); t.modifiers["bevel"].segments = 4
                box(f"tabletbase_{x}_{y}", c + Vector((0, 0.25, 0.04)), (1.0, 0.4, 0.08), tab, bevel=0.03)
                for k in range(3):   # carved lines on its face
                    box(f"glyph_{x}_{y}_{k}", c + Vector((0, 0.13, 0.75 - k * 0.18)), (0.5 - k * 0.08, 0.02, 0.05), B.mat("glyph", "#5A5A6A", rough=0.8), bevel=0)
            elif ch_ == "N":
                nest = B.rubber("nest", "#7A5A3A", rough=0.8)
                bpy.ops.mesh.primitive_torus_add(major_radius=0.42, minor_radius=0.13, location=c + Vector((0, 0, 0.1))); t = bpy.context.object
                t.scale = (1, 1, 0.7); t.data.materials.append(nest)
                for k in range(10):
                    a = k / 10 * math.tau
                    cyl(f"twig_{x}_{y}_{k}", c + Vector((math.cos(a) * 0.42, math.sin(a) * 0.42, 0.16)), 0.025, 0.5, nest, verts=8).rotation_euler = (math.radians(80), 0, a)
    return th

def landscape(ch, th):
    """The world past the room: ground that keeps going, then the chapter's horizon."""
    ground = stone("ground", *th["ground"], scale=0.8, bump=0.4)
    nt = ground.node_tree; p = nt.nodes["Principled BSDF"]
    big = nt.nodes.new("ShaderNodeTexNoise"); big.inputs["Scale"].default_value = 0.12; big.inputs["Detail"].default_value = 3
    rr = nt.nodes.new("ShaderNodeValToRGB"); rr.color_ramp.elements[0].color = B.hexcol(th["ground"][1]); rr.color_ramp.elements[1].color = B.hexcol(th["ground"][0])
    rr.color_ramp.elements[0].position = 0.4; rr.color_ramp.elements[1].position = 0.62
    mixg = nt.nodes.new("ShaderNodeMix"); mixg.data_type = "RGBA"; mixg.blend_type = "MULTIPLY"; mixg.inputs["Factor"].default_value = 0.6
    old = p.inputs["Base Color"].links[0].from_socket
    nt.links.new(old, mixg.inputs["A"]); nt.links.new(rr.outputs["Color"], mixg.inputs["B"]); nt.links.new(big.outputs["Fac"], rr.inputs["Fac"])
    nt.links.new(mixg.outputs["Result"], p.inputs["Base Color"])
    tcg = nt.nodes.new("ShaderNodeTexCoord"); vl = nt.nodes.new("ShaderNodeVectorMath"); vl.operation = "LENGTH"
    nt.links.new(tcg.outputs["Object"], vl.inputs[0])
    mr = nt.nodes.new("ShaderNodeMapRange"); mr.inputs["From Min"].default_value = 7; mr.inputs["From Max"].default_value = 20
    nt.links.new(vl.outputs["Value"], mr.inputs["Value"])
    fog = nt.nodes.new("ShaderNodeMix"); fog.data_type = "RGBA"; fog.inputs["B"].default_value = B.hexcol("#141A30")
    nt.links.new(mr.outputs["Result"], fog.inputs["Factor"]); nt.links.new(mixg.outputs["Result"], fog.inputs["A"])
    nt.links.new(fog.outputs["Result"], p.inputs["Base Color"])
    wv = nt.nodes.new("ShaderNodeTexWave"); wv.inputs["Scale"].default_value = 1.6; wv.inputs["Distortion"].default_value = 4; wv.inputs["Detail"].default_value = 3
    bm = nt.nodes.new("ShaderNodeBump"); bm.inputs["Strength"].default_value = 0.35
    nt.links.new(wv.outputs["Fac"], bm.inputs["Height"]); nt.links.new(bm.outputs["Normal"], p.inputs["Normal"])
    def hgt(wx, wy):
        d = max(0.0, max(abs(wx) - W * S / 2, abs(wy) - H * S / 2))
        return (math.sin(wx * 0.45 + wy * 0.2) * 0.25 + math.sin(wy * 0.9) * 0.08) * min(1.0, d / 3) - 0.12
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=160, y_subdivisions=160, size=70, location=(0, 0, 0))
    g = bpy.context.object; g.data.materials.append(ground)
    for v in g.data.vertices:
        inside = abs(v.co.x) < W * S / 2 - 0.05 and abs(v.co.y) < H * S / 2 - 0.05
        v.co.z = -0.5 if inside else hgt(v.co.x, v.co.y)
    for p in g.data.polygons: p.use_smooth = True
    rub = stone("rubble", th["wall"][0], th["wall"][1], scale=5, bump=0.5)
    placed = 0
    while placed < 46:
        x, y = rnd.uniform(-14, 14), rnd.uniform(-22, 22)
        if abs(x) < W * S / 2 + 0.5 and abs(y) < H * S / 2 + 0.5: continue
        sc = 0.08 + rnd.random() ** 3 * 0.45
        blob(f"rock{placed}", (x, y, hgt(x, y) + sc * 0.05), (sc * 1.3, sc, sc * 0.7), rub, seed=placed, sub=2)
        placed += 1
    tuft = B.mat("tuft", "#7A7048" if ch == 4 else "#4A6A40", rough=0.8)
    for i in range(60):
        x, y = rnd.uniform(-13, 13), rnd.uniform(-20, 20)
        if abs(x) < W * S / 2 + 0.4 and abs(y) < H * S / 2 + 0.4: continue
        z = hgt(x, y)
        for k in range(7):
            a = rnd.random() * math.tau
            bpy.ops.mesh.primitive_cone_add(vertices=5, radius1=0.025, radius2=0.0, depth=0.35 + rnd.random() * 0.3, location=(x + math.cos(a) * 0.08, y + math.sin(a) * 0.08, z + 0.15))
            t = bpy.context.object; t.rotation_euler = (math.cos(a) * 0.45, math.sin(a) * 0.45, 0); t.data.materials.append(tuft)
    if ch == 4:
        road = stone("road", "#B08A5E", "#7A5A3A", scale=2.5, bump=0.3)
        top = H * S / 2
        for i in range(14):   # flagstones running north from the room
            y = top + 0.6 + i * 1.1
            x = math.sin(i * 0.5) * 0.8
            box(f"flag{i}", (x + rnd.uniform(-0.1, 0.1), y, hgt(x, y) + 0.02), (1.3 + rnd.uniform(-0.2, 0.2), 0.9, 0.12), road, bevel=0.05)
        for i in range(6):    # waymarks: short standing stones each side of the road
            y = top + 1.5 + i * 2.3; side = -1 if i % 2 else 1
            x = math.sin(i) * 0.6 + side * 1.6
            box(f"mark{i}", (x, y, hgt(x, y) + 0.45), (0.35, 0.3, 0.9), rub, bevel=0.08)
        point_light((0, top + 30, 4), 2500, "#FF8A40", 10)
        lamp_dead = B.mat("deadlamp", "#2A2A30", rough=0.3, coat=0.5)
        metal = B.mat("metal2", "#3A3A44", rough=0.4)
        for i, (x, y) in enumerate([(-2.6, top + 3.0), (2.4, top + 6.5), (-2.2, top + 10.5)]):
            cyl(f"rpost{i}", (x, y, hgt(x, y) + 0.7), 0.05, 1.4, metal)
            B.sphere(f"rlamp{i}", (x, y, hgt(x, y) + 1.45), (0.15, 0.15, 0.19), lamp_dead)
        for i, (x, y, hh) in enumerate([(-W * S / 2 - 1.6, -1.0, 2.2), (W * S / 2 + 1.4, 1.5, 1.5), (-W * S / 2 - 1.2, -H * S / 2 - 3.0, 1.0), (W * S / 2 + 1.8, -H * S / 2 - 5.0, 2.6)]):
            cyl(f"pillar{i}", (x, y, hgt(x, y) + hh / 2), 0.32, hh, rub, verts=10)
            blob(f"pillarcap{i}", (x + 0.1, y, hgt(x, y) + hh + 0.05), (0.42, 0.38, 0.14), rub, seed=200 + i, sub=2)    # the sleeping sun, far beyond the top of the screen

def terrain(ch, th):
    """The world around the room in the same block language: the room is a lowered court; outside it the ground
    rises in terraces, lowest in front (so nothing hides the room) and highest far behind; lanes run out from the
    room; chapter props stand on the terraces."""
    rockside, toptile, floor = MATS["rockside"], MATS["toptile"], MATS["floor"]
    top2 = stone("top2", th["top"][1], th["wall"][1], scale=3, bump=0.4)
    mx = max(4, (CW - W) // 2 + 2)
    X0, X1, Y0, Y1 = -mx, W + mx, -14, H + 14
    cx = W // 2
    lane_n = {y: cx + int(round(math.sin(y * 0.5) * 1.2)) for y in range(Y0, 0)}        # a lane north from the room
    lane_s = {y: cx + int(round(math.sin(y * 0.45 + 1) * 1.5)) for y in range(H, Y1)}    # and one south
    noise = lambda x, y: (math.sin(x * 0.7 + y * 0.31) + math.sin(x * 0.23 - y * 0.57) + math.sin((x + y) * 0.41)) / 3
    props = []
    for y in range(Y0, Y1):
        for x in range(X0, X1):
            if 0 <= x < W and 0 <= y < H: continue
            c = cell(x, y)
            on_lane = (y < 0 and abs(x - lane_n.get(y, -99)) <= 0) or (y >= H and abs(x - lane_s.get(y, -99)) <= 0)
            if on_lane:
                rise = S * 0.42 * ((max(0, -y) + 1) // 3) if y < 0 else 0.0
                if rise > 0: WALLS.append(box(f"lanebase_{x}_{y}", c + Vector((0, 0, rise / 2 - 0.2)), (S, S, rise + 0.2), rockside, bevel=0))
                box(f"lane_{x}_{y}", c + Vector((0, 0, rise - 0.07)), (S * 0.96, S * 0.96, 0.12), floor, bevel=0.05)
                LANE_TOP[(x, y)] = rise
                continue
            dx = max(0, -x, x - W + 1); dy_n = max(0, -y); dy_s = max(0, y - H + 1)
            d = max(dx, dy_n, dy_s)
            # the land climbs in big steps toward the north (where the sun sleeps); low and open to the south
            lvl = 1 + int((noise(x, y) * 0.5 + 0.5) * 1.6) + (dy_n + 1) // 3 + max(0, dx - 2) // 2
            if dy_s > 0: lvl = 1 if noise(x * 1.3, y) < 0.35 else 2
            if dy_s > 0 and dy_s <= 2: lvl = 1
            lvl = min(lvl, 6)
            hgt = S * 0.42 * lvl
            WALLS.append(box(f"t_{x}_{y}", c + Vector((0, 0, hgt / 2 - 0.15)), (S * 1.0, S * 1.0, hgt + 0.3), rockside, bevel=0))
            props.append((x, y, hgt))
    land = remesh_join(WALLS, "land")
    land.data.materials.append(vinyl_land("land", *LAND[ch]))
    rnd2 = random.Random(11)
    if ch == 4:
        sandstone = B.rubber("sandstone", "#B07A4A", rough=0.6)
        pale = B.rubber("palestone", "#D9B888", rough=0.6)
        grass = B.rubber("drygrass", "#C8A050", rough=0.7)
        sunstone = emit("carved", "#FFB060", 0.6)
        for (x, y, hgt) in props:
            c = cell(x, y, hgt); r = rnd2.random()
            if r < 0.08:          # a standing stone with a sun carved in it, faintly warm
                st = box(f"menhir_{x}_{y}", c + Vector((0, 0, 0.5)), (0.42, 0.3, 1.0), pale, bevel=0.14)
                st.modifiers["bevel"].segments = 4
                cyl(f"carve_{x}_{y}", c + Vector((0, -0.16, 0.62)), 0.1, 0.02, sunstone, verts=16).rotation_euler = (math.radians(90), 0, 0)
            elif r < 0.30:        # tufts of dry grass
                for k in range(5 + int(rnd2.random() * 5)):
                    a_ = rnd2.random() * math.tau; rr = rnd2.random() * 0.35
                    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.035, radius2=0.0, depth=0.3 + rnd2.random() * 0.25,
                        location=c + Vector((math.cos(a_) * rr, math.sin(a_) * rr, 0.13)))
                    t = bpy.context.object; t.rotation_euler = (rnd2.uniform(-0.4, 0.4), rnd2.uniform(-0.4, 0.4), 0); t.data.materials.append(grass)
            elif r < 0.40:        # round sandstone boulders, in twos and threes
                for k in range(1 + int(rnd2.random() * 3)):
                    sc = 0.2 + rnd2.random() * 0.25
                    blob(f"boul_{x}_{y}_{k}", c + Vector((rnd2.uniform(-0.35, 0.35), rnd2.uniform(-0.35, 0.35), sc * 0.6)), (sc * 1.2, sc, sc * 0.85), sandstone, noise=0.04, seed=x + y * 9 + k, sub=3)
        gy = -5; gx = lane_n[gy]; base = cell(gx, gy, LANE_TOP.get((gx, gy), 0.0))
        for sx in (-1, 1):
            pl = cyl(f"gate_{sx}", base + Vector((sx * 1.05, 0, 1.2)), 0.28, 2.4, pale, verts=24)
            blob(f"gatecap_{sx}", base + Vector((sx * 1.05, 0, 2.45)), (0.36, 0.36, 0.16), pale, noise=0.0, seed=sx + 5)
        lt = box("gate_lintel", base + Vector((0, 0, 2.6)), (2.9, 0.5, 0.38), pale, bevel=0.12); lt.modifiers["bevel"].segments = 4
        disc = cyl("gate_sun", base + Vector((0, -0.27, 2.6)), 0.3, 0.06, emit("gateSun", "#FFB060", 2.0), verts=32); disc.rotation_euler = (math.radians(90), 0, 0)
        point_light(base + Vector((0, -0.8, 2.2)), 120, "#FFB060", 0.3)
        # the sleeping sun's warmth from beyond the top edge, and the night everywhere else
        top_y = cell(0, Y0).y
        bpy.ops.object.light_add(type="AREA", location=(0, top_y + 2, 7), rotation=(math.radians(-60), 0, 0)); l = bpy.context.object
        l.data.energy = 600; l.data.size = 24; l.data.color = B.hexcol("#FF9A50")[:3]
    elif ch == 1:
        # the lighthouse town: toy houses on the terraces, a few windows still lit, the lighthouse up the north lane
        roofs = [B.rubber(f"roof{i}", c_, rough=0.6) for i, c_ in enumerate(("#8A3A3A", "#4A5A8A", "#6A4A3A"))]
        walls_ = [B.rubber(f"hw{i}", c_, rough=0.65) for i, c_ in enumerate(("#D8CCB4", "#B8C0CC", "#CCB8A0"))]
        win = emit("window", "#FFC46A", 2.5); dark = B.mat("winDark", "#1A1E2A", rough=0.3)
        crate = B.rubber("crate", "#7A5A3A", rough=0.7)
        for (x, y, hgt) in props:
            c = cell(x, y, hgt); r = rnd2.random()
            if r < 0.16:
                hh = 0.75 + rnd2.random() * 0.35; wm = walls_[rnd2.randrange(3)]
                hb = box(f"house_{x}_{y}", c + Vector((0, 0.05, hh / 2)), (S * 0.78, S * 0.7, hh), wm, bevel=0.06); hb.modifiers["bevel"].segments = 3
                bpy.ops.mesh.primitive_cylinder_add(vertices=3, radius=S * 0.48, depth=S * 0.82, location=c + Vector((0, 0.05, hh + 0.2)), rotation=(0, math.radians(90), 0))
                rf = bpy.context.object; rf.scale = (1, 1, 0.75); rf.data.materials.append(roofs[rnd2.randrange(3)])
                for wx in (-0.25, 0.25):
                    box(f"win_{x}_{y}_{wx}", c + Vector((wx, -S * 0.35 + 0.05 - 0.02, hh * 0.55)), (0.2, 0.03, 0.24), win if rnd2.random() < 0.45 else dark, bevel=0.01)
                if rnd2.random() < 0.5:
                    box(f"chim_{x}_{y}", c + Vector((0.3, 0.2, hh + 0.45)), (0.16, 0.16, 0.4), walls_[0], bevel=0.03)
            elif r < 0.22:
                for k in range(1 + int(rnd2.random() * 2)):
                    cb = box(f"crate_{x}_{y}_{k}", c + Vector((rnd2.uniform(-0.3, 0.3), rnd2.uniform(-0.3, 0.3), 0.18 + k * 0.33)), (0.36, 0.36, 0.34), crate, bevel=0.05)
        gy = -6; gx = lane_n[gy]; base = cell(gx + 2, gy, S * 0.42 * 3)
        tw = B.rubber("tower", "#E8E0D0", rough=0.6); band = B.rubber("band", "#B83A3A", rough=0.6)
        bpy.ops.mesh.primitive_cone_add(vertices=48, radius1=0.9, radius2=0.6, depth=4.2, location=base + Vector((0, 0, 2.1))); t = bpy.context.object; t.data.materials.append(tw)
        for k in range(2): cyl(f"band{k}", base + Vector((0, 0, 1.2 + k * 1.4)), 0.84 - k * 0.1, 0.35, band, verts=48)
        cyl("lantern_room", base + Vector((0, 0, 4.5)), 0.55, 0.6, B.mat("lroom", "#3A3020", rough=0.2, coat=0.6), verts=32)
        bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=0.7, depth=0.6, location=base + Vector((0, 0, 5.1))); bpy.context.object.data.materials.append(band)
    elif ch == 2:
        # ruins in the green dark: broken columns, a fallen arch, round trees, ferns
        stoneM = B.rubber("ruin", "#B8B8A0", rough=0.65); mossy = B.rubber("mossy", "#4E7A46", rough=0.75)
        trunk = B.rubber("trunk", "#5A4632", rough=0.7); leaves = [B.rubber(f"leaf{i}", c_, rough=0.7) for i, c_ in enumerate(("#3E6A3E", "#4E7E46", "#35583A"))]
        for (x, y, hgt) in props:
            c = cell(x, y, hgt); r = rnd2.random()
            if r < 0.14:
                hh = 0.6 + rnd2.random() * 1.6
                cyl(f"col_{x}_{y}", c + Vector((0, 0, hh / 2)), 0.26, hh, stoneM, verts=20)
                box(f"colcap_{x}_{y}", c + Vector((0, 0, hh + 0.06)), (0.66, 0.66, 0.14), stoneM, bevel=0.04)
                blob(f"colmoss_{x}_{y}", c + Vector((0.05, 0, hh + 0.16)), (0.3, 0.28, 0.08), mossy, seed=x * 3 + y, sub=2)
            elif r < 0.36:
                th_ = 0.5 + rnd2.random() * 0.4
                cyl(f"trunk_{x}_{y}", c + Vector((0, 0, th_ / 2)), 0.08, th_, trunk, verts=12)
                for k in range(3):
                    blob(f"canopy_{x}_{y}_{k}", c + Vector((rnd2.uniform(-0.2, 0.2), rnd2.uniform(-0.2, 0.2), th_ + 0.25 + k * 0.12)), (0.45 - k * 0.08,) * 3, leaves[rnd2.randrange(3)], noise=0.06, seed=x * 7 + y * 11 + k, sub=3)
            elif r < 0.5:
                for k in range(3 + int(rnd2.random() * 3)):
                    blob(f"fern_{x}_{y}_{k}", c + Vector((rnd2.uniform(-0.45, 0.45), rnd2.uniform(-0.45, 0.45), 0.08)), (0.2, 0.16, 0.1), mossy, seed=x + y * 5 + k, sub=2)
    elif ch == 3:
        # the shadow country: violet crystal clusters glowing faintly, thin spires, dead trees
        crystal = B.mat("crystal", "#8A6AD0", rough=0.15, coat=0.8, emit="#7A5AE0", emit_strength=0.6)
        spireM = B.rubber("spire", "#3A2E58", rough=0.6); dead = B.rubber("deadtree", "#2A2236", rough=0.8)
        for (x, y, hgt) in props:
            c = cell(x, y, hgt); r = rnd2.random()
            if r < 0.2:
                for k in range(3 + int(rnd2.random() * 3)):
                    hh = 0.3 + rnd2.random() * 0.6
                    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.09 + rnd2.random() * 0.06, depth=hh, location=c + Vector((rnd2.uniform(-0.35, 0.35), rnd2.uniform(-0.35, 0.35), hh / 2)))
                    o_ = bpy.context.object; o_.rotation_euler = (rnd2.uniform(-0.35, 0.35), rnd2.uniform(-0.35, 0.35), 0); o_.data.materials.append(crystal)
            elif r < 0.3:
                hh = 1.5 + rnd2.random() * 2.5
                bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=0.4, depth=hh, location=c + Vector((0, 0, hh / 2))); bpy.context.object.data.materials.append(spireM)
            elif r < 0.4:
                cyl(f"dt_{x}_{y}", c + Vector((0, 0, 0.45)), 0.06, 0.9, dead, verts=8)
                for k in range(3):
                    a_ = k * 2.1
                    cyl(f"br_{x}_{y}_{k}", c + Vector((math.cos(a_) * 0.15, math.sin(a_) * 0.15, 0.75)), 0.03, 0.4, dead, verts=6).rotation_euler = (math.cos(a_) * 0.8, math.sin(a_) * 0.8, 0)

def sky():
    world = bpy.data.worlds.new("night"); bpy.context.scene.world = world; world.use_nodes = True
    bg = world.node_tree.nodes["Background"]; bg.inputs["Color"].default_value = B.hexcol("#1A2040"); bg.inputs["Strength"].default_value = 0.6
    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(50), math.radians(-20), math.radians(25))); m = bpy.context.object
    m.data.energy = 2.6; m.data.color = B.hexcol("#A4AEDC")[:3]; m.data.angle = math.radians(3)
    star = emit("star", "#E6ECFF", 6)
    for i in range(160):
        B.sphere(f"star{i}", (rnd.uniform(-60, 60), 80, rnd.uniform(8, 70)), (0.06 + rnd.random() * 0.08,) * 3, star, seg=8)

def camera(w, h):
    s = bpy.context.scene; t = math.radians(TILT); d = 40
    aim = Vector((0, 0, 0.3))
    bpy.ops.object.camera_add(location=aim + Vector((0, -d * math.cos(t), d * math.sin(t)))); c = bpy.context.object
    c.rotation_euler = (math.radians(90) - t, 0, 0); c.data.type = "ORTHO"
    c.data.ortho_scale = (W * S + 1.0) / (w / h)
    if "--zoom" in ARGS:   # a close look at one cell: --zoom x,y,width_in_cells
        zx, zy, zw = (float(v) for v in arg("--zoom", "0,0,3").split(","))
        aim2 = cell(zx, zy, 0.6)
        c.location = aim2 + Vector((0, -d * math.cos(t), d * math.sin(t))); c.data.ortho_scale = zw * S / min(1.0, w / h)
    if BG:
        c.data.ortho_scale = CH * S
    c.data.clip_end = 300
    s.camera = c

def main():
    w, h = (int(CW * PC), int(CH * PC)) if BG else (arg("--w", 603), arg("--h", 1311))
    s = B.reset(); s.view_settings.look = "AgX - Punchy"; s.view_settings.exposure = 1.0; s.cycles.samples = arg("--samples", 48)
    s.cycles.max_bounces = 4; s.cycles.diffuse_bounces = 2; s.cycles.glossy_bounces = 2; s.cycles.transmission_bounces = 2
    s.cycles.use_adaptive_sampling = True; s.cycles.adaptive_threshold = 0.03
    B.materials(); MO.mosto_materials()
    chapters = json.load(open(os.path.join(ROOT, "Game", "Resources", "rooms.json")))["chapters"]
    ch = next((c_["id"] for c_ in chapters for st in c_["steps"] if st.get("room") == ROOM), 4)
    ch = arg("--chapter", ch)
    import time; t0 = time.time()
    th = build_room(ch); terrain(ch, th); sky()
    print("TIMING build", round(time.time() - t0, 1), "s", flush=True)
    heroes = {} if BG else {c_: (x, y) for y, row in enumerate(GRID) for x, c_ in enumerate(row) if c_ in "OMX"}
    if "O" in heroes:
        x, y = heroes["O"]
        place(B.build_otto, cell(x, y), turn=20, glow=1.0, lid=0.55, look=(0.5, -0.1), slouch=0.8, droop=0.6, bags=True)
        point_light(cell(x, y) + Vector((0.5, -0.2, 2.0)), 120, "#FFC46A", 0.08)
    if "M" in heroes:
        x, y = heroes["M"]
        place(B.build_moss, cell(x, y), turn=-10, look=(0.8, 0.2), lid=0.05, er=0.12, pupil=0.56, perk=0.9, lean=-6)
    if "X" in heroes:
        x, y = heroes["X"]
        place(MO.build_mosto, cell(x, y), turn=-25, moss_eye=dict(look=(-0.6, -0.1), lid=0.25), otto_eye=dict(look=(-0.6, -0.1), lid=0.35), evil=0.6, perk=0.9)
        spark(cell(x, y) + Vector((-0.08, -0.55, 0.62)), 1.9)
    camera(w, h)
    if BG:
        s.render.film_transparent = False
        s.render.image_settings.file_format = "JPEG"; s.render.image_settings.quality = 86
        from bpy_extras.object_utils import world_to_camera_view
        bpy.context.view_layer.update()
        corner = cell(0, 0) + Vector((-S / 2, S / 2, 0))
        v = world_to_camera_view(s, s.camera, corner)
        json.dump(dict(pc=PC, tilt=TILT, w=w, h=h, origin=[round(v.x * w, 2), round((1 - v.y) * h, 2)], cols=W, rows=H),
                  open(os.path.splitext(OUT)[0] + ".json", "w"))
    import time; t0 = time.time()
    B.render(OUT, w, h)
    print("TIMING render", round(time.time() - t0, 1), "s", flush=True)

main()
