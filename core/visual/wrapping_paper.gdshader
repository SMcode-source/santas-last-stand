// Glossy printed wrapping paper: stripes, polka dots, snowflakes or tartan,
// projected onto each face of a box, with gentle crinkles and creases from
// being folded round it. Prints can be metallic foil.
shader_type spatial;

uniform vec3 paper_color : source_color = vec3(0.8, 0.1, 0.1);
uniform vec3 print_color : source_color = vec3(1.0);
uniform vec3 accent_color : source_color = vec3(0.85, 0.65, 0.2);
// 0 stripes, 1 polka dots, 2 snowflakes, 3 tartan, 4 plain (gift tags)
uniform int pattern = 0;
// Pattern repeats per metre.
uniform float pattern_scale = 14.0;
// 1 makes the print shiny metal foil.
uniform float foil = 0.0;
uniform float roughness = 0.42;
uniform float crinkle = 0.0006;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec3 obj_pos;
varying vec3 obj_normal;

void vertex() {
	obj_pos = VERTEX;
	obj_normal = NORMAL;
}

// Anti-aliased step: 1 inside (value < edge), 0 outside.
float fill(float value, float edge) {
	float aa = max(fwidth(value), 0.0005);
	return 1.0 - smoothstep(edge - aa, edge + aa, value);
}

float snowflake(vec2 q) {
	float r = length(q);
	float a = atan(q.y, q.x);
	// Six arms, each with a pair of little side branches.
	float arm = abs(sin(a * 3.0)) * r;
	float body = fill(arm, 0.018) * fill(r, 0.3);
	float side = abs(sin((a + 0.52) * 3.0)) * abs(r - 0.18);
	body = max(body, fill(side, 0.012) * fill(abs(r - 0.18), 0.06));
	return max(body, fill(r, 0.05));
}

void fragment() {
	vec3 n = abs(obj_normal);
	vec2 p;
	if (n.y >= n.x && n.y >= n.z) {
		p = obj_pos.xz;
	} else if (n.x >= n.z) {
		p = obj_pos.zy;
	} else {
		p = obj_pos.xy;
	}
	vec2 q = p * pattern_scale;
	float print_mask = 0.0;
	float accent_mask = 0.0;
	if (pattern == 0) {
		float s = fract((q.x + q.y) * 0.5);
		print_mask = fill(abs(s - 0.25), 0.12);
		accent_mask = fill(abs(s - 0.62), 0.03);
	} else if (pattern == 1) {
		vec2 cell = q;
		cell.x += step(1.0, mod(floor(cell.y), 2.0)) * 0.5;
		vec2 c = fract(cell) - 0.5;
		print_mask = fill(length(c), 0.2);
		accent_mask = fill(length(fract(cell + 0.5) - 0.5), 0.06);
	} else if (pattern == 2) {
		vec2 cell = q * 0.6;
		vec2 id = floor(cell);
		vec2 c = fract(cell) - 0.5;
		float turn = fract(sin(dot(id, vec2(12.9898, 78.233))) * 43758.5453) * 1.0;
		mat2 rot = mat2(vec2(cos(turn), -sin(turn)), vec2(sin(turn), cos(turn)));
		print_mask = snowflake(rot * c);
		accent_mask = fill(length(fract(cell + 0.5) - 0.5), 0.035);
	} else if (pattern == 3) {
		// Tartan: wide and narrow bands crossing, darker where they overlap.
		float bx = fill(abs(fract(q.x * 0.5) - 0.5), 0.14);
		float by = fill(abs(fract(q.y * 0.5) - 0.5), 0.14);
		float tx = fill(abs(fract(q.x * 0.5 + 0.25) - 0.5), 0.025);
		float ty = fill(abs(fract(q.y * 0.5 + 0.25) - 0.5), 0.025);
		print_mask = clamp((bx + by) * 0.55, 0.0, 1.0);
		accent_mask = max(tx, ty);
	}
	vec3 albedo = mix(paper_color, print_color, print_mask);
	albedo = mix(albedo, accent_color, accent_mask);

	// Crinkles: broad soft waves plus the fine tooth of the paper.
	float waves = texture(noise_tex, p * 2.3).r;
	float tooth = texture(noise_tex, p * 40.0 + 0.3).r;
	float creases = 1.0 - smoothstep(0.0, 0.03, abs(texture(noise_tex, p * 0.9 + 0.7).r - 0.5));
	float h = (waves * 0.7 + tooth * 0.15 - creases * 0.4) * crinkle;
	albedo *= 0.97 + tooth * 0.04 - creases * 0.05;
	ALBEDO = albedo;

	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad);

	float metal = foil * max(print_mask, accent_mask);
	METALLIC = metal;
	ROUGHNESS = mix(roughness + (waves - 0.5) * 0.12 + creases * 0.15, 0.25, metal);
	SPECULAR = 0.5;
}
