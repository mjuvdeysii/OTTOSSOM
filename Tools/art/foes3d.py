"""The first region's foes and the chests, in the same soft vinyl: the shadows Mosto stirred up when he took the fire.

  shade     a cold lost shadow: a soft black drop with two pale eyes
  shell     a shade hiding under a cracked stone shell
  moth      a dark moth with pale eye-spots on its wings, a fat furry body
  fang      a spikier shade, a jagged grin with two white fangs, ember eyes
  bigshade  a big lumpy shade with a ring of small eyes
  maw       the lamp-swallower: a great round shadow with a wide mouth and the stolen light glowing in its belly
"""
import math, random
import bpy
import ip3d as B

def _body(name, loc, scale, mat, sub=2, noise=0.0, seed=0):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, location=loc); o = bpy.context.object
    o.name = name; o.scale = scale
    if noise:
        r = random.Random(seed)
        for v in o.data.vertices: v.co *= 1 + noise * (r.random() - 0.5)
    o.data.materials.append(mat); B.smooth(o, sub)
    return o

def _eyes(z, y, dx, size, mat, n=2):
    for i in range(n):
        s = -1 if i == 0 else 1
        B.sphere(f"fe{i}", (s * dx, y, z), size, mat)

def shade():
    body = B.mat("shadeBody", "#07080E", rough=0.85)
    _body("shade", (0, 0, 0.42), (0.44, 0.38, 0.5), body)
    _eyes(0.58, -0.35, 0.13, (0.055, 0.02, 0.04), B.mat("seye", "#CFD6FF", emit="#CFD6FF", emit_strength=2.5))

def shell():
    body = B.mat("shellBody", "#08090F", rough=0.85)
    _body("shellshade", (0, 0.02, 0.36), (0.42, 0.36, 0.42), body)
    stone = B.rubber("shellStone", "#7A7488", rough=0.75)
    crack = B.mat("shellCrack", "#2A2632", rough=0.9)
    # a domed stone shell over the back and head, cracked across
    sh = _body("shellcap", (0, 0.06, 0.55), (0.52, 0.46, 0.36), stone, noise=0.08, seed=4)
    bpy.ops.mesh.primitive_cube_add(location=(0, -0.2, 0.0)); cut = bpy.context.object; cut.scale = (0.8, 0.5, 0.36)
    m = sh.modifiers.new("cut", "BOOLEAN"); m.object = cut; m.operation = "DIFFERENCE"
    bpy.context.view_layer.objects.active = sh; bpy.ops.object.modifier_apply(modifier="cut"); bpy.data.objects.remove(cut)
    for i, (x, z, rz) in enumerate([(-0.1, 0.78, 20), (0.15, 0.7, -35), (0.0, 0.62, 70)]):
        bpy.ops.mesh.primitive_cube_add(location=(x, -0.2, z), rotation=(0.3, 0, math.radians(rz))); c = bpy.context.object
        c.scale = (0.14, 0.012, 0.012); c.data.materials.append(crack)
    _eyes(0.42, -0.34, 0.12, (0.05, 0.02, 0.036), B.mat("seye2", "#CFD6FF", emit="#CFD6FF", emit_strength=2.5))

def moth():
    fur = B.rubber("mothFur", "#2A2236", rough=0.85)
    wing = B.mat("mothWing", "#1A1626", rough=0.6, sheen=0.4)
    spot = B.mat("mothSpot", "#E8E2FF", emit="#BFB4FF", emit_strength=1.6)
    _body("mothBody", (0, 0, 0.62), (0.2, 0.18, 0.3), fur)
    _body("mothHead", (0, -0.14, 0.88), (0.17, 0.15, 0.14), fur)
    for s in (-1, 1):
        for k, (sz, z) in enumerate([((0.42, 0.04, 0.34), 0.86), ((0.3, 0.04, 0.24), 0.46)]):
            bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, location=(s * (0.36 + 0.02 * k), 0.06, z)); wo = bpy.context.object
            wo.scale = sz; wo.rotation_euler = (0, math.radians(-s * (20 + 15 * k)), math.radians(s * 10)); wo.data.materials.append(wing); B.smooth(wo, 1)
            B.sphere(f"spot{s}{k}", (s * (0.42 + 0.02 * k), -0.0, z + 0.02), (0.09 - 0.03 * k, 0.03, 0.09 - 0.03 * k), spot)
        B.tube(f"ant{s}", [(s * 0.05, -0.2, 0.98), (s * 0.12, -0.25, 1.12), (s * 0.2, -0.22, 1.2)], 0.012, fur)
    _eyes(0.9, -0.27, 0.07, (0.04, 0.02, 0.04), B.mat("meye", "#FFE2A0", emit="#FFD27A", emit_strength=3))

def fang():
    body = B.mat("fangBody", "#0A0608", rough=0.8)
    _body("fang", (0, 0, 0.44), (0.46, 0.4, 0.52), body, noise=0.05, seed=7)
    spike = B.mat("fangSpike", "#14080C", rough=0.7)
    for i in range(7):
        a = -0.9 + i * 0.3
        bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.08, depth=0.3, location=(math.sin(a) * 0.32, 0.1, 0.78 + math.cos(a) * 0.12),
                                        rotation=(0.2, math.sin(a) * 0.8, 0)); bpy.context.object.data.materials.append(spike)
    _eyes(0.6, -0.37, 0.14, (0.06, 0.02, 0.03), B.mat("feye", "#FF8A3A", emit="#FF6A20", emit_strength=4))
    mouth = B.mat("fangMouth", "#3A0A12", rough=0.6)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, location=(0, -0.36, 0.38)); mo = bpy.context.object
    mo.scale = (0.2, 0.05, 0.06); mo.data.materials.append(mouth)
    tooth = B.rubber("tooth", "#F4F0E8", rough=0.4)
    for s in (-1, 1):
        bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.035, depth=0.11, location=(s * 0.08, -0.39, 0.34), rotation=(math.radians(180), 0, 0))
        bpy.context.object.data.materials.append(tooth)

def bigshade():
    body = B.mat("bigBody", "#06070C", rough=0.85)
    _body("big", (0, 0, 0.62), (0.72, 0.6, 0.72), body, noise=0.04, seed=11)
    for s in (-1, 1):
        _body(f"arm{s}", (s * 0.66, -0.05, 0.42), (0.22, 0.2, 0.3), body, noise=0.03, seed=12 + s)
    eye = B.mat("beye", "#CFD6FF", emit="#CFD6FF", emit_strength=3)
    for i, (x, z, r) in enumerate([(-0.22, 0.86, 0.07), (0.22, 0.86, 0.07), (0.0, 1.02, 0.05), (-0.42, 0.7, 0.04), (0.42, 0.7, 0.04)]):
        B.sphere(f"be{i}", (x, -0.58 + abs(x) * 0.25, z), (r, 0.02, r * 0.8), eye)

def maw():
    body = B.mat("mawBody", "#05060A", rough=0.85)
    _body("maw", (0, 0, 0.78), (0.86, 0.72, 0.82), body, noise=0.03, seed=21)
    # the stolen light, glowing inside its belly through a thin skin
    belly = B.mat("mawBelly", "#FFB860", emit="#FFA040", emit_strength=3.5)
    B.sphere("belly", (0, -0.62, 0.58), (0.36, 0.14, 0.3), belly)
    skin = B.mat("mawSkin", "#120A10", rough=0.5)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.38, minor_radius=0.05, location=(0, -0.7, 0.58), rotation=(math.radians(90), 0, 0))
    bpy.context.object.scale = (1, 0.8, 1); bpy.context.object.data.materials.append(skin)
    mouth = B.mat("mawMouth", "#2A0810", rough=0.6)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, location=(0, -0.66, 1.06)); mo = bpy.context.object
    mo.scale = (0.4, 0.06, 0.1); mo.data.materials.append(mouth)
    tooth = B.rubber("mtooth", "#F4F0E8", rough=0.4)
    for i in range(6):
        x = -0.3 + i * 0.12
        bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=0.04, depth=0.1, location=(x, -0.7, 1.12), rotation=(math.radians(180), 0, 0))
        bpy.context.object.data.materials.append(tooth)
    eye = B.mat("meye2", "#FFE2A0", emit="#FFD27A", emit_strength=3)
    for s in (-1, 1):
        B.sphere(f"me{s}", (s * 0.3, -0.62, 1.32), (0.08, 0.02, 0.06), eye)
    for s in (-1, 1):
        bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=0.12, depth=0.36, location=(s * 0.48, 0.0, 1.5), rotation=(0, math.radians(s * 25), 0))
        bpy.context.object.data.materials.append(body)

def chest(open_=False):
    wood = B.rubber("chestWood", "#8A5A32", rough=0.6)
    band = B.mat("chestBand", "#C9963E", rough=0.35, coat=0.3)
    bpy.ops.mesh.primitive_cube_add(location=(0, 0, 0.22)); b = bpy.context.object; b.scale = (0.36, 0.26, 0.2)
    b.data.materials.append(wood); m = b.modifiers.new("bev", "BEVEL"); m.width = 0.05; m.segments = 4
    if open_:
        bpy.ops.mesh.primitive_cube_add(location=(0, 0.3, 0.6), rotation=(math.radians(-70), 0, 0)); l = bpy.context.object
        glow = B.mat("chestGlow", "#FFD27A", emit="#FFD27A", emit_strength=2)
        bpy.ops.mesh.primitive_cube_add(location=(0, 0, 0.41)); gl = bpy.context.object; gl.scale = (0.32, 0.22, 0.01); gl.data.materials.append(B.mat("chestIn", "#2A1A10", rough=0.9))
    else:
        bpy.ops.mesh.primitive_cube_add(location=(0, 0, 0.47)); l = bpy.context.object
    l.scale = (0.37, 0.27, 0.07); l.data.materials.append(wood); m = l.modifiers.new("bev", "BEVEL"); m.width = 0.05; m.segments = 4
    for x in (-0.22, 0.22):
        bpy.ops.mesh.primitive_cube_add(location=(x, -0.005, 0.3)); s = bpy.context.object; s.scale = (0.035, 0.27, 0.24); s.data.materials.append(band)
    B.sphere("lock", (0, -0.27, 0.36), (0.05, 0.02, 0.06), band)
