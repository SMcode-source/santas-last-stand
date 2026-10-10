extends SceneTree
## Builds a baked recipe and reports how long it took and what it holds:
##   godot --headless --path . --script res://tools/set_check.gd -- --recipe=yule_valley_set

func _init() -> void:
	var recipe := "yule_valley_set"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--recipe="):
			recipe = arg.get_slice("=", 1)
	var start := Time.get_ticks_msec()
	var made: Node3D = Baked.recipes()[recipe].call()
	print("%s built in %d ms" % [recipe, Time.get_ticks_msec() - start])
	for child in made.get_children():
		var tris := 0
		for mi: MeshInstance3D in child.find_children("*", "MeshInstance3D", true, false) + ([child] if child is MeshInstance3D else []):
			if mi.mesh == null:
				continue
			for k in mi.mesh.get_surface_count():
				var arrays := mi.mesh.surface_get_arrays(k)
				var idx = arrays[Mesh.ARRAY_INDEX]
				tris += (idx.size() if idx != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		print("  %s: %d triangles, %d shapes" % [child.name, tris, child.find_children("*", "CollisionShape3D", true, false).size()])
	made.free()
	quit()
