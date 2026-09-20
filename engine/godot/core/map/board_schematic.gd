class_name BoardSchematic
extends RefCounted

## The board as a circuit-board schematic: sites are boxes, tunnel rings are
## small circles, tunnels are traces. No hex art is drawn, but everything is
## derived from the assembled hexes and their rotations (state.layout and
## state.graph), so the schematic has exactly the adjacency the rules use.
##
## Owner's drawing rules (2026-09-16):
##   1. traces are straight and as parallel as possible;
##   2. traces only turn by 45 degrees (a 135 degree corner); a 90 degree turn
##      is two such corners with a short run between them;
##   3. a trace that crosses a hex edge crosses it at the edge midpoint,
##      perpendicular to the edge;
##   4. sites and rings may move, but only inside their own hex.
##
## Hex geometry cannot give 45 degrees on its own: a hex neighbour sits 60
## degrees from the next one. So the invisible hex grid is squeezed across its
## N-S axis by sqrt(3): the diagonal neighbours then sit exactly at 45 degrees,
## every edge midpoint lies on the centre-to-centre line and every crossing is
## straight. The whole picture is also turned 90 degrees clockwise (hex north
## points right) so the long axis of the board runs along the wide screen.
##
## Layout is a small local search: each site/ring tries nearby positions, each
## tunnel picks the best octilinear route for the current positions, and the
## score punishes corners, crossings, overlapping traces, nodes leaving their
## hex and moving far from where the hex art puts them. The search runs per tile
## and rotation offline (tools/build_schematic_tiles.gd -> tiles_path(K)); a game
## just places those pieces. Tunnels stay inside their own hex, so pieces laid
## out alone still fit together, and the edge midpoints join them straight.

## Pixels from a hex centre to its north edge midpoint (a diagonal edge
## midpoint is at (K/2, K/2)). Even, so every port lands on a whole pixel.
##
## Шаг подобран под ЗОНУ ДОСКИ на экране (решение владельца, 2026-09-20:
## «доска должна занимать максимальное пространство board zone»).
##
## Считать надо так. Схема рисуется только целым числом экранных пикселей на
## свой пиксель — иначе трассы и шрифт 5x7 превращаются в кашу. На полном
## экране расчётные 640x360 растянуты втрое, то есть зона доски — это
## 474x254 расчётных или 1422x762 экранных пикселей, и на пиксель схемы
## достаётся 1, 2 или 3 экранных, без промежуточных значений. Значит, чтобы
## доска заполнила зону, картинка должна быть либо не больше 474x254 (по 3
## экранных пикселя), либо около 711x381 (по 2). Между этими размерами
## заполнения не будет — останутся пустые поля.
##
## Первый вариант (ужать схему до 474x254) не годится: при таком шаге рамки
## локаций, размер которых задан шрифтом и не уменьшается, начинают налезать
## друг на друга — примерно в трети партий, вплоть до наложения 29x12
## пикселей. Поэтому взят второй: шаг УВЕЛИЧЕН, гексам просторнее прежнего, а
## картинка заполняет зону на 90-94% в масштабе две трети. Подписи локаций
## при этом такого же размера, как раньше.
##
## Шаг свой на каждое число игроков: на четверых гексов пятнадцать, на двоих
## девять, и общий шаг одним из раскладов промахнулся бы мимо ступени.
## Таблица тайлов у каждого шага своя (tiles_path).
static var K := 92
## Шаг сетки по числу игроков. Меняя его, проверь тестом «доска заполняет
## зону»: картинка должна попадать в ступень масштаба почти впритык.
## Делится на 4: решётка колец идёт с шагом K/4 (_lattice), и на нецелом шаге
## кольца встали бы на половину пикселя.
const GRID_BY_PLAYERS := {2: 92, 3: 92, 4: 72}
const GRID_DEFAULT := 92
## Куда упаковывать карту (см. _pack). Нулевой размер — старое поведение:
## локация двигается только внутри своего гекса. Пока это эксперимент, и
## включает его только инструмент предпросмотра.
static var pack_into := Vector2.ZERO
## Замеры последней упаковки — чтобы видеть, куда уходит время.
static var pack_stats: Dictionary = {}
## Layout units from a hex centre to an edge midpoint (half the neighbour step).
const INRADIUS := 7.3612159
const GRID := 2
const STUB := 5            # shortest straight run out of an edge midpoint or a box
const PIN_MARGIN := 3      # a tunnel enters a box at least this far from its corner
const MIN_SEG := 4         # shortest visible trace segment
const TRACE_GAP := 4       # closer parallel traces count as touching
const NODE_GAP := 4
## Поле вокруг картинки: только чтобы обводка рамок и концы трасс не
## упирались в край. Было 6 — двенадцать пикселей ширины, из-за которых
## схема переставала влезать в зону доски (см. GRID_BY_PLAYERS).
const IMAGE_MARGIN := 1

# Site box metrics (see SchematicPainter). All in pixels at 1x.
const RING_R := 4
## Отступ от рамки локации до её содержимого. Ноль: карта на четверых
## упирается в плотность, и полтора десятка пикселей площади рамки решают.
const BOX_PAD := 1
const SLOT_R := 4
const SLOT_PITCH := 10
const SLOT_COLS := 3
const VP_SCALE := 1
const NAME_GAP := 2
## Сколько знаков помещается в рамку локации.
const NAME_MAX := 7

## Короткие подписи локаций: полное название осталось в данных (журнал,
## подсказки, диалоги целей), а на доске рисуется сокращение — иначе рамки
## шире самого гекса. "Great Web" и "The Great Web" лежат на A3 и A1, то есть
## в одной партии встречается только одно из них, и общая подпись им не мешает.
const SHORT_NAMES := {
	"Council Chamber": "COUNCIL", "Fountain of Screams": "SCREAMS",
	"Wells of Darkness": "WELLS", "Darklight Realm": "DARKLGT",
	"Menzoberranzan": "MENZOB", "The Great Web": "GRTWEB", "Great Web": "GRTWEB",
	"Thanatos Gate": "THANATO", "Spiral Desert": "SPIRAL", "Rotting Plain": "ROTTING",
	"Heaving Hills": "HEAVING", "Erelhei-Cinlu": "ERELHEI", "The Twilight": "TWILGHT",
	"Lolth Shrine": "LOLTH", "Indifference": "INDIFF", "Xith Idrana": "XITH",
	"Xal Veldrin": "XALVELD", "The Barrens": "BARRENS", "Iron Wastes": "IRONWST",
	"Gallenghast": "GALLENG", "Spiderhome": "SPIDER", "Red Forest": "REDFRST",
	"Magma Gate": "MAGMA", "Black Gate": "BLKGATE", "Red Gate": "REDGATE",
	"Zi'Xzolca": "ZIXZOLC", "Shedaklah": "SHEDAKL", "Faerholme": "FAERHLM",
	"Darkflame": "DARKFLM", "Caer Sidi": "CAERSID", "Araumycos": "ARAUMYC",
	"Xelathir": "XELATHR", "Venathir": "VENATHR", "Enzithir": "ENZITHR",
	# Шесть веток Паутины стоят в одном гексе вокруг Great Web, и полные
	# подписи там просто не помещаются — остаётся только сторона света.
	"Web (N)": "N", "Web (S)": "S", "Web (NE)": "NE",
	"Web (NW)": "NW", "Web (SE)": "SE", "Web (SW)": "SW",
}

const DIRS: Array[Vector2] = [
	Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(-1, 1),
	Vector2(-1, 0), Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1),
]

enum Kind { SITE, RING, PORT }

const W_BEND := 12.0
const W_LEN := 0.01
const W_SHORT := 25.0
const W_HIT := 300.0
const W_CROSS := 200.0
const W_OVERLAP := 250.0
const W_CLOSE := 40.0
const W_DISP := 0.08
const W_OUT := 15.0
const W_OUT_PX := 6.0      # per pixel a box corner sticks out of its hex
const W_NODE_OVERLAP := 400.0
## Ring with two tunnels: penalty by the angle between them, index = steps of 45.
const RING_TURN := [500.0, 300.0, 60.0, 6.0, 0.0]
const PASSES := [[10, 40], [4, 12], [2, 4], [2, 4]]
const TILE_ATTEMPTS := 5
## То же, что W_OUT/W_OUT_PX, но для РАМКИ локации: при свободной упаковке
## рамка обязана остаться внутри картинки, даже ценой кривоватой разводки.
const W_OUT_BOX := 200.0
const W_OUT_BOX_PX := 100.0
## То же для ТРАССЫ при упаковке: выпирающая за край петля крадёт у доски
## масштаб, потому что размер картинки считается и по трассам.
const W_OUT_TRACE_PX := 60.0
## Во сколько раз дороже при упаковке трасса, задевающая рамку локации.
const PACK_HIT_FACTOR := 10.0
## Обход препятствий: запас коробки поиска вокруг концов тоннеля и потолок
## по числу клеток — на длинных связях поиск стал бы дороже пользы.
const PACK_ROUTE_MARGIN := 40.0
const PACK_ROUTE_CELLS := 9000
## Насколько жадно поиск тянется к цели: цена пикселя в прикидке остатка.
const PACK_ROUTE_PULL := 0.6
## Свободная упаковка: сколько раз разводить наложившиеся рамки и какими
## проходами потом улучшать разводку (шаг поиска, радиус).
const PACK_SEPARATE_PASSES := 40
## Ступени сжатия: доля от нужного размера. Последняя обязательно 1.0.
const PACK_SHRINK := [1.5, 1.3, 1.15, 1.05, 1.0]
## Шаги поиска ЧЁТНЫЕ: узлы обязаны остаться на сетке, по которой ищет
## обход препятствий (_astar_route).
const PACK_PASSES := [[4, 12]]
## Сколько узлов улучшать и с какой цены считать узел проблемным. Двигать
## все подряд слишком дорого: один узел — около 40 мс.
const PACK_FIX_NODES := 6
## Сколько раундов «найти худших — поправить — развести».
const PACK_ROUNDS := 2
## Спасательный дальний поиск места: шаг и радиус.
const PACK_RESCUE := [4, 40]
## Сколько узлов спасать: дальний поиск стоит около 90 мс на узел.
const PACK_RESCUE_MAX := 4
## Во сколько раз дороже наложение рамок при упаковке.
const PACK_OVERLAP_FACTOR := 12.0
const PACK_FIX_COST := 60.0

var _key: Array[String] = []
var _kind: Array[int] = []
var _hex: Array[String] = []
var _pos: Array[Vector2] = []
var _home: Array[Vector2] = []
var _half: Array[Vector2] = []
var _index: Dictionary = {}          # key -> node index
var _centre: Dictionary = {}         # layout slot -> Vector2
var _incident: Array = []            # node -> Array[int] of edges

var _edge_a: Array[int] = []         # port end when _edge_dir >= 0
var _edge_b: Array[int] = []
var _edge_dir: Array[int] = []       # direction leaving the port, or -1
var _routes: Array[PackedVector2Array] = []
var _visible: Array[PackedVector2Array] = []   # clipped segments, pairs of points
var _bbox: Array[Rect2] = []
var _near: Dictionary = {}           # layout slot -> Array[int] of nearby sites and rings
var _poly: Dictionary = {}           # layout slot -> hex outline
var _poly_nodes: Dictionary = {}     # то же, но с отступом NODE_GAP — для рамок
var _port_side: Dictionary = {}      # "port key|hex" -> that hex's name for the edge
var _fallback_routes := 0            # tunnels not found in the tile table
## Прямоугольник свободной упаковки (см. _pack); нулевой — упаковки не было.
var _pack_rect := Rect2()


## Returns {} for boards without hex layout (synthetic test graphs), else
## {
##   "size": [w, h],
##   "traces": [[x0, y0, x1, y1, ...], ...],
##   "rings": {slot_id: [x, y]},
##   "sites": {site_id: {"rect": [x, y, w, h], "name", "vp", "starting", "marker",
##             "slots": {slot_id: [x, y]}}},
##   "slots": {slot_id: {"x", "y"}},   # every troop space, rings included
## }
static func build(state: GameState) -> Dictionary:
	var hex_by_slot: Dictionary = state.layout.get("hex_by_slot", {})
	if hex_by_slot.is_empty():
		return {}
	var layouts: Dictionary = BoardData.load_all()["layouts"]
	var players := int(state.layout.get("player_count", state.turn_order.size()))
	# Шаг сетки свой на каждое число игроков, и таблица тайлов тоже своя.
	K = int(GRID_BY_PLAYERS.get(players, GRID_DEFAULT))
	var schematic := BoardSchematic.new()
	schematic._collect(state.graph, layouts[str(players)], hex_by_slot)
	schematic._index_neighbourhoods()
	schematic._apply_tiles(_load_tiles(), hex_by_slot, state.layout.get("rotations", {}))
	schematic._repair()
	if pack_into != Vector2.ZERO:
		schematic._pack(pack_into)
	return schematic._export(state)


## Lays out one tile at one rotation on its own, with a tunnel to every edge
## the tile prints. tools/build_schematic_tiles.gd stores the result for all
## tiles in tiles_path(K); a game only assembles those pieces (the search itself
## takes seconds, too slow for every game start). Positions are relative to
## the hex centre; ports are named "port:<world direction>".
static func layout_tile(builder: BoardBuilder, tile: String, rotation: int) -> Dictionary:
	var graph := builder.build(2, {"a": tile}, {"a": float(rotation)})
	# The search is local, so it can get stuck; tables are built offline, so
	# try a few starts (the first is the plain one) and keep the cheapest.
	var schematic: BoardSchematic = null
	var best_cost := INF
	for attempt in TILE_ATTEMPTS:
		var candidate := _tile_attempt(builder, graph, tile, rotation, attempt)
		var cost := candidate._total_cost()
		if cost < best_cost - 0.01:
			best_cost = cost
			schematic = candidate
	var nodes := {}
	for n in schematic._key.size():
		if schematic._kind[n] != Kind.PORT:
			nodes[_local_name(schematic._key[n])] = [schematic._pos[n].x, schematic._pos[n].y]
	var routes := {}
	for e in schematic._routes.size():
		var name_a := schematic._tile_name(schematic._edge_a[e], "a")
		var name_b := schematic._tile_name(schematic._edge_b[e], "a")
		var points := schematic._routes[e]
		if name_a > name_b:
			points = points.duplicate()
			points.reverse()
		var flat: Array = []
		for p in points:
			flat.append_array([p.x, p.y])
		routes[mini_key(name_a, name_b)] = flat
	return {"nodes": nodes, "routes": routes}


static func _tile_attempt(builder: BoardBuilder, graph: MapGraph, tile: String, rotation: int, attempt: int) -> BoardSchematic:
	var schematic := BoardSchematic.new()
	schematic._collect(graph, {"slots": {"a": {"x": 0.0, "z": 0.0}}, "adjacency": []}, {"a": tile})
	for world_dir: String in BoardBuilder.DIR_CYCLE:
		if not builder.hex_has_connection_facing(tile, world_dir, rotation):
			continue
		var port_slot := "a:" + builder.port_name(tile, BoardBuilder.raw_edge_facing_world(world_dir, rotation))
		var port := schematic._side_port("a", world_dir)
		schematic._add_edge(port, schematic._index[_node_of(graph, port_slot)], _dir_index(-schematic._pos[port]))
	if attempt > 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s/%d/%d" % [tile, rotation, attempt])
		for n in schematic._key.size():
			if schematic._kind[n] != Kind.PORT:
				var jitter := Vector2(rng.randi_range(-K / 5, K / 5), rng.randi_range(-K / 8, K / 8))
				var p := _snap(schematic._pos[n] + jitter)
				if Geometry2D.is_point_in_polygon(p, hex_polygon(Vector2.ZERO)):
					schematic._pos[n] = p
	schematic._optimise()
	return schematic


## Whole score of the current layout (only used to compare attempts).
func _total_cost() -> float:
	var cost := 0.0
	for n in _key.size():
		if _kind[n] != Kind.PORT:
			cost += _node_cost(n) + _ring_cost(n)
	for e in _routes.size():
		cost += _local_cost(e, _routes[e], _visible[e])
		for f in range(e + 1, _routes.size()):
			cost += _pair_cost(_visible[e], _visible[f])
	return cost

## Таблица тайлов своя на каждый шаг сетки: при другом K гекс другого размера,
## и разложенные в нём узлы уже не годятся.
static func tiles_path(grid: int) -> String:
	return "res://data/board/schematic_tiles_%d.json" % grid

static var _tiles_cache: Dictionary = {}   # K -> таблица


static func _load_tiles() -> Dictionary:
	if not _tiles_cache.has(K):
		var path := tiles_path(K)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY:
			_tiles_cache[K] = parsed
		else:
			push_warning("schematic: no tile table at %s, laying out from scratch" % path)
			_tiles_cache[K] = {}
	return _tiles_cache[K]


static func rotation_key(rotation: float) -> String:
	return str(posmod(roundi(rotation / 60.0), 6) * 60)


## "c_n1:C1_route0" -> "C1_route0" (sites and rings; ports go through _tile_name).
static func _local_name(key: String) -> String:
	return key if key.begins_with("port:") else key.get_slice(":", 1)


static func mini_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a


## Hex-local layout vector (x right, y down, units of the layout) to schematic pixels.
static func to_schematic(v: Vector2) -> Vector2:
	var squeezed := Vector2(v.x / sqrt(3.0), v.y)
	return Vector2(-squeezed.y, squeezed.x) * (K / INRADIUS)


## Corners of the (invisible, squeezed) hex around its centre.
static func hex_polygon(centre: Vector2, inset: float = 0.0) -> PackedVector2Array:
	var k := float(K) - inset
	return PackedVector2Array([
		centre + Vector2(0, -2 * k / 3), centre + Vector2(k, -k / 3), centre + Vector2(k, k / 3),
		centre + Vector2(0, 2 * k / 3), centre + Vector2(-k, k / 3), centre + Vector2(-k, -k / 3),
	])


## Подпись локации на доске: сокращение из SHORT_NAMES, а если названия там
## нет — первые NAME_MAX знаков без лишних слов. Полное название нигде не
## теряется, оно остаётся в данных локации.
static func short_name(full: String) -> String:
	if SHORT_NAMES.has(full):
		return SHORT_NAMES[full]
	var s := full.to_upper()
	if s.begins_with("THE "):
		s = s.substr(4)
	return s if s.length() <= NAME_MAX else s.substr(0, NAME_MAX)


## Size of a site box and its troop spaces relative to the box's top-left corner.
static func site_box(site_name: String, slot_count: int) -> Dictionary:
	var name_w := PixelFont.text_width(short_name(site_name))
	var cols := mini(maxi(slot_count, 1), SLOT_COLS)
	var rows := int(ceil(slot_count / float(SLOT_COLS)))
	var slots_w := cols * SLOT_PITCH - 2
	var vp_w := PixelFont.ADVANCE * VP_SCALE - VP_SCALE - 1
	var body_w := slots_w + 4 + vp_w
	var inner_w := maxi(name_w, body_w)
	var body_h := maxi(rows * SLOT_PITCH - 2, PixelFont.HEIGHT * VP_SCALE)
	# Стороны рамки ЧЁТНЫЕ. Узлы стоят на сетке с шагом GRID, и при нечётной
	# стороне край рамки попадал бы на половину пикселя — тогда точка выхода
	# тоннеля не ложится на ту же сетку, по которой ищет обход _astar_route.
	var w := _even(2 + 2 * BOX_PAD + inner_w)
	var h := _even(2 + 2 * BOX_PAD + PixelFont.HEIGHT + NAME_GAP + body_h)
	var left := 1 + BOX_PAD + (inner_w - body_w) / 2
	var top := 1 + BOX_PAD + PixelFont.HEIGHT + NAME_GAP + (body_h - (rows * SLOT_PITCH - 2)) / 2
	var slots: Array[Vector2] = []
	for i in slot_count:
		var row := i / SLOT_COLS
		var in_row := mini(SLOT_COLS, slot_count - row * SLOT_COLS)
		var shift := (cols - in_row) * SLOT_PITCH / 2
		slots.append(Vector2(left + shift + (i % SLOT_COLS) * SLOT_PITCH + SLOT_R,
			top + row * SLOT_PITCH + SLOT_R))
	return {
		"w": w, "h": h, "slots": slots,
		"name_at": Vector2(1 + BOX_PAD + (inner_w - name_w) / 2, 1 + BOX_PAD),
		"vp_at": Vector2(left + slots_w + 4, 1 + BOX_PAD + PixelFont.HEIGHT + NAME_GAP + (body_h - PixelFont.HEIGHT * VP_SCALE) / 2),
	}


# --- graph -> nodes and tunnels ---------------------------------------------------

func _add_node(key: String, kind: int, hex: String, home: Vector2, half: Vector2) -> int:
	var i := _key.size()
	_key.append(key)
	_kind.append(kind)
	_hex.append(hex)
	_home.append(home)
	_pos.append(home if kind == Kind.PORT else _snap(home))
	_half.append(half)
	_incident.append([])
	_index[key] = i
	return i


func _add_edge(a: int, b: int, port_dir: int) -> void:
	for e in _edge_a.size():
		if (_edge_a[e] == a and _edge_b[e] == b) or (_edge_a[e] == b and _edge_b[e] == a):
			return
	_edge_a.append(a)
	_edge_b.append(b)
	_edge_dir.append(port_dir)
	_routes.append(PackedVector2Array())
	_visible.append(PackedVector2Array())
	_bbox.append(Rect2())
	(_incident[a] as Array).append(_edge_a.size() - 1)
	(_incident[b] as Array).append(_edge_a.size() - 1)


func _collect(graph: MapGraph, layout: Dictionary, hex_by_slot: Dictionary) -> void:
	var places: Dictionary = layout["slots"]
	for layout_slot: String in hex_by_slot.keys():
		var place: Dictionary = places[layout_slot]
		_centre[layout_slot] = _snap(to_schematic(Vector2(float(place["x"]), -float(place["z"]))))

	# Graph positions are hex-local, already rotated, z pointing up.
	for site_id: String in graph.sites.keys():
		var site: Dictionary = graph.sites[site_id]
		var members := graph.slots_of_site(site_id)
		var sum := Vector2.ZERO
		for slot_id in members:
			var p: Vector2 = graph.slots[slot_id]["pos"]
			sum += Vector2(p.x, -p.y)
		var hex := site_id.get_slice(":", 0)
		var box := site_box(String(site["name"]), members.size())
		var home: Vector2 = _centre[hex] + to_schematic(sum / maxi(members.size(), 1))
		_add_node(site_id, Kind.SITE, hex, home, Vector2(int(box["w"]) / 2, int(box["h"]) / 2))
	for slot_id: String in graph.slots.keys():
		if not graph.is_route_slot(slot_id):
			continue
		var p2: Vector2 = graph.slots[slot_id]["pos"]
		var hex2 := slot_id.get_slice(":", 0)
		var ring := _add_node(slot_id, Kind.RING, hex2, _centre[hex2] + to_schematic(Vector2(p2.x, -p2.y)),
			Vector2(RING_R, RING_R))
		_pos[ring] = _centre[hex2] + _lattice(_home[ring] - _centre[hex2])

	var dir_between: Dictionary = {}
	for link: Dictionary in layout["adjacency"]:
		dir_between[String(link["a"]) + "|" + String(link["b"])] = String(link["dir"])
		dir_between[String(link["b"]) + "|" + String(link["a"])] = BoardBuilder.OPPOSITE_DIR[String(link["dir"])]

	var node_pairs: Array = []
	for slot_id: String in graph.slots.keys():
		for other: String in graph.adjacent_slots(slot_id):
			node_pairs.append([_node_of(graph, slot_id), _node_of(graph, other)])
	for site_id: String in graph.sites.keys():
		for other_site: String in graph.adjacent_sites(site_id):
			node_pairs.append([site_id, other_site])

	for pair: Array in node_pairs:
		var a: String = pair[0]
		var b: String = pair[1]
		if a == b or a > b:
			continue
		var hex_a := a.get_slice(":", 0)
		var hex_b := b.get_slice(":", 0)
		if hex_a == hex_b:
			_add_edge(_index[a], _index[b], -1)
			continue
		var world_dir: String = dir_between.get(hex_a + "|" + hex_b, "")
		if world_dir == "":
			push_warning("schematic: %s and %s are linked but their hexes are not neighbours" % [a, b])
			continue
		# one shared point, known to each hex as its own side
		var port := _side_port(hex_a, world_dir)
		_port_side[_key[port] + "|" + hex_b] = BoardBuilder.OPPOSITE_DIR[world_dir]
		_add_edge(port, _index[a], _dir_index(_centre[hex_a] - _pos[port]))
		_add_edge(port, _index[b], _dir_index(_centre[hex_b] - _pos[port]))


static func _node_of(graph: MapGraph, slot_id: String) -> String:
	var site := graph.site_of_slot(slot_id)
	return site if site != "" else slot_id


## The midpoint of the hex edge facing world_dir. Keyed by the hex it was made
## for; _port_side tells what the same point is called from the other hex.
func _side_port(hex: String, world_dir: String) -> int:
	var key := "port:%s:%s" % [hex, world_dir]
	if _index.has(key):
		return _index[key]
	var v: Vector2 = BoardBuilder.DIR_VECTORS[world_dir]
	var at: Vector2 = _centre[hex] + to_schematic(Vector2(v.x, -v.y) * INRADIUS)
	_port_side[key + "|" + hex] = world_dir
	return _add_node(key, Kind.PORT, hex, at.round(), Vector2.ZERO)


## Positions and routes from the precomputed tile table; anything missing
## there (a tile added later) is routed here.
func _apply_tiles(table: Dictionary, hex_by_slot: Dictionary, rotations: Dictionary) -> void:
	var tiles: Dictionary = table.get("tiles", {})
	var entries := {}
	for hex: String in hex_by_slot.keys():
		entries[hex] = ((tiles.get(hex_by_slot[hex], {}) as Dictionary)
			.get(rotation_key(float(rotations.get(hex, 0.0))), {}))
	for n in _key.size():
		if _kind[n] == Kind.PORT:
			continue
		var local: Variant = ((entries[_hex[n]] as Dictionary).get("nodes", {}) as Dictionary).get(_local_name(_key[n]))
		if local != null:
			_pos[n] = _centre[_hex[n]] + Vector2(local[0], local[1])
	for e in _routes.size():
		var inner := _edge_b[e]
		var hex: String = _hex[inner]
		var name_a := _tile_name(_edge_a[e], hex)
		var name_b := _local_name(_key[inner])
		var flat: Variant = ((entries[hex] as Dictionary).get("routes", {}) as Dictionary).get(mini_key(name_a, name_b))
		if flat == null:
			_fallback_routes += 1
			_choose_route(e, {})
			continue
		var points := PackedVector2Array()
		for i in range(0, (flat as Array).size(), 2):
			points.append(_centre[hex] + Vector2(flat[i], flat[i + 1]))
		if not points[0].is_equal_approx(_pos[_edge_a[e]]) and not _near_end(points[0], _edge_a[e]):
			points.reverse()
		_routes[e] = points
		_visible[e] = _clip(e, points)
		_bbox[e] = _bounds(_visible[e])


func _tile_name(n: int, hex: String) -> String:
	if _kind[n] != Kind.PORT:
		return _local_name(_key[n])
	return "port:" + String(_port_side[_key[n] + "|" + hex])


## A route end sits on the node itself (ring, port) or on its box border (site).
func _near_end(p: Vector2, n: int) -> bool:
	return _node_rect(n, 1.0).has_point(p)


## Tiles are laid out alone, so a box near the edge can touch a box of the
## neighbouring hex. Only those nodes are moved, a little.
func _repair() -> void:
	for n in _key.size():
		if _kind[n] == Kind.PORT:
			continue
		var grown := _node_rect(n, NODE_GAP)
		for m: int in _near[_hex[n]]:
			if m != n and _hex[m] != _hex[n] and grown.intersects(_node_rect(m)):
				_move_node(n, 2, 12)
				break
	# a moved box may now sit on a tunnel of the neighbouring hex
	for e in _routes.size():
		if _local_cost(e, _routes[e], _visible[e]) >= W_HIT:
			_choose_route(e, {})


static func _snap(p: Vector2) -> Vector2:
	return (p / GRID).round() * GRID


## Nearest point of the squeezed hex lattice (i*K/4, j*K/4) with i + j even:
## neighbouring lattice points are always joined by a straight trace, so rings
## that start there line up with each other and with the edge midpoints.
static func _lattice(v: Vector2) -> Vector2:
	var step := K / 4.0
	var best := Vector2.ZERO
	var best_d := INF
	var i0 := roundi(v.x / step)
	var j0 := roundi(v.y / step)
	for i in range(i0 - 1, i0 + 2):
		for j in range(j0 - 1, j0 + 2):
			if (i + j) % 2 != 0:
				continue
			var p := Vector2(i, j) * step
			if p.distance_squared_to(v) < best_d:
				best_d = p.distance_squared_to(v)
				best = p
	return best


static func _dir_index(v: Vector2) -> int:
	return DIRS.find(Vector2(signf(v.x), signf(v.y)))


# --- routes ----------------------------------------------------------------------

## Polyline through the given directions; lens < 0 are solved so the line ends at B.
static func _solve(a: Vector2, b: Vector2, dirs: Array, lens: Array, equal_ends := false) -> PackedVector2Array:
	var rest := b - a
	var unknown: Array[int] = []
	lens = lens.duplicate()
	for i in dirs.size():
		if float(lens[i]) < 0.0:
			unknown.append(i)
		else:
			rest -= DIRS[dirs[i]] * float(lens[i])
	if equal_ends:
		# [d1 x, d2 y, d1 x]: symmetric jog, the two outer runs share a length
		var u := DIRS[dirs[0]] * 2.0
		var v := DIRS[dirs[1]]
		var den := u.x * v.y - u.y * v.x
		if absf(den) < 0.001:
			return PackedVector2Array()
		lens[0] = (rest.x * v.y - rest.y * v.x) / den
		lens[2] = lens[0]
		lens[1] = (u.x * rest.y - u.y * rest.x) / den
	elif unknown.size() == 2:
		var u2 := DIRS[dirs[unknown[0]]]
		var v2 := DIRS[dirs[unknown[1]]]
		var den2 := u2.x * v2.y - u2.y * v2.x
		if absf(den2) < 0.001:
			return PackedVector2Array()
		lens[unknown[0]] = (rest.x * v2.y - rest.y * v2.x) / den2
		lens[unknown[1]] = (u2.x * rest.y - u2.y * rest.x) / den2
	elif unknown.size() == 1:
		var d := DIRS[dirs[unknown[0]]]
		var t := rest.dot(d) / d.length_squared()
		if not (rest - d * t).is_zero_approx():
			return PackedVector2Array()
		lens[unknown[0]] = t
	var points := PackedVector2Array([a])
	var at := a
	for i in dirs.size():
		if float(lens[i]) < 0.99:
			return PackedVector2Array()
		at += DIRS[dirs[i]] * float(lens[i])
		points.append(at)
	return points


func _variants(e: int) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var a := _edge_a[e]
	var b := _edge_b[e]
	for end_a: Array in _ends(a, b, e):
		for end_b: Array in _ends(b, a, e):
			_routes_between(out, end_a[0], end_a[1], end_b[0], end_b[1])
	return out


## Where a tunnel may start at node n, as [point, direction it must leave in]
## (-1 = any). A port has one fixed direction, a ring takes any, and a site box
## is entered straight through one of the sides that face the other end.
func _ends(n: int, other: int, e: int) -> Array:
	if _kind[n] == Kind.PORT:
		return [[_pos[n], _edge_dir[e]]]
	if _kind[n] == Kind.RING:
		return [[_pos[n], -1]]
	var rect := _node_rect(n)
	var toward := _pos[other] - _pos[n]
	var ends: Array = []
	for side: Array in [[0, rect.end.x - 1], [4, rect.position.x + 1]]:
		if toward.x * DIRS[side[0]].x > _half[n].x * 0.5:
			var lo := rect.position.y + PIN_MARGIN
			var hi := rect.end.y - PIN_MARGIN
			for y: float in [clampf(_pos[other].y, lo, hi), _pos[n].y]:
				_add_end(ends, Vector2(side[1], _snap_axis(y, lo, hi)), side[0])
	for side2: Array in [[2, rect.end.y - 1], [6, rect.position.y + 1]]:
		if toward.y * DIRS[side2[0]].y > 0.0:
			var lo2 := rect.position.x + PIN_MARGIN
			var hi2 := rect.end.x - PIN_MARGIN
			for x: float in [clampf(_pos[other].x, lo2, hi2), _pos[n].x]:
				_add_end(ends, Vector2(_snap_axis(x, lo2, hi2), side2[1]), side2[0])
	if ends.is_empty():
		ends = [[Vector2(rect.end.x - 1, _pos[n].y), 0], [Vector2(rect.position.x + 1, _pos[n].y), 4]]
	return ends


static func _snap_axis(v: float, lo: float, hi: float) -> float:
	return clampf(roundf(v / GRID) * GRID, ceilf(lo / GRID) * GRID, floorf(hi / GRID) * GRID)


static func _add_end(ends: Array, at: Vector2, dir: int) -> void:
	for existing: Array in ends:
		if existing[0] == at and existing[1] == dir:
			return
	ends.append([at, dir])


## All short octilinear routes from a (leaving in da) to b (leaving b in db).
func _routes_between(out: Array[PackedVector2Array], a: Vector2, da: int, b: Vector2, db: int) -> void:
	if (b - a).is_zero_approx():
		return
	if da < 0 and db >= 0:
		var reversed: Array[PackedVector2Array] = []
		_routes_between(reversed, b, db, a, da)
		for points in reversed:
			points.reverse()
			out.append(points)
		return
	if da < 0:
		_keep(out, _solve(a, b, [_dir_index(b - a)], [-1]))
		# only the two directions that bracket the straight line can reach b
		var d := int(floor(fposmod((b - a).angle(), TAU) / (PI / 4.0))) % 8
		var d_next := (d + 1) % 8
		_keep(out, _solve(a, b, [d, d_next], [-1, -1]))
		_keep(out, _solve(a, b, [d_next, d], [-1, -1]))
		_keep(out, _solve(a, b, [d, d_next, d], [-1, -1, -1], true))
		_keep(out, _solve(a, b, [d_next, d, d_next], [-1, -1, -1], true))
		return
	var last := -1 if db < 0 else (db + 4) % 8
	var found := out.size()
	if last < 0 or last == da:
		_keep(out, _solve(a, b, [da], [-1]))
	for s1: int in [-1, 1]:
		var d1 := (da + s1 + 8) % 8
		if last < 0 or last == d1:
			_keep(out, _solve(a, b, [da, d1], [-1, -1]))
		for s2: int in [-1, 1]:
			var d2 := (d1 + s2 + 8) % 8
			if last >= 0 and last != d2:
				continue
			var dirs := [da, d1, d2]
			_keep(out, _solve(a, b, dirs, [STUB, -1, -1]))
			_keep(out, _solve(a, b, dirs, [-1, -1, STUB]))
			_keep(out, _solve(a, b, dirs, [-1, STUB, -1]))
			if d2 == da:
				_keep(out, _solve(a, b, dirs, [-1, -1, -1], true))
	if out.size() > found:
		return
	# nothing short fits: allow a third corner
	for s1: int in [-1, 1]:
		for s2: int in [-1, 1]:
			for s3: int in [-1, 1]:
				var d1 := (da + s1 + 8) % 8
				var d2 := (d1 + s2 + 8) % 8
				var d3 := (d2 + s3 + 8) % 8
				if last >= 0 and last != d3:
					continue
				_keep(out, _solve(a, b, [da, d1, d2, d3], [STUB, -1, -1, STUB]))
				_keep(out, _solve(a, b, [da, d1, d2, d3], [STUB, STUB, -1, -1]))


static func _keep(out: Array[PackedVector2Array], points: PackedVector2Array) -> void:
	if points.size() >= 2:
		out.append(points)


func _node_rect(n: int, grow: float = 0.0) -> Rect2:
	return Rect2(_pos[n] - _half[n] - Vector2(grow, grow), _half[n] * 2.0 + Vector2(grow, grow) * 2.0)


## Segments of the route outside its two end boxes, as point pairs.
func _clip(e: int, points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var start_rect := _node_rect(_edge_a[e])
	var end_rect := _node_rect(_edge_b[e])
	var inside_start := _kind[_edge_a[e]] != Kind.PORT
	for i in points.size() - 1:
		var p := points[i]
		var q := points[i + 1]
		if inside_start:
			var exit: Variant = _exit_point(p, q, start_rect)
			if exit == null:
				continue
			p = exit
			inside_start = false
		if _kind[_edge_b[e]] != Kind.PORT and i == points.size() - 2:
			var entry: Variant = _exit_point(q, p, end_rect)
			if entry == null:
				continue
			q = entry
		out.append(p)
		out.append(q)
	return out


## Where segment p->q leaves rect (p inside), or null if it never does.
static func _exit_point(p: Vector2, q: Vector2, rect: Rect2) -> Variant:
	if not rect.has_point(p):
		return p
	if rect.grow(-0.01).has_point(q):
		return null
	var d := q - p
	var t := 1.0
	if d.x > 0: t = minf(t, (rect.end.x - p.x) / d.x)
	if d.x < 0: t = minf(t, (rect.position.x - p.x) / d.x)
	if d.y > 0: t = minf(t, (rect.end.y - p.y) / d.y)
	if d.y < 0: t = minf(t, (rect.position.y - p.y) / d.y)
	return p + d * t


static func _segment_hits_rect(p: Vector2, q: Vector2, rect: Rect2) -> bool:
	if not Rect2(p, Vector2.ZERO).expand(q).grow(0.5).intersects(rect):
		return false
	if rect.has_point(p) or rect.has_point(q):
		return true
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(p, q, corners[i], corners[(i + 1) % 4]) != null:
			return true
	return false


func _local_cost(e: int, points: PackedVector2Array, segs: PackedVector2Array) -> float:
	var cost := (points.size() - 2) * W_BEND
	for i in points.size() - 1:
		var run := points[i].distance_to(points[i + 1])
		cost += run * W_LEN
		if i > 0 and i < points.size() - 2 and run < MIN_SEG:
			cost += W_SHORT
	if points.size() > 2:
		for i in range(0, segs.size(), 2):
			if segs[i].distance_to(segs[i + 1]) < MIN_SEG:
				cost += W_SHORT
	if _edge_dir[e] >= 0 and _dir_index(points[1] - points[0]) != _edge_dir[e]:
		cost += W_HIT * 3.0
	# tiles are laid out alone: a tunnel that leaves its hex could cross the neighbour's
	#
	# При свободной упаковке «свой гекс» — это вся картинка, и выход за её край
	# стоит намного дороже: размер картинки считается по трассам тоже, и
	# выпирающая петля отнимает у доски масштаб.
	var poly: PackedVector2Array = _poly[_hex[_edge_b[e]]]
	var out_px: float = W_OUT_TRACE_PX if _pack_rect.size.x > 0.0 else W_OUT_PX
	for i in range(0, segs.size(), 2):
		for p: Vector2 in [segs[i], segs[i + 1], (segs[i] + segs[i + 1]) * 0.5]:
			if not Geometry2D.is_point_in_polygon(p, poly):
				cost += _outside_by(p, poly) * out_px
	var reach := _bounds(segs)
	for n: int in _near[_hex[_edge_b[e]]]:
		if n == _edge_a[e] or n == _edge_b[e]:
			continue
		var rect := _node_rect(n, 2.0)
		if not reach.intersects(rect):
			continue
		for i in range(0, segs.size(), 2):
			if _segment_hits_rect(segs[i], segs[i + 1], rect):
				# При упаковке трасса поверх рамки — самое заметное уродство: она
				# перечёркивает название локации. Дороже любого крюка.
				cost += W_HIT * PACK_HIT_FACTOR if _pack_rect.size.x > 0.0 else W_HIT
				break
	return cost


static func _bounds(segs: PackedVector2Array) -> Rect2:
	if segs.is_empty():
		return Rect2(Vector2(INF, INF), Vector2.ZERO)
	var r := Rect2(segs[0], Vector2.ZERO)
	for p in segs:
		r = r.expand(p)
	return r.grow(TRACE_GAP)


static func _pair_cost(s1: PackedVector2Array, s2: PackedVector2Array) -> float:
	var cost := 0.0
	for i in range(0, s1.size(), 2):
		var p1 := s1[i]
		var p2 := s1[i + 1]
		var d1 := p2 - p1
		var len1 := d1.length()
		if len1 < 0.01:
			continue
		var box1 := Rect2(p1, Vector2.ZERO).expand(p2).grow(TRACE_GAP)
		for j in range(0, s2.size(), 2):
			var q1 := s2[j]
			var q2 := s2[j + 1]
			if not box1.intersects(Rect2(q1, Vector2.ZERO).expand(q2)):
				continue
			var d2 := q2 - q1
			if absf(d1.x * d2.y - d1.y * d2.x) > 0.001:
				if Geometry2D.segment_intersects_segment(p1, p2, q1, q2) != null:
					cost += W_CROSS
				continue
			var dist := absf((q1 - p1).x * d1.y - (q1 - p1).y * d1.x) / len1
			if dist >= TRACE_GAP:
				continue
			var t1 := (q1 - p1).dot(d1) / len1
			var t2 := (q2 - p1).dot(d1) / len1
			var overlap := minf(len1, maxf(t1, t2)) - maxf(0.0, minf(t1, t2))
			if overlap > 0.5:
				cost += (W_OVERLAP if dist < 1.0 else W_CLOSE) + overlap * 0.5
	return cost


## Angle penalty at a ring: tunnels through a ring should go straight on.
func _ring_cost(n: int) -> float:
	if _kind[n] != Kind.RING:
		return 0.0
	var dirs: Array[int] = []
	for e: int in _incident[n]:
		var points := _routes[e]
		if points.size() < 2:
			continue
		if _edge_a[e] == n:
			dirs.append(_dir_index(points[1] - points[0]))
		else:
			dirs.append(_dir_index(points[points.size() - 2] - points[points.size() - 1]))
	var cost := 0.0
	for i in dirs.size():
		for j in range(i + 1, dirs.size()):
			var steps := absi(dirs[i] - dirs[j])
			steps = mini(steps, 8 - steps)
			if dirs.size() == 2:
				cost += RING_TURN[steps]
			elif steps == 0:
				cost += RING_TURN[0]
	return cost


static func _outside_by(p: Vector2, poly: PackedVector2Array) -> float:
	var best := INF
	for i in poly.size():
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])))
	return best


func _node_cost(n: int) -> float:
	var p := _pos[n]
	var cost := p.distance_to(_home[n]) * W_DISP
	var centre: Vector2 = _centre[_hex[n]]
	# Рамки держатся дальше от края гекса, чем трассы: соседние гексы кладутся
	# независимо друг от друга, и две рамки, прижатые к общему ребру с разных
	# сторон, налезали бы друг на друга уже на собранной доске.
	var poly: PackedVector2Array = _poly_nodes[_hex[n]]
	# При свободной упаковке (_pack) выйти «наружу» значит выйти за КРАЙ
	# КАРТИНКИ, а это недопустимо — там штраф на порядок больше. В обычной
	# раскладке рамке можно слегка выступить за свой гекс: гекс невидимый, и
	# выступ часто спрямляет трассу.
	var packing := _pack_rect.size.x > 0.0
	var out_flat: float = W_OUT_BOX if packing else W_OUT
	var out_px: float = W_OUT_BOX_PX if packing else W_OUT_PX
	var rect := _node_rect(n)
	for corner in [rect.position, rect.end, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y)]:
		if not Geometry2D.is_point_in_polygon(corner, poly):
			cost += out_flat + _outside_by(corner, poly) * out_px
	var grown := _node_rect(n, NODE_GAP)
	for m: int in _near[_hex[n]]:
		if m == n:
			continue
		var other := _node_rect(m)
		if grown.intersects(other):
			# При свободной упаковке наложение рамок запрещено наглухо: карта
			# и так на пределе плотности, и узел иначе охотно меняет чистую
			# разводку на «налезу чуть-чуть».
			var weight: float = W_NODE_OVERLAP * PACK_OVERLAP_FACTOR if packing else W_NODE_OVERLAP
			cost += weight + grown.intersection(other).get_area() * 0.5
	return cost


## Pick the cheapest route for edge e with the endpoints where they are now.
func _choose_route(e: int, skip: Dictionary) -> float:
	var ranked: Array = []
	for points in _variants(e):
		var segs := _clip(e, points)
		ranked.append([_local_cost(e, points, segs), points, segs])
	ranked.sort_custom(func(x, y): return x[0] < y[0])
	if ranked.is_empty():
		_routes[e] = PackedVector2Array([_pos[_edge_a[e]], _pos[_edge_b[e]]])
		_visible[e] = PackedVector2Array()
		_bbox[e] = Rect2(Vector2(INF, INF), Vector2.ZERO)
		return W_HIT * 10.0
	var best := INF
	for k in mini(4, ranked.size()):
		var segs2: PackedVector2Array = ranked[k][2]
		var box := _bounds(segs2)
		var cost: float = ranked[k][0]
		if cost >= best:
			break
		for f in _routes.size():
			if f == e or skip.has(f) or not box.intersects(_bbox[f]):
				continue
			cost += _pair_cost(segs2, _visible[f])
		if cost < best:
			best = cost
			_routes[e] = ranked[k][1]
			_visible[e] = segs2
			_bbox[e] = box
	return best


## Cost of everything that depends on node n; routes of n are re-chosen.
func _cost_around(n: int) -> float:
	var inc: Array = _incident[n]
	var skip := {}
	for e: int in inc:
		skip[e] = true
	var cost := _node_cost(n)
	for e: int in inc:
		cost += _choose_route(e, skip)
	for i in inc.size():
		for j in range(i + 1, inc.size()):
			cost += _pair_cost(_visible[inc[i]], _visible[inc[j]])
	cost += _ring_cost(n)
	for e: int in inc:
		var other := _edge_b[e] if _edge_a[e] == n else _edge_a[e]
		cost += _ring_cost(other)
	var rect := _node_rect(n, 2.0)
	for f in _routes.size():
		if skip.has(f) or _edge_a[f] == n or _edge_b[f] == n or not rect.intersects(_bbox[f]):
			continue
		var segs := _visible[f]
		for i in range(0, segs.size(), 2):
			if _segment_hits_rect(segs[i], segs[i + 1], rect):
				cost += W_HIT
				break
	return cost


## Per hex: its sites and rings plus those of the neighbouring hexes, and the
## hex outline. Nothing further away can touch a node or a trace of this hex.
func _index_neighbourhoods() -> void:
	for hex: String in _centre.keys():
		_poly[hex] = hex_polygon(_centre[hex])
		_poly_nodes[hex] = hex_polygon(_centre[hex], NODE_GAP)
		var near: Array[int] = []
		for n in _key.size():
			if _kind[n] != Kind.PORT and (_centre[hex] as Vector2).distance_to(_centre[_hex[n]]) < K * 2.1:
				near.append(n)
		_near[hex] = near


## Свободная упаковка карты в прямоугольник target (эксперимент 2026-09-20).
##
## Прежнее правило «локация двигается только внутри своего гекса» держит карту
## разреженной: гекс должен быть таким, чтобы вместить свои рамки, и ужать
## сетку нельзя. Здесь гексы перестают что-либо ограничивать — вся картинка
## сжимается под нужный размер, а рамки разводятся между собой уже по всему
## полю. Геометрия гексов при этом сохраняется как ПЕРВОЕ ПРИБЛИЖЕНИЕ: карта
## остаётся похожей на настолку, но плотнее.
func _pack(target: Vector2) -> void:
	var started := Time.get_ticks_msec()
	pack_stats = {}
	var span := _node_span()
	if span.size.x <= 0.0 or span.size.y <= 0.0:
		return
	var centre := span.get_center()

	# 1. Гексы больше ничего не ограничивают: и «не вылезать», и «с кем можно
	# столкнуться» теперь считаются по всей картинке.
	var everyone: Array[int] = []
	for n in _key.size():
		if _kind[n] != Kind.PORT:
			everyone.append(n)

	# 2. Сжимать постепенно. Одним рывком до нужного размера карта на четверых
	# даёт сразу полтора десятка наложившихся пар, и растащить такой клубок
	# сдвигами по одному узлу уже нельзя. По шагам каждое сжатие добавляет
	# два-три наложения, они тут же разводятся, и следующий шаг начинается с
	# чистой карты. Масштаб не меняет углов, поэтому трассы остаются под 45.
	var left := 0
	for factor: float in PACK_SHRINK:
		var want := target * factor
		var now := _node_span()
		var scale: float = minf(want.x / now.size.x, want.y / now.size.y)
		if scale < 1.0:
			for n in _pos.size():
				_pos[n] = _snap(centre + (_pos[n] - centre) * scale)
			for hex: String in _centre.keys():
				_centre[hex] = _snap(centre + (_centre[hex] as Vector2 - centre) * scale)
		_pack_rect = Rect2(_snap(centre - want * 0.5), _snap(want))
		# Округление до чётного пикселя могло вынести крайний узел за рамку, а
		# разведение поджимает только тех, кто с кем-то налез. Поджимаем всех:
		# иначе картинка вылезает за зону на пиксель и теряет весь масштаб.
		for n: int in everyone:
			_pos[n] = _clamp_in_frame(n, _pos[n])
		var frame := PackedVector2Array([_pack_rect.position,
			Vector2(_pack_rect.end.x, _pack_rect.position.y), _pack_rect.end,
			Vector2(_pack_rect.position.x, _pack_rect.end.y)])
		for hex: String in _centre.keys():
			_poly[hex] = frame
			_poly_nodes[hex] = frame
			_near[hex] = everyone
		left = _separate(everyone)
	pack_stats["separate_ms"] = Time.get_ticks_msec() - started
	pack_stats["overlaps_left"] = left

	# 4. Трассы считаются заново: узлы разъехались, прежние ходы устарели.
	var routed := Time.get_ticks_msec()
	for e in _routes.size():
		_choose_route(e, {})
	pack_stats["reroute_ms"] = Time.get_ticks_msec() - routed

	# 5. Локальное улучшение — только там, где плохо. Двигать все узлы подряд
	# слишком дорого (по 40 мс на узел), а после разведения у большинства из
	# них и так всё в порядке: трасса идёт прямо и никого не задевает.
	#
	# Раундами: после каждого раунда список худших пересчитывается — узел,
	# который мешал больше всех, уже поправлен, и на первое место выходит
	# следующий. Разово взятая двадцатка так не умеет: половина её к середине
	# работы уже не нужна.
	var fixed := 0
	for round_no in PACK_ROUNDS:
		var round_started := Time.get_ticks_msec()
		var picked := _worst_nodes(everyone, PACK_FIX_NODES)
		if picked.is_empty():
			break
		fixed += picked.size()
		for pass_info: Array in PACK_PASSES:
			for n: int in picked:
				_move_node(n, int(pass_info[0]), int(pass_info[1]))
		for e in _routes.size():
			_choose_route(e, {})
		_separate(everyone)
		pack_stats["round_%d_ms" % round_no] = Time.get_ticks_msec() - round_started

	# 6. Спасательный проход. Если рамка всё ещё сидит на соседке, соседний
	# пятачок ей не поможет — там и так занято. Такой рамке разрешается уйти
	# далеко, хоть на другой конец карты: пустое место обычно есть, просто не
	# рядом. Узлов таких единицы, поэтому дальний поиск по карману.
	var stuck := _overlapping(everyone)
	pack_stats["stuck"] = stuck.size()
	if not stuck.is_empty():
		var rescue := Time.get_ticks_msec()
		for n: int in stuck.slice(0, PACK_RESCUE_MAX):
			_move_node(n, PACK_RESCUE[0], PACK_RESCUE[1])
		for e in _routes.size():
			_choose_route(e, {})
		_separate(everyone)
		pack_stats["rescue_ms"] = Time.get_ticks_msec() - rescue
	for e in _routes.size():
		_choose_route(e, {})

	# 7. Последним делом — обойти рамки. Прямые варианты в плотной карте почти
	# все кого-нибудь задевают и перечёркивают названия локаций; здесь такие
	# тоннели прокладываются поиском по сетке. Именно последним: сдвиг узла
	# заново выбирает маршрут из прямых вариантов и обход бы затёр.
	var around := Time.get_ticks_msec()
	pack_stats["rerouted"] = _reroute_around_boxes()
	pack_stats["reroute_around_ms"] = Time.get_ticks_msec() - around
	pack_stats["fixed"] = fixed
	pack_stats["nodes"] = everyone.size()
	pack_stats["edges"] = _routes.size()


## Разводит наложившиеся рамки и кольца. Возвращает, сколько пар осталось
## внахлёст (ноль — всё чисто).
func _separate(everyone: Array[int]) -> int:
	var left := 0
	for _pass in PACK_SEPARATE_PASSES:
		left = 0
		for i in everyone.size():
			for j in range(i + 1, everyone.size()):
				var a: int = everyone[i]
				var b: int = everyone[j]
				var overlap := _node_rect(a, NODE_GAP * 0.5).intersection(_node_rect(b, NODE_GAP * 0.5))
				if overlap.size.x <= 0.0 or overlap.size.y <= 0.0:
					continue
				left += 1
				var push := Vector2(overlap.size.x, 0.0) if overlap.size.x <= overlap.size.y \
					else Vector2(0.0, overlap.size.y)
				if (_pos[b] - _pos[a]).dot(push) < 0.0:
					push = -push
				var was_a: Vector2 = _pos[a]
				var was_b: Vector2 = _pos[b]
				_pos[a] = _clamp_in_frame(a, _snap(was_a - push * 0.5))
				_pos[b] = _clamp_in_frame(b, _snap(was_b + push * 0.5))
				# Кого-то придержал край — недостающую половину проходит сосед.
				var done := (was_a - _pos[a]) + (_pos[b] - was_b)
				var short_by := push - done
				if short_by.length_squared() > 0.5:
					if _pos[a] == was_a:
						_pos[b] = _clamp_in_frame(b, _snap(_pos[b] + short_by))
					else:
						_pos[a] = _clamp_in_frame(a, _snap(_pos[a] - short_by))
		if left == 0:
			break
	return left


## Узлы, которые сейчас с кем-то внахлёст.
func _overlapping(everyone: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for i in everyone.size():
		var a: int = everyone[i]
		for b: int in everyone:
			if a != b and _node_rect(a).intersects(_node_rect(b)):
				out.append(a)
				break
	return out


## Узлы, вокруг которых сейчас хуже всего: наложения, задетые трассы,
## пересечения. Их и двигаем — по ним и видно кривую разводку.
func _worst_nodes(everyone: Array[int], limit: int) -> Array[int]:
	var scored: Array = []
	for n: int in everyone:
		scored.append([_node_cost(n), n])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var out: Array[int] = []
	for row: Array in scored.slice(0, limit):
		if float(row[0]) < PACK_FIX_COST:
			break
		out.append(int(row[1]))
	return out


## Рамка узла целиком внутри картинки, а сам узел — на чётной сетке. Сетка
## важна: по ней ищет обход _astar_route, и съехавший на пиксель узел просто
## выпадает из поиска.
func _clamp_in_frame(n: int, p: Vector2) -> Vector2:
	var half: Vector2 = _half[n]
	return Vector2(
		_snap_axis(p.x, _pack_rect.position.x + half.x, _pack_rect.end.x - half.x),
		_snap_axis(p.y, _pack_rect.position.y + half.y, _pack_rect.end.y - half.y))


## Прямоугольник по рамкам локаций и кольцам, без трасс.
func _node_span() -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for n in _key.size():
		if _kind[n] == Kind.PORT:
			continue
		lo = lo.min(_pos[n] - _half[n])
		hi = hi.max(_pos[n] + _half[n])
	return Rect2(lo, hi - lo) if lo.x < hi.x else Rect2()


func _optimise() -> void:
	_index_neighbourhoods()
	for e in _routes.size():
		_choose_route(e, {e: true})
	for e in _routes.size():
		_choose_route(e, {})
	for pass_info: Array in PASSES:
		var step: int = pass_info[0]
		var radius: int = pass_info[1]
		for n in _key.size():
			if _kind[n] == Kind.PORT:
				continue
			_move_node(n, step, radius)
		for e in _routes.size():
			_choose_route(e, {})


## Перебирает места вокруг узла и оставляет самое дешёвое. Квадратом (step,
## radius) — в офлайновой раскладке тайла, где время не жмёт; при свободной
## упаковке вместо квадрата берутся восемь направлений на нескольких
## расстояниях (_ring_offsets): позиций втрое меньше при почти том же
## результате, а одна проверка стоит около миллисекунды.
func _move_node(n: int, step: int, radius: int) -> void:
	var start := _pos[n]
	var inc: Array = _incident[n]
	var poly: PackedVector2Array = _poly_nodes[_hex[n]] if _kind[n] != Kind.PORT \
		else hex_polygon(_centre[_hex[n]])
	var best_cost := _cost_around(n)
	var best_pos := start
	var best_routes: Array = _snapshot_routes(inc)
	var packing := _pack_rect.size.x > 0.0 and _kind[n] != Kind.PORT
	for offset: Vector2 in _offsets(step, radius):
		var p := start + offset
		# При упаковке рамка обязана целиком остаться в картинке — это
		# проверяется точно, а не штрафом: иначе узел, которому запрещено
		# налезать на соседа, просто уходит за край, и картинка растёт.
		if packing:
			if not _pack_rect.encloses(Rect2(p - _half[n], _half[n] * 2.0)):
				continue
		elif not Geometry2D.is_point_in_polygon(p, poly):
			continue
		_pos[n] = p
		var cost := _cost_around(n)
		if cost < best_cost - 0.01:
			best_cost = cost
			best_pos = p
			best_routes = _snapshot_routes(inc)
	_pos[n] = best_pos
	for i in inc.size():
		var e: int = inc[i]
		_routes[e] = best_routes[i][0]
		_visible[e] = best_routes[i][1]
		_bbox[e] = best_routes[i][2]


## Куда пробовать сдвинуть узел. В офлайновой раскладке — весь квадрат; при
## свободной упаковке — восемь направлений на расстояниях step, 2*step ... до
## radius. Позиций втрое меньше, а направления те же, по каким вообще ходят
## трассы.
func _offsets(step: int, radius: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if _pack_rect.size.x <= 0.0:
		for dy in range(-radius, radius + 1, step):
			for dx in range(-radius, radius + 1, step):
				if dx != 0 or dy != 0:
					out.append(Vector2(dx, dy))
		return out
	var away := step
	while away <= radius:
		for dir: Vector2 in DIRS:
			out.append(dir * away)
		away += step
	return out


func _snapshot_routes(inc: Array) -> Array:
	var out: Array = []
	for e: int in inc:
		out.append([_routes[e], _visible[e], _bbox[e]])
	return out


# --- export ------------------------------------------------------------------------

func _export(state: GameState) -> Dictionary:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for n in _key.size():
		if _kind[n] == Kind.PORT:
			continue
		lo = lo.min(_pos[n] - _half[n])
		hi = hi.max(_pos[n] + _half[n])
	for points in _routes:
		for p in points:
			lo = lo.min(p)
			hi = hi.max(p)
	var shift := (-lo + Vector2(IMAGE_MARGIN, IMAGE_MARGIN)).round()
	var size := (hi - lo + Vector2(IMAGE_MARGIN, IMAGE_MARGIN) * 2).ceil()

	var starting := GameSetup.STARTING_SITE_NAMES
	var marked := ControlMarkers.marked_sites(state)
	var sites := {}
	var slots := {}
	var rings := {}
	for n in _key.size():
		var at := _pos[n] + shift
		if _kind[n] == Kind.RING:
			rings[_key[n]] = [at.x, at.y]
			slots[_key[n]] = {"x": at.x, "y": at.y}
		elif _kind[n] == Kind.SITE:
			var site: Dictionary = state.graph.sites[_key[n]]
			var members := state.graph.slots_of_site(_key[n])
			var box := site_box(String(site["name"]), members.size())
			var corner := at - _half[n]
			var site_slots := {}
			for i in members.size():
				var slot_at: Vector2 = corner + ((box["slots"] as Array)[i] as Vector2)
				site_slots[members[i]] = [slot_at.x, slot_at.y]
				slots[members[i]] = {"x": slot_at.x, "y": slot_at.y}
			sites[_key[n]] = {
				"rect": [corner.x, corner.y, float(box["w"]), float(box["h"])],
				"name": site["name"],
				"vp": site["vp"],
				"starting": starting.has(String(site["name"])),
				"marker": marked.has(_key[n]),
				"slots": site_slots,
			}
	var traces: Array = []
	var trace_ends: Array = []
	for e in _routes.size():
		var flat: Array = []
		for p in _routes[e]:
			flat.append(p.x + shift.x)
			flat.append(p.y + shift.y)
		traces.append(flat)
		trace_ends.append([_key[_edge_a[e]], _key[_edge_b[e]]])
	var ports := {}
	for n in _key.size():
		if _kind[n] == Kind.PORT:
			ports[_key[n]] = [_pos[n].x + shift.x, _pos[n].y + shift.y]
	var centres := {}
	for hex: String in _centre.keys():
		centres[hex] = [(_centre[hex] as Vector2).x + shift.x, (_centre[hex] as Vector2).y + shift.y]
	return {
		"size": [size.x, size.y], "traces": traces, "rings": rings, "sites": sites, "slots": slots,
		# for checks and debugging: which nodes each trace joins, edge midpoints, hex centres
		"trace_ends": trace_ends, "ports": ports, "hex_centres": centres,
		"fallback_routes": _fallback_routes,
	}


## Ближайшее чётное число не меньше данного.
static func _even(v: int) -> int:
	return v + (v & 1)


# --- разводка в обход препятствий (только при упаковке) ----------------------

## Перекладывает тоннели, которые иначе идут прямо по рамке локации и
## перечёркивают её название. Возвращает, сколько удалось исправить.
##
## Это отдельный проход в самом конце упаковки, а не часть _choose_route:
## выбор маршрута зовётся тысячи раз внутри сдвигов узлов, и поиск по сетке
## там не по карману. В разреженной раскладке по гексам прямые варианты
## справляются и сами — там этот проход просто ничего не находит.
func _reroute_around_boxes() -> int:
	var fixed := 0
	var hits := 0
	var no_path := 0
	for e in _routes.size():
		var was_hits := _route_hit_count(e)
		if was_hits == 0:
			continue
		hits += 1
		var path := _astar_route(e)
		if path.is_empty():
			no_path += 1
			continue
		var was_route: PackedVector2Array = _routes[e]
		var was_visible: PackedVector2Array = _visible[e]
		var was_box: Rect2 = _bbox[e]
		_routes[e] = path
		_visible[e] = _clip(e, path)
		_bbox[e] = _bounds(_visible[e])
		# Обход оставляем, если он задевает МЕНЬШЕ рамок, а не только если
		# чист совсем: в плотной карте «чуть лучше» тоже дорогого стоит.
		var now_hits := _route_hit_count(e)
		if now_hits >= was_hits:
			_routes[e] = was_route
			_visible[e] = was_visible
			_bbox[e] = was_box
		else:
			fixed += was_hits - now_hits
	pack_stats["route_hits"] = hits
	pack_stats["route_no_path"] = no_path
	return fixed


## Сколько чужих рамок и колец задевает трасса.
func _route_hit_count(e: int) -> int:
	var hits := 0
	var segs: PackedVector2Array = _visible[e]
	if segs.is_empty():
		return 0
	var a: Vector2 = _pos[_edge_a[e]]
	var b: Vector2 = _pos[_edge_b[e]]
	for m in _key.size():
		if _kind[m] == Kind.PORT or m == _edge_a[e] or m == _edge_b[e]:
			continue
		var rect := _node_rect(m)
		if not _bbox[e].intersects(rect):
			continue
		# Узел, накрывший сам конец тоннеля, не в счёт: трасса обязана оттуда
		# выйти, и никакой обход этого не изменит. Это наложение рамок, а не
		# кривая разводка, и лечится оно разведением.
		if rect.has_point(a) or rect.has_point(b):
			continue
		for i in range(0, segs.size(), 2):
			if _segment_hits_rect(segs[i], segs[i + 1], rect):
				hits += 1
				break
	return hits


## Поиск маршрута по сетке в восемь направлений: рамки локаций и кольца —
## стенки, поворот только на 45 градусов, цена — длина плюс штраф за излом
## (те же веса, что в _local_cost). Пусто, если маршрута нет или коробка
## поиска вышла слишком большой.
func _astar_route(e: int) -> PackedVector2Array:
	var a := _edge_a[e]
	var b := _edge_b[e]
	var starts := _ends(a, b, e)
	var goals := _ends(b, a, e)
	if starts.is_empty() or goals.is_empty():
		return PackedVector2Array()

	var box := Rect2(starts[0][0], Vector2.ZERO)
	for s: Array in starts:
		box = box.expand(s[0])
	for g: Array in goals:
		box = box.expand(g[0])
	box = box.grow(PACK_ROUTE_MARGIN)
	var origin := (box.position / GRID).floor() * GRID
	var w := int((box.end.x - origin.x) / GRID) + 2
	var h := int((box.end.y - origin.y) / GRID) + 2
	if w < 2 or h < 2 or w * h > PACK_ROUTE_CELLS:
		pack_stats["fail_big"] = int(pack_stats.get("fail_big", 0)) + 1
		return PackedVector2Array()

	var blocked := PackedByteArray()
	blocked.resize(w * h)
	for m in _key.size():
		if _kind[m] == Kind.PORT or m == a or m == b:
			continue
		var r := _node_rect(m, 1.0)
		var x0 := maxi(int(ceilf((r.position.x - origin.x) / GRID)), 0)
		var x1 := mini(int(floorf((r.end.x - origin.x) / GRID)), w - 1)
		var y0 := maxi(int(ceilf((r.position.y - origin.y) / GRID)), 0)
		var y1 := mini(int(floorf((r.end.y - origin.y) / GRID)), h - 1)
		for cy in range(y0, y1 + 1):
			var row := cy * w
			for cx in range(x0, x1 + 1):
				blocked[row + cx] = 1

	var states := w * h * 8
	var dist := PackedFloat32Array()
	dist.resize(states)
	dist.fill(INF)
	var seen := PackedByteArray()
	seen.resize(states)
	var prev := PackedInt32Array()
	prev.resize(states)
	prev.fill(-1)
	var heap_cost := PackedFloat32Array()
	var heap_state := PackedInt32Array()

	# Точка выхода может лежать между узлами сетки — до ближайшего узла идём
	# прямо по направлению выхода, излома это не добавляет.
	var entry := {}
	var starting: Array = []
	for s: Array in starts:
		var at: Vector2 = s[0]
		var dir: int = int(s[1])
		var lattice := _lattice_ahead(at, dir)
		if lattice == Vector2.INF:
			continue
		var cell := _cell_of(lattice, origin, w, h)
		if cell < 0:
			continue
		# Конец тоннеля может оказаться накрыт чужой рамкой — упаковка тесная.
		# Его клетку всё равно открываем: выходить откуда-то надо.
		blocked[cell] = 0
		for d in range(8):
			if dir >= 0 and d != dir:
				continue
			var st := cell * 8 + d
			var reach := at.distance_to(lattice) * W_LEN
			if reach < dist[st]:
				dist[st] = reach
				entry[st] = at
				starting.append([reach, st])
	if starting.is_empty():
		pack_stats["fail_start"] = int(pack_stats.get("fail_start", 0)) + 1

	var want := {}
	var exit_at := {}
	var goal_cells: Array[Vector2i] = []
	for g: Array in goals:
		var at: Vector2 = g[0]
		var dir: int = int(g[1])
		var lattice := _lattice_ahead(at, dir)
		if lattice == Vector2.INF:
			continue
		var cell := _cell_of(lattice, origin, w, h)
		if cell < 0:
			continue
		blocked[cell] = 0
		want[cell] = -1 if dir < 0 else (dir + 4) % 8
		exit_at[cell] = at
		goal_cells.append(Vector2i(cell % w, cell / w))
	if want.is_empty():
		pack_stats["fail_goal"] = int(pack_stats.get("fail_goal", 0)) + 1
		return PackedVector2Array()

	# Старты кладём в кучу только теперь: прикидка остатка пути считается до
	# целей, а они стали известны строкой выше.
	for row: Array in starting:
		var st_cell: int = int(row[1]) / 8
		_heap_push(heap_cost, heap_state, float(row[0]) + _octile(st_cell % w, st_cell / w, goal_cells), int(row[1]))

	var found := -1
	while not heap_state.is_empty():
		var st := _heap_pop(heap_cost, heap_state)
		if seen[st] == 1:
			continue
		seen[st] = 1
		var cell := st / 8
		var dir := st % 8
		if want.has(cell) and not entry.has(st):
			var need: int = int(want[cell])
			if need < 0 or need == dir:
				found = st
				break
		var cx := cell % w
		var cy := cell / w
		for turn: int in [-1, 0, 1]:
			var nd: int = (dir + turn + 8) % 8
			var step: Vector2 = DIRS[nd]
			var nx := cx + int(step.x)
			var ny := cy + int(step.y)
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var ncell := ny * w + nx
			if blocked[ncell] == 1:
				continue
			# По диагонали нельзя проскочить между двумя занятыми клетками:
			# трасса прошла бы ровно по углу рамки.
			if step.x != 0.0 and step.y != 0.0:
				if blocked[cy * w + nx] == 1 or blocked[ny * w + cx] == 1:
					continue
			var nst: int = ncell * 8 + nd
			var cost: float = dist[st] + step.length() * GRID * W_LEN
			if turn != 0:
				cost += W_BEND
			if cost < dist[nst]:
				dist[nst] = cost
				prev[nst] = st
				# В куче лежит цена С ПРИКИДКОЙ остатка пути: без неё это
				# честный перебор всего поля, а он на сетке в тридцать тысяч
				# состояний считается секундами. Прикидка намеренно жадная —
				# маршрут может выйти чуть длиннее идеального, зато находится
				# сразу и идёт в сторону цели.
				_heap_push(heap_cost, heap_state, cost + _octile(nx, ny, goal_cells), nst)
	if found < 0:
		pack_stats["fail_search"] = int(pack_stats.get("fail_search", 0)) + 1
		return PackedVector2Array()

	var cells: Array[Vector2] = []
	var at_state := found
	while at_state >= 0:
		var cell := at_state / 8
		cells.append(origin + Vector2(cell % w, cell / w) * GRID)
		if entry.has(at_state):
			var real: Vector2 = entry[at_state]
			if not real.is_equal_approx(cells[cells.size() - 1]):
				cells.append(real)
			break
		at_state = prev[at_state]
	cells.reverse()
	var goal_cell := found / 8
	if exit_at.has(goal_cell):
		var real_end: Vector2 = exit_at[goal_cell]
		if not real_end.is_equal_approx(cells[cells.size() - 1]):
			cells.append(real_end)
	if cells.size() < 2:
		return PackedVector2Array()

	var out := PackedVector2Array()
	for i in cells.size():
		if i == 0 or i == cells.size() - 1:
			out.append(cells[i])
			continue
		var before: Vector2 = cells[i] - cells[i - 1]
		var after: Vector2 = cells[i + 1] - cells[i]
		if not before.normalized().is_equal_approx(after.normalized()):
			out.append(cells[i])
	return out


## Номер клетки сетки под точкой, или -1 если точка вне коробки.
func _cell_of(at: Vector2, origin: Vector2, w: int, h: int) -> int:
	var cx := int(roundf((at.x - origin.x) / GRID))
	var cy := int(roundf((at.y - origin.y) / GRID))
	if cx < 0 or cy < 0 or cx >= w or cy >= h:
		return -1
	return cy * w + cx


## Ближайший узел сетки по направлению выхода из рамки. Точка выхода лежит в
## пикселе от края рамки и потому на нечётной координате, а поиск идёт по
## чётной сетке: до неё нужно пройти прямо, чтобы не появилось лишнего излома.
## Vector2.INF — узла по этому направлению нет (свободное направление у
## кольца, которое само стоит не на сетке).
static func _lattice_ahead(at: Vector2, dir: int) -> Vector2:
	if _on_lattice(at):
		return at
	if dir < 0:
		return Vector2.INF
	for k in range(1, GRID + 1):
		var p: Vector2 = at + DIRS[dir] * k
		if _on_lattice(p):
			return p
	return Vector2.INF


static func _on_lattice(p: Vector2) -> bool:
	return int(roundf(p.x)) % GRID == 0 and int(roundf(p.y)) % GRID == 0


static func _heap_push(costs: PackedFloat32Array, states: PackedInt32Array,
		cost: float, state: int) -> void:
	costs.append(cost)
	states.append(state)
	var i := states.size() - 1
	while i > 0:
		var parent := (i - 1) / 2
		if costs[parent] <= costs[i]:
			break
		var c := costs[i]
		costs[i] = costs[parent]
		costs[parent] = c
		var s := states[i]
		states[i] = states[parent]
		states[parent] = s
		i = parent


## Прикидка остатка пути до ближайшей цели: расстояние по сетке с диагоналями,
## переведённое в цену. Намеренно завышена (см. PACK_ROUTE_PULL) — иначе штраф
## за излом перевешивает всё и поиск вырождается в перебор поля.
static func _octile(cx: int, cy: int, goals: Array[Vector2i]) -> float:
	var best := INF
	for g: Vector2i in goals:
		var dx := absi(g.x - cx)
		var dy := absi(g.y - cy)
		var far := maxi(dx, dy)
		var near := mini(dx, dy)
		best = minf(best, float(far - near) + float(near) * sqrt(2.0))
	return best * GRID * PACK_ROUTE_PULL


## Достаёт самое дешёвое состояние. Повторы отсеивает вызывающий: у состояния
## в куче могла остаться прежняя, более дорогая цена.
static func _heap_pop(costs: PackedFloat32Array, states: PackedInt32Array) -> int:
	var top := states[0]
	var last := states.size() - 1
	costs[0] = costs[last]
	states[0] = states[last]
	costs.resize(last)
	states.resize(last)
	var i := 0
	while true:
		var left := i * 2 + 1
		var right := left + 1
		var small := i
		if left < last and costs[left] < costs[small]:
			small = left
		if right < last and costs[right] < costs[small]:
			small = right
		if small == i:
			break
		var c := costs[i]
		costs[i] = costs[small]
		costs[small] = c
		var s := states[i]
		states[i] = states[small]
		states[small] = s
		i = small
	return top
