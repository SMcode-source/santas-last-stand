// One layer of fluff over Santa's fur trim and beard. Several of these are
// drawn, each pushed a little further out along the surface, keeping only the
// strand tips that reach that far, so the fur gets a soft, fuzzy edge instead
// of a hard one. Only the white parts of the texture grow fluff.
shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D cell_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float detail_scale = 60.0;
// 0 at the skin, 1 at the outermost layer.
uniform float layer = 0.5;
// How far the outermost layer stands off the surface, in metres.
uniform float fur_length = 0.009;

void vertex() {
	VERTEX += NORMAL * fur_length * layer;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float top = max(c.r, max(c.g, c.b));
	float sat = (top - min(c.r, min(c.g, c.b))) / max(top, 0.002);
	float fur = (1.0 - smoothstep(0.1, 0.22, sat)) * smoothstep(0.25, 0.5, top);
	vec2 p = UV * detail_scale;
	// Strands stand where the cellular noise is low: tuft centres reach the
	// outer layers, the gaps between tufts stop short.
	float strand = 1.0 - texture(cell_tex, p * 9.0 + 0.17).r;
	float tuft = smoothstep(0.05, 0.55, texture(cell_tex, p * 1.1 + 0.21).r);
	float reach = strand * (0.55 + tuft * 0.45) + texture(noise_tex, p * 4.0).r * 0.2;
	if (fur < 0.6 || reach < layer * 0.9 + 0.12) {
		discard;
	}
	// Roots sit in the shade of the fur above them; tips catch the light.
	ALBEDO = c * mix(0.55, 0.92, layer) * (0.85 + tuft * 0.15);
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
	RIM = 0.25;
	RIM_TINT = 0.4;
	BACKLIGHT = ALBEDO * 0.08;
}
