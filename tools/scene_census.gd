extends SceneTree
## Lists every visible mesh in the title scene with its triangle count and
## surface count, biggest first: `godot --path . --script res://tools/scene_census.gd`

func _initialize() -> void:
	var scene: Node = load("res://hello/hello_santa.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var rows := []
	for node in scene.find_children("*", "GeometryInstance3D", true, false):
		var tris := 0
		var surfaces := 0
		var count := 1
		var mesh: Mesh
		if node is MeshInstance3D:
			mesh = node.mesh
		elif node is MultiMeshInstance3D and node.multimesh:
			mesh = node.multimesh.mesh
			count = node.multimesh.visible_instance_count if node.multimesh.visible_instance_count >= 0 else node.multimesh.instance_count
		if mesh:
			surfaces = mesh.get_surface_count()
			for s in surfaces:
				var arrays := mesh.surface_get_arrays(s)
				var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] else PackedInt32Array()
				tris += (idx.size() if idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		var vis: bool = node.is_visible_in_tree()
		rows.append([tris * count, surfaces, count, str(scene.get_path_to(node)), vis, node.cast_shadow])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	var total := 0
	for r in rows:
		total += r[0] if r[4] else 0
	print("TOTAL visible tris ", total, " nodes ", rows.size())
	for r in rows.slice(0, 60):
		print("%8d tris  %2d surf  x%-4d %s %s shadow=%d" % [r[0], r[1], r[2], r[3], "" if r[4] else "(hidden)", r[5]])
	quit()
