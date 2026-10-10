// Snowfield: three texture scales to hide tiling, cool blue in the hollows,
// wind-carved ripples in drifting patches, a trail of boot prints, and tiny
// ice-crystal sparkles that glint as the camera moves.
shader_type spatial;

uniform sampler2D snow_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D snow_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D snow_roughness : filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float tile = 2.5;
uniform vec3 tint : source_color = vec3(0.91, 0.94, 0.99);
uniform vec3 hollow_tint : source_color = vec3(0.72, 0.8, 0.95);
uniform float sparkle_strength = 1.2;
uniform float sparkle_density = 0.992;
// Wind ripples: direction the wind blew, crest spacing (m) and height (m).
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float ripple_spacing = 0.3;
uniform float ripple_height = 0.006;
// A walked path of boot prints through these points (x, z), in order.
uniform vec2 trail[12];
uniform int trail_count = 0;
// The trail's bounding box (min x, min z, max x, max z), so the rest of the
// ground skips the footprint search entirely.
uniform vec4 trail_bounds = vec4(0.0);
uniform float stride = 0.36;
// Set by GraphicsQuality at the Low level: no wind ripples or extra texture scales.
global uniform bool lite_shading;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// A hash without sin(), which keeps its randomness far from the origin
// (sin() of a large number loses precision and the sparkles form a grid).
float hash_far(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Depth of the boot prints under `p` (0 outside, 1 at the bottom of a print).
float prints(vec2 p) {
	if (any(lessThan(p, trail_bounds.xy)) || any(greaterThan(p, trail_bounds.zw))) {
		return 0.0;
	}
	float depth = 0.0;
	float walked = 0.0;
	for (int i = 0; i < 11; i++) {
		if (i + 1 >= trail_count) {
			break;
		}
		vec2 a = trail[i];
		vec2 b = trail[i + 1];
		vec2 d = b - a;
		float len = length(d);
		d /= len;
		vec2 rel = p - a;
		float along = dot(rel, d);
		float across = d.x * rel.y - d.y * rel.x;
		if (along > -0.3 && along < len + 0.3 && abs(across) < 0.4) {
			float n = floor((walked + along) / stride);
			for (float k = -1.0; k <= 1.0; k += 1.0) {
				float step_n = n + k;
				float side = mod(step_n, 2.0) < 1.0 ? -1.0 : 1.0;
				float wobble = hash(vec2(step_n, 3.1)) - 0.5;
				vec2 centre = vec2((step_n + 0.5) * stride - walked, side * 0.11 + wobble * 0.03);
				vec2 q = vec2(along, across) - centre;
				q.y -= q.x * 0.15 * side;
				// Boot sole: wider at the toe than the heel.
				float width = 0.05 + 0.012 * clamp(q.x / 0.14, -1.0, 1.0);
				float shape = length(vec2(q.x / 0.14, q.y / width));
				depth = max(depth, 1.0 - smoothstep(0.75, 1.05, shape));
			}
		}
		walked += len;
	}
	return depth;
}

void fragment() {
	vec2 uv = world_pos.xz / tile;
	float dist = length(world_pos - (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
	vec3 near = texture(snow_albedo, uv).rgb;
	vec3 far = texture(snow_albedo, uv * 0.13 + 0.37).rgb;
	// Far away, the coarse scales take over so the repeat never shows.
	near = mix(near, far, smoothstep(12.0, 35.0, dist) * 0.6);
	float variation = far.r;
	if (!lite_shading) {
		variation = mix(far.r, texture(snow_albedo, uv * 0.031 + 0.71).rgb.r, 0.5);
	}
	vec3 col = near * mix(0.9, 1.06, variation);
	// Hollows (darker texture areas) pick up the blue of the sky.
	col *= mix(hollow_tint, tint, smoothstep(0.55, 0.85, near.r));

	// Wind ripples, in patches, bending around the drifts.
	vec2 p = world_pos.xz;
	float h = 0.0;
	if (!lite_shading) {
		float warp = texture(noise_tex, p * 0.07).r * 7.0;
		float drift_mask = smoothstep(0.42, 0.62, texture(noise_tex, p * 0.025 + 0.3).r);
		float phase = dot(p, normalize(wind_dir)) / ripple_spacing + warp;
		float crest = pow(0.5 + 0.5 * sin(phase * 6.2832), 2.0);
		float fade = 1.0 - smoothstep(0.25, 0.6, fwidth(phase));
		h = crest * ripple_height * drift_mask * fade;
	}

	// Boot prints: pressed hollows, bluish in the shade, with a scuffed rim.
	float print_depth = prints(p);
	float rim = print_depth * (1.0 - print_depth) * 4.0;
	h += -print_depth * 0.035 + rim * 0.004;
	col *= mix(vec3(1.0), hollow_tint * 0.88, print_depth * 0.8);

	ALBEDO = col;
	NORMAL_MAP = texture(snow_normal, uv).rgb;
	NORMAL_MAP_DEPTH = 1.2;
	ROUGHNESS = (lite_shading ? 0.75 : texture(snow_roughness, uv).r * 0.9) + print_depth * 0.08;

	// Surface-gradient bump from the ripples and prints (no tangents needed).
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad);

	// Sparkles: a few random cells per square metre catch the light from
	// particular viewing angles, so they twinkle as the camera moves.
	vec2 cell = floor(world_pos.xz * 55.0);
	vec3 view_world = (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;
	float angle_bucket = floor(dot(view_world, vec3(9.0, 13.0, 7.0)) * 1.5);
	float glint = step(sparkle_density, hash_far(cell + angle_bucket * 0.618)) * (1.0 - print_depth);
	EMISSION = vec3(0.85, 0.92, 1.0) * glint * sparkle_strength * (1.0 - smoothstep(4.0, 14.0, dist));
}
