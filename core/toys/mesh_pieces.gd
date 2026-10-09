class_name MeshPieces
extends RefCounted
## Collects triangles with normals, UVs and optional colours into one mesh
## surface, for shaders that need texture coordinates (wrapping paper, ribbon,
## log end grain, window glass). ToyBuilder merges shapes without UVs.

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var uvs := PackedVector2Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()


func is_empty() -> bool:
	return verts.is_empty()


func vertex(pos: Vector3, normal: Vector3, uv: Vector2, color := Color.WHITE) -> int:
	verts.append(pos)
	normals.append(normal)
	uvs.append(uv)
	colors.append(color)
	return verts.size() - 1


## Corners a, b, c, d in order round the quad.
func quad(a: int, b: int, c: int, d: int) -> void:
	tri(a, b, c)
	tri(a, c, d)


## Wound so the triangle faces along its vertex normals.
func tri(i0: int, i1: int, i2: int) -> void:
	var face := (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0])
	var facing := face.dot(normals[i0] + normals[i1] + normals[i2])
	if facing * ToyBuilder._engine_front_sign() < 0.0:
		indices.append_array([i0, i2, i1])
	else:
		indices.append_array([i0, i1, i2])


## A flat rectangle facing `normal`, `up` giving its vertical. UVs run 0 to 1
## left to right and bottom to top.
func rect(centre: Vector3, normal: Vector3, up: Vector3, size: Vector2, color := Color.WHITE) -> void:
	var right := up.cross(normal).normalized() * size.x / 2.0
	var top := up.normalized() * size.y / 2.0
	var a := vertex(centre - right - top, normal, Vector2(0, 0), color)
	var b := vertex(centre + right - top, normal, Vector2(1, 0), color)
	var c := vertex(centre + right + top, normal, Vector2(1, 1), color)
	var d := vertex(centre - right + top, normal, Vector2(0, 1), color)
	quad(a, b, c, d)


## A flat disc facing `normal`. UVs are the position on the disc from -1 to 1,
## with +v towards `up`.
func disc(centre: Vector3, normal: Vector3, up: Vector3, radius: float, color := Color.WHITE, segments := 16) -> void:
	var right := up.cross(normal).normalized()
	var top := normal.cross(right).normalized()
	var middle := vertex(centre, normal, Vector2.ZERO, color)
	var first := verts.size()
	for i in segments:
		var a := TAU * i / segments
		var on := Vector2(cos(a), sin(a))
		vertex(centre + (right * on.x + top * on.y) * radius, normal, on, color)
	for i in segments:
		tri(middle, first + i, first + (i + 1) % segments)


func add_to(mesh: ArrayMesh, material: Material) -> void:
	if verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)
