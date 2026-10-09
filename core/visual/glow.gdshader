// Self-lit parts (fairy lights, windows, eye sparkles). Values above 1 feed the bloom.
shader_type spatial;
render_mode unshaded;

uniform float strength = 3.0;

void fragment() {
	ALBEDO = COLOR.rgb * strength;
}
