// The night sky as the environment sees it, for reflections. It never changes,
// so Godot works out the reflections once instead of every frame; the
// twinkling and the drifting aurora are drawn by the sky dome (night_sky_dome).
shader_type sky;

#include "res://core/visual/night_sky.gdshaderinc"

void sky() {
	COLOR = night_sky(normalize(EYEDIR), 0.0, false);
}
