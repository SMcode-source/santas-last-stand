// Satin ribbon: a glossy face with fine woven ribs running along its length
// and slightly raised, matte selvedge edges. UV.x runs along the ribbon and
// UV.y across it (0 to 1). Both sides are drawn, so bow loops look solid.
shader_type spatial;
render_mode cull_disabled;

// The ribbon's colour (sRGB) is in COLOR.rgb, and COLOR.a is 1 for metallic
// gift ribbon, so every present shares this material.
uniform float sheen = 0.25;
// Ribs across the ribbon's width.
uniform float ribs = 40.0;

vec3 to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void fragment() {
	vec3 ribbon_color = to_linear(COLOR.rgb);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	float across = UV.y;
	float rib = sin(across * ribs * 6.2832);
	// Fade the ribs out when they get smaller than a pixel, so they never shimmer.
	float fade = 1.0 - smoothstep(0.15, 0.45, fwidth(across * ribs));
	float edge = 1.0 - smoothstep(0.0, 0.06, min(across, 1.0 - across));
	ALBEDO = ribbon_color * (0.96 + rib * 0.04 * fade) * (1.0 - edge * 0.12);
	ROUGHNESS = mix(sheen, 0.6, edge) + rib * 0.04 * fade;
	METALLIC = COLOR.a * 0.45;
	SPECULAR = 0.65;
	RIM = 0.25;
	RIM_TINT = 0.6;
}
