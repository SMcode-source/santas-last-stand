extends Node
## Saves the scenery built from code, ready-made, for the export (see Baked):
## `godot --headless --path . res://tools/bake.tscn`


func _ready() -> void:
	get_tree().quit(0 if Baked.bake_all() else 1)
