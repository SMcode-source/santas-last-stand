extends SceneTree
## Generates the textures we draw ourselves rather than download.
## Run: godot --headless --script res://tools/make_textures.gd

const OUT := "res://assets/textures/generated/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_fir_branch().save_png(OUT + "fir_branch.png")
	print("Wrote ", OUT, "fir_branch.png")
	quit()


## A fir branch seen from above: a twig with side shoots, densely covered in
## needles, on a transparent background. Branch runs left (trunk) to right (tip).
## Drawn at double size, then shrunk for smooth edges.
func _fir_branch() -> Image:
	var w := 1024
	var h := 512
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.12, 0.2, 0.12, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2512
	var twig := Color("4a3424")
	var mid := h / 2.0

	# Main twig, then side shoots angled toward the tip.
	var shoots: Array[PackedVector2Array] = []
	shoots.append(PackedVector2Array([Vector2(10, mid), Vector2(w - 20, mid + 6)]))
	var x := 90.0
	while x < w - 140:
		var t := x / w
		var length := lerpf(230.0, 70.0, t) * rng.randf_range(0.8, 1.1)
		for side: float in [-1.0, 1.0]:
			var angle := deg_to_rad(rng.randf_range(32, 48)) * side
			var start := Vector2(x + rng.randf_range(-10, 10), mid + t * 6)
			var tip := start + Vector2(cos(angle), sin(angle)) * length
			# Keep shoots inside the card, tapering towards the tip like a real branch.
			var reach := h * 0.45 * (1.0 - t * 0.6)
			tip.y = clampf(tip.y, mid - reach, mid + reach)
			shoots.append(PackedVector2Array([start, tip]))
		x += rng.randf_range(40, 60)

	# Needles first, then twigs drawn on top.
	for shoot in shoots:
		var a := shoot[0]
		var b := shoot[1]
		var dir := (b - a).normalized()
		var normal := Vector2(-dir.y, dir.x)
		var length := a.distance_to(b)
		var s := 0.0
		while s < length:
			var p := a + dir * s
			var taper := 1.0 - 0.55 * (s / length)
			for side: float in [-1.0, 1.0]:
				var needle_len := rng.randf_range(26, 38) * taper
				var spread := deg_to_rad(rng.randf_range(50, 75))
				var nd := (dir * cos(spread) + normal * side * sin(spread)).normalized()
				var base := Color("16301c").lerp(Color("2c5530"), rng.randf())
				var tip_col := base.lightened(0.18).lerp(Color("3d6b55"), 0.25)
				_line(img, p, p + nd * needle_len, base, tip_col, 3.0)
			s += rng.randf_range(3.0, 4.5)
	for i in shoots.size():
		_line(img, shoots[i][0], shoots[i][1], twig, twig.darkened(0.2), 5.0 if i == 0 else 3.0)

	img.resize(w / 2, h / 2, Image.INTERPOLATE_LANCZOS)
	return img


## Draws an anti-aliased line with a colour gradient and the given thickness.
func _line(img: Image, from: Vector2, to: Vector2, c0: Color, c1: Color, width: float) -> void:
	var steps := int(from.distance_to(to)) + 1
	var r := width / 2.0
	for i in steps + 1:
		var t := float(i) / steps
		var p := from.lerp(to, t)
		var col := c0.lerp(c1, t)
		for dy in range(int(-r) - 1, int(r) + 2):
			for dx in range(int(-r) - 1, int(r) + 2):
				var q := Vector2i(int(p.x) + dx, int(p.y) + dy)
				if q.x < 0 or q.y < 0 or q.x >= img.get_width() or q.y >= img.get_height():
					continue
				var cover := clampf(r + 0.5 - Vector2(q.x + 0.5, q.y + 0.5).distance_to(p), 0.0, 1.0)
				if cover > 0.0:
					img.set_pixelv(q, Color(col.r, col.g, col.b, maxf(img.get_pixelv(q).a, cover)))
