// The paper-cut continents: card in soft colours (from COLOR), with paper
// fibres, a little shading and a darker cut edge.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 edge_ink : source_color = vec3(0.32, 0.24, 0.16);

varying vec3 world_pos;
varying float facing_up;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	facing_up = NORMAL.y;
}

void fragment() {
	float n1 = texture(noise_tex, world_pos.xz * 1.6).r;
	float n2 = texture(noise_tex, world_pos.xz * 14.0 + 0.5).r;
	// Paper fibres: long thin streaks.
	float fibre = texture(noise_tex, vec2(world_pos.x * 3.0, world_pos.z * 60.0)).r;
	vec3 col = COLOR.rgb * (0.9 + n1 * 0.12 + (n2 - 0.5) * 0.06 + (fibre - 0.5) * 0.04);
	// Ink along the coast (COLOR.a is 0 on the inked rim strip) and on the cut edge.
	col = mix(edge_ink, col, COLOR.a);
	col = mix(edge_ink * 1.4, col, smoothstep(0.3, 0.9, facing_up));
	ALBEDO = col;
	ROUGHNESS = 0.9;
	SPECULAR = 0.25;
}
