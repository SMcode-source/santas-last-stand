// Inverted-hull outline, used as the next pass of the toon material.
shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(0.13, 0.08, 0.12, 1.0);
uniform float thickness = 0.012;

void vertex() {
	VERTEX += NORMAL * thickness;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
