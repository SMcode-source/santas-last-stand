class_name Cast
## The characters made on Meshy, each with the build and bearing that suits
## them. Levels ask for a character by name: `Cast.make("scrooge")`.

const MODELS := {
	"scrooge": preload("res://assets/characters/scrooge.glb"),
}

## [arm spread (degrees), elbow bend (degrees), stoop, restless]
const BEARING := {
	"scrooge": [5.0, 18.0, 0.55, 0.6],
}

## Joints Meshy's auto-rig misplaced, moved to where they belong (see
## CastModel.joint_fixes). Scrooge's left ankle sat 6 cm up his shin.
const JOINTS := {
	"scrooge": {"LeftFoot": Vector3(0.146, 0.075, 0.016)},
}


static func make(character: String, seed := 0) -> CastModel:
	var model := CastModel.new(MODELS[character], seed)
	model.name = character.capitalize().replace(" ", "")
	var bearing: Array = BEARING.get(character, [8.0, 14.0, 0.0, 1.0])
	model.arm_spread = deg_to_rad(bearing[0])
	model.elbow_bend = deg_to_rad(bearing[1])
	model.stoop = bearing[2]
	model.restless = bearing[3]
	model.joint_fixes = JOINTS.get(character, {})
	return model
