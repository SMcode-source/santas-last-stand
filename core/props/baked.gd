class_name Baked
extends RefCounted
## Scenery and meshes built from code (ToyBuilder and friends) take seconds to
## make in the web build, so the export makes them beforehand: tools/bake.tscn
## saves each recipe below to res://baked/, and the exported game just loads
## those files.
##
## Run from the project (editor, tools, tests), everything is built afresh, so
## an old file can never hide a code change. Pass `--baked` to use the files.

const DIR := "res://baked/"


## Name -> the static function that builds it (a Node3D or a Resource).
static func recipes() -> Dictionary:
	return {
		"title_camp": load("res://hello/hello_santa.gd").build_camp,
		"santa_fur": SantaModel.build_fur,
		"workshop_set": WorkshopSet.build,
		"village_set": VillageSet.build,
		"boardroom_set": BoardroomSet.build,
	}


## The scene called `recipe_name`: loaded if baked, built otherwise.
static func node(recipe_name: String) -> Node3D:
	var baked: Resource = _baked(recipe_name)
	if baked is PackedScene:
		var scene: Node3D = (baked as PackedScene).instantiate()
		for scattered: MultiMeshInstance3D in scene.find_children("*", "MultiMeshInstance3D", true, false):
			_fill(scattered)
		return scene
	return recipes()[recipe_name].call()


## The resource (e.g. a mesh) called `recipe_name`: loaded if baked, built otherwise.
static func resource(recipe_name: String) -> Resource:
	var baked: Resource = _baked(recipe_name)
	return baked if baked != null else recipes()[recipe_name].call()


static func _baked(recipe_name: String) -> Resource:
	if not (OS.has_feature("template") or "--baked" in OS.get_cmdline_user_args()):
		return null
	for extension in [".scn", ".res"]:
		var path: String = DIR + recipe_name + extension
		if ResourceLoader.exists(path):
			return load(path)
	return null


## Builds every recipe and saves it in DIR. Returns false if any failed.
static func bake_all() -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var ok := true
	for recipe_name: String in recipes():
		var start := Time.get_ticks_msec()
		var made: Variant = recipes()[recipe_name].call()
		var path: String
		var saved: Resource
		if made is Node:
			_prepare(made, made)
			var scene := PackedScene.new()
			if scene.pack(made) != OK:
				ok = false
			saved = scene
			path = DIR + recipe_name + ".scn"
		else:
			saved = made
			path = DIR + recipe_name + ".res"
		var error := ResourceSaver.save(saved, path, ResourceSaver.FLAG_COMPRESS)
		if made is Node:
			(made as Node).free()
		if error != OK:
			push_error("Could not bake %s: %s" % [recipe_name, error_string(error)])
			ok = false
		else:
			print("Baked %s in %d ms (%d KB)" % [path, Time.get_ticks_msec() - start,
					FileAccess.get_file_as_bytes(path).size() / 1024])
	return ok


## Puts back the instances of a scatter (see WinterProps.scatter), which are
## saved as a list of transforms.
static func _fill(scattered: MultiMeshInstance3D) -> void:
	if not scattered.has_meta("transforms"):
		return
	var transforms: Array = scattered.get_meta("transforms")
	var multi := scattered.multimesh
	multi.instance_count = transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i, transforms[i])


## Readies a built tree for saving: every node belongs to the root, groups
## are kept, and build-time notes on meshes (plain objects that cannot be
## saved) are dropped.
static func _prepare(node: Node, root: Node) -> void:
	if node != root:
		node.owner = root
	for group in node.get_groups():
		if not String(group).begins_with("_"):
			node.remove_from_group(group)
			node.add_to_group(group, true)
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for key in mesh.get_meta_list():
			mesh.remove_meta(key)
	if node is MultiMeshInstance3D and node.has_meta("transforms"):
		# Saved as the list of transforms instead; _fill() puts them back.
		(node as MultiMeshInstance3D).multimesh.instance_count = 0
	for child in node.get_children():
		_prepare(child, root)
