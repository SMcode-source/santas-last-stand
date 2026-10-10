extends RefCounted
## Where everything is in Level 2, "Krampusnacht": an Alpine village on a
## plateau, its main street running north from the landing field to the
## church square, the church and its onion-domed bell tower at the north end
## of the square, and a lane west to the bridge over the gorge. The flight in
## comes up the valley from the south.
##
## Ground level in the village is y = 0. +z is south (towards the landing
## field), -x is west (towards the gorge).

## The village edge, where the plateau drops into the gorge...
const GORGE_EAST := -29.0
## ...and its far side.
const GORGE_WEST := -43.0
const GORGE_FLOOR := -30.0
## Below this Santa has fallen into the gorge.
const FALL_Y := -4.0

## Where Santa can walk: x from the gorge edge east, z north to south.
const BOUNDS := Rect2(-29.0, -46.0, 69.0, 110.0)

const BRIDGE_Z := -6.0
const BRIDGE_HALF := 1.6
## A sack carried this far west, over the bridge, is lost.
const ESCAPE_X := -45.5
## The far end of the bridge, as far as Santa may chase.
const BRIDGE_END_X := -46.5

const SANTA_START := Vector3(0.0, 0.0, 52.0)
const SLEIGH_PARK := Vector3(3.6, 0.0, 56.5)

const SQUARE := Vector3(0.0, 0.0, -6.0)
const SQUARE_RADIUS := 13.0
## Walking into the square (north of this) starts the scene at the church.
const SQUARE_ENTRY_Z := 9.0

const TOWER := Vector3(0.0, 0.0, -22.0)
const TOWER_HALF := 2.4
const TOWER_HEIGHT := 16.0
## Height of the belfry floor, where the bells hang behind the arches.
const BELFRY_Y := 12.0
## The church door at the foot of the tower, with the bell rope inside.
const DOOR := Vector3(0.0, 0.0, -19.2)
const NAVE := Vector3(0.0, 0.0, -31.4)
const NAVE_SIZE := Vector3(9.0, 7.6, 14.8)
## Krampus watches from the belfry ledge until the boss fight.
const PERCH := Vector3(0.0, 12.15, -18.9)
## Where he lands in the square to fight.
const ARENA_DROP := Vector3(0.0, 0.0, -11.0)

## The six sacked elves, hanging on ropes from the belfry ledge: the bottom
## of each sack.
const SACKS := [
	Vector3(-1.05, 6.2, -19.15), Vector3(1.05, 5.3, -19.15),
	Vector3(-2.75, 6.8, -20.9), Vector3(-2.75, 5.0, -23.0),
	Vector3(2.75, 5.8, -20.9), Vector3(2.75, 6.6, -23.0),
]

## Chalets: centre of the ground floor (y = 0), yaw (degrees; the front with
## the door and balcony faces the chalet's +z), width, depth, seed.
const CHALETS := [
	# The main street, west side facing east, then east side facing west.
	[Vector3(-10.8, 0, 44.0), 90.0, 7.0, 8.0, 1],
	[Vector3(-11.2, 0, 31.0), 90.0, 8.0, 9.0, 2],
	[Vector3(-10.6, 0, 18.5), 90.0, 7.0, 7.5, 3],
	[Vector3(10.8, 0, 41.0), -90.0, 7.5, 8.5, 4],
	[Vector3(11.0, 0, 27.5), -90.0, 8.0, 8.0, 5],
	[Vector3(10.6, 0, 15.0), -90.0, 7.0, 7.5, 6],
	# Round the square.
	[Vector3(-18.0, 0, 3.5), 70.0, 8.0, 8.0, 7],
	[Vector3(-16.5, 0, -18.0), 40.0, 8.0, 8.5, 8],
	[Vector3(17.0, 0, -2.0), -80.0, 8.5, 8.0, 9],
	[Vector3(16.0, 0, -17.5), -40.0, 8.0, 8.0, 10],
	# Further out.
	[Vector3(-22.0, 0, 26.0), 100.0, 7.0, 7.0, 11],
	[Vector3(24.0, 0, 33.0), -110.0, 7.5, 7.0, 12],
	[Vector3(27.0, 0, 8.0), -95.0, 7.0, 7.5, 13],
	[Vector3(-20.0, 0, -33.0), 20.0, 7.0, 7.0, 14],
	[Vector3(19.0, 0, -34.0), -15.0, 7.5, 7.0, 15],
]

## Christmas market stalls in the square: position and yaw (front faces +z).
const STALLS := [
	[Vector3(-9.5, 0, 1.5), 60.0], [Vector3(-10.5, 0, -10.0), 95.0],
	[Vector3(10.5, 0, -11.0), -95.0],
]
const CHRISTMAS_TREE := Vector3(8.8, 0.0, 2.6)

## Street lamps: they and every window are dark until the church bells ring.
const LAMPS := [
	Vector3(-5.2, 0, 45.0), Vector3(5.2, 0, 36.0), Vector3(-5.2, 0, 26.0), Vector3(5.2, 0, 16.0),
	Vector3(-8.0, 0, 6.0), Vector3(9.5, 0, -6.5), Vector3(-8.5, 0, -15.0), Vector3(-25.0, 0, -3.6),
]

## Krampus's helpers lying in wait along the main street.
const STREET_GUARDS := [Vector3(-2.5, 0, 34.0), Vector3(3.0, 0, 31.0), Vector3(-2.0, 0, 18.0), Vector3(3.5, 0, 14.0)]
## Two more that jump into the square when the sacks come down.
const SQUARE_GUARDS := [Vector3(-6.0, 0, -3.0), Vector3(6.5, 0, -8.0)]

## The way the helpers carry the sacks: from the foot of the tower, across
## the square, along the lane and over the bridge.
const ESCAPE_ROUTE := [Vector3(-9.0, 0, -5.0), Vector3(-24.0, 0, -6.0), Vector3(-29.5, 0, BRIDGE_Z),
	Vector3(-47.0, 0, BRIDGE_Z)]

## The flight in: the rail's points, from high over the Alps down the valley
## to the landing field.
const FLIGHT := [
	Vector3(0, 70, 1150), Vector3(60, 62, 1020), Vector3(20, 48, 900), Vector3(-50, 40, 790),
	Vector3(-20, 34, 680), Vector3(40, 44, 570), Vector3(60, 30, 470), Vector3(0, 24, 380),
	Vector3(-40, 30, 300), Vector3(-10, 20, 220), Vector3(10, 12, 150), Vector3(2, 6, 96),
	Vector3(0, 2.2, 60),
]


## The ground spot under sack `i`, a step out from the tower wall.
static func sack_ground(i: int) -> Vector3:
	var hang: Vector3 = SACKS[i]
	var out := Vector3(hang.x - TOWER.x, 0, hang.z - TOWER.z)
	if absf(out.x) > absf(out.z):
		out = Vector3(signf(out.x), 0, 0)
	else:
		out = Vector3(0, 0, signf(out.z))
	return Vector3(hang.x, 0, hang.z) + out * 0.5


## The whole way sack `i` is carried: out from the tower, then the route.
static func sack_route(i: int) -> PackedVector3Array:
	var start := sack_ground(i)
	var points := PackedVector3Array([start])
	if absf(start.x) > TOWER_HALF:
		# Round the side of the tower to the front.
		points.append(Vector3(signf(start.x) * 4.2, 0, -17.6))
	points.append(Vector3(-3.6, 0, -16.0))
	for p: Vector3 in ESCAPE_ROUTE:
		points.append(p)
	return points


## Height of the land outside the village at (x, z): the gorge, the valley
## floor and the hills rising either side of the way the flight comes in.
static func land_height(x: float, z: float, noise: FastNoiseLite) -> float:
	if x > GORGE_WEST + 0.6 and x < GORGE_EAST - 0.6 and absf(z) < 260.0:
		return GORGE_FLOOR
	var bumps := noise.get_noise_2d(x, z) * 3.0
	# The plateau the village stands on, flat.
	if x > GORGE_EAST - 0.6 and x < 70.0 and z > -70.0 and z < 90.0:
		return 0.0
	if x > GORGE_WEST - 30.0 and x <= GORGE_WEST + 0.6 and absf(z) < 120.0:
		return maxf(0.0, bumps * 0.3)
	# The valley: low along the flight's way in, rising to the sides.
	var axis := 0.0 if z < 100.0 else sin(z * 0.006) * 30.0
	var off := absf(x - axis)
	var rise := smoothstep(70.0, 240.0, off) * 45.0 + smoothstep(120.0, 320.0, -z) * 40.0
	return bumps + rise


## The church's tall windows down both sides of the nave: [centre, outward
## normal]. Dark until the bells ring, then they glow.
static func church_windows() -> Array:
	var windows := []
	for side: float in [-1.0, 1.0]:
		for dz: float in [-4.3, 0.0, 4.3]:
			windows.append([Vector3(NAVE.x + side * (NAVE_SIZE.x / 2.0 + 0.02), 3.5, NAVE.z + dz), Vector3(side, 0, 0)])
	return windows


## The flight's rail as a smooth curve through FLIGHT.
static func flight_curve() -> Curve3D:
	var curve := Curve3D.new()
	var count := FLIGHT.size()
	for i in count:
		var at: Vector3 = FLIGHT[i]
		var before: Vector3 = FLIGHT[maxi(i - 1, 0)]
		var after: Vector3 = FLIGHT[mini(i + 1, count - 1)]
		var span := (after - before) / 6.0
		curve.add_point(at, -span, span)
	curve.bake_interval = 2.0
	return curve
