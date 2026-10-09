// A lit cabin window at night, seen from outside: warm lamplight inside,
// curtains tied back at each side and a scalloped pelmet along the top, all
// glowing through the cloth, and frost creeping in from the corners of the
// cold glass. UV runs 0 to 1, left to right and bottom to top.
shader_type spatial;

uniform vec3 lamp : source_color = vec3(1.0, 0.68, 0.36);
uniform vec3 curtain : source_color = vec3(0.6, 0.08, 0.08);
uniform float energy = 1.25;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D cell_tex : filter_linear_mipmap, repeat_enable;

float soft_step(float edge, float x) {
	float aa = max(fwidth(x), 0.002);
	return smoothstep(edge - aa, edge + aa, x);
}

void fragment() {
	vec2 uv = UV;
	// The room: brightest low in the middle where the lamp stands.
	float glow = 0.35 + 0.75 * exp(-pow(length((uv - vec2(0.5, 0.3)) * vec2(1.3, 1.6)), 2.0) * 3.0);
	glow *= 1.0 - uv.y * 0.25;
	vec3 room = lamp * glow;

	// Curtains, tied back halfway down, with vertical folds.
	float tie = exp(-pow((uv.y - 0.4) / 0.14, 2.0));
	float width = 0.24 - 0.12 * tie;
	float side = min(uv.x, 1.0 - uv.x);
	float in_curtain = 1.0 - soft_step(width, side);
	float folds = 0.5 + 0.5 * sin(uv.x * 55.0 + sin(uv.y * 4.0) * 2.0);
	// Pelmet: a scalloped strip of the same cloth across the top.
	float scallop = 0.86 - 0.035 * abs(sin(uv.x * 3.14159 * 5.0));
	float in_pelmet = soft_step(scallop, uv.y);
	float cloth = max(in_curtain, in_pelmet);
	vec3 lit_cloth = curtain * lamp * (0.6 + 0.6 * folds);
	vec3 inside = mix(room, lit_cloth, cloth);

	// Frost from the edges and corners, in feathery crystals.
	float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float corner = length(max(vec2(0.0), abs(uv - 0.5) - 0.32));
	float crystals = texture(cell_tex, uv * 9.0).r;
	float drift = texture(noise_tex, uv * 3.0).r;
	float frost = smoothstep(0.07, 0.0, edge + (drift - 0.5) * 0.06 - corner * 0.5 - (1.0 - crystals) * 0.02);
	frost = clamp(frost, 0.0, 1.0) * 0.6;

	ALBEDO = mix(vec3(0.02), vec3(0.62, 0.68, 0.76), frost);
	EMISSION = inside * energy * (1.0 - frost * 0.8);
	ROUGHNESS = mix(0.06, 0.55, frost);
	SPECULAR = 0.6;
}
