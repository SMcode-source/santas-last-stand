// Realistic PBR surface with snow settled on its upward-facing parts.
// Works for UV-mapped models (scanned rocks, logs, props) and, with
// `use_triplanar`, for generated meshes that have no UVs (cabin, mountains).
shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_strength = 1.0;
uniform sampler2D roughness_tex : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec4 roughness_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform float roughness = 1.0;
uniform sampler2D metallic_tex : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec4 metallic_channel = vec4(0.0, 0.0, 1.0, 0.0);
uniform float metallic = 0.0;
uniform sampler2D ao_tex : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec4 ao_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec3 uv_scale = vec3(1.0);

uniform bool use_triplanar = false;
// Distant surfaces (mountains) skip the normal, roughness and AO maps.
uniform bool detail_maps = true;
uniform float triplanar_tile = 1.0;

// 0 = bare, 0.5 = snow on tops, 1 = nearly buried.
uniform float snow_amount : hint_range(0.0, 1.0) = 0.5;
// Extra snow higher up (mountains); leave start very high to disable.
uniform float snow_height_start = 10000.0;
uniform float snow_height_end = 10001.0;
uniform sampler2D snow_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D snow_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float snow_tile = 1.5;
uniform vec3 snow_tint : source_color = vec3(0.9, 0.93, 0.98);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (use_triplanar) {
		// Fixed tangent frame per projection axis, as StandardMaterial3D does.
		vec3 n = abs(world_normal);
		TANGENT = normalize(vec3(0.0, 0.0, -1.0) * n.x + vec3(1.0, 0.0, 0.0) * n.y + vec3(1.0, 0.0, 0.0) * n.z);
		BINORMAL = normalize(vec3(0.0, 1.0, 0.0) * n.x + vec3(0.0, 0.0, -1.0) * n.y + vec3(0.0, 1.0, 0.0) * n.z);
	}
}

vec4 sample_surface(sampler2D tex, vec2 uv, vec3 weights) {
	if (!use_triplanar) {
		return texture(tex, uv);
	}
	vec3 p = world_pos / triplanar_tile;
	return texture(tex, p.zy) * weights.x + texture(tex, p.xz) * weights.y + texture(tex, p.xy) * weights.z;
}

void fragment() {
	vec2 uv = UV * uv_scale.xy;
	vec3 weights = pow(abs(world_normal), vec3(4.0));
	weights /= dot(weights, vec3(1.0));

	vec3 base = sample_surface(albedo_tex, uv, weights).rgb * albedo_color.rgb;
	vec3 base_normal = vec3(0.5, 0.5, 1.0);
	float base_rough = roughness;
	float base_metal = metallic;
	float ao = 1.0;
	if (detail_maps) {
		base_normal = sample_surface(normal_tex, uv, weights).rgb;
		base_rough *= dot(sample_surface(roughness_tex, uv, weights), roughness_channel);
		base_metal *= dot(sample_surface(metallic_tex, uv, weights), metallic_channel);
		ao = dot(sample_surface(ao_tex, uv, weights), ao_channel);
	}

	// Snow settles where the surface faces up, with a ragged noisy edge.
	vec2 snow_uv = world_pos.xz / snow_tile;
	vec3 snow = texture(snow_albedo, snow_uv).rgb * snow_tint;
	float breakup = texture(snow_albedo, snow_uv * 0.23).r - 0.5;
	float up = world_normal.y + breakup * 0.5;
	up += smoothstep(snow_height_start, snow_height_end, world_pos.y) * 0.8;
	float threshold = 1.0 - snow_amount * 1.3;
	float mask = smoothstep(threshold, threshold + 0.18, up) * step(0.001, snow_amount);

	ALBEDO = mix(base, snow, mask);
	NORMAL_MAP = mix(base_normal, texture(snow_normal, snow_uv).rgb, mask);
	NORMAL_MAP_DEPTH = mix(normal_strength, 0.6, mask);
	ROUGHNESS = mix(base_rough, 0.75, mask);
	METALLIC = mix(base_metal, 0.0, mask);
	AO = mix(ao, 1.0, mask);
	AO_LIGHT_AFFECT = 0.3;
}
