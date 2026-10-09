class_name CharacterFinish
## Shared materials for character surfaces. Colour comes from vertex colours,
## so one material per finish serves every character in the game.

const SHADER := preload("res://core/visual/character.gdshader")

## roughness, metallic, specular, rim, rim_tint, detail_scale, bump (metres), mottle
const FINISHES := {
	"velvet": [0.82, 0.0, 0.3, 0.6, 0.3, 9.0, 0.0005, 0.12],
	"fur": [1.0, 0.0, 0.2, 0.8, 0.6, 24.0, 0.003, 0.18],
	"hair": [0.45, 0.0, 0.55, 0.5, 0.6, 30.0, 0.0, 0.1],
	"skin": [0.5, 0.0, 0.4, 0.3, 0.85, 40.0, 0.00006, 0.1],
	"leather": [0.3, 0.0, 0.5, 0.15, 0.3, 7.0, 0.0006, 0.2],
	"metal": [0.25, 1.0, 0.5, 0.0, 0.0, 10.0, 0.0, 0.0],
	"eye": [0.05, 0.0, 0.7, 0.0, 0.0, 10.0, 0.0, 0.0],
}

static var _cache := {}
static var _noise: Texture2D


static func material(finish: String) -> ShaderMaterial:
	if not _cache.has(finish):
		var v: Array = FINISHES[finish]
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("noise_tex", noise())
		mat.set_shader_parameter("roughness", v[0])
		mat.set_shader_parameter("metallic", v[1])
		mat.set_shader_parameter("specular", v[2])
		mat.set_shader_parameter("rim", v[3])
		mat.set_shader_parameter("rim_tint", v[4])
		mat.set_shader_parameter("detail_scale", v[5])
		mat.set_shader_parameter("bump", v[6])
		mat.set_shader_parameter("mottle", v[7])
		_cache[finish] = mat
	return _cache[finish]


## A small tileable noise texture, generated once at startup (no download).
static func noise() -> Texture2D:
	if _noise == null:
		var gen := FastNoiseLite.new()
		gen.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		gen.frequency = 1.0 / 6.0
		gen.fractal_octaves = 3
		var image := gen.get_seamless_image(256, 256)
		image.generate_mipmaps()
		_noise = ImageTexture.create_from_image(image)
	return _noise
