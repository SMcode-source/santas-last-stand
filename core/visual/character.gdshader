// Character surfaces: velvet, fur, hair, skin, leather and metal finishes.
// Colour comes from vertex colours. Fine fibre and pore detail is bump-mapped
// from object-space noise, so generated meshes need no UVs or tangents.
shader_type spatial;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float roughness = 0.8;
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

varying vec3 obj_pos;
varying vec3 obj_normal;

void vertex() {
	obj_pos = VERTEX;
	obj_normal = NORMAL;
}

float triplanar(vec3 p, vec3 w) {
	return texture(noise_tex, p.zy).r * w.x + texture(noise_tex, p.xz).r * w.y + texture(noise_tex, p.xy).r * w.z;
}

void fragment() {
	vec3 w = pow(abs(obj_normal), vec3(4.0));
	w /= dot(w, vec3(1.0));
	vec3 p = obj_pos * detail_scale;
	float fine = triplanar(p, w);
	float coarse = triplanar(p * 0.21 + 0.37, w);

	ALBEDO = COLOR.rgb * (1.0 + (coarse - 0.5) * mottle);
	if (bump > 0.0) {
		// Bump mapping from the surface gradient (Mikkelsen), no tangents needed.
		float h = (fine * 0.75 + coarse * 0.25) * bump;
		vec3 dpdx = dFdx(VERTEX);
		vec3 dpdy = dFdy(VERTEX);
		vec3 r1 = cross(dpdy, NORMAL);
		vec3 r2 = cross(NORMAL, dpdx);
		float det = dot(dpdx, r1);
		vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
		NORMAL = normalize(abs(det) * NORMAL - grad);
		AO = 1.0 - (1.0 - fine) * 0.35;
		AO_LIGHT_AFFECT = 0.2;
	}
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = specular;
	RIM = rim;
	RIM_TINT = rim_tint;
}
