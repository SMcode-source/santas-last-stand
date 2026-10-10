"""Shrinks a glTF/GLB model to a web-friendly triangle budget and saves it as GLB.

Usage:
    blender --background --factory-startup --python tools/blender/optimize_model.py -- \
        <input.gltf|glb> <output.glb> <target_triangles> [max_texture_px=1024] [base_color_px]
        [--reweight=<from_bone>,<to_bone>,<full_below>,<none_above> ...]

Decimates every mesh by the same ratio (so a multi-part model keeps its balance),
caps texture size and re-encodes textures as JPEG. Base colour textures can keep
a bigger cap than normal and roughness maps. Rigged models keep their skeleton,
skin weights and animations.

--reweight mends an auto-rig that bound too much to one bone: vertices of
<from_bone> keep their weight up to <full_below> metres above the ground, then
hand it over smoothly to <to_bone> by <none_above> (e.g. a foot bone that also
carries the lower shin).
"""
import os
import sys

import bpy


def triangles(obj) -> int:
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def reweight(meshes, spec: str) -> None:
    source, target, full, none = spec.split(",")
    full, none = float(full), float(none)
    moved = 0
    for obj in meshes:
        groups = obj.vertex_groups
        if source not in groups:
            continue
        a, b = groups[source], groups.get(target) or groups.new(name=target)
        for v in obj.data.vertices:
            w = next((g.weight for g in v.groups if g.group == a.index), 0.0)
            if w <= 0.0:
                continue
            z = (obj.matrix_world @ v.co).z
            t = min(1.0, max(0.0, (z - full) / (none - full)))
            give = w * t * t * (3.0 - 2.0 * t)
            if give <= 0.0:
                continue
            a.add([v.index], w - give, "REPLACE")
            b.add([v.index], give, "ADD")
            moved += 1
    print(f"REWEIGHT {source} -> {target}: {moved} vertices")


def main() -> None:
    every = sys.argv[sys.argv.index("--") + 1:]
    args = [a for a in every if not a.startswith("--")]
    fixes = [a.split("=", 1)[1] for a in every if a.startswith("--reweight=")]
    source, target_path, budget = args[0], args[1], int(args[2])
    max_px = int(args[3]) if len(args) > 3 else 1024
    base_px = int(args[4]) if len(args) > 4 else max_px

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=source)

    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for spec in fixes:
        reweight(meshes, spec)
    before = sum(triangles(o) for o in meshes)
    ratio = min(1.0, budget / max(before, 1))
    if ratio < 1.0:
        for obj in meshes:
            mod = obj.modifiers.new("Decimate", "DECIMATE")
            mod.decimate_type = "COLLAPSE"
            mod.ratio = ratio
            mod.use_collapse_triangulate = True
            bpy.context.view_layer.objects.active = obj
            # Decimate the rest pose, before any armature deformation.
            bpy.ops.object.modifier_move_to_index(modifier=mod.name, index=0)
            bpy.ops.object.modifier_apply(modifier=mod.name)
    after = sum(triangles(o) for o in meshes)

    base_colour = set()
    for material in bpy.data.materials:
        if material.node_tree:
            for link in material.node_tree.links:
                if link.to_socket.name == "Base Color" and link.from_node.type == "TEX_IMAGE":
                    base_colour.add(link.from_node.image)
    for image in bpy.data.images:
        w, h = image.size
        cap = base_px if image in base_colour else max_px
        if max(w, h) > cap:
            scale = cap / max(w, h)
            image.scale(int(w * scale), int(h * scale))

    os.makedirs(os.path.dirname(os.path.abspath(target_path)), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=target_path,
        export_format="GLB",
        export_image_format="JPEG",
        export_jpeg_quality=85,
        export_apply=True,
    )
    size = os.path.getsize(target_path) / 1e6
    print(f"OPTIMIZED {os.path.basename(target_path)}: {before} -> {after} triangles, {size:.2f} MB")


main()
