// Needle branch cards for fir trees: cut-out needles, a gentle sway in the
// wind, snow resting on the upper sides, and soft light glowing through.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D branch_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 needle_tint : source_color = vec3(1.0);
uniform float snow_amount : hint_range(0.0, 1.0) = 0.5;
uniform sampler2D snow_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform float wind = 0.04;

varying vec3 world_pos;
varying vec3 world_normal;
varying float variation;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 origin = MODEL_MATRIX[3].xyz;
	variation = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
	// Branch tips (UV.x near 1) sway more than where they join the trunk.
	float sway = sin(TIME * 1.3 + world_pos.x * 0.5 + world_pos.z * 0.35) * wind * UV.x * UV.x;
	VERTEX.xz += vec2(sway, sway * 0.6);
}

void fragment() {
	vec4 tex = texture(branch_tex, UV);
	// Both sides of a card use the same outward-facing normal, so the tree
	// is lit as one soft volume instead of flat cards.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec3 col = tex.rgb * needle_tint * mix(0.85, 1.15, variation);
	float noise = texture(snow_albedo, world_pos.xz * 0.8).r;
	// Snow clings in patches on the upper sides of branches, not everywhere.
	float up = world_normal.y * 0.5 + (noise - 0.5) * 1.4 + (tex.g - 0.25) * 0.6;
	float threshold = 1.0 - snow_amount;
	float mask = smoothstep(threshold, threshold + 0.15, up) * step(0.001, snow_amount);
	ALBEDO = mix(col, vec3(0.86, 0.9, 0.97), mask);
	// Mipmaps average the cut-out alpha down, so distant trees would lose
	// their needles. Boost alpha with the mip level to keep them full.
	vec2 texels = UV * vec2(textureSize(branch_tex, 0));
	vec2 dx = dFdx(texels);
	vec2 dy = dFdy(texels);
	float lod = max(0.0, 0.5 * log2(max(dot(dx, dx), dot(dy, dy))));
	ALPHA = tex.a * (1.0 + lod * 0.25);
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	ROUGHNESS = 0.8;
	SPECULAR = 0.3;
	BACKLIGHT = vec3(0.12, 0.2, 0.1) * (1.0 - mask);
}
