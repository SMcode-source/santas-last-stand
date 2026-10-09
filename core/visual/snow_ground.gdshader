// Snowfield: two texture scales to hide tiling, cool blue in the hollows,
// and tiny ice-crystal sparkles that glint as the camera moves.
shader_type spatial;

uniform sampler2D snow_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D snow_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D snow_roughness : filter_linear_mipmap, repeat_enable;
uniform float tile = 2.5;
uniform vec3 tint : source_color = vec3(0.91, 0.94, 0.99);
uniform vec3 hollow_tint : source_color = vec3(0.72, 0.8, 0.95);
uniform float sparkle_strength = 1.2;
uniform float sparkle_density = 0.992;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = world_pos.xz / tile;
	vec3 near = texture(snow_albedo, uv).rgb;
	vec3 far = texture(snow_albedo, uv * 0.13 + 0.37).rgb;
	float variation = far.r;
	vec3 col = near * mix(0.92, 1.05, variation);
	// Hollows (darker texture areas) pick up the blue of the sky.
	col *= mix(hollow_tint, tint, smoothstep(0.55, 0.85, near.r));
	ALBEDO = col;
	NORMAL_MAP = texture(snow_normal, uv).rgb;
	NORMAL_MAP_DEPTH = 1.2;
	ROUGHNESS = texture(snow_roughness, uv).r * 0.9;

	// Sparkles: a few random cells per square metre catch the light from
	// particular viewing angles, so they twinkle as the camera moves.
	vec2 cell = floor(world_pos.xz * 55.0);
	vec3 view_world = (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;
	float angle_bucket = floor(dot(view_world, vec3(9.0, 13.0, 7.0)) * 1.5);
	float glint = step(sparkle_density, hash(cell + angle_bucket * 0.618));
	float dist = length(world_pos - (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
	EMISSION = vec3(0.85, 0.92, 1.0) * glint * sparkle_strength * (1.0 - smoothstep(4.0, 14.0, dist));
}
