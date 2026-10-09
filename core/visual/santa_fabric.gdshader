// The realistic Santa's suit. One texture holds every material, so each pixel
// is sorted by colour: deep red is velvet (a fine pile, crushed patches and a
// soft sheen at grazing angles), near-white is fur and beard (matted tufts,
// dark gaps between them, light glowing through the edges), and everything
// else keeps the model's own roughness. Detail follows the UVs, so it stays
// put on the skin while Santa moves.
shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// glTF metallic-roughness: G roughness, B metallic.
uniform sampler2D orm_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
// Smooth fractal noise (R) and cellular distance noise (R), both tileable.
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D cell_tex : filter_linear_mipmap, repeat_enable;
// Noise repeats per UV unit; one UV unit spans roughly two metres of suit.
uniform float detail_scale = 60.0;
uniform float velvet_bump = 0.0006;
uniform float fur_bump = 0.005;

// 1 where the texture is the suit's deep red.
float velvet_mask(vec3 c) {
	float red = c.r / max(max(c.g, c.b), 0.002);
	return smoothstep(3.0, 6.0, red) * smoothstep(0.02, 0.06, c.r);
}

// 1 where the texture is white or pale grey: fur trim, beard, hair, bobble.
float fur_mask(vec3 c) {
	float top = max(c.r, max(c.g, c.b));
	float sat = (top - min(c.r, min(c.g, c.b))) / max(top, 0.002);
	return (1.0 - smoothstep(0.1, 0.22, sat)) * smoothstep(0.25, 0.5, top);
}

void fragment() {
	vec3 albedo = texture(albedo_tex, UV).rgb;
	vec4 orm = texture(orm_tex, UV);
	float velvet = velvet_mask(albedo);
	float fur = fur_mask(albedo);

	vec2 p = UV * detail_scale;
	float fine = texture(noise_tex, p * 3.0).r;
	float coarse = texture(noise_tex, p * 0.3 + 0.37).r;
	float tufts = texture(cell_tex, p * 1.1 + 0.21).r;
	float strands = texture(noise_tex, p * 7.0 + 0.53).r;

	// Velvet: pile flattened in patches catches more light ("crushed" velvet).
	float crushed = smoothstep(0.3, 0.7, coarse);
	albedo *= mix(1.0, mix(0.9, 1.07, crushed) * (0.93 + fine * 0.14), velvet);
	// Fur: matted tufts with darker gaps, and a little cream-and-grey variation.
	float tuft = smoothstep(0.05, 0.55, tufts);
	albedo *= mix(1.0, (0.5 + tuft * 0.42) * (0.86 + strands * 0.18), fur);
	albedo = mix(albedo, albedo * vec3(1.0, 0.98, 0.94), fur * smoothstep(0.4, 0.7, coarse) * 0.6);
	ALBEDO = albedo;

	// Bump from the surface gradient (Mikkelsen), so it needs no tangents of its own.
	float h = velvet * velvet_bump * (fine * 0.7 + crushed * 0.3)
			+ fur * fur_bump * (tuft * 0.6 + strands * 0.4);
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad);
	NORMAL_MAP = texture(normal_tex, UV).rgb;

	float rough = orm.g;
	rough = mix(rough, 0.82 + (1.0 - crushed) * 0.1, velvet);
	rough = mix(rough, 1.0, fur);
	ROUGHNESS = rough;
	METALLIC = orm.b * (1.0 - max(velvet, fur));
	SPECULAR = mix(0.5, 0.25, max(velvet, fur));
	// Velvet and fur both glow softly where the surface turns away from you.
	RIM = velvet * mix(0.55, 0.8, crushed) + fur * 0.25;
	RIM_TINT = mix(0.6, 0.35, fur);
	BACKLIGHT = albedo * fur * 0.08;
	AO = 1.0 - fur * (1.0 - tuft) * 0.5 - velvet * (1.0 - fine) * 0.12;
	AO_LIGHT_AFFECT = 0.25;
}
