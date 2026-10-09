class_name PbrLibrary
## Realistic PBR materials built from the texture sets in assets/textures.
## World-space triplanar mapping, so generated meshes need no UVs and
## textures keep a consistent real-world scale across every prop.

const ROOT := "res://assets/textures/"

static var _cache := {}


## `tile_size` is how many metres one copy of the texture covers.
static func material(texture_set: String, tile_size := 1.0, tint := Color.WHITE) -> StandardMaterial3D:
	var key := "%s|%.3f|%s" % [texture_set, tile_size, tint.to_html()]
	if _cache.has(key):
		return _cache[key]
	var dir := ROOT + texture_set + "/"
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(dir + "albedo.jpg")
	mat.albedo_color = tint
	mat.normal_enabled = true
	mat.normal_texture = load(dir + "normal.jpg")
	mat.roughness = 1.0
	mat.roughness_texture = load(dir + "roughness.jpg")
	mat.ao_enabled = true
	mat.ao_texture = load(dir + "ao.jpg")
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_triplanar_sharpness = 4.0
	mat.uv1_scale = Vector3.ONE / tile_size
	_cache[key] = mat
	return mat


## Untextured PBR surface coloured by vertex colours (used for painted parts).
static func painted(roughness := 0.7) -> StandardMaterial3D:
	var key := "painted|%.2f" % roughness
	if not _cache.has(key):
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = roughness
		_cache[key] = mat
	return _cache[key]
