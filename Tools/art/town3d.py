"""The lighthouse town's people in the IP's soft vinyl, shared by the game sprites (sprites3d.py) and the story
pictures (vision3d.py): Hank the old gatekeeper, Dora with her paper lantern, Lynn the net-mender."""
import math
import bpy
import ip3d as B

def townsfolk(body, hat, scarf=None, small=False, who=None, lit=False):
    """A lighthouse-town figure in the same vinyl: a soft capsule, two painted eyes, a hat — and the one thing that says
    who they are: Hank's grey moustache and the gate key on his belt, Dora's paper lantern on a stick, Lynn's net."""
    k = 0.75 if small else 1.0
    mb = B.rubber("tf_body", body); mh = B.rubber("tf_hat", hat)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, location=(0, 0, 0.45 * k)); o = bpy.context.object
    o.scale = (0.36 * k, 0.32 * k, 0.48 * k); o.data.materials.append(mb); B.smooth(o, 1)
    for s in (-1, 1):
        B.sphere(f"tf_eye{s}", (s * 0.1 * k, -0.29 * k, 0.6 * k), (0.035 * k, 0.02, 0.045 * k), B.M["pupil"])
        B.sphere(f"tf_foot{s}", (s * 0.14 * k, -0.06, 0.04), (0.07 * k, 0.09 * k, 0.045), B.M["foot"])
    B.sphere("tf_hat", (0, 0, 0.9 * k), (0.3 * k, 0.28 * k, 0.12 * k), mh)
    if scarf:
        bpy.ops.mesh.primitive_torus_add(major_radius=0.3 * k, minor_radius=0.06 * k, location=(0, 0, 0.42 * k)); t = bpy.context.object
        t.data.materials.append(B.rubber("tf_scarf", scarf))
    if who == "hank":
        grey = B.rubber("tf_grey", "#D8D4CC", rough=0.6)
        for sd in (-1, 1):
            B.sphere(f"tf_stache{sd}", (sd * 0.075, -0.33, 0.5), (0.085, 0.04, 0.035), grey)
        # a cap's brim, and the town-gate key hanging at his belt
        B.sphere("tf_brim", (0, -0.18, 0.86), (0.26, 0.16, 0.035), B.rubber("tf_brimM", "#2A2A32"))
        gold = B.mat("tf_key", "#D8A22A", rough=0.3, coat=0.4)
        bpy.ops.mesh.primitive_torus_add(major_radius=0.06, minor_radius=0.015, location=(0.2, -0.28, 0.3), rotation=(math.radians(90), 0, 0))
        bpy.context.object.data.materials.append(gold)
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.016, depth=0.16, location=(0.2, -0.29, 0.19)); bpy.context.object.data.materials.append(gold)
        B.sphere("tf_bit", (0.235, -0.29, 0.13), (0.035, 0.015, 0.02), gold)
    if who == "dora":
        # a paper lantern on a little stick, held out to her side
        stick = B.rubber("tf_stick", "#8A5A3A", rough=0.6)
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.014, depth=0.42, location=(0.3 * k + 0.05, -0.12, 0.62 * k + 0.12), rotation=(0, math.radians(-30), 0))
        bpy.context.object.data.materials.append(stick)
        paper = B.mat("tf_paperLit", "#FFC870", emit="#FFB050", emit_strength=9) if lit else B.mat("tf_paper", "#D8C8A8", rough=0.7)
        lx, lz = 0.3 * k + 0.17, 0.62 * k + 0.12
        B.sphere("tf_lantern", (lx + 0.03, -0.12, lz - 0.12), (0.14, 0.14, 0.17), paper)
        cap = B.rubber("tf_cap", "#B03A2A")
        B.sphere("tf_capT", (lx + 0.03, -0.12, lz + 0.05), (0.08, 0.065, 0.025), cap)
        B.sphere("tf_capB", (lx + 0.03, -0.12, lz - 0.29), (0.08, 0.065, 0.025), cap)
        B.sphere("tf_hand", (0.3 * k - 0.02, -0.16, 0.5 * k), (0.06, 0.05, 0.05), B.rubber("tf_handM", body))
    if who == "lynn":
        # a bundle of net over her arm: a soft knot of cord with the mesh pressed in, a cork float
        net = B.rubber("tf_net", "#5E7A6A", rough=0.75)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, location=(-0.33, -0.12, 0.36)); o = bpy.context.object
        o.scale = (0.19, 0.16, 0.2); o.data.materials.append(net); B.smooth(o, 1)
        for i in range(3):
            bpy.ops.mesh.primitive_torus_add(major_radius=0.13, minor_radius=0.008, location=(-0.33, -0.12, 0.28 + i * 0.07), rotation=(0, math.radians(90), 0))
            bpy.context.object.scale = (1, 0.95, 1.1); bpy.context.object.data.materials.append(B.rubber("tf_cord", "#2E4236"))
        B.sphere("tf_cork", (-0.36, -0.24, 0.24), (0.05, 0.04, 0.035), B.rubber("tf_corkM", "#E0A040"))

def house(name, at, w=0.7, h=0.6, wall="#D8CCB4", roof="#8A4A3A", window=None):
    """A soft little house: a rounded block, a pillowy roof, and (optionally) a lit window."""
    x, y, z = at
    bpy.ops.mesh.primitive_cube_add(location=(x, y, z + h / 2)); o = bpy.context.object
    o.scale = (w / 2, w / 2, h / 2); o.data.materials.append(B.rubber(name + "W", wall))
    m = o.modifiers.new("bev", "BEVEL"); m.width = 0.08; m.segments = 4
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=w * 0.78, depth=h * 0.6, location=(x, y, z + h + h * 0.28), rotation=(0, 0, math.radians(45)))
    r = bpy.context.object; r.data.materials.append(B.rubber(name + "R", roof))
    m = r.modifiers.new("bev", "BEVEL"); m.width = 0.06; m.segments = 4
    if window:
        B.sphere(name + "win", (x, y - w / 2 - 0.005, z + h * 0.55), (0.1, 0.02, 0.12), B.mat(name + "G", window, emit=window, emit_strength=6))
