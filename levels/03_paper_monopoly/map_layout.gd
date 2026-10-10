extends RefCounted
## Where everything in Level 3 sits: Scrooge & Co.'s boardroom, the long table,
## and the parchment world map laid out on it with paper-cut continents. The
## map is equirectangular: longitude across (x), latitude up the table (-z).

const TABLE_TOP := 0.8
const TABLE_SIZE := Vector2(4.3, 2.3)
const MAP_SIZE := Vector2(3.7, 1.46)
const LAT_TOP := 84.0
const LAT_BOTTOM := -58.0
## The paper continents stand this proud of the parchment.
const LAND_HEIGHT := 0.004
## Top of the map, where the pieces stand.
const MAP_Y := TABLE_TOP + 0.006

const ROOM := Vector3(9.0, 3.6, 7.6)
## Scrooge stands at the head of the table, across from Santa.
const SCROOGE_SPOT := Vector3(0.0, 0.0, -1.62)
const FIREPLACE := Vector3(0.0, 0.0, -3.8)
const DOOR := Vector3(4.5, 0.0, 1.6)
const WINDOWS := [Vector3(-4.5, 1.75, -1.6), Vector3(-4.5, 1.75, 1.6)]
const LAMP := Vector3(0.0, 2.35, 0.0)

## Map positions (longitude, latitude) of the pieces, in PaperMarket's order.
const TOWN_SPOTS := [Vector2(-2.0, 53.0), Vector2(-80.0, 40.5), Vector2(11.5, 50.0), Vector2(-46.5, -22.5),
	Vector2(139.0, 36.0)]
const SUPPLIER_SPOTS := [Vector2(-96.0, 55.0), Vector2(78.0, 22.5), Vector2(110.0, 33.0)]
const MILL_SPOTS := [Vector2(26.0, 67.0), Vector2(-19.0, 64.8), Vector2(-160.0, 64.5)]

## Camera: the whole table from Santa's end, and how it frames one piece.
const OVERVIEW_EYE := Vector3(0.0, 2.1, 2.05)
const OVERVIEW_LOOK := Vector3(0.0, TABLE_TOP, -0.22)
const FOCUS_OFFSET := Vector3(0.0, 0.62, 0.55)

## Paper-cut continents, (longitude, latitude), each a simple outline.
const CONTINENTS := {
	"north_america": [
		Vector2(-168, 66), Vector2(-162, 70), Vector2(-156, 71.3), Vector2(-140, 69.6), Vector2(-128, 70), Vector2(-115, 68.5),
		Vector2(-95, 72), Vector2(-85, 70), Vector2(-80, 63), Vector2(-94, 59), Vector2(-92, 57), Vector2(-82, 55),
		Vector2(-78, 52), Vector2(-79, 57), Vector2(-77, 62), Vector2(-70, 61), Vector2(-64, 60), Vector2(-61, 56),
		Vector2(-56, 52), Vector2(-60, 47), Vector2(-66, 45), Vector2(-70, 43), Vector2(-70, 41.5), Vector2(-74, 40.5),
		Vector2(-76, 37), Vector2(-75.5, 35), Vector2(-81, 31), Vector2(-80, 27), Vector2(-80.5, 25.2), Vector2(-82, 26.5),
		Vector2(-83, 29.5), Vector2(-89, 30.2), Vector2(-94, 29.5), Vector2(-97.5, 26), Vector2(-97.5, 22), Vector2(-95, 18.5),
		Vector2(-91, 19), Vector2(-87, 21.5), Vector2(-88, 16), Vector2(-84, 15), Vector2(-83.5, 11), Vector2(-80, 8.8),
		Vector2(-77.6, 8.2), Vector2(-79.5, 7.4), Vector2(-82, 8), Vector2(-85.5, 10.5), Vector2(-87.5, 13), Vector2(-92, 14.5),
		Vector2(-96, 15.8), Vector2(-105, 19.5), Vector2(-105.5, 22.5), Vector2(-109, 26), Vector2(-112.5, 29),
		Vector2(-114.7, 31.7), Vector2(-113, 29), Vector2(-111.5, 26.5), Vector2(-110, 23), Vector2(-112, 25.5),
		Vector2(-114.5, 28), Vector2(-116.5, 31.5), Vector2(-117.2, 32.6), Vector2(-120.5, 34.5), Vector2(-124, 40),
		Vector2(-124.5, 46), Vector2(-124, 48.5), Vector2(-127, 50.5), Vector2(-130.5, 54.5), Vector2(-135, 57.5),
		Vector2(-140, 59.8), Vector2(-147, 60.5), Vector2(-152, 59), Vector2(-158, 56.5), Vector2(-164, 54.5),
		Vector2(-158, 58.5), Vector2(-162, 60), Vector2(-166, 61.5), Vector2(-164.5, 63.5),
	],
	"greenland": [
		Vector2(-73, 78), Vector2(-60, 82), Vector2(-30, 83.5), Vector2(-20, 81.5), Vector2(-18, 77), Vector2(-22, 72),
		Vector2(-24, 69.5), Vector2(-32, 68), Vector2(-40, 65), Vector2(-43, 60), Vector2(-48, 61), Vector2(-52, 65),
		Vector2(-54, 69), Vector2(-56, 73), Vector2(-66, 76.5),
	],
	"cuba": [Vector2(-85, 21.8), Vector2(-82, 23.1), Vector2(-77, 21.8), Vector2(-74.2, 20.2), Vector2(-77.5, 19.9), Vector2(-81, 21.5)],
	"south_america": [
		Vector2(-77.5, 8), Vector2(-72, 12), Vector2(-64, 10.5), Vector2(-60, 8.5), Vector2(-52, 5), Vector2(-50, 0),
		Vector2(-44, -2.5), Vector2(-35, -5.5), Vector2(-35, -9), Vector2(-39, -13.5), Vector2(-39, -17.5), Vector2(-41, -22),
		Vector2(-48, -26), Vector2(-48.5, -28.5), Vector2(-53, -34), Vector2(-57, -35), Vector2(-56.5, -36.5), Vector2(-62, -39),
		Vector2(-65, -41), Vector2(-63.5, -42.8), Vector2(-67.5, -46), Vector2(-66, -48), Vector2(-69, -51), Vector2(-68.5, -52.5),
		Vector2(-70, -54.5), Vector2(-73, -53), Vector2(-75, -50), Vector2(-74, -45), Vector2(-73.5, -40), Vector2(-73.3, -37),
		Vector2(-71.5, -32), Vector2(-71.3, -28), Vector2(-70.3, -23), Vector2(-70.2, -18.5), Vector2(-75.5, -15), Vector2(-78, -11),
		Vector2(-81, -6), Vector2(-80, -2), Vector2(-80.5, 0.8), Vector2(-78, 2.5), Vector2(-77.3, 4),
	],
	"africa": [
		Vector2(-17, 21), Vector2(-16.5, 24), Vector2(-13, 27.5), Vector2(-9.5, 30), Vector2(-9.5, 32.5), Vector2(-6, 35.8),
		Vector2(-2, 35.2), Vector2(3, 36.8), Vector2(10, 37.3), Vector2(11, 35), Vector2(10.2, 33.8), Vector2(15, 32.3),
		Vector2(19.8, 30.5), Vector2(20, 32.8), Vector2(25, 32), Vector2(29, 30.9), Vector2(32.5, 31.3), Vector2(34.2, 27.5),
		Vector2(37, 22), Vector2(39, 16), Vector2(43, 12.5), Vector2(51, 11.8), Vector2(51, 10.5), Vector2(48, 5), Vector2(44, -1),
		Vector2(40.5, -3), Vector2(39, -8), Vector2(40.5, -11), Vector2(40.5, -15), Vector2(35, -20), Vector2(35.5, -24),
		Vector2(32.8, -26), Vector2(32.5, -29), Vector2(28.5, -32.8), Vector2(25, -34), Vector2(20, -34.8), Vector2(18.4, -34),
		Vector2(17.8, -31.5), Vector2(15.2, -27), Vector2(14.5, -23), Vector2(12, -18), Vector2(11.8, -15), Vector2(13.6, -11.5),
		Vector2(13.2, -9), Vector2(12, -6), Vector2(9.5, -2), Vector2(9.8, 3), Vector2(8.5, 4.5), Vector2(5.5, 4.3), Vector2(2, 6.3),
		Vector2(-2, 4.8), Vector2(-7.5, 4.5), Vector2(-11.5, 6.9), Vector2(-13.3, 9), Vector2(-15.2, 11), Vector2(-16.8, 13.5),
		Vector2(-17.4, 14.7), Vector2(-16.5, 16.5), Vector2(-16.2, 19.5),
	],
	"madagascar": [Vector2(49.3, -12), Vector2(50.5, -15.5), Vector2(49.5, -17.5), Vector2(47.3, -24.8), Vector2(45.2, -25.5),
		Vector2(43.7, -23.4), Vector2(44, -17), Vector2(46, -15.7)],
	"eurasia": [
		Vector2(-9.5, 43), Vector2(-9.3, 38.7), Vector2(-8.9, 37), Vector2(-6, 36.2), Vector2(-2, 36.7), Vector2(0, 38.8),
		Vector2(3.2, 42), Vector2(3, 43.3), Vector2(6, 43.1), Vector2(8.7, 44.4), Vector2(10.5, 43), Vector2(12, 41.5),
		Vector2(15.6, 38), Vector2(16.2, 38.2), Vector2(17, 39), Vector2(18.5, 40.2), Vector2(16, 41.4), Vector2(14, 42.7),
		Vector2(12.3, 44.2), Vector2(13.6, 45.7), Vector2(15, 44.5), Vector2(17.5, 43), Vector2(19.5, 41.8), Vector2(19.5, 40),
		Vector2(21, 38.5), Vector2(22.5, 36.5), Vector2(23, 38), Vector2(24, 40.5), Vector2(26, 40.6), Vector2(27, 37.5),
		Vector2(30, 36.3), Vector2(36, 36.5), Vector2(35.8, 34.5), Vector2(34.3, 31.3), Vector2(34.9, 29.5), Vector2(35, 28),
		Vector2(39, 21.5), Vector2(42.8, 14.8), Vector2(43.5, 12.7), Vector2(45, 12.9), Vector2(49, 14.2), Vector2(52.2, 15.8),
		Vector2(55.5, 17.5), Vector2(57.8, 19), Vector2(59.8, 22.5), Vector2(58.5, 23.6), Vector2(56.4, 24.8), Vector2(56.3, 26.3),
		Vector2(54, 24.2), Vector2(51.5, 24.5), Vector2(50.8, 25.8), Vector2(50, 26.8), Vector2(48.5, 29.8), Vector2(50.5, 29.5),
		Vector2(54, 26.7), Vector2(57, 25.7), Vector2(61.5, 25.2), Vector2(66.5, 25.4), Vector2(68.5, 23.5), Vector2(70, 21),
		Vector2(72.8, 19), Vector2(73.5, 16), Vector2(74.8, 12.8), Vector2(76.5, 8.6), Vector2(77.5, 8), Vector2(78.2, 9),
		Vector2(80, 10.3), Vector2(80.2, 13), Vector2(80.3, 15.8), Vector2(82.3, 17), Vector2(86.5, 20), Vector2(87, 21.6),
		Vector2(89, 22), Vector2(91.5, 22.5), Vector2(92.3, 20.5), Vector2(94.3, 16), Vector2(97.5, 16.5), Vector2(98.5, 13),
		Vector2(98.5, 9), Vector2(100.4, 4), Vector2(103.4, 1.3), Vector2(104.3, 1.4), Vector2(103.5, 4), Vector2(102.3, 6.2),
		Vector2(100.4, 7.3), Vector2(100, 12.5), Vector2(102.5, 12), Vector2(104.8, 8.6), Vector2(106.8, 10.4), Vector2(109.2, 12),
		Vector2(108.8, 15.4), Vector2(106.5, 18), Vector2(106, 20), Vector2(108, 21.6), Vector2(110.4, 20.4), Vector2(113, 22.2),
		Vector2(117, 23.5), Vector2(119.5, 26), Vector2(121.8, 30.5), Vector2(120.8, 32.6), Vector2(119.2, 35), Vector2(122.5, 37.2),
		Vector2(121, 37.7), Vector2(118.8, 37.4), Vector2(118, 38.6), Vector2(121.6, 40.9), Vector2(124.3, 39.9), Vector2(126, 37.6),
		Vector2(126.5, 34.6), Vector2(129.3, 35.3), Vector2(129.5, 37), Vector2(128.3, 38.6), Vector2(130.5, 42.3), Vector2(133, 42.8),
		Vector2(137, 45), Vector2(140.4, 48.5), Vector2(141.4, 52.3), Vector2(137, 54), Vector2(135, 54.7), Vector2(140.5, 57.7),
		Vector2(143.3, 59.3), Vector2(150, 59.6), Vector2(155, 59.3), Vector2(156.7, 61.5), Vector2(160, 61.7), Vector2(156, 57.5),
		Vector2(156.7, 51), Vector2(160, 54), Vector2(162.5, 56.4), Vector2(163.3, 59), Vector2(167, 60.3), Vector2(172, 60.8),
		Vector2(179, 62.3), Vector2(180, 65), Vector2(180, 68.8), Vector2(175, 69.8), Vector2(170, 70.1), Vector2(160, 69.6),
		Vector2(150, 71), Vector2(140, 72.5), Vector2(130, 71), Vector2(128, 72.5), Vector2(118, 73.6), Vector2(113, 73.8),
		Vector2(110, 76.8), Vector2(104, 77.7), Vector2(95, 76), Vector2(88, 75.4), Vector2(80, 72.5), Vector2(75, 72.8),
		Vector2(68, 76.5), Vector2(66, 70), Vector2(60, 68.8), Vector2(53, 68.3), Vector2(44, 68.5), Vector2(40.5, 64.5),
		Vector2(37, 66), Vector2(42, 67.7), Vector2(35, 69.2), Vector2(28, 71), Vector2(20, 70.1), Vector2(14, 67.5),
		Vector2(12, 64.5), Vector2(5.2, 62), Vector2(5, 58.7), Vector2(7.5, 58), Vector2(10.5, 59.3), Vector2(11.5, 58.2),
		Vector2(12.5, 56.3), Vector2(10.6, 57.7), Vector2(8.2, 56.8), Vector2(8.6, 53.5), Vector2(4.8, 53), Vector2(3.6, 51.4),
		Vector2(1.6, 50.9), Vector2(-1.4, 49.6), Vector2(-1.9, 48.7), Vector2(-4.6, 48.4), Vector2(-1.2, 46), Vector2(-1.6, 43.4),
		Vector2(-8, 43.7),
	],
	"britain": [
		Vector2(-5.7, 50), Vector2(-3, 50.6), Vector2(1.4, 51.2), Vector2(1.7, 52.7), Vector2(0.2, 53.5), Vector2(-1.3, 54.7),
		Vector2(-2, 55.9), Vector2(-3, 56), Vector2(-1.8, 57.5), Vector2(-3.3, 58.6), Vector2(-5, 58.6), Vector2(-6.2, 56.6),
		Vector2(-5.6, 55.3), Vector2(-4.8, 54.8), Vector2(-3.2, 54.5), Vector2(-3, 53.4), Vector2(-4.6, 53.3), Vector2(-4.2, 52.3),
		Vector2(-5.2, 51.7), Vector2(-3.4, 51.4),
	],
	"ireland": [Vector2(-6, 52), Vector2(-6.2, 53.8), Vector2(-5.5, 54.6), Vector2(-7.3, 55.3), Vector2(-8.5, 54.4),
		Vector2(-10, 54.2), Vector2(-9.8, 53.2), Vector2(-10.3, 51.8), Vector2(-8, 51.6)],
	"iceland": [Vector2(-24, 65.5), Vector2(-22, 66.5), Vector2(-16, 66.5), Vector2(-13.5, 65.2), Vector2(-15, 64.2),
		Vector2(-19, 63.4), Vector2(-22.5, 63.8)],
	"honshu": [
		Vector2(130, 31.5), Vector2(131.5, 31.3), Vector2(132, 33.8), Vector2(135, 33.6), Vector2(136.8, 34.4), Vector2(139.8, 35),
		Vector2(140.9, 36.9), Vector2(141.5, 39.5), Vector2(141.5, 41.4), Vector2(140.2, 41.5), Vector2(140, 40), Vector2(139.8, 38.5),
		Vector2(138.5, 37.3), Vector2(136.8, 37), Vector2(136, 35.8), Vector2(133.2, 35.6), Vector2(131, 34.4), Vector2(130, 33.4),
	],
	"hokkaido": [Vector2(140, 41.8), Vector2(141.2, 42), Vector2(143.3, 42), Vector2(145.5, 43.3), Vector2(144.3, 44.1),
		Vector2(141.7, 45.4), Vector2(141.4, 43.4), Vector2(140, 42.6)],
	"borneo": [Vector2(109, 1.5), Vector2(111, 1.8), Vector2(114, 4.5), Vector2(117, 7), Vector2(119, 5), Vector2(117.8, 1),
		Vector2(116, -3.8), Vector2(113, -3.3), Vector2(110.2, -2.9)],
	"sumatra": [Vector2(95.3, 5.6), Vector2(98.5, 3.5), Vector2(103.8, -1), Vector2(106, -3), Vector2(106, -5.8), Vector2(104.5, -5.9),
		Vector2(101, -2.5), Vector2(98.5, 1.5)],
	"new_guinea": [Vector2(131, -1), Vector2(135, -3.3), Vector2(138, -1.6), Vector2(141, -2.6), Vector2(145.8, -5), Vector2(150, -10.5),
		Vector2(147, -10), Vector2(143, -9), Vector2(138.5, -8.3), Vector2(137, -5), Vector2(132.5, -4)],
	"australia": [
		Vector2(113.5, -22), Vector2(114, -26.5), Vector2(115, -34), Vector2(118, -35), Vector2(123.5, -33.9), Vector2(129, -31.7),
		Vector2(131.5, -31.5), Vector2(135, -34.8), Vector2(138, -35.5), Vector2(140, -38), Vector2(144, -38.3), Vector2(146.3, -39.1),
		Vector2(150, -37.5), Vector2(150.8, -34.5), Vector2(153.2, -30), Vector2(153, -25), Vector2(149, -21), Vector2(145.4, -15),
		Vector2(143.5, -14), Vector2(142.5, -10.7), Vector2(141.5, -13.5), Vector2(141.5, -17), Vector2(140, -17.7), Vector2(137, -16),
		Vector2(135.5, -14.7), Vector2(136.8, -12.2), Vector2(132.6, -11.5), Vector2(130, -13), Vector2(129.5, -15), Vector2(126.5, -14),
		Vector2(122.3, -17.5), Vector2(119, -20), Vector2(116.7, -20.6),
	],
	"new_zealand_north": [Vector2(172.7, -34.4), Vector2(174.7, -37), Vector2(178.5, -37.7), Vector2(177, -39.5), Vector2(174.7, -41.3),
		Vector2(173.5, -39.5), Vector2(174.5, -38.5)],
	"new_zealand_south": [Vector2(172.7, -40.5), Vector2(174.2, -41.7), Vector2(171, -44.5), Vector2(169, -46.6), Vector2(166.5, -46),
		Vector2(168.4, -44)],
}


## A point on the map's surface, `lift` above the parchment.
static func at(lonlat: Vector2, lift := 0.0) -> Vector3:
	var u := (lonlat.x + 180.0) / 360.0
	var v := (LAT_TOP - lonlat.y) / (LAT_TOP - LAT_BOTTOM)
	return Vector3((u - 0.5) * MAP_SIZE.x, TABLE_TOP + 0.002 + lift, (v - 0.5) * MAP_SIZE.y)


static func town_at(i: int) -> Vector3:
	return at(TOWN_SPOTS[i], LAND_HEIGHT)


static func supplier_at(i: int) -> Vector3:
	return at(SUPPLIER_SPOTS[i], LAND_HEIGHT)


static func mill_at(i: int) -> Vector3:
	return at(MILL_SPOTS[i], LAND_HEIGHT)
