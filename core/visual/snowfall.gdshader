// Falling snow worked out entirely on the graphics card: each flake is a
// little quad whose vertex colour holds its random seed, and the vertex shader
// moves it down through the box and back to the top, so the CPU does nothing.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D dot_tex : source_color, filter_linear;
uniform vec3 box_min = vec3(-14.0, 0.0, -12.5);
uniform vec3 box_size = vec3(28.0, 8.5, 16.0);
uniform float fall_speed = 1.05;
uniform float flake_size = 0.07;
uniform vec4 flake_color : source_color = vec4(0.95, 0.97, 1.0, 0.9);

varying float fade;

void vertex() {
	vec3 seed = COLOR.rgb;
	float speed = fall_speed * (0.75 + 0.5 * COLOR.a);
	vec3 centre = box_min + seed * box_size;
	float drop = mod(seed.y * box_size.y + TIME * speed, box_size.y);
	centre.y = box_min.y + box_size.y - drop;
	// A lazy side-to-side flutter, and a slow drift with the wind.
	centre.x += sin(TIME * (0.6 + seed.z) + seed.x * 40.0) * 0.18 + drop * 0.1;
	centre.z += cos(TIME * (0.5 + seed.x) + seed.z * 40.0) * 0.12;
	// Fade in at the top and out as they reach the ground.
	fade = smoothstep(0.0, 0.6, centre.y - box_min.y) * smoothstep(0.0, 0.8, drop);
	vec4 view = VIEW_MATRIX * vec4(centre, 1.0);
	view.xy += (UV - 0.5) * flake_size * (0.6 + 0.8 * fract(seed.x * 13.7));
	POSITION = PROJECTION_MATRIX * view;
}

void fragment() {
	ALBEDO = flake_color.rgb;
	ALPHA = texture(dot_tex, UV).a * flake_color.a * fade;
}
