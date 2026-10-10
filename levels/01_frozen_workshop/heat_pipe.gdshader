shader_type spatial;
// An iron pipe that starts frosted over. When heat is sent up it, a glowing
// front travels along it (UV.x is metres along the pipe): the frost melts
// away behind the front and the iron stays warm, with a dull red glow.

uniform float front = -1.0;      // metres along the pipe the heat has reached
uniform float glow = 0.0;        // 0..1, how hot the heated part looks
uniform float time_offset = 0.0;

varying float up_facing;

void vertex() {
	up_facing = (MODEL_MATRIX * vec4(NORMAL, 0.0)).y;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float along = UV.x;
	float around = UV.y;
	float grain = noise(vec2(along * 6.0, around * 18.0)) * 0.6 + noise(vec2(along * 23.0, around * 61.0)) * 0.4;
	// Frost is thickest on top of the pipe.
	float top = 0.5 + 0.5 * up_facing;
	float frost = smoothstep(0.35, 0.75, grain * 0.7 + top * 0.6);
	float edge = front - along + (grain - 0.5) * 0.6;
	float heated = smoothstep(-0.05, 0.25, edge);
	frost *= 1.0 - heated;

	vec3 iron = vec3(0.10, 0.10, 0.11) * (0.75 + grain * 0.5);
	vec3 rime = vec3(0.80, 0.88, 0.95);
	ALBEDO = mix(iron, rime, frost);
	ROUGHNESS = mix(0.55, 0.9, frost);
	METALLIC = mix(0.8, 0.0, frost);
	SPECULAR = 0.5;

	// The bright band where the heat front is, and a warm glow behind it.
	float band = exp(-edge * edge * 6.0) * step(0.0, front);
	float flicker = 0.85 + 0.15 * sin(TIME * 7.0 + along * 1.7 + time_offset);
	vec3 hot = vec3(1.0, 0.35, 0.08);
	EMISSION = hot * (band * 3.0 * flicker + heated * glow * 0.35 * (0.7 + grain * 0.6));
}
