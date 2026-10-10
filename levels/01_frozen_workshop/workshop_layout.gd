class_name WorkshopLayout
extends RefCounted
## Where everything in Level 1 stands, shared by the set builder and the level
## script. North is -z. The workshop sits on a stone terrace in the middle of
## a frozen bay; thin ice lies five metres below every edge. Three wings run
## out over the ice to the furnaces (west, east, north), and the Clock Tower
## stands at the north end of the terrace.

## The thin ice: fall below FALL_Y and Santa has gone through it.
const ICE_Y := -5.0
const FALL_Y := -3.0
## A drop this high or more is a fatal fall (from the tower or a roof).
const FATAL_DROP := 6.5

## The terrace: x -20..20, z -23..17, its top at y 0.
const TERRACE_MIN := Vector2(-20, -23)
const TERRACE_MAX := Vector2(20, 17)

const START := Vector3(0, 0.05, 11)

const TOWER := Vector3(0, 0, -11)
const TOWER_HALF := 3.5
const TOWER_TOP := 26.0

## The climb round the tower: 11 sloping walkways, corner to corner, rising
## from the plaza (south-west corner) to the top (north-west corner).
const CLIMB_FACES := 11
const CLIMB_OUT := 4.5
const WALK_WIDTH := 2.0
const CORNERS := [Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1)]
## How each walkway is built: a plain ramp, a ramp with a gap to jump, three
## stepping beams, or end stubs with a moving platform between.
const FACE_KINDS := ["ramp", "gap", "ramp", "beams", "ramp", "mover", "gap", "ramp", "beams", "mover", "ramp"]

## The furnaces at the end of each wing, and the way each one faces.
const FURNACES := {
	"west": [Vector3(-57.3, 1.5, 2), 90.0],
	"east": [Vector3(52.5, 1.5, 2), -90.0],
	"north": [Vector3(0, 1.5, -61.2), 0.0],
}
## Order of the pipes in the boss fight (FrostFight pipe index).
const PIPE_ORDER := ["west", "east", "north"]

## The arena on top of the tower: three gears round the central column, one
## below each pipe. Angles in degrees round the tower, 0 = east, 90 = south;
## in pipe order they go clockwise seen from above, the way the hand turns.
const GEAR_ANGLES := [30.0, 90.0, 180.0]
const GEAR_OUT := 6.6
const GEAR_RADIUS := 3.0
const PIPE_OUT := 10.2

## Overhead pipe runs, from each furnace's flue to where the pipe enters the
## tower (at a corner, between the climb's walkways).
const PIPE_RUNS := {
	"west": [Vector3(-58.4, 3.4, 2), Vector3(-58.4, 10.5, 2), Vector3(-22, 10.5, 2),
			Vector3(-8, 10.5, -16.5), Vector3(-3.2, 10.5, -14.6)],
	"east": [Vector3(53.6, 3.4, 2), Vector3(53.6, 6.6, 2), Vector3(8, 6.6, 2),
			Vector3(5.6, 6.6, -5.6), Vector3(3.2, 6.6, -7.4)],
	"north": [Vector3(0, 3.4, -62.3), Vector3(0, 8.6, -62.3), Vector3(4.9, 8.6, -56),
			Vector3(4.9, 8.6, -18.6), Vector3(3.2, 8.6, -14.6)],
}

## Workshop halls round the terrace edge: centre (on the ground) and size.
const HALLS := [
	[Vector3(-9.5, 0, 14.5), Vector3(11, 7, 5)], [Vector3(9.5, 0, 14.5), Vector3(11, 7, 5)],
	[Vector3(-17.5, 0, -9), Vector3(5, 7, 10)], [Vector3(-17.5, 0, 10), Vector3(5, 7, 6)],
	[Vector3(17.5, 0, -9), Vector3(5, 7, 10)], [Vector3(17.5, 0, 10), Vector3(5, 7, 6)],
	[Vector3(-12, 0, -20.5), Vector3(11, 7, 5)], [Vector3(12, 0, -20.5), Vector3(11, 7, 5)],
]

## Fires to warm up at: position and how far their warmth reaches.
const BRAZIERS := [
	[Vector3(-15.5, 0, -1.5), 3.2], [Vector3(15.5, 0, -1.5), 3.2], [Vector3(-3.6, 0, -19.5), 3.2],
	[Vector3(5.0, 0, 6.0), 3.0],
	[Vector3(-35.5, 1.0, 4.2), 2.6], [Vector3(38.0, 2.6, 4.0), 2.6], [Vector3(0.6, 0.0, -35.4), 2.4],
]

## The north wing is out in the wind: the cold bites harder there.
const NORTH_WIND_Z := -23.5


## A corner of the climb (0 = the plaza, CLIMB_FACES = the top).
static func corner(i: int) -> Vector3:
	var c: Vector2 = CORNERS[i % 4]
	return TOWER + Vector3(c.x * CLIMB_OUT, climb_rise() * i, c.y * CLIMB_OUT)


static func climb_rise() -> float:
	return TOWER_TOP / CLIMB_FACES


## Where gear `i` sits (its top surface, at the middle).
static func gear_centre(i: int) -> Vector3:
	var a := deg_to_rad(GEAR_ANGLES[i])
	return TOWER + Vector3(cos(a) * GEAR_OUT, TOWER_TOP + 0.05, sin(a) * GEAR_OUT)


static func direction(angle_deg: float) -> Vector3:
	var a := deg_to_rad(angle_deg)
	return Vector3(cos(a), 0, sin(a))
