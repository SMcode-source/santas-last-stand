// The sawn end of a log: growth rings, a dark bark rim, a few drying cracks
// running out from the heart, silvery weathering and a cap of snow on top.
// UV is the position on the end from -1 to 1 (+v up); COLOR.r seeds each log.
shader_type spatial;

uniform vec3 heartwood : source_color = vec3(0.62, 0.45, 0.29);
uniform vec3 sapwood : source_color = vec3(0.74, 0.58, 0.4);
uniform vec3 bark : source_color = vec3(0.2, 0.14, 0.1);
uniform vec3 weathered : source_color = vec3(0.55, 0.53, 0.5);
uniform vec3 snow : source_color = vec3(0.9, 0.93, 0.98);
uniform float snow_cap = 1.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void fragment() {
	float seed = COLOR.r * 17.0;
	vec2 uv = UV;
	// The heart is rarely dead centre.
	vec2 heart = vec2(sin(seed * 3.1), cos(seed * 2.3)) * 0.12;
	vec2 q = uv - heart;
	float r = length(q);
	float angle = atan(q.y, q.x);
	float wobble = texture(noise_tex, vec2(angle * 0.32 + seed, r * 0.4)).r;
	float rings = sin((r * 11.0 + wobble * 1.2) * 6.2832);
	float aa = fwidth(r * 11.0);
	rings *= 1.0 - smoothstep(0.3, 0.7, aa);
	vec3 col = mix(heartwood, sapwood, smoothstep(0.35, 0.8, length(uv)));
	col *= 0.9 + rings * 0.08;
	// Radial drying cracks from the heart outwards.
	float spokes = abs(fract(angle / 6.2832 * 4.0 + seed) - 0.5);
	float crack = (1.0 - smoothstep(0.0, 0.02 + r * 0.01, spokes)) * smoothstep(0.15, 0.4, r) * step(0.5, fract(seed * 7.3 + floor(angle / 6.2832 * 4.0 + seed) * 0.37));
	col *= 1.0 - crack * 0.6;
	// Old logs go silver-grey at the end, more so near the edge.
	float grey = texture(noise_tex, uv * 0.6 + seed).r;
	col = mix(col, weathered * (0.85 + grey * 0.3), 0.35 + smoothstep(0.5, 1.0, length(uv)) * 0.2);
	// Bark rim
	float rim = smoothstep(0.86, 0.93, length(uv));
	col = mix(col, bark * (0.8 + grey * 0.4), rim);
	// Snow settles on the top edge.
	float cap = smoothstep(0.62, 0.78, uv.y + (grey - 0.5) * 0.15) * snow_cap;
	col = mix(col, snow, cap);
	ALBEDO = col;
	ROUGHNESS = mix(0.85, 0.7, cap) + crack * 0.1;
	SPECULAR = 0.3;
	// Rings and cracks slightly raised and sunk.
	float h = rings * 0.0008 - crack * 0.003;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad);
	AO = 1.0 - crack * 0.5;
}
