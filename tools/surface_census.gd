extends SceneTree
## Prints each surface's material for the meshes named on the command line:
## `godot --headless --path . --script res://tools/surface_census.gd -- LogCabin/Mesh FirTree/Mesh`

func _initialize() -> void:
	var scene: Node = load("res://hello/hello_santa.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	for path in OS.get_cmdline_user_args():
		var node := scene.get_node_or_null(path) as MeshInstance3D
		if node == null:
			continue
		print("== ", path)
		for s in node.mesh.get_surface_count():
			var mat := node.get_active_material(s)
			var desc := ""
			if mat is StandardMaterial3D:
				desc = "std %s tint=%s" % [mat.albedo_texture.resource_path if mat.albedo_texture else "-", mat.albedo_color.to_html(false)]
			elif mat is ShaderMaterial:
				var tex = mat.get_shader_parameter("albedo_tex")
				desc = "%s %s tint=%s" % [mat.shader.resource_path.get_file(), tex.resource_path if tex else "", mat.get_shader_parameter("albedo_color")]
			print("  %d  %5d tris  %s" % [s, node.mesh.surface_get_array_index_len(s) / 3, desc])
	quit()
