"""An RPG map (Game/Resources/rpg.json) as one lit soft-vinyl diorama, seen by the game's camera: orthographic,
looking down 48°, S world units to a cell. Only what never changes is built (ground, walls, houses, trees, water,
the lighthouse, stalls, tablets, stairs); people, foes, chests and lamps are drawn by the game on top.

Writes rpg_<map>.jpg and rpg_<map>.json (pixel origin of the map's top-left ground corner, pixels per cell).

  python3 Tools/art/world3d.py MAP OUT_DIR [--samples 24 --pc 100]
"""
import json, math, os, random, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy
import ip3d as B
from mathutils import Vector

ARGS = sys.argv[1:]
def arg(name, default):
    return type(default)(ARGS[ARGS.index(name) + 1]) if name in ARGS else default

MAP_ID, OUT = ARGS[0], os.path.abspath(ARGS[1])
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SPEC = json.load(open(os.path.join(ROOT, "Game", "Resources", "rpg.json")))["maps"][MAP_ID]
G = SPEC["map"]; H, W = len(G), len(G[0]); THEME = SPEC["theme"]
S = 1.5; TILT = 48; PC = arg("--pc", 100)
MX, MY = 3, 5                       # margin cells round the map (x, y)
rnd = random.Random(17)

def cell(x, y, z=0.0):
    return Vector(((x - (W - 1) / 2) * S, -(y - (H - 1) / 2) * S, z))

def ch(x, y):
    if 0 <= x < W and 0 <= y < H: return G[y][x]
    # past the edge: more of what the edge is
    border = {"town": "#", "wilds": "T", "cellar": "x"}[THEME]
    if THEME == "town" and y >= H - 3: return "~"
    if THEME == "town": return "H" if (x * 7 + y * 3) % 5 else "T"      # more of the town round the edges
    if THEME == "wilds" and y < 0 and 5 <= x <= 9: return "#"
    return border

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

def emit(name, color, strength):
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    o = nt.nodes.new("ShaderNodeOutputMaterial"); e = nt.nodes.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = B.hexcol(color); e.inputs["Strength"].default_value = strength
    nt.links.new(e.outputs[0], o.inputs["Surface"]); return m

def water_mat():
    m = bpy.data.materials.new("water"); m.use_nodes = True; nt = m.node_tree; p = nt.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = B.hexcol("#0E1C3A"); p.inputs["Roughness"].default_value = 0.08
    p.inputs["Coat Weight"].default_value = 0.6
    n = nt.nodes.new("ShaderNodeTexNoise"); n.inputs["Scale"].default_value = 3.0
    bm = nt.nodes.new("ShaderNodeBump"); bm.inputs["Strength"].default_value = 0.25
    nt.links.new(n.outputs["Fac"], bm.inputs["Height"]); nt.links.new(bm.outputs["Normal"], p.inputs["Normal"])
    return m

def vinyl(name, top, side):
    """Matte soft vinyl, tops one colour and sides a deeper one."""
    m = B.rubber(name, top, rough=0.62, sss=0.02); nt = m.node_tree; p = nt.nodes["Principled BSDF"]
    geo = nt.nodes.new("ShaderNodeNewGeometry"); sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], sep.inputs[0])
    mr = nt.nodes.new("ShaderNodeMapRange"); mr.inputs["From Min"].default_value = 0.55; mr.inputs["From Max"].default_value = 0.85
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"; mix.inputs["A"].default_value = B.hexcol(side); mix.inputs["B"].default_value = B.hexcol(top)
    nt.links.new(mr.outputs["Result"], mix.inputs["Factor"]); nt.links.new(mix.outputs["Result"], p.inputs["Base Color"])
    return m

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

def cyl(name, center, r, h, material, verts=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=center); o = bpy.context.object
    o.name = name; o.data.materials.append(material)
    for p in o.data.polygons: p.use_smooth = True
    return o

def blob(name, center, scale, material, noise=0.08, seed=0, sub=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, location=center); o = bpy.context.object; o.name = name
    o.scale = scale
    r = random.Random(seed)
    for v in o.data.vertices: v.co *= 1 + noise * (r.random() - 0.5)
    o.data.materials.append(material)
    for p in o.data.polygons: p.use_smooth = True
    return o

def remesh_join(objs, name, voxel=0.2, smooth=3):
    if not objs: return None
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

# ---------- the map ----------
def build():
    if THEME == "town":
        ground = stone("cobble", "#8E8A80", "#6A665E", scale=9, bump=0.35)
        grass = B.rubber("grass", "#4E6A44", rough=0.8); wallTop = ("#7A7486", "#4A4458")
    elif THEME == "wilds":
        ground = stone("earth", "#7A6A50", "#5A4C38", scale=5, bump=0.3)
        grass = B.rubber("grass", "#4E7A46", rough=0.8); wallTop = ("#5A7E4E", "#2E3E2A")
    else:
        ground = stone("flag", "#4A4656", "#2E2A38", scale=7, bump=0.4)
        grass = B.rubber("moss", "#2E3E30", rough=0.85); wallTop = ("#3A3448", "#1E1A28")
    water = water_mat()
    wood = B.rubber("wood", "#8A6A48", rough=0.7); woodDark = B.rubber("woodDark", "#5A4030", rough=0.75)
    metal = B.mat("metal", "#3A3A44", rough=0.4); glassOff = B.mat("glassOff", "#2A2A30", rough=0.2, coat=0.6)
    trunk = B.rubber("trunk", "#5A4632", rough=0.7)
    leaves = [B.rubber(f"leaf{i}", c_, rough=0.7) for i, c_ in enumerate(("#3E6A3E", "#4E7E46", "#35583A"))]
    rock = stone("rock", "#8A8494", "#5A5664", scale=4, bump=0.5)
    roofs = [B.rubber(f"roof{i}", c_, rough=0.6) for i, c_ in enumerate(("#8A3A3A", "#4A5A8A", "#6A4A3A", "#3A6A5A"))]
    walls_ = [B.rubber(f"hw{i}", c_, rough=0.65) for i, c_ in enumerate(("#D8CCB4", "#B8C0CC", "#CCB8A0"))]
    win = emit("window", "#FFC46A", 2.5); dark = B.mat("winDark", "#1A1E2A", rough=0.3)
    tab = B.rubber("tablet", "#9A9AA8", rough=0.65); glyph = B.mat("glyph", "#5A5A6A", rough=0.8)
    townwall = stone("townwall", "#B8B0A0", "#8A8274", scale=8, bump=0.4); townwallTop = B.rubber("twTop", "#D8D0C0", rough=0.6)
    raised = []
    lighthouse = []
    for y in range(-MY, H + MY):
        for x in range(-MX, W + MX):
            c_ = ch(x, y); c = cell(x, y)
            if c_ == "#" and THEME == "town":
                # the town wall: a low run of pale stone blocks, capped
                box(f"tw_{x}_{y}", c + Vector((0, 0, 0.32)), (S, S * 0.9, 0.64), townwall, bevel=0.05)
                box(f"twc_{x}_{y}", c + Vector((0, 0, 0.68)), (S * 1.02, S * 0.95, 0.1), townwallTop, bevel=0.03)
                continue
            if c_ in "#x":
                hgt = S * (0.5 if THEME == "town" else 0.9 if THEME == "wilds" else 1.1)
                raised.append(box(f"r_{x}_{y}", c + Vector((0, 0, hgt / 2 - 0.15)), (S, S, hgt + 0.3), ground, bevel=0))
                continue
            if c_ == "~":
                box(f"w_{x}_{y}", c + Vector((0, 0, -0.12)), (S, S, 0.06), water, bevel=0)
                box(f"bed_{x}_{y}", c + Vector((0, 0, -0.5)), (S, S, 0.2), stone("bed", "#14203A", "#0A0E18"), bevel=0)
                continue
            # ground slab
            slab = box(f"g_{x}_{y}", c + Vector((0, 0, -0.06)), (S * 0.98, S * 0.98, 0.12), grass if c_ in ",T" and THEME != "cellar" else ground, bevel=0.08)
            slab.rotation_euler = (rnd.uniform(-0.01, 0.01), rnd.uniform(-0.01, 0.01), rnd.uniform(-0.015, 0.015))
            if c_ == ",":
                for k in range(5):
                    a = rnd.random() * math.tau; rr = rnd.random() * 0.5
                    bpy.ops.mesh.primitive_cone_add(vertices=5, radius1=0.035, radius2=0.0, depth=0.25 + rnd.random() * 0.2,
                                                    location=c + Vector((math.cos(a) * rr, math.sin(a) * rr, 0.1)))
                    t = bpy.context.object; t.rotation_euler = (rnd.uniform(-0.4, 0.4), rnd.uniform(-0.4, 0.4), 0); t.data.materials.append(grass)
            elif c_ == "T":
                th = 0.6 + rnd.random() * 0.4
                cyl(f"tr_{x}_{y}", c + Vector((0, 0, th / 2)), 0.1, th, trunk, verts=10)
                for k in range(2):
                    blob(f"cn_{x}_{y}_{k}", c + Vector((rnd.uniform(-0.15, 0.15), rnd.uniform(-0.15, 0.15), th + 0.3 + k * 0.25)),
                         (0.62 - k * 0.15,) * 3, leaves[rnd.randrange(3)], noise=0.06, seed=x * 7 + y * 11 + k)
            elif c_ == "R":
                sc = 0.38 + rnd.random() * 0.15
                blob(f"rk_{x}_{y}", c + Vector((0, 0, sc * 0.6)), (sc * 1.3, sc * 1.1, sc), rock, noise=0.12, seed=x * 3 + y)
            elif c_ == "H":
                hh = 0.85 + rnd.random() * 0.3; wm = walls_[rnd.randrange(3)]
                hb = box(f"h_{x}_{y}", c + Vector((0, 0.05, hh / 2)), (S * 0.86, S * 0.8, hh), wm, bevel=0.06)
                bpy.ops.mesh.primitive_cylinder_add(vertices=3, radius=S * 0.52, depth=S * 0.9, location=c + Vector((0, 0.05, hh + 0.22)), rotation=(0, math.radians(90), 0))
                rf = bpy.context.object; rf.scale = (1, 1, 0.75); rf.data.materials.append(roofs[rnd.randrange(4)])
                for wx in (-0.3, 0.3):
                    box(f"win_{x}_{y}_{wx}", c + Vector((wx, -S * 0.4 + 0.03, hh * 0.58)), (0.22, 0.03, 0.26), win if rnd.random() < 0.4 else dark, bevel=0.01)
                if rnd.random() < 0.5: box(f"chim_{x}_{y}", c + Vector((0.35, 0.25, hh + 0.5)), (0.16, 0.16, 0.42), walls_[0], bevel=0.03)
            elif c_ == "i":
                cyl(f"post_{x}_{y}", c + Vector((0, 0.1, 0.6)), 0.05, 1.2, metal)
                B.sphere(f"dlamp_{x}_{y}", c + Vector((0, 0.1, 1.28)), (0.16, 0.16, 0.2), glassOff)
                cyl(f"lcap_{x}_{y}", c + Vector((0, 0.1, 1.5)), 0.17, 0.06, metal)
            elif c_ == "=":
                for k in range(4):
                    box(f"pl_{x}_{y}_{k}", c + Vector((0, (k - 1.5) * S * 0.24, 0.04)), (S * 1.02, S * 0.2, 0.08), wood if k % 2 else woodDark, bevel=0.02)
            elif c_ == "B":
                box(f"stall_{x}_{y}", c + Vector((0, 0.1, 0.38)), (S * 0.95, S * 0.6, 0.76), wood, bevel=0.04)
                for sx in (-1, 1): cyl(f"sp_{x}_{y}_{sx}", c + Vector((sx * 0.62, 0.25, 0.85)), 0.04, 1.0, woodDark, verts=8)
                aw = box(f"aw_{x}_{y}", c + Vector((0, 0.05, 1.4)), (S * 1.05, S * 0.75, 0.08), B.rubber("awning", "#C04A4A", rough=0.6), bevel=0.03)
                aw.rotation_euler = (math.radians(-12), 0, 0)
                for k in range(4): B.sphere(f"fruit_{x}_{y}_{k}", c + Vector((-0.45 + k * 0.3, -0.05, 0.84)), (0.1,) * 3, B.rubber(f"fr{k}", ("#E0A040", "#C05A3A", "#8AB060", "#E8D070")[k], rough=0.5))
            elif c_ == "t":
                t = box(f"tab_{x}_{y}", c + Vector((0, 0.15, 0.55)), (0.85, 0.24, 1.1), tab, bevel=0.12); t.modifiers["bevel"].segments = 4
                for k in range(3): box(f"gl_{x}_{y}_{k}", c + Vector((0, 0.02, 0.8 - k * 0.2)), (0.5 - k * 0.08, 0.02, 0.05), glyph, bevel=0)
            elif c_ in "su":
                for k in range(4):
                    box(f"st_{x}_{y}_{k}", c + Vector((0, (k - 1.5) * S * 0.22, -0.06 - k * 0.12 if c_ == "s" else -0.06 - (3 - k) * 0.12)), (S * 0.9, S * 0.22, 0.1), stone("step", "#6A6676", "#3A3646"), bevel=0.02)
                box(f"arch_{x}_{y}", c + Vector((0, S * 0.45, 1.25)), (S * 1.0, 0.3, 0.25), stone("archS", "#8A8494", "#5A5664"), bevel=0.06)
                for sx in (-1, 1): cyl(f"jamb_{x}_{y}_{sx}", c + Vector((sx * 0.62, S * 0.45, 0.6)), 0.14, 1.3, stone("jambS", "#8A8494", "#5A5664"), verts=16)
            elif c_ == "D":
                pale = B.rubber("gate", "#E6D2B0", rough=0.6)
                for sx in (-1, 1): cyl(f"gj_{x}_{y}_{sx}", c + Vector((sx * 0.68, 0.3, 0.8)), 0.16, 1.6, pale, verts=16)
                box(f"gl_{x}_{y}", c + Vector((0, 0.3, 1.65)), (1.7, 0.36, 0.28), pale, bevel=0.08)
            elif c_ == "^":
                lighthouse.append(c)
    land = remesh_join(raised, "land", voxel=0.22)
    if land: land.data.materials.append(vinyl("land", *wallTop))
    if lighthouse:
        base = sum(lighthouse, Vector()) / len(lighthouse)
        tw = B.rubber("tower", "#E8E0D0", rough=0.6); band = B.rubber("band", "#B83A3A", rough=0.6)
        bpy.ops.mesh.primitive_cone_add(vertices=48, radius1=1.2, radius2=0.8, depth=5.0, location=base + Vector((0, 0.4, 2.5)))
        bpy.context.object.data.materials.append(tw)
        for k in range(2): cyl(f"band{k}", base + Vector((0, 0.4, 1.3 + k * 1.6)), 1.1 - k * 0.13, 0.42, band, verts=48)
        cyl("lroom", base + Vector((0, 0.4, 5.35)), 0.72, 0.75, B.mat("lroomM", "#3A3020", rough=0.2, coat=0.6), verts=32)
        bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=0.9, depth=0.7, location=base + Vector((0, 0.4, 6.05))); bpy.context.object.data.materials.append(band)
        box("ldoor", base + Vector((0, -0.75, 0.55)), (0.6, 0.1, 1.1), B.rubber("ldoorM", "#5A3A2A"), bevel=0.05)

def light_world():
    world = bpy.data.worlds.new("night"); bpy.context.scene.world = world; world.use_nodes = True
    bg = world.node_tree.nodes["Background"]; bg.inputs["Color"].default_value = B.hexcol("#1A2040"); bg.inputs["Strength"].default_value = 0.6 if THEME != "cellar" else 0.25
    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(50), math.radians(-20), math.radians(25))); m = bpy.context.object
    m.data.energy = 2.6 if THEME != "cellar" else 1.4; m.data.color = B.hexcol("#A4AEDC")[:3]; m.data.angle = math.radians(3)

def main():
    K = math.sin(math.radians(TILT))
    cw = W + 2 * MX - 2; chh = H * K + 2 * MY * K - 1     # screen cells the frame covers
    w, h = int(cw * PC), int(chh * PC)
    s = B.reset(); s.view_settings.look = "AgX - Punchy"; s.view_settings.exposure = 1.0; s.cycles.samples = arg("--samples", 24)
    s.cycles.max_bounces = 4; s.cycles.diffuse_bounces = 2; s.cycles.glossy_bounces = 2; s.cycles.transmission_bounces = 2
    s.cycles.use_adaptive_sampling = True; s.cycles.adaptive_threshold = 0.03
    s.cycles.use_auto_tile = True; s.cycles.tile_size = 512
    B.materials()
    build(); light_world()
    t = math.radians(TILT); d = 60
    aim = Vector((0, 0, 0.0))
    bpy.ops.object.camera_add(location=aim + Vector((0, -d * math.cos(t), d * math.sin(t)))); c = bpy.context.object
    c.rotation_euler = (math.radians(90) - t, 0, 0); c.data.type = "ORTHO"
    c.data.ortho_scale = max(cw, chh) * S; c.data.clip_end = 300
    s.camera = c
    s.render.resolution_x = w; s.render.resolution_y = h
    s.render.film_transparent = False
    s.render.image_settings.file_format = "JPEG"; s.render.image_settings.quality = 86
    from bpy_extras.object_utils import world_to_camera_view
    bpy.context.view_layer.update()
    corner = cell(0, 0) + Vector((-S / 2, S / 2, 0))
    v = world_to_camera_view(s, s.camera, corner)
    meta = dict(pc=PC, tilt=TILT, w=w, h=h, origin=[round(v.x * w, 2), round((1 - v.y) * h, 2)], cols=W, rows=H)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, f"bg_rpg_{MAP_ID}.jpg")
    B.render(path, w, h)
    json.dump(meta, open(os.path.splitext(path)[0] + ".json", "w"))
    print("wrote", path, w, h, meta["origin"])

main()
