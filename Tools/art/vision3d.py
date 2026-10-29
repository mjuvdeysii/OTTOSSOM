"""The game's wordless story pictures: memories Moss reads from stones, and the moments between rooms. Same soft-vinyl
figures as the game (ip3d.py, kb/mosto3d.py), staged with a perspective camera. Memories come out warm sepia, like
something remembered; story moments keep their colour.

  python3 Tools/art/vision3d.py NAME OUT.jpg [--w 900 --h 1950 --samples 64]
  names: prologue thief sun town lamp shadow dark dawn
"""
import math, os, random, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy
import ip3d as B
sys.path.insert(0, os.path.join(HERE, "kb"))
import mosto3d as MO
from mathutils import Vector

ARGS = sys.argv[1:]
NAME, OUT = ARGS[0], os.path.abspath(ARGS[1])
def arg(name, default):
    return type(default)(ARGS[ARGS.index(name) + 1]) if name in ARGS else default
rnd = random.Random(5)
MEMORY = {"thief", "sun", "town", "lamp"}

def emit(name, color, strength):
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    o = nt.nodes.new("ShaderNodeOutputMaterial"); e = nt.nodes.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = B.hexcol(color); e.inputs["Strength"].default_value = strength
    nt.links.new(e.outputs[0], o.inputs["Surface"]); return m

def light(kind, loc, energy, color, size=1.0, rot=(0, 0, 0)):
    bpy.ops.object.light_add(type=kind, location=loc, rotation=rot); l = bpy.context.object
    l.data.energy = energy; l.data.color = B.hexcol(color)[:3]
    if kind == "AREA": l.data.size = size
    elif kind in ("POINT", "SPOT"): l.data.shadow_soft_size = size
    return l

def world(color, strength):
    w = bpy.data.worlds.new("w"); bpy.context.scene.world = w; w.use_nodes = True
    bg = w.node_tree.nodes["Background"]; bg.inputs["Color"].default_value = B.hexcol(color); bg.inputs["Strength"].default_value = strength

def camera(loc, aim, lens=50, fstop=None):
    bpy.ops.object.camera_add(location=loc); c = bpy.context.object
    d = Vector(aim) - Vector(loc); c.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    c.data.lens = lens; c.data.clip_end = 500
    if fstop:
        c.data.dof.use_dof = True; c.data.dof.focus_distance = d.length; c.data.dof.aperture_fstop = fstop
    bpy.context.scene.camera = c

def ground(color, size=200):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, 0)); g = bpy.context.object
    g.data.materials.append(B.rubber("ground", color, rough=0.7))
    return g

def place(build, at, turn=0.0, scale=1.0, mirror=False, **kw):
    before = set(bpy.data.objects)
    build(**kw)
    bpy.ops.object.empty_add(location=(0, 0, 0)); pivot = bpy.context.object
    for o in set(bpy.data.objects) - before:
        if o is not pivot and o.parent is None and o.type != "CAMERA": o.parent = pivot
    pivot.rotation_euler = (0, 0, math.radians(turn)); pivot.location = at; pivot.scale = (-scale if mirror else scale, scale, scale)
    return pivot

def flame_mat(name, root, mid, tip, strength):
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    o = nt.nodes.new("ShaderNodeOutputMaterial"); e = nt.nodes.new("ShaderNodeEmission")
    tc = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB"); cr = ramp.color_ramp
    cr.elements[0].position = 0.25; cr.elements[0].color = B.hexcol(root)
    cr.elements[1].position = 0.92; cr.elements[1].color = B.hexcol(tip)
    cr.elements.new(0.55).color = B.hexcol(mid)
    nt.links.new(tc.outputs["Generated"], sep.inputs[0]); nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], e.inputs["Color"]); e.inputs["Strength"].default_value = strength
    nt.links.new(e.outputs[0], o.inputs["Surface"]); return m

def tear(at, rr, hh, mat, lean=(0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=24, location=at); o = bpy.context.object
    for v in o.data.vertices:
        z = v.co.z; k = (z + 1) / 2
        sq = ((1 - k) / 0.7) ** 0.55 if k > 0.3 else 1.0
        v.co.x *= sq; v.co.y *= sq; v.co.z = z if z < 0 else z * 1.9
        v.co.x += lean[0] * k * k * 2; v.co.y += lean[1] * k * k * 2
    o.scale = (rr, rr, hh / 3.4); o.data.materials.append(mat)
    for p in o.data.polygons: p.use_smooth = True
    return o

def fire(at, sc=1.0, energy=120):
    at = Vector(at)
    B.sphere("core", at + Vector((0, -0.06 * sc, -0.02 * sc)), (0.06 * sc,) * 3, emit("core", "#FFF8E0", 12))
    tear(at + Vector((0, -0.03 * sc, -0.02 * sc)), 0.1 * sc, 0.36 * sc, flame_mat("fi", "#FFE680", "#FFB820", "#FF8A10", 1.6))
    tear(at + Vector((0, 0, -0.05 * sc)), 0.17 * sc, 0.62 * sc, flame_mat("fo", "#FFA010", "#FF5A00", "#D02000", 1.3), (0.04, 0))
    for j, dx in enumerate((-0.09, 0.1)):
        tear(at + Vector((dx * sc, 0.02, -0.04 * sc)), 0.07 * sc, 0.32 * sc, flame_mat(f"fs{j}", "#FF9000", "#F04800", "#C01800", 1.2), (dx * 0.6, 0))
    light("POINT", at + Vector((0, -0.2 * sc, 0.2 * sc)), energy * sc, "#FF9A3A", 0.15 * sc)

def embers(at, n, spread, color="#FF9A3A"):
    m = emit("ember", color, 6)
    for i in range(n):
        p = Vector(at) + Vector((rnd.uniform(-spread, spread), rnd.uniform(-spread * 0.5, spread * 0.5), rnd.uniform(0, spread * 1.5)))
        B.sphere(f"emb{i}", p, (0.025 + rnd.random() * 0.02,) * 3, m, seg=8)

def tired_sun(at, r, awake=False, glow=1.0):
    """The sun: a vast soft dome, tired like Otto — heavy lid, bags under the eye."""
    body = B.rubber("sunbody", "#E07A2A", rough=0.55)
    p = body.node_tree.nodes["Principled BSDF"]
    p.inputs["Emission Color"].default_value = B.hexcol("#FF9A40"); p.inputs["Emission Strength"].default_value = 0.6 * glow
    B.sphere("sun", at, (r, r * 0.85, r), body, seg=96)
    face = Vector(at) + Vector((0, -r * 0.84, r * 0.35))
    ink = B.mat("sunInk", "#4A1E0A", rough=0.5)
    if awake:
        B.eye("sun_eye", tuple(face + Vector((0, -0.02, 0.1 * r))), r * 0.2, (0, -0.1), scale=(1.1, 0.4, 0.9), lid=0.62, skin=body, pupil=0.55)
    else:
        # asleep: one soft closed curve, three short lashes, one tired fold under it — read even when tiny
        B.tube("sun_lid", [tuple(face + Vector((x * r * 0.24, -0.01, x * x * r * 0.07))) for x in (-1, -0.6, -0.2, 0.2, 0.6, 1)], r * 0.026, ink)
        for k in (-0.55, 0.0, 0.55):
            st = face + Vector((k * r * 0.24, -0.02, (k * k) * r * 0.07 - r * 0.01))
            B.tube(f"lash{k}", [tuple(st), tuple(st + Vector((k * r * 0.05, -0.02, -r * 0.08)))], r * 0.016, ink)
    bag = B.mat("sunBag", "#B85A20", rough=0.6)
    B.tube("bag", [tuple(face + Vector((x * r * 0.13, -0.015, -0.13 * r + (x * x) * r * 0.035))) for x in (-1, -0.5, 0, 0.5, 1)], r * 0.013, bag)
    light("POINT", Vector(at) + Vector((0, -r * 1.3, r * 0.6)), 1400 * glow * (r / 3) ** 2, "#FF9A50", r * 0.4)

def finish(path, w, h):
    s = bpy.context.scene
    s.render.film_transparent = False
    s.render.image_settings.file_format = "JPEG"; s.render.image_settings.quality = 88
    B.render(path, w, h)
    if NAME in MEMORY:   # a memory: warm sepia, the edges fading
        from PIL import Image, ImageOps, ImageFilter
        im = Image.open(path).convert("RGB")
        g = ImageOps.grayscale(im)
        sep = ImageOps.colorize(g, black="#1E140C", mid="#8A6440", white="#F6E2B8")
        im = Image.blend(im, sep, 0.82)
        im.save(path, quality=88)

def main():
    w, h = arg("--w", 900), arg("--h", 1950)
    s = B.reset(); s.cycles.samples = arg("--samples", 64); s.view_settings.look = "AgX - Punchy"
    s.cycles.max_bounces = 4
    B.materials(); MO.mosto_materials()
    n = NAME
    if n == "prologue":
        # the sun's nest, the last of the night before dawn: the sun asleep, its fire on the rim; Mosto reaching for it
        world("#140E24", 0.5); ground("#5A3A2A")
        tired_sun((0, 7, -1.2), 4.0, glow=0.7)
        fire((0.2, 3.1, 0.75), 1.6)
        place(MO.build_mosto, (-0.35, 2.4, 0.0), turn=-35, scale=1.15, moss_eye=dict(look=(0.8, 0.5), lid=0.3), otto_eye=dict(look=(0.8, 0.5), lid=0.38), evil=0.9, perk=1.0)
        light("AREA", (-4, -4, 6), 300, "#8A9AE8", 6, rot=(math.radians(45), 0, math.radians(-40)))
        camera((1.2, -3.8, 1.6), (0, 3.0, 1.4), lens=40, fstop=2.8)
    elif n == "thief":
        world("#1A1410", 0.4); ground("#6A5A48")
        place(MO.build_mosto, (0, 0, 0.25), turn=70, scale=1.0, moss_eye=dict(look=(-0.9, 0.1), lid=0.2), otto_eye=dict(look=(-0.9, 0.1), lid=0.3), evil=0.8, perk=1.0)
        fire((-0.5, -0.1, 0.75), 1.3)
        embers((1.2, 0, 0.5), 22, 1.4)
        light("AREA", (-3, -4, 4), 260, "#E8D8C0", 5, rot=(math.radians(50), 0, math.radians(-35)))
        camera((0.4, -4.2, 1.2), (0.1, 0, 0.7), lens=55, fstop=3.2)
    elif n == "sun":
        world("#2A1A10", 0.6); ground("#8A6A48")
        tired_sun((0, 4, -0.5), 2.6, awake=True, glow=1.2)
        for i in range(6):
            bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.25, depth=0.8, location=(-3 + i * 1.2, -0.5 + (i % 2) * 0.4, 0.4))
            bpy.context.object.data.materials.append(B.rubber("roof", "#8A4A3A"))
        camera((0, -6, 1.2), (0, 3, 2.0), lens=40)
    elif n == "town":
        world("#2A1E14", 0.5); ground("#7A6A58")
        lamp = B.mat("lampLit", "#FFD27A", emit="#FFD27A", emit_strength=10)
        wallm = B.rubber("hw", "#D8CCB4"); roofm = B.rubber("roof", "#8A3A3A")
        for i in range(7):
            x = -4 + i * 1.4; y = 1.5 + (i % 3) * 0.8
            bpy.ops.mesh.primitive_cube_add(location=(x, y, 0.5)); o = bpy.context.object; o.scale = (0.5, 0.5, 0.5); o.data.materials.append(wallm)
            bpy.ops.mesh.primitive_cylinder_add(vertices=3, radius=0.6, depth=1.05, location=(x, y, 1.25), rotation=(0, math.radians(90), 0))
            bpy.context.object.scale = (1, 1, 0.7); bpy.context.object.data.materials.append(roofm)
            B.sphere(f"lamp{i}", (x + 0.7, y - 0.6, 1.2), (0.12, 0.12, 0.15), lamp)
            light("POINT", (x + 0.7, y - 0.7, 1.2), 30, "#FFC46A", 0.1)
        tired_sun((0, 14, 0.5), 4.0, awake=True, glow=0.9)
        place(B.build_otto, (0.3, 0, 0), turn=-10, glow=1.0, lid=0.5, look=(0, 0.3), slouch=0.8, droop=0.6, bags=True)
        camera((0.5, -5.5, 1.4), (0, 2, 1.6), lens=40, fstop=4)
    elif n == "lamp":
        world("#16121E", 0.4); ground("#5A5048")
        lampm = B.mat("main", "#FFE0A0", emit="#FFD27A", emit_strength=14)
        bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.12, depth=2.4, location=(0.6, 0.6, 1.2)); bpy.context.object.data.materials.append(B.rubber("post", "#3A3A44"))
        B.sphere("mainlamp", (0.6, 0.6, 2.6), (0.42, 0.42, 0.5), lampm)
        light("POINT", (0.6, 0.3, 2.6), 300, "#FFC46A", 0.3)
        tired_sun((-3, 12, 1.5), 3.0, awake=False, glow=0.5)
        place(B.build_otto, (-0.5, 0.1, 0), turn=25, glow=1.0, lid=0.62, look=(0.6, 0.6), slouch=1.0, droop=0.8, bags=True)
        camera((-0.6, -4.2, 1.3), (0.1, 0.5, 1.4), lens=45, fstop=3)
    elif n == "shadow":
        # by Otto's bulb, Moss's shadow falls long across the ground — and on its head, a crooked crown
        world("#0E1020", 0.3); ground("#4A4A58")
        place(B.build_moss, (0, 0, 0), turn=-15, look=(0.3, -0.2), lid=0.1, er=0.12, pupil=0.6, perk=0.8)
        place(B.build_otto, (-1.9, -1.4, 0), turn=-40, glow=1.0, lid=0.5, look=(0.7, -0.2), slouch=0.8, droop=0.6, bags=True)
        light("SPOT", (-1.4, -1.2, 1.0), 900, "#FFC46A", 0.05, rot=(math.radians(78), 0, math.radians(-128)))
        # the crown, standing just behind Moss so its shadow lands on the head of Moss's shadow
        crown = B.mat("crownSh", "#000000")
        pts = [(-0.12, 0), (-0.12, 0.11), (-0.06, 0.05), (0, 0.13), (0.06, 0.05), (0.12, 0.11), (0.12, 0)]
        me = bpy.data.meshes.new("cr"); me.from_pydata([(x, 0, z) for x, z in pts], [], [tuple(range(len(pts)))])
        cr = bpy.data.objects.new("crown_caster", me); bpy.context.collection.objects.link(cr)
        cr.location = (0.1, 0.25, 1.0); cr.rotation_euler = (0, math.radians(18), math.radians(-40)); cr.scale = (2.4, 2.4, 2.4)
        cr.visible_camera = False; cr.data.materials.append(crown)
        camera((0.9, -3.0, 2.3), (0.9, 1.4, 0.0), lens=35)
    elif n == "dark":
        world("#05060C", 0.15); ground("#2A2A34")
        tired_sun((0, 9, -2.5), 4.5, awake=False, glow=0.0)
        place(MO.build_mosto, (1.6, 3.0, 2.2), turn=-60, scale=0.6, moss_eye=dict(look=(0.9, 0.3), lid=0.3), otto_eye=dict(look=(0.9, 0.3), lid=0.4), evil=1.0)
        fire((1.35, 2.8, 2.6), 0.8, energy=60)
        embers((0.4, 3.2, 1.6), 18, 1.0)
        camera((-0.5, -4.0, 1.0), (0.4, 4, 1.8), lens=35)
    elif n == "icon":
        # the app icon, a silent story in one frame. Mosto is the star: front and centre, whole face in view, holding
        # up the fire he took, grinning. A trail of sparks leads back to the sun asleep behind him. Moss leans in from
        # the left to take it back; Otto looms behind, bulb lit over Mosto's head.
        world("#0A1030", 0.4); ground("#2E2438")
        tired_sun((0.0, 5.2, 0.4), 2.8, awake=False, glow=0.5)
        fire_at = Vector((0.82, -0.8, 0.5))
        spark = emit("trail", "#FF9A30", 5)
        for i in range(16):
            t = i / 15
            p = Vector((-0.3 * (1 - t) + fire_at.x * t, 4.2 * (1 - t) + fire_at.y * t, 3.1 * (1 - t) ** 1.6 + fire_at.z * t + 0.8 * math.sin(math.pi * t)))
            B.sphere(f"tr{i}", p, (0.035 * (0.5 + t),) * 3, spark, seg=10)
        place(B.build_otto, (-0.8, 1.3, 0), turn=-15, mirror=True, glow=1.0, lid=0.5, look=(-0.7, -0.45), slouch=0.7, droop=0.5, bags=True)
        bead = bpy.data.objects.get("otto_bead")
        if bead:
            bpy.context.view_layer.update(); bp = bead.matrix_world.translation.copy()
            B.sphere("bead_glow", bp, (0.075,) * 3, emit("beadGlow", "#FFD27A", 18))
            light("POINT", bp + Vector((0.1, -0.15, 0)), 90, "#FFC46A", 0.08)
        light("AREA", (-3.2, -1.2, 2.6), 160, "#9AAAF0", 2, rot=(math.radians(60), 0, math.radians(-70)))
        place(B.build_moss, (-1.15, -0.05, 0), turn=40, scale=0.82, look=(0.95, 0.3), lid=0.0, er=0.13, pupil=0.5, perk=1.0)
        place(MO.build_mosto, (0.12, -0.25, 0), turn=-8, scale=1.18, moss_eye=dict(look=(0.25, 0.0), lid=0.45, pupil=0.5), otto_eye=dict(look=(0.25, 0.0), lid=0.5, pupil=0.5), evil=1.0, perk=1.0)
        fire(fire_at, 1.15, energy=150)
        # Mosto's own light: a soft key from the front so his face and crown read at any size
        light("AREA", (0.6, -3.0, 2.0), 140, "#E8D8FF", 1.5, rot=(math.radians(62), 0, math.radians(8)))
        light("AREA", (-2.5, -4, 4), 150, "#8C9CE8", 4, rot=(math.radians(48), 0, math.radians(-32)))
        light("AREA", (3, 2.2, 3), 200, "#C87AF0", 3, rot=(math.radians(-50), 0, math.radians(140)))
        camera((0.05, -4.5, 1.5), (0.0, 1.0, 1.05), lens=50, fstop=6.3)
    elif n == "dawn":
        world("#3A4A7A", 0.8); ground("#7A6A58")
        tired_sun((0, 16, -2.0), 6.0, awake=True, glow=1.6)
        place(B.build_otto, (-0.7, 0, 0), turn=10, glow=0.0, shut="down", slouch=1.2, droop=1.0, bags=True)
        place(B.build_moss, (0.6, -0.2, 0), turn=-20, look=(-0.4, 0.4), lid=0.0, er=0.12, pupil=0.5, perk=1.0)
        light("SUN", (0, 0, 10), 3.5, "#FFC890", rot=(math.radians(80), 0, math.radians(180)))
        camera((0.4, -4.6, 1.0), (0, 3, 1.3), lens=40, fstop=4)
    finish(OUT, w, h)

main()
