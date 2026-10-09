// Cel-shaded material for toy characters and props.
// Colour comes from vertex colours, so a whole character can share one material.
shader_type spatial;
render_mode cull_back;

// Tint applied to the side facing away from the light (cool, painterly shadows).
uniform vec4 shadow_tint : source_color = vec4(0.55, 0.6, 0.85, 1.0);
uniform float shadow_fill = 0.32;
uniform float highlight = 0.18;
uniform float rim_strength = 0.35;
uniform float glossiness = 0.0;

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	// Two crisp bands: lit / shadow, plus a soft highlight band on the brightest side.
	float lit = smoothstep(0.0, 0.05, ndl) * ATTENUATION;
	float hi = smoothstep(0.6, 0.65, ndl) * ATTENUATION * highlight;
	vec3 tone = mix(shadow_tint.rgb * shadow_fill, vec3(1.0), lit) + vec3(hi);
	// Rim light on silhouettes facing the light source.
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	float rim = fresnel * rim_strength * smoothstep(-0.3, 0.4, ndl) * ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR * (tone + rim) / PI;
	if (glossiness > 0.0) {
		vec3 h = normalize(LIGHT + VIEW);
		float spec = smoothstep(0.92, 0.95, dot(NORMAL, h)) * glossiness * ATTENUATION;
		SPECULAR_LIGHT += LIGHT_COLOR * spec / PI;
	}
}
