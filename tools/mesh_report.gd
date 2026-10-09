extends SceneTree
## Prints triangle counts per top-level node of the title backdrop.
## Run: godot --headless --script res://tools/mesh_report.gd

func _initialize() -> void:
	var scene: Node = load("res://hello/hello_santa.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var totals := {}
	var counts := {}
	for child in scene.get_children():
		var key: String = child.get_child(0).name if child.name.begins_with("@") and child.get_child_count() > 0 else String(child.name)
		if child is SantaToy or child is SantaModel:
			key = "Santa"
		totals[key] = totals.get(key, 0) + _tris(child)
		counts[key] = counts.get(key, 0) + 1
	var keys := totals.keys()
	keys.sort_custom(func(a, b): return totals[a] > totals[b])
	for k in keys:
		if totals[k] > 0:
			print("%-14s x%-3d %7d tris" % [k, counts[k], totals[k]])
	quit()


func _tris(node: Node) -> int:
	var n := 0
	if node is MeshInstance3D and node.mesh:
		for s in node.mesh.get_surface_count():
			var a: Array = node.mesh.surface_get_arrays(s)
			n += (a[Mesh.ARRAY_INDEX].size() if a[Mesh.ARRAY_INDEX] else a[Mesh.ARRAY_VERTEX].size()) / 3
	if node is MultiMeshInstance3D and node.multimesh and node.multimesh.mesh:
		var mesh: Mesh = node.multimesh.mesh
		for s in mesh.get_surface_count():
			var a: Array = mesh.surface_get_arrays(s)
			n += (a[Mesh.ARRAY_INDEX].size() if a[Mesh.ARRAY_INDEX] else a[Mesh.ARRAY_VERTEX].size()) / 3 * node.multimesh.instance_count
	for c in node.get_children():
		n += _tris(c)
	return n
