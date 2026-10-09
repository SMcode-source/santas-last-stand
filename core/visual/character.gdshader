// Character surfaces: velvet, fur, hair, skin, leather and metal finishes.
// Colour comes from vertex colours. Fabric nap, leather grain, skin pores and
// wear are bump-mapped from object-space noise, so generated meshes need no
// UVs or tangents.
shader_type spatial;

// Smooth fractal noise (R).
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
// Cellular distance noise (R): pebbled leather grain and skin pores.
uniform sampler2D cell_tex : filter_linear_mipmap, repeat_enable;
uniform float roughness = 0.8;
// How much roughness wanders across the surface (worn, oily or polished patches).
uniform float roughness_variation = 0.0;
uniform float metallic = 0.0;
uniform float specular = 0.5;
// Soft light grazing the edges, as on velvet, fur and skin.
uniform float rim = 0.0;
uniform float rim_tint = 0.5;
// How many times the noise repeats per metre.
uniform float detail_scale = 20.0;
// Bump height in metres.
uniform float bump = 0.0;
// Blotchy colour variation (skin redness, worn leather, dyed cloth).
uniform float mottle = 0.0;
// 0 plain, 1 velvet, 2 leather, 3 skin, 4 worn metal
uniform int pattern = 0;

varying vec3 obj_pos;
varying vec3 obj_normal;

void vertex() {
	obj_pos = VERTEX;
	obj_normal = NORMAL;
}

float tri_noise(vec3 p, vec3 w) {
	return texture(noise_tex, p.zy).r * w.x + texture(noise_tex, p.xz).r * w.y + texture(noise_tex, p.xy).r * w.z;
}

float tri_cell(vec3 p, vec3 w) {
	return texture(cell_tex, p.zy).r * w.x + texture(cell_tex, p.xz).r * w.y + texture(cell_tex, p.xy).r * w.z;
}

void fragment() {
	vec3 w = pow(abs(obj_normal), vec3(4.0));
	w /= dot(w, vec3(1.0));
	vec3 p = obj_pos * detail_scale;
	float fine = tri_noise(p, w);
	float coarse = tri_noise(p * 0.21 + 0.37, w);

	vec3 albedo = COLOR.rgb * (1.0 + (coarse - 0.5) * mottle);
	float h = fine * 0.75 + coarse * 0.25;
	float rough = roughness + (coarse - 0.5) * roughness_variation;
	float rim_amount = rim;
	float cavity = fine;

	if (pattern == 1) {
		// Velvet: a fine pile, plus large crushed patches where the pile lies
		// flat and catches more light.
		float pile = tri_noise(p * 2.7 + 0.11, w);
		float crushed = tri_noise(p * 0.045 + 0.53, w);
		albedo *= mix(0.94, 1.06, smoothstep(0.3, 0.7, crushed)) * (0.9 + pile * 0.2);
		h = pile * 0.55 + fine * 0.3 + crushed * 0.15;
		rim_amount = rim * mix(0.8, 1.25, crushed);
		cavity = pile;
	} else if (pattern == 2) {
		// Leather: pebbled grain, fine creases and paler scuffs.
		float grain = tri_cell(p * 2.2, w);
		float crease_noise = tri_noise(p * 0.6 + 0.29, w);
		float crease = 1.0 - smoothstep(0.0, 0.035, abs(crease_noise - 0.5));
		float scuff = smoothstep(0.6, 0.8, coarse);
		h = grain * 0.6 + fine * 0.2 - crease * 0.5;
		albedo *= (1.0 - crease * 0.35) * (0.92 + grain * 0.12);
		albedo = mix(albedo, albedo * 1.4 + vec3(0.03), scuff * 0.45);
		rough += scuff * 0.3 + crease * 0.15;
		cavity = 1.0 - crease;
	} else if (pattern == 3) {
		// Skin: pores, a criss-cross of fine lines, blotchy redness and the odd
		// faint age spot.
		float pores = tri_cell(p, w);
		float lines = tri_noise(p * 1.8 + 0.71, w);
		float lines2 = tri_noise(p.yzx * 1.8 + 0.13, w);
		float creases = (1.0 - smoothstep(0.0, 0.05, abs(lines - 0.5))) + (1.0 - smoothstep(0.0, 0.05, abs(lines2 - 0.5)));
		float spots = smoothstep(0.78, 0.9, tri_noise(p * 0.33 + 0.47, w));
		h = smoothstep(0.0, 0.35, pores) * 0.7 + fine * 0.3 - creases * 0.25;
		albedo = mix(albedo, albedo * vec3(1.04, 0.9, 0.88), smoothstep(0.4, 0.75, coarse) * 0.5);
		albedo *= 1.0 - spots * 0.12;
		albedo *= 0.96 + smoothstep(0.0, 0.3, pores) * 0.04;
		rough += (1.0 - smoothstep(0.0, 0.3, pores)) * 0.12;
		cavity = smoothstep(0.0, 0.3, pores);
	} else if (pattern == 4) {
		// Worn metal: polished high points, darker tarnish in between.
		float wear = smoothstep(0.35, 0.7, coarse);
		albedo *= mix(0.7, 1.08, wear);
		rough = mix(roughness + 0.25, roughness - 0.1, wear) + (fine - 0.5) * 0.1;
	}

	ALBEDO = albedo;
	if (bump > 0.0) {
		// Bump mapping from the surface gradient (Mikkelsen), no tangents needed.
		float height = h * bump;
		vec3 dpdx = dFdx(VERTEX);
		vec3 dpdy = dFdy(VERTEX);
		vec3 r1 = cross(dpdy, NORMAL);
		vec3 r2 = cross(NORMAL, dpdx);
		float det = dot(dpdx, r1);
		vec3 grad = sign(det) * (dFdx(height) * r1 + dFdy(height) * r2);
		NORMAL = normalize(abs(det) * NORMAL - grad);
		AO = 1.0 - (1.0 - cavity) * 0.35;
		AO_LIGHT_AFFECT = 0.2;
	}
	ROUGHNESS = clamp(rough, 0.03, 1.0);
	METALLIC = metallic;
	SPECULAR = specular;
	RIM = rim_amount;
	RIM_TINT = rim_tint;
}
