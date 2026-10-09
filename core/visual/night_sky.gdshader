// Stylised Christmas night sky: gradient, twinkling stars, moon and a gentle aurora.
shader_type sky;

uniform vec4 top_color : source_color = vec4(0.03, 0.05, 0.15, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.24, 0.22, 0.45, 1.0);
uniform vec4 ground_color : source_color = vec4(0.12, 0.13, 0.24, 1.0);
uniform vec3 moon_direction = vec3(-0.45, 0.42, -0.79);
uniform vec4 aurora_color : source_color = vec4(0.15, 0.95, 0.6, 1.0);
uniform float aurora_strength = 0.45;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col = mix(horizon_color.rgb, top_color.rgb, smoothstep(0.0, 0.55, h));
	if (h < 0.0) {
		col = mix(horizon_color.rgb, ground_color.rgb, smoothstep(0.0, -0.15, h));
	}

	// Stars: one candidate per cell, drawn as a small round dot.
	vec3 grid = d * 160.0;
	vec3 cell = floor(grid);
	float rnd = hash(cell);
	float dist = length(fract(grid) - 0.5);
	float star = step(0.985, rnd) * smoothstep(0.22, 0.05, dist) * smoothstep(0.02, 0.2, h);
	float twinkle = 0.55 + 0.45 * sin(TIME * (1.5 + rnd * 3.0) + rnd * 60.0);
	col += vec3(0.95, 0.95, 1.0) * star * twinkle * 1.6;

	// Moon with a soft halo.
	vec3 md = normalize(moon_direction);
	float m = dot(d, md);
	col += vec3(1.0, 0.96, 0.82) * smoothstep(0.9991, 0.9994, m) * 2.0;
	col += vec3(0.55, 0.6, 0.85) * pow(max(m, 0.0), 120.0) * 0.5;

	// Aurora: drifting curtains of light above the horizon.
	float wave = sin(d.x * 5.0 + TIME * 0.15 + sin(d.z * 3.0 + TIME * 0.1) * 2.0);
	float curtain = 0.5 + 0.5 * sin(d.x * 23.0 + wave * 3.0 + TIME * 0.3);
	float band = smoothstep(0.12, 0.3, h) * smoothstep(0.65, 0.3, h) * (0.4 + 0.6 * curtain) * (0.5 + 0.5 * wave);
	col += aurora_color.rgb * band * aurora_strength;

	COLOR = col;
}
