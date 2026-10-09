extends SceneTree
## Generates the textures we draw ourselves rather than download.
## Run: godot --headless --script res://tools/make_textures.gd

const OUT := "res://assets/textures/generated/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_fir_branch().save_png(OUT + "fir_branch.png")
	print("Wrote ", OUT, "fir_branch.png")
	quit()


## A fir branch seen from above: a gently curving twig with side shoots (the
## bigger ones branching again), densely covered in tapered needles on a
## transparent background. Needles are darker deep in the branch and fresh,
## lighter green at the shoot tips, each with a faint highlight down its
## length. Branch runs left (trunk) to right (tip). Drawn at double size, then
## shrunk for smooth edges.
func _fir_branch() -> Image:
	var w := 2048
	var h := 1024
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.1, 0.18, 0.11, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2512
	var twig := Color("4a3424")
	var mid := h / 2.0

	# Each shoot is a curved polyline; `depth` 0 is the main twig.
	var shoots: Array[Dictionary] = []
	shoots.append({"points": _curve(Vector2(20, mid), Vector2(w - 40, mid + 14), 18.0, rng), "depth": 0})
	var x := 160.0
	while x < w - 240:
		var t := x / w
		for side: float in [-1.0, 1.0]:
			var length := lerpf(470.0, 140.0, t) * rng.randf_range(0.8, 1.1)
			var angle := deg_to_rad(rng.randf_range(30, 46)) * side
			var start := Vector2(x + rng.randf_range(-16, 16), mid + t * 14)
			var tip := start + Vector2(cos(angle), sin(angle)) * length
			var reach := h * 0.46 * (1.0 - t * 0.55)
			tip.y = clampf(tip.y, mid - reach, mid + reach)
			var points := _curve(start, tip, 14.0 * side, rng)
			shoots.append({"points": points, "depth": 1})
			# Longer shoots fork again partway along.
			if length > 260.0:
				for k in 2:
					var f := rng.randf_range(0.3, 0.6)
					var fork := _along(points, f)
					var fdir := (_along(points, f + 0.05) - fork).normalized()
					var turn := deg_to_rad(rng.randf_range(28, 40)) * (1.0 if k == 0 else -1.0)
					var ftip := fork + fdir.rotated(turn) * length * rng.randf_range(0.28, 0.4)
					ftip.y = clampf(ftip.y, mid - reach, mid + reach)
					shoots.append({"points": _curve(fork, ftip, 6.0, rng), "depth": 2})
		x += rng.randf_range(70, 105)

	var deep := Color("10241a")
	var green := Color("24502f")
	var fresh := Color("5d8f45")
	# Two passes: a darker, sparser layer underneath, then the twigs, then the
	# main needles, which hide most of the twigs as on a real branch.
	for layer in 2:
		if layer == 1:
			for shoot in shoots:
				var depth: int = shoot["depth"]
				var points: PackedVector2Array = shoot["points"]
				for i in points.size() - 1:
					var width: float = [9.0, 5.0, 3.5][depth] * (1.0 - 0.4 * float(i) / points.size())
					_line(img, points[i], points[i + 1], twig, twig.darkened(0.15), width)
		for shoot in shoots:
			var points: PackedVector2Array = shoot["points"]
			var total := _length(points)
			var s := 0.0
			while s < total:
				var f := s / total
				var p := _along(points, f)
				var dir := (_along(points, minf(f + 0.01, 1.0)) - _along(points, maxf(f - 0.01, 0.0))).normalized()
				var normal := Vector2(-dir.y, dir.x)
				var taper := 1.0 - 0.5 * f
				var depth: int = shoot["depth"]
				for side: float in [-1.0, 1.0]:
					var needle_len := rng.randf_range(44, 64) * taper * (0.8 if layer == 0 else 1.0) * (0.85 if depth == 2 else 1.0)
					var spread := deg_to_rad(rng.randf_range(40, 72) + (14.0 if layer == 0 else 0.0))
					var nd := (dir * cos(spread) + normal * side * sin(spread)).normalized()
					# A little droop and curl so the needles aren't ruler-straight.
					nd = nd.rotated(rng.randf_range(-0.12, 0.12))
					var col := deep.lerp(green, rng.randf_range(0.35, 1.0))
					if depth == 0:
						col = col.lerp(deep, 0.35)
					# Fresh growth towards the tips of the shoots.
					col = col.lerp(fresh, smoothstep(0.7, 1.0, f) * rng.randf_range(0.5, 0.9))
					if layer == 0:
						col = col.darkened(0.35)
					var tip := p + nd * needle_len
					_needle(img, p, tip, col, 5.0 if layer == 1 else 4.0)
				s += rng.randf_range(4.0, 6.0) * (1.6 if layer == 0 else 1.0)

	img.resize(w / 2, h / 2, Image.INTERPOLATE_LANCZOS)
	return img


## A gently bowed polyline from `a` to `b`, bulging sideways by `bend` pixels.
func _curve(a: Vector2, b: Vector2, bend: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var points := PackedVector2Array()
	var normal := (b - a).normalized().orthogonal()
	var wobble := rng.randf_range(0.7, 1.3)
	for i in 9:
		var t := i / 8.0
		points.append(a.lerp(b, t) + normal * sin(t * PI) * bend * wobble)
	return points


func _length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in points.size() - 1:
		total += points[i].distance_to(points[i + 1])
	return total


## The point a fraction `f` of the way along a polyline.
func _along(points: PackedVector2Array, f: float) -> Vector2:
	var target := clampf(f, 0.0, 1.0) * _length(points)
	for i in points.size() - 1:
		var seg := points[i].distance_to(points[i + 1])
		if target <= seg or i == points.size() - 2:
			return points[i].lerp(points[i + 1], clampf(target / maxf(seg, 0.001), 0.0, 1.0))
		target -= seg
	return points[-1]


## One needle: tapering from `width` at the base to a point, darker at the
## base, with a lighter stripe down the middle where it catches the light.
func _needle(img: Image, from: Vector2, to: Vector2, col: Color, width: float) -> void:
	var steps := int(from.distance_to(to)) + 1
	for i in steps + 1:
		var t := float(i) / steps
		var p := from.lerp(to, t)
		var r := lerpf(width, 1.2, t) / 2.0
		var shade := col.darkened(0.25 * (1.0 - t))
		var light := shade.lightened(0.28)
		for dy in range(int(-r) - 1, int(r) + 2):
			for dx in range(int(-r) - 1, int(r) + 2):
				var q := Vector2i(int(p.x) + dx, int(p.y) + dy)
				if q.x < 0 or q.y < 0 or q.x >= img.get_width() or q.y >= img.get_height():
					continue
				var d := Vector2(q.x + 0.5, q.y + 0.5).distance_to(p)
				var cover := clampf(r + 0.5 - d, 0.0, 1.0)
				if cover > 0.0:
					var c := light.lerp(shade, clampf(d / maxf(r, 0.5), 0.0, 1.0))
					var old := img.get_pixelv(q)
					var rgb := c if old.a == 0.0 else Color(old.r, old.g, old.b).lerp(c, cover)
					img.set_pixelv(q, Color(rgb.r, rgb.g, rgb.b, maxf(old.a, cover)))


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
