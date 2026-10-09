extends SceneTree
## Prints the size, triangle count and materials of every model in assets/models.
## Run: godot --headless --script res://tools/model_report.gd

func _initialize() -> void:
	for file in DirAccess.get_files_at("res://assets/models"):
		if not file.ends_with(".glb"):
			continue
		var scene: Node3D = load("res://assets/models/" + file).instantiate()
		var box := AABB()
		var mats := []
		for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			var b := mi.global_transform * mi.get_aabb() if mi.is_inside_tree() else mi.transform * mi.get_aabb()
			box = b if box.size == Vector3.ZERO else box.merge(b)
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s)
				if m is BaseMaterial3D:
					mats.append("%s(alpha=%d)" % [m.resource_name, m.transparency])
		print("%-28s size %s  %s" % [file, box.size.snapped(Vector3.ONE * 0.01), ", ".join(mats)])
		scene.free()
	quit()
