// The ring round a factory town's base that fills as the workers warm to
// Santa: a faint track, filled clockwise from the top in warm gold.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform float fill = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float band = smoothstep(0.78, 0.8, r) * (1.0 - smoothstep(0.95, 0.97, r));
	float a = fract(atan(p.x, -p.y) / 6.2832 + 1.0);
	float lit = step(a, fill);
	vec3 col = mix(vec3(0.18, 0.12, 0.08), vec3(1.0, 0.78, 0.3) * 1.6, lit);
	ALBEDO = col;
	ALPHA = band * mix(0.35, 0.95, lit);
}
