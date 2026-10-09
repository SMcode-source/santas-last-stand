// The animated night sky on a huge inside-out sphere around the scene. Drawn
// after the solid objects (as if see-through), so only open sky gets shaded.
shader_type spatial;
render_mode unshaded, cull_front, fog_disabled, shadows_disabled, depth_draw_never, blend_mix;

#include "res://core/visual/night_sky.gdshaderinc"

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = night_sky(normalize(world_pos - CAMERA_POSITION_WORLD), TIME, true);
	// Counted as see-through so it is drawn after everything solid.
	ALPHA = 1.0;
}
