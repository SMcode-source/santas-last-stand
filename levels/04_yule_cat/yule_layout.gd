extends RefCounted
## Where everything is in Level 4, "The Yule Cat Prowls": Grýla's valley in
## Iceland. North is -z. The sleigh lands at the south end; the lower village
## of turf houses runs up a lane to the square, where the Yule Cat prowls;
## above it the upper village, the Red Caps' barracks to the east, and the
## cliff with Grýla's cave at the top. The old sheep track runs up the west
## side behind a turf wall, its gate barred until the Lads mutiny.
## Shared by the set builder, the level script and the tests.

## The walkable valley floor (flat, y = 0).
const BOUNDS := Rect2(-31.0, -60.0, 62.0, 112.0)

const SLEIGH_PARK := Vector3(6.0, 0.0, 45.0)
const SANTA_START := Vector3(3.0, 0.0, 40.0)
## Reaching this close to the sleigh ends the chase.
const SLEIGH_REACH := 3.6

const SQUARE := Vector3(0.0, 0.0, 0.0)
const SQUARE_RADIUS := 9.5
const POND_RADIUS := 3.6

## The cliff face, the cave mouth in it, and the chamber behind.
const CLIFF_Z := -42.0
const CLIFF_HEIGHT := 17.0
const MOUTH_HALF := 3.4
const MOUTH_HEIGHT := 5.2
const CHAMBER := Rect2(-9.0, -60.0, 18.0, 16.0)
const CHAMBER_HEIGHT := 7.0
const CAGE := Vector3(-5.0, 0.0, -55.0)
const GRYLA_SEAT := Vector3(5.2, 0.0, -56.5)
const CAULDRON := Vector3(2.4, 0.0, -54.2)
const HEADSHOT := Vector3(-8.85, 2.3, -49.0)
## Grýla on the clifftop for the intro, and where the Cat waits for the chase.
const CLIFF_TOP := Vector3(0.0, CLIFF_HEIGHT, -41.8)
const CAT_LEAP := Vector3(-4.0, CLIFF_HEIGHT, -41.8)
## Inside this, Santa is in the cave (the checkpoint and the chase start).
const CAVE_ENTRY_Z := -44.5

## The barracks yard (a palisade with a gate on its west side) and the
## open-fronted shed where the Red Caps sleep.
const YARD := Rect2(12.0, -32.0, 15.0, 22.0)
const YARD_GATE := Vector3(12.0, 0.0, -20.0)
const YARD_GATE_HALF := 2.0
const SHED := Rect2(20.5, -29.5, 5.0, 18.0)
const BUNKS := [Vector3(23.2, 0.0, -27.0), Vector3(23.2, 0.0, -24.0), Vector3(23.2, 0.0, -21.0),
		Vector3(23.2, 0.0, -18.0), Vector3(23.2, 0.0, -15.0), Vector3(23.2, 0.0, -12.0)]
const BUNK_TOP := 0.55
const YARD_FIRE := Vector3(16.0, 0.0, -21.0)

## The sheep track: behind a turf wall at x = -21, gate at the south end.
const TRACK_WALL_X := -21.0
const TRACK_SOUTH := 31.0
const TRACK_NORTH := -34.0
const SHEEP_GATE := Vector3(-25.5, 0.0, 31.0)
const SHEEP_GATE_HALF := 4.5

## Turf houses: [position, yaw (degrees, 0 = door facing +z), width, depth].
const HOUSES := [
	[Vector3(-7.5, 0, 30.0), 90.0, 6.0, 8.0],
	[Vector3(9.0, 0, 27.0), -90.0, 6.0, 8.0],
	[Vector3(-9.5, 0, 17.5), 90.0, 7.0, 9.0],
	[Vector3(9.5, 0, 15.0), -90.0, 6.0, 7.5],
	[Vector3(-17.2, 0, 24.0), 0.0, 5.0, 6.5],
	[Vector3(18.0, 0, 22.0), 180.0, 6.0, 7.0],
	[Vector3(-10.5, 0, -14.0), 90.0, 7.0, 10.0],
	[Vector3(-11.0, 0, -28.0), 90.0, 6.0, 8.0],
	[Vector3(8.0, 0, -32.0), 0.0, 6.0, 6.0],
	[Vector3(17.0, 0, 8.0), -90.0, 5.0, 6.0],
]
## Turf houses: wall height, roof rise per metre out from the ridge, and how
## far the rounded back of the mound reaches past the walls.
const HOUSE_WALL := 1.75
const ROOF_SLOPE := 0.75
const HOUSE_BACK := 0.9
## Door-Slammer's house (index into HOUSES) and his door.
const SLAMMER_HOUSE := 3
const SLAMMER_DOOR := Vector3(5.2, 0.0, 15.0)

## Lanterns hung by doors and on posts: warm pools of light.
const LANTERNS := [Vector3(-2.9, 0, 31.6), Vector3(4.3, 0, 25.2), Vector3(-4.2, 0, 15.6), Vector3(5.1, 0, 18.6),
		Vector3(-4.8, 0, -11.5), Vector3(-6.2, 0, -25.0), Vector3(3.6, 0, -38.5), Vector3(-3.6, 0, -38.5)]
## Fish-drying racks, woodpiles, barrels and carts: cover to hide behind.
const RACKS := [Vector3(-7.0, 0, -5.5), Vector3(6.5, 0, 7.5)]
const WOODPILES := [[Vector3(-13.0, 0, 33.5), 0.0], [Vector3(11.5, 0, 34.5), 0.0], [Vector3(-14.5, 0, -6.0), 90.0],
		[Vector3(4.5, 0, -22.0), 0.0]]
const BARRELS := [Vector3(-6.5, 0, 3.8), Vector3(-7.2, 0, 4.9), Vector3(13.0, 0, 18.5), Vector3(-4.2, 0, -33.0),
		Vector3(11.5, 0, -6.0)]
const CARTS := [[Vector3(4.2, 0, 34.0), 20.0], [Vector3(-4.0, 0, 21.5), -15.0], [Vector3(9.5, 0, -14.0), 80.0]]
const BOULDERS := [Vector3(-3.5, 0, 9.5), Vector3(13.5, 0, -2.0), Vector3(-13.0, 0, 8.0), Vector3(2.0, 0, -18.0),
		Vector3(-16.0, 0, -34.0), Vector3(16.0, 0, -37.0), Vector3(-25.0, 0, -5.0), Vector3(-26.5, 0, 12.0)]

## Where the treasures Grýla took lie.
const TREASURES := {
	"spoon": Vector3(-13.0, 0, 31.5),
	"skyr": Vector3(13.4, 0, 21.0),
	"candle": Vector3(-7.0, 0, -4.6),
	"pot": Vector3(13.2, 0, 5.0),
	"bowl": Vector3(-6.8, 0, -21.0),
	"sausage": Vector3(6.5, 0, -26.0),
}

## The Yule Lads. "post": where he stands (or the first point of "route");
## "look": the way he faces when standing (degrees, 0 = +z); "range"/"angle"
## of sight; "speed"/"turn" when walking; "glance": [seconds looking, seconds
## not] for the ones who keep ducking away; "hear": how far he hears
## footsteps and thumps; "smell": noses Santa out this close, unseen;
## "height": where his eyes are; "scale": his size.
const LADS := {
	"stubby": {"route": [Vector3(0.5, 0, 33.5), Vector3(0.5, 0, 23.0)], "range": 6.0, "angle": 50.0, "speed": 1.4, "scale": 0.72},
	"window_peeper": {"post": Vector3(-2.8, 0, 28.2), "look": 90.0, "glance": [2.2, 5.0], "back": -90.0, "range": 9.0, "angle": 40.0},
	"spoon_licker": {"route": [Vector3(4.0, 0, 19.5), Vector3(4.0, 0, 31.5), Vector3(14.3, 0, 32.0), Vector3(14.3, 0, 20.5)],
			"range": 8.0, "angle": 45.0, "speed": 1.5, "hear": 14.0, "eager": true},
	"door_slammer": {"route": [Vector3(4.6, 0, 12.5), Vector3(4.6, 0, 18.0)], "range": 8.0, "angle": 45.0, "speed": 1.3, "door": true},
	"skyr_gobbler": {"post": Vector3(-4.5, 0, 13.0), "look": 10.0, "glance": [2.5, 4.5], "range": 7.0, "angle": 45.0},
	"sheep_clod": {"route": [Vector3(-13.1, 0, 22.5), Vector3(-13.1, 0, 35.0)], "range": 8.5, "angle": 40.0, "speed": 0.9, "turn": 0.6},
	"pot_scraper": {"post": Vector3(6.0, 0, -3.5), "look": -90.0, "glance": [2.0, 4.0], "range": 9.0, "angle": 45.0},
	"bowl_licker": {"post": Vector3(-6.0, 0, 6.0), "look": 90.0, "glance": [3.0, 4.0], "hide": true, "range": 8.0, "angle": 50.0},
	"candle_stealer": {"route": [Vector3(5.5, 0, 0.0), Vector3(0.0, 0, -5.5), Vector3(-5.5, 0, 0.0), Vector3(0.0, 0, 5.5)],
			"range": 10.0, "angle": 45.0, "speed": 1.2, "candle": true},
	"sausage_swiper": {"post": Vector3(-6.0, 4.4, -14.0), "look": 90.0, "range": 13.0, "angle": 35.0, "height": 5.5, "sweep": 35.0},
	"doorway_sniffer": {"post": Vector3(-6.3, 0, -26.5), "look": 90.0, "range": 7.0, "angle": 45.0, "smell": 3.5, "sweep": 50.0},
	"gully_gawk": {"post": Vector3(4.5, 0, -37.0), "look": -10.0, "range": 11.0, "angle": 30.0, "sweep": 25.0},
	"meat_hook": {"route": [Vector3(14.5, 0, -12.5), Vector3(14.5, 0, -29.5), Vector3(18.5, 0, -29.5), Vector3(18.5, 0, -12.5)],
			"range": 8.0, "angle": 45.0, "speed": 1.6},
}

## The Yule Cat's prowl round the square and up the lane, with pauses to sit.
const CAT_ROUTE := [Vector3(10.5, 0, 9.0), Vector3(11.0, 0, -9.0), Vector3(2.0, 0, -12.0), Vector3(1.5, 0, -24.0),
		Vector3(-2.0, 0, -9.0), Vector3(-11.0, 0, -7.5), Vector3(-11.0, 0, 9.0), Vector3(0.0, 0, 12.0)]
const CAT_SITS := [2, 3, 6]


## Torches on the chamber walls.
const TORCHES := [Vector3(-8.5, 2.6, -46.6), Vector3(8.5, 2.6, -50.0), Vector3(-8.5, 2.6, -57.0)]


## The valley floor (flat) and the slopes and fells rising round it.
static func land_height(x: float, z: float, noise: FastNoiseLite) -> float:
	var out_x := maxf(0.0, absf(x) - 31.0)
	var out_z := maxf(0.0, z - 52.0) + maxf(0.0, -60.0 - z) * 0.4
	var out := Vector2(out_x, out_z).length()
	if out <= 0.0:
		return 0.0
	var rise := smoothstep(0.0, 22.0, out) * 16.0 + out * 0.15
	return rise + noise.get_noise_2d(x, z) * rise * 0.3


## Where the ridge of a turf house `width` across is.
static func ridge_height(width: float) -> float:
	return HOUSE_WALL + width / 2.0 * ROOF_SLOPE


## Inside the walkable valley (any wall aside).
static func in_bounds(p: Vector3) -> bool:
	return BOUNDS.has_point(Vector2(p.x, p.z))


static func in_yard(p: Vector3) -> bool:
	return YARD.has_point(Vector2(p.x, p.z))
