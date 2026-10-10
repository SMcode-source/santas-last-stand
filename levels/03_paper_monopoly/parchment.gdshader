// The parchment world map on Scrooge's table: mottled, foxed old paper with
// darkened, scorched edges, an inked graticule every 30 degrees, faint wave
// hatching for the sea, a few coffee-ring stains and a compass rose.
// UV runs over the whole map (0 to 1), longitude across, latitude down.
shader_type spatial;

uniform vec3 paper : source_color = vec3(0.86, 0.77, 0.58);
uniform vec3 aged : source_color = vec3(0.66, 0.53, 0.34);
uniform vec3 ink : source_color = vec3(0.3, 0.2, 0.13);
uniform vec2 map_size = vec2(3.7, 1.46);
uniform float lat_top = 84.0;
uniform float lat_bottom = -58.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

float line(float coord, float spacing, float width) {
	float d = abs(fract(coord / spacing + 0.5) - 0.5) * spacing;
	float aa = fwidth(coord) * 0.75;
	return 1.0 - smoothstep(width, width + aa, d);
}

void fragment() {
	vec2 metres = UV * map_size;
	float n1 = texture(noise_tex, metres * 0.35).r;
	float n2 = texture(noise_tex, metres * 2.1 + 0.37).r;
	float n3 = texture(noise_tex, metres * 9.0 + 0.71).r;
	vec3 col = mix(paper, aged, smoothstep(0.35, 0.85, n1) * 0.55);
	col *= 0.94 + n2 * 0.08 + (n3 - 0.5) * 0.05;
	// Foxing: little brown age spots.
	float fox = smoothstep(0.78, 0.82, texture(noise_tex, metres * 3.3 + 0.13).r);
	col = mix(col, aged * 0.8, fox * 0.35);
	// Graticule: lines every 30 degrees, the equator a touch bolder.
	float lon = UV.x * 360.0 - 180.0;
	float lat = lat_top - UV.y * (lat_top - lat_bottom);
	float grid = max(line(lon, 30.0, 0.12), line(lat, 30.0, 0.12));
	grid = max(grid, line(lat, 360.0, 0.3));
	col = mix(col, ink, grid * 0.35);
	// Sea hatching: fine wavy strokes.
	float wave = sin(metres.y * 260.0 + sin(metres.x * 40.0) * 2.0);
	col = mix(col, ink, smoothstep(0.92, 1.0, wave) * 0.06 * (0.5 + n2));
	// Coffee rings.
	for (int i = 0; i < 3; i++) {
		vec2 c = vec2(0.13 + float(i) * 0.37, 0.78 - float(i) * 0.31) * map_size;
		float r = 0.07 + float(i) * 0.015;
		float d = abs(length(metres - c) - r);
		col = mix(col, aged * 0.75, (1.0 - smoothstep(0.0, 0.006 + n3 * 0.004, d)) * 0.35);
	}
	// Compass rose in the South Pacific.
	vec2 rc = vec2(0.115, 0.79) * map_size;
	vec2 q = metres - rc;
	float rad = length(q);
	float ang = atan(q.y, q.x);
	float star = 0.11 * pow(abs(cos(ang * 2.0)), 6.0) + 0.04 * pow(abs(cos(ang * 2.0 + 0.785)), 6.0) + 0.012;
	float rose = 1.0 - smoothstep(star - 0.002, star + 0.002, rad);
	float ring = 1.0 - smoothstep(0.0, 0.0025, abs(rad - 0.085));
	col = mix(col, ink, max(rose * (0.45 + 0.25 * step(0.0, sin(ang * 8.0))), ring * 0.5));
	// Darkened, singed edges.
	vec2 edge = min(UV, 1.0 - UV) * map_size;
	float e = min(edge.x, edge.y) + (n2 - 0.5) * 0.03;
	col = mix(aged * 0.45, col, smoothstep(0.0, 0.07, e));
	col *= mix(0.25, 1.0, smoothstep(-0.005, 0.012, e));
	ALBEDO = col;
	ROUGHNESS = 0.82;
	SPECULAR = 0.3;
}
