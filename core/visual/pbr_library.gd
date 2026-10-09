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


# --- Snow ----------------------------------------------------------------------

const SNOW_COVER_SHADER := preload("res://core/visual/snow_cover.gdshader")
const SNOW_GROUND_SHADER := preload("res://core/visual/snow_ground.gdshader")
const SNOW_SET := "snow_02"


## Triplanar texture set with snow lying on its upward faces. Mountains can
## add `height_start`/`height_end` so peaks are whiter than their feet.
static func snowy(texture_set: String, tile_size := 1.0, tint := Color.WHITE, snow := 0.5,
		height_start := 10000.0, height_end := 10001.0) -> ShaderMaterial:
	var key := "snowy|%s|%.3f|%s|%.2f|%.1f" % [texture_set, tile_size, tint.to_html(), snow, height_start]
	if _cache.has(key):
		return _cache[key]
	var dir := ROOT + texture_set + "/"
	var mat := _snow_material(snow)
	mat.set_shader_parameter("use_triplanar", true)
	mat.set_shader_parameter("triplanar_tile", tile_size)
	mat.set_shader_parameter("albedo_tex", load(dir + "albedo.jpg"))
	mat.set_shader_parameter("albedo_color", tint)
	mat.set_shader_parameter("normal_tex", load(dir + "normal.jpg"))
	mat.set_shader_parameter("roughness_tex", load(dir + "roughness.jpg"))
	mat.set_shader_parameter("ao_tex", load(dir + "ao.jpg"))
	mat.set_shader_parameter("snow_height_start", height_start)
	mat.set_shader_parameter("snow_height_end", height_end)
	_cache[key] = mat
	return mat


## Sparkling snowfield material for terrain.
static func snow_ground() -> ShaderMaterial:
	if not _cache.has("snow_ground"):
		var dir := ROOT + SNOW_SET + "/"
		var mat := ShaderMaterial.new()
		mat.shader = SNOW_GROUND_SHADER
		mat.set_shader_parameter("snow_albedo", load(dir + "albedo.jpg"))
		mat.set_shader_parameter("snow_normal", load(dir + "normal.jpg"))
		mat.set_shader_parameter("snow_roughness", load(dir + "roughness.jpg"))
		mat.set_shader_parameter("noise_tex", CharacterFinish.noise())
		_cache["snow_ground"] = mat
	return _cache["snow_ground"]


## Loads a model from assets/models and lets snow settle on it.
static func model(model_name: String, snow := 0.45) -> Node3D:
	var scene: PackedScene = load("res://assets/models/%s.glb" % model_name)
	var node: Node3D = scene.instantiate()
	if snow > 0.0:
		cover_with_snow(node, snow)
	return node


## Swaps every opaque material under `root` for a snow-covered version of itself.
static func cover_with_snow(root: Node, snow := 0.45) -> void:
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for s in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(s) as BaseMaterial3D
			if source and source.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
				mesh.set_surface_override_material(s, _snowy_copy(source, snow))


static func _snowy_copy(source: BaseMaterial3D, snow: float) -> ShaderMaterial:
	var key := "copy|%d|%.2f" % [source.get_instance_id(), snow]
	if _cache.has(key):
		return _cache[key]
	var mat := _snow_material(snow)
	mat.set_shader_parameter("albedo_tex", source.albedo_texture)
	mat.set_shader_parameter("albedo_color", source.albedo_color)
	if source.normal_enabled:
		mat.set_shader_parameter("normal_tex", source.normal_texture)
		mat.set_shader_parameter("normal_strength", source.normal_scale)
	mat.set_shader_parameter("roughness", source.roughness)
	if source.roughness_texture:
		mat.set_shader_parameter("roughness_tex", source.roughness_texture)
		mat.set_shader_parameter("roughness_channel", _channel(source.roughness_texture_channel))
	mat.set_shader_parameter("metallic", source.metallic)
	if source.metallic_texture:
		mat.set_shader_parameter("metallic_tex", source.metallic_texture)
		mat.set_shader_parameter("metallic_channel", _channel(source.metallic_texture_channel))
	if source.ao_enabled and source.ao_texture:
		mat.set_shader_parameter("ao_tex", source.ao_texture)
		mat.set_shader_parameter("ao_channel", _channel(source.ao_texture_channel))
	mat.set_shader_parameter("uv_scale", source.uv1_scale)
	_cache[key] = mat
	return mat


static func _snow_material(snow: float) -> ShaderMaterial:
	var dir := ROOT + SNOW_SET + "/"
	var mat := ShaderMaterial.new()
	mat.shader = SNOW_COVER_SHADER
	mat.set_shader_parameter("snow_amount", snow)
	mat.set_shader_parameter("snow_albedo", load(dir + "albedo.jpg"))
	mat.set_shader_parameter("snow_normal", load(dir + "normal.jpg"))
	return mat


static func _channel(channel: BaseMaterial3D.TextureChannel) -> Vector4:
	if channel == BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE:
		return Vector4(1.0, 1.0, 1.0, 0.0) / 3.0
	var v := Vector4.ZERO
	v[channel] = 1.0
	return v
