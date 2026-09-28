class_name BoardSchematic
extends RefCounted

## The board as a circuit-board schematic: sites are boxes, tunnel rings are
## small circles, tunnels are traces. No hex art is drawn, but everything is
## derived from the assembled hexes and their rotations (state.layout and
## state.graph), so the schematic has exactly the adjacency the rules use.
##
## Owner's drawing rules (2026-09-16, changed 2026-09-22):
##   1. traces are straight and as parallel as possible;
##   2. traces run along the axes only and turn by 90 degrees; the corners are
##      rounded when drawn (SchematicPainter);
##   3. a trace that crosses a hex edge crosses it at the edge midpoint;
##   4. sites and rings may move, but only inside their own hex.
##
## Rule 2 used to ask for 45-degree corners, and that is why the invisible hex
## grid was squeezed across its N-S axis by exactly sqrt(3): only then do the
## diagonal neighbours sit at 45 degrees. Right angles need no such angle, so
## the squeeze is now a free parameter (SQUEEZE) and is chosen by proportion —
## the board as a whole comes out close to the golden ratio, and the hexes are
## much taller, which is what the site boxes were short of. The picture is
## still turned 90 degrees clockwise (hex north points right), so the long axis
## of the board runs along the wide screen.
##
## Layout is a small local search: each site/ring tries nearby positions, each
## tunnel picks the best octilinear route for the current positions, and the
## score punishes corners, crossings, overlapping traces, nodes leaving their
## hex and moving far from where the hex art puts them. The search runs per tile
## and rotation offline (tools/build_schematic_tiles.gd -> TILES_PATH); a game
## places those pieces and polishes the whole board once (see build).
## Tunnels stay inside their own hex, so pieces laid out alone still fit
## together, and the edge midpoints join them straight.

## Pixels from a hex centre to its north edge midpoint (a diagonal edge
## midpoint is at (K/2, K/2)). Even, so every port lands on a whole pixel.
## Экран игры — 960x540 (x2 на 1920x1080), и доска должна читаться БЕЗ
## приближения (решение владельца, 2026-09-22): карта на четверых встаёт в
## зону доски 612x456 один в один. Шаг 60 (было 128, 64, 48 под экран
## 640x360), подписи и очки шрифтом 5x7 (3x5 на новом экране не читался),
## места под войска 9 px вплотную, тупиковые кольца убраны из игры
## (MapGraph.prune_dead_ends), названия сокращены до пяти знаков (SHORT_NAMES):
## при шести рамки на тесных гексах налезали друг на друга.
## Замер: tools/measure_board.gd, наложения: tools/overlaps.gd.
const K := 60
## Во сколько раз невидимая сетка гексов сжата поперёк (см. заголовок файла).
## Прежде было ровно sqrt(3) — только так диагональные соседи вставали под 45°,
## как того требовали трассы. Трассы теперь прямоугольные, и угол не важен,
## поэтому сжатие выбирается по пропорции: 1.30 даёт доске на четверых
## соотношение сторон около золотого сечения (решение владельца, 2026-09-22).
## 1.0 — правильные шестиугольники, sqrt(3) — прежние плоские.
const SQUEEZE := 1.30
## Пропорция, к которой подгоняется доска целиком.
const GOLDEN := 1.6180339887
## Layout units from a hex centre to an edge midpoint (half the neighbour step).
const INRADIUS := 7.3612159
const GRID := 2
const STUB := 5            # shortest straight run out of an edge midpoint or a box
const PIN_MARGIN := 3      # a tunnel enters a box at least this far from its corner
const MIN_SEG := 4         # shortest visible trace segment
const TRACE_GAP := 4       # closer parallel traces count as touching
const NODE_GAP := 4
const IMAGE_MARGIN := 4

# Site box metrics (see SchematicPainter). All in pixels at 1x.
const RING_R := 4
const BOX_PAD := 1
const SLOT_R := 4
const SLOT_PITCH := 9
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

## Трассы идут только по горизонтали и вертикали, повороты на 90° (решение
## владельца, 2026-09-22; углы скругляет SchematicPainter). Порядок важен:
## соседние индексы — поворот на 90°, противоположный — +2.
const DIRS: Array[Vector2] = [
	Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1),
]

## Два поворота на 90° от направления: -1 и +1 по индексу DIRS.
const SIGNS: Array[int] = [-1, 1]

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
## Ring with two tunnels: penalty by the angle between them, index = steps of 90.
## 0 — обе трассы уходят в одну сторону (так нельзя), 1 — поворот, 2 — насквозь.
const RING_TURN := [500.0, 60.0, 0.0]
const PASSES := [[10, 40], [4, 12], [2, 4], [2, 4]]
## Whole-board polish starts from good pieces, so the coarse pass is skipped:
## same result, half the time (measured 2026-09-22).
const POLISH_PASSES := [[4, 12], [2, 4]]
const TILE_ATTEMPTS := 5
## How many times _repair goes over the board.
const REPAIR_ROUNDS := 2
## Сколько раз растаскивать оставшиеся пересечения (_push_apart).
const PUSH_ROUNDS := 10

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


## Returns {} for boards without hex layout (synthetic test graphs), else
## {
##   "size": [w, h],
##   "traces": [[x0, y0, x1, y1, ...], ...],
##   "rings": {slot_id: [x, y]},
##   "sites": {site_id: {"rect": [x, y, w, h], "name", "vp", "starting", "marker",
##             "slots": {slot_id: [x, y]}}},
##   "slots": {slot_id: {"x", "y"}},   # every troop space, rings included
## }
## polish: after the pieces are placed, run the search once more over the
## whole board (POLISH_PASSES). Without dead ends (MapGraph.prune_dead_ends)
## nodes near the board edge get room the pieces had to keep for tunnels to
## neighbours that are not there; the board comes out narrower and cleaner.
## Takes ~0.4-0.9 s (was 2-4 s before the exact cuts in _cost_around and
## _choose_route), so it runs once per game (StateView.board_snapshot); the
## dedicated server runs it off the main thread (NetSession._start_room).
static func build(state: GameState, polish := true) -> Dictionary:
	var hex_by_slot: Dictionary = state.layout.get("hex_by_slot", {})
	if hex_by_slot.is_empty():
		return {}
	var layouts: Dictionary = BoardData.load_all()["layouts"]
	var players := int(state.layout.get("player_count", state.turn_order.size()))
	var schematic := BoardSchematic.new()
	schematic._collect(state.graph, layouts[str(players)], hex_by_slot)
	schematic._index_neighbourhoods()
	schematic._apply_tiles(_load_tiles(), hex_by_slot, state.layout.get("rotations", {}))
	if polish:
		schematic._optimise(POLISH_PASSES)
	schematic._repair()
	return schematic._export(state)


## Lays out one tile at one rotation on its own, with a tunnel to every edge
## the tile prints. tools/build_schematic_tiles.gd stores the result for all
## tiles in TILES_PATH; a game only assembles those pieces (the search itself
## takes seconds, too slow for every game start). Positions are relative to
## the hex centre; ports are named "port:<world direction>".
static func layout_tile(builder: BoardBuilder, tile: String, rotation: int) -> Dictionary:
	var graph := builder.build(2, {"a": tile}, {"a": float(rotation)}, false)
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
		cost += _local_cost(e, _routes[e], _visible[e], _obstacles(e))
		for f in range(e + 1, _routes.size()):
			cost += _pair_cost(_visible[e], _visible[f])
	return cost

const TILES_PATH := "res://data/board/schematic_tiles.json"
static var _tiles_cache: Dictionary = {}


## Загрузить общие таблицы, которые build только читает. Выделенный сервер
## зовёт build из фонового потока (NetSession._start_room), а ленивая
## загрузка из двух потоков сразу — гонка; поэтому грузим в основном.
static func warm_up(state: GameState) -> void:
	_load_tiles()
	ControlMarkers.marked_sites(state)


static func _load_tiles() -> Dictionary:
	if _tiles_cache.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TILES_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			_tiles_cache = parsed
		else:
			push_warning("schematic: no tile table at %s, laying out from scratch" % TILES_PATH)
	return _tiles_cache


static func rotation_key(rotation: float) -> String:
	return str(posmod(roundi(rotation / 60.0), 6) * 60)


## "c_n1:C1_route0" -> "C1_route0" (sites and rings; ports go through _tile_name).
static func _local_name(key: String) -> String:
	return key if key.begins_with("port:") else key.get_slice(":", 1)


static func mini_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a


## Hex-local layout vector (x right, y down, units of the layout) to schematic pixels.
static func to_schematic(v: Vector2) -> Vector2:
	var squeezed := Vector2(v.x / SQUEEZE, v.y)
	return Vector2(-squeezed.y, squeezed.x) * (K / INRADIUS)


## Corners of the (invisible) hex around its centre. Height follows SQUEEZE:
## at sqrt(3) the hex is the flat one the 45-degree traces needed, at 1.0 it is
## a regular hexagon.
static func hex_polygon(centre: Vector2, inset: float = 0.0) -> PackedVector2Array:
	var k := float(K) - inset
	var tall := k * (2.0 / 3.0) * (sqrt(3.0) / SQUEEZE)
	return PackedVector2Array([
		centre + Vector2(0, -tall), centre + Vector2(k, -tall / 2.0), centre + Vector2(k, tall / 2.0),
		centre + Vector2(0, tall), centre + Vector2(-k, tall / 2.0), centre + Vector2(-k, -tall / 2.0),
	])


## Подпись локации на доске: сокращение из SHORT_NAMES, а если названия там
## нет — первые NAME_MAX знаков без лишних слов. Полное название нигде не
## теряется, оно остаётся в данных локации.
static func short_name(full: String) -> String:
	if SHORT_NAMES.has(full):
		return String(SHORT_NAMES[full]).substr(0, NAME_MAX)
	var s := full.to_upper()
	if s.begins_with("THE "):
		s = s.substr(4)
	return s if s.length() <= NAME_MAX else s.substr(0, NAME_MAX)


## Size of a site box and its troop spaces relative to the box's top-left corner.
## marker: город с маркером контроля — слева от мест столбик из двух значков
## (MARKER_ICONS_W x MARKER_ICONS_H): «◆1» над «корона N».
static func site_box(site_name: String, slot_count: int, marker := false) -> Dictionary:
	var name_w := PixelFont.text_width(short_name(site_name))
	var cols := mini(maxi(slot_count, 1), SLOT_COLS)
	var rows := int(ceil(slot_count / float(SLOT_COLS)))
	var slots_w := cols * SLOT_PITCH - 2
	var icons_w := MARKER_ICONS_W + 2 if marker else 0
	# Ширина цифры очков со свободным пикселем справа: без него цифра упиралась
	# в рамку, а входящая в этом же ряду трасса читалась как перечёркивание.
	var vp_w := PixelFont.ADVANCE * VP_SCALE
	var body_w := icons_w + slots_w + 4 + vp_w
	var inner_w := maxi(name_w, body_w)
	var body_h := maxi(rows * SLOT_PITCH - 2, PixelFont.HEIGHT * VP_SCALE)
	if marker:
		body_h = maxi(body_h, MARKER_ICONS_H)
	var w := 2 + 2 * BOX_PAD + inner_w
	var h := 2 + 2 * BOX_PAD + PixelFont.HEIGHT + NAME_GAP + body_h
	var left := 1 + BOX_PAD + (inner_w - body_w) / 2
	var body_top := 1 + BOX_PAD + PixelFont.HEIGHT + NAME_GAP
	var top := body_top + (body_h - (rows * SLOT_PITCH - 2)) / 2
	var slots: Array[Vector2] = []
	for i in slot_count:
		var row := i / SLOT_COLS
		var in_row := mini(SLOT_COLS, slot_count - row * SLOT_COLS)
		var shift := (cols - in_row) * SLOT_PITCH / 2
		slots.append(Vector2(left + icons_w + shift + (i % SLOT_COLS) * SLOT_PITCH + SLOT_R,
			top + row * SLOT_PITCH + SLOT_R))
	var result := {
		"w": w, "h": h, "slots": slots,
		"name_at": Vector2(1 + BOX_PAD + (inner_w - name_w) / 2, 1 + BOX_PAD),
		"vp_at": Vector2(left + icons_w + slots_w + 4, body_top + (body_h - PixelFont.HEIGHT * VP_SCALE) / 2),
	}
	if marker:
		result["icons_at"] = Vector2(left, body_top + (body_h - MARKER_ICONS_H) / 2)
	return result


## Столбик значков города с маркером: значок 5x5 и цифра 3x5 через пиксель,
## два ряда через пиксель.
const MARKER_ICONS_W := 9
const MARKER_ICONS_H := 11


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
		var box := site_box(String(site["name"]), members.size(), ControlMarkers.is_marked(String(site["hex"]), String(site["name"])))
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
## neighbouring hex; with the 5x7 board font boxes are big enough that the
## polish can also leave two nodes of one hex touching. Only those nodes are
## moved, a little. Rings go first: a small ring steps aside easily. A move
## that lands the node on anything is taken back, and the other node of the
## pair gets its turn. A move can free one pair and touch another, so the
## pass runs a few times.
func _repair() -> void:
	for _round in REPAIR_ROUNDS:
		for kind in [Kind.RING, Kind.SITE]:
			for n in _key.size():
				if _kind[n] == kind and _crowded(n):
					_step_aside(n)
	_push_apart()
	# a moved box may now sit on a tunnel of the neighbouring hex
	for e in _routes.size():
		if _local_cost(e, _routes[e], _visible[e], _obstacles(e)) >= W_HIT:
			_choose_route(e, {})


## Последнее средство: рамки, которые всё ещё пересекаются, просто
## растаскиваются в стороны по кратчайшей оси — по половине перекрытия каждой.
## Поиск места до этого работает внутри своего гекса, и на тесных гексах
## свободного места там иногда нет вовсе. Гексы не рисуются, так что выход
## рамки за свой гекс не виден, а вот наложение видно сразу. Трассы после
## сдвига перекладываются (см. конец _repair).
func _push_apart() -> void:
	for _round in PUSH_ROUNDS:
		var moved := false
		for n in _key.size():
			if _kind[n] == Kind.PORT:
				continue
			for m: int in _near[_hex[n]]:
				if m <= n or _kind[m] == Kind.PORT:
					continue
				var over := _node_rect(n).intersection(_node_rect(m))
				if over.size.x <= 0.0 or over.size.y <= 0.0:
					continue
				# Двигаем один узел на целое число шагов сетки: половина
				# перекрытия у соседних рамок бывает меньше шага, и _snap
				# возвращал бы узел на прежнее место.
				var by := over.size.x if over.size.x <= over.size.y else over.size.y
				var steps := ceilf((by + 1.0) / float(GRID)) * float(GRID)
				var axis := Vector2(1.0, 0.0) if over.size.x <= over.size.y else Vector2(0.0, 1.0)
				# Уступает меньший: кольцу подвинуться проще, чем рамке локации.
				var small := m if _node_rect(m).get_area() <= _node_rect(n).get_area() else n
				var other := n if small == m else m
				var away: float = (_pos[small] - _pos[other]).dot(axis)
				_pos[small] = _snap(_pos[small] + axis * steps * (1.0 if away >= 0.0 else -1.0))
				moved = true
		if not moved:
			return


## A node of another hex closer than NODE_GAP, or one of its own hex touching.
func _crowded(n: int) -> bool:
	var grown := _node_rect(n, NODE_GAP)
	var rect := _node_rect(n)
	for m: int in _near[_hex[n]]:
		if m == n:
			continue
		if _hex[m] != _hex[n] and grown.intersects(_node_rect(m)):
			return true
		if _hex[m] == _hex[n] and rect.intersects(_node_rect(m)):
			return true
	return false


## Уводит узел на лучшее место рядом: так рамка не
## уезжает далеко от своего места на арте. Место
## оставляем за собой даже когда наложение убралось не
## полностью, лучшее по цене место перекрывает соседа меньше, а доводка
## сдвинет ещё и самого соседа (REPAIR_ROUNDS).
func _step_aside(n: int) -> void:
	_move_node(n, 2, 12)


## The node's box or ring actually overlaps another one (gaps not counted).
func _touches_any(n: int) -> bool:
	var rect := _node_rect(n)
	for m: int in _near[_hex[n]]:
		if m != n and rect.intersects(_node_rect(m)):
			return true
	return false


static func _snap(p: Vector2) -> Vector2:
	return (p / GRID).round() * GRID


## Ближайший узел ровной сетки с шагом K/4: кольца встают в один ряд и в один
## столбец друг с другом и с серединами рёбер, и прямая трасса между соседями
## идёт без изломов. Прежде сетка была шахматной (i + j чётное) — под трассы
## под 45°; для прямых углов это только мешало бы ровным рядам.
static func _lattice(v: Vector2) -> Vector2:
	var step := K / 4.0
	return (v / step).round() * step


## Ближайшее из четырёх направлений: по большей из двух осей.
static func _dir_index(v: Vector2) -> int:
	if absf(v.x) >= absf(v.y):
		return 0 if v.x >= 0.0 else 2
	return 1 if v.y >= 0.0 else 3


# --- routes ----------------------------------------------------------------------

## Polyline through `count` runs in directions d0..d3 with lengths l0..l3;
## a length < 0 is solved so the line ends at B. The search calls this a few
## hundred thousand times per board, so the runs are plain arguments rather
## than arrays: allocating two arrays per call was most of the build time.
static func _solve(a: Vector2, b: Vector2, count: int, d0: int, d1: int, d2: int, d3: int,
		l0: float, l1: float, l2: float, l3: float, equal_ends := false) -> PackedVector2Array:
	var rest := b - a
	var unknown_a := -1
	var unknown_b := -1
	var unknowns := 0
	for i in count:
		var l := _pick_f(i, l0, l1, l2, l3)
		if l < 0.0:
			if unknowns == 0:
				unknown_a = i
			elif unknowns == 1:
				unknown_b = i
			unknowns += 1
		else:
			rest -= DIRS[_pick_i(i, d0, d1, d2, d3)] * l
	if equal_ends:
		# [d1 x, d2 y, d1 x]: symmetric jog, the two outer runs share a length
		var u := DIRS[d0] * 2.0
		var v := DIRS[d1]
		var den := u.x * v.y - u.y * v.x
		if absf(den) < 0.001:
			return PackedVector2Array()
		l0 = (rest.x * v.y - rest.y * v.x) / den
		l2 = l0
		l1 = (u.x * rest.y - u.y * rest.x) / den
	elif unknowns == 2:
		var u2 := DIRS[_pick_i(unknown_a, d0, d1, d2, d3)]
		var v2 := DIRS[_pick_i(unknown_b, d0, d1, d2, d3)]
		var den2 := u2.x * v2.y - u2.y * v2.x
		if absf(den2) < 0.001:
			return PackedVector2Array()
		var len_a := (rest.x * v2.y - rest.y * v2.x) / den2
		var len_b := (u2.x * rest.y - u2.y * rest.x) / den2
		if unknown_a == 0: l0 = len_a
		elif unknown_a == 1: l1 = len_a
		elif unknown_a == 2: l2 = len_a
		else: l3 = len_a
		if unknown_b == 1: l1 = len_b
		elif unknown_b == 2: l2 = len_b
		else: l3 = len_b
	elif unknowns == 1:
		var d := DIRS[_pick_i(unknown_a, d0, d1, d2, d3)]
		var t := rest.dot(d) / d.length_squared()
		if not (rest - d * t).is_zero_approx():
			return PackedVector2Array()
		if unknown_a == 0: l0 = t
		elif unknown_a == 1: l1 = t
		elif unknown_a == 2: l2 = t
		else: l3 = t
	# a run that came out too short (or unsolved) rules the route out
	if l0 < 0.99 or (count > 1 and l1 < 0.99) or (count > 2 and l2 < 0.99) or (count > 3 and l3 < 0.99):
		return PackedVector2Array()
	var points := PackedVector2Array()
	points.resize(count + 1)
	points[0] = a
	var at := a
	for i in count:
		at += DIRS[_pick_i(i, d0, d1, d2, d3)] * _pick_f(i, l0, l1, l2, l3)
		points[i + 1] = at
	return points


static func _pick_i(i: int, v0: int, v1: int, v2: int, v3: int) -> int:
	return v0 if i == 0 else (v1 if i == 1 else (v2 if i == 2 else v3))


static func _pick_f(i: int, v0: float, v1: float, v2: float, v3: float) -> float:
	return v0 if i == 0 else (v1 if i == 1 else (v2 if i == 2 else v3))


func _variants(e: int) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var a := _edge_a[e]
	var b := _edge_b[e]
	var ends_b := _ends(b, a, e)
	for end_a: Array in _ends(a, b, e):
		for end_b: Array in ends_b:
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
	for side: Array in [[0, rect.end.x - 1], [2, rect.position.x + 1]]:
		if toward.x * DIRS[side[0]].x > _half[n].x * 0.5:
			var lo := rect.position.y + PIN_MARGIN
			var hi := rect.end.y - PIN_MARGIN
			for y: float in [clampf(_pos[other].y, lo, hi), _pos[n].y]:
				_add_end(ends, Vector2(side[1], _snap_axis(y, lo, hi)), side[0])
	for side2: Array in [[1, rect.end.y - 1], [3, rect.position.y + 1]]:
		if toward.y * DIRS[side2[0]].y > 0.0:
			var lo2 := rect.position.x + PIN_MARGIN
			var hi2 := rect.end.x - PIN_MARGIN
			for x: float in [clampf(_pos[other].x, lo2, hi2), _pos[n].x]:
				_add_end(ends, Vector2(_snap_axis(x, lo2, hi2), side2[1]), side2[0])
	if ends.is_empty():
		ends = [[Vector2(rect.end.x - 1, _pos[n].y), 0], [Vector2(rect.position.x + 1, _pos[n].y), 2]]
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
		_keep(out, _solve(a, b, 1, _dir_index(b - a), 0, 0, 0, -1, -1, -1, -1))
		# only the two directions that bracket the straight line can reach b
		var d := int(floor(fposmod((b - a).angle(), TAU) / (PI / 2.0))) % 4
		var d_next := (d + 1) % 4
		_keep(out, _solve(a, b, 2, d, d_next, 0, 0, -1, -1, -1, -1))
		_keep(out, _solve(a, b, 2, d_next, d, 0, 0, -1, -1, -1, -1))
		_keep(out, _solve(a, b, 3, d, d_next, d, 0, -1, -1, -1, -1, true))
		_keep(out, _solve(a, b, 3, d_next, d, d_next, 0, -1, -1, -1, -1, true))
		return
	var last := -1 if db < 0 else (db + 2) % 4
	var found := out.size()
	if last < 0 or last == da:
		_keep(out, _solve(a, b, 1, da, 0, 0, 0, -1, -1, -1, -1))
	for s1: int in SIGNS:
		var d1 := (da + s1 + 4) % 4
		if last < 0 or last == d1:
			_keep(out, _solve(a, b, 2, da, d1, 0, 0, -1, -1, -1, -1))
		for s2: int in SIGNS:
			var d2 := (d1 + s2 + 4) % 4
			if last >= 0 and last != d2:
				continue
			_keep(out, _solve(a, b, 3, da, d1, d2, 0, STUB, -1, -1, -1))
			_keep(out, _solve(a, b, 3, da, d1, d2, 0, -1, -1, STUB, -1))
			# [-1, STUB, -1] is not tried: da and d2 are parallel, so the two
			# unknown runs can never be solved (it always came out empty).
			if d2 == da:
				_keep(out, _solve(a, b, 3, da, d1, d2, 0, -1, -1, -1, -1, true))
	if out.size() > found:
		return
	# nothing short fits: allow a third corner
	for s1: int in SIGNS:
		for s2: int in SIGNS:
			for s3: int in SIGNS:
				var d1 := (da + s1 + 4) % 4
				var d2 := (d1 + s2 + 4) % 4
				var d3 := (d2 + s3 + 4) % 4
				if last >= 0 and last != d3:
					continue
				_keep(out, _solve(a, b, 4, da, d1, d2, d3, STUB, -1, -1, STUB))
				_keep(out, _solve(a, b, 4, da, d1, d2, d3, STUB, STUB, -1, -1))


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


## Boxes and rings a tunnel of edge e must not run through (its own two ends
## excluded), grown by 2 px. Depends only on node positions, so _choose_route
## makes it once for all route variants.
func _obstacles(e: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for n: int in _near[_hex[_edge_b[e]]]:
		if n != _edge_a[e] and n != _edge_b[e]:
			out.append(_node_rect(n, 2.0))
	return out


## The first terms of _local_cost (corners and length), summed the same way.
## Everything else _local_cost adds is >= 0, so this is a floor under it.
static func _shape_cost(points: PackedVector2Array) -> float:
	var cost := (points.size() - 2) * W_BEND
	for i in points.size() - 1:
		cost += points[i].distance_to(points[i + 1]) * W_LEN
	return cost


func _local_cost(e: int, points: PackedVector2Array, segs: PackedVector2Array, obstacles: Array[Rect2]) -> float:
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
	var poly: PackedVector2Array = _poly[_hex[_edge_b[e]]]
	for i in range(0, segs.size(), 2):
		var p0 := segs[i]
		var p1 := segs[i + 1]
		var mid := (p0 + p1) * 0.5
		if not Geometry2D.is_point_in_polygon(p0, poly):
			cost += _outside_by(p0, poly) * W_OUT_PX
		if not Geometry2D.is_point_in_polygon(p1, poly):
			cost += _outside_by(p1, poly) * W_OUT_PX
		if not Geometry2D.is_point_in_polygon(mid, poly):
			cost += _outside_by(mid, poly) * W_OUT_PX
	var reach := _bounds(segs)
	for rect in obstacles:
		if not reach.intersects(rect):
			continue
		for i in range(0, segs.size(), 2):
			if _segment_hits_rect(segs[i], segs[i + 1], rect):
				cost += W_HIT
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
			steps = mini(steps, 4 - steps)
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
	var rect := _node_rect(n)
	for corner in [rect.position, rect.end, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y)]:
		if not Geometry2D.is_point_in_polygon(corner, poly):
			cost += W_OUT + _outside_by(corner, poly) * W_OUT_PX
	var grown := _node_rect(n, NODE_GAP)
	for m: int in _near[_hex[n]]:
		if m == n:
			continue
		var other := _node_rect(m)
		if grown.intersects(other):
			cost += W_NODE_OVERLAP + grown.intersection(other).get_area() * 0.5
	return cost


## Pick the cheapest route for edge e with the endpoints where they are now.
## base, hits, limit: the cut of _cost_around. If even the cheapest route
## would bring the sum to limit, nothing is chosen and INF is returned.
func _choose_route(e: int, skip: Dictionary, base := 0.0, hits := 0, limit := INF) -> float:
	var ranked: Array = []
	var variants := _variants(e)
	if limit < INF and not variants.is_empty():
		var floor_cost := INF
		for points in variants:
			floor_cost = minf(floor_cost, _shape_cost(points))
		if _with_hits(base + floor_cost, hits) >= limit:
			return INF
	var obstacles := _obstacles(e)
	for points in variants:
		var segs := _clip(e, points)
		ranked.append([_local_cost(e, points, segs, obstacles), points, segs])
	ranked.sort_custom(func(x, y): return x[0] < y[0])
	if not ranked.is_empty() and _with_hits(base + float(ranked[0][0]), hits) >= limit:
		return INF
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
## Every term is >= 0, so once the sum so far reaches limit the node's place
## cannot win and the rest is skipped (returns INF). That cut is exact: the
## search keeps the same places it would without it, just ~3x faster. Routes
## of n are then left half-chosen, which is fine: _move_node restores them.
func _cost_around(n: int, limit: float = INF) -> float:
	var inc: Array = _incident[n]
	var skip := {}
	for e: int in inc:
		skip[e] = true
	var cost := _node_cost(n)
	# Traces of other nodes that run through n's box. They do not depend on
	# n's own routes, so they are counted first (for the cut) and added last
	# (so the sum is the same number, bit for bit, as before the cut).
	var hits := 0
	var rect := _node_rect(n, 2.0)
	for f in _routes.size():
		if skip.has(f) or _edge_a[f] == n or _edge_b[f] == n or not rect.intersects(_bbox[f]):
			continue
		var segs := _visible[f]
		for i in range(0, segs.size(), 2):
			if _segment_hits_rect(segs[i], segs[i + 1], rect):
				hits += 1
				break
	if _with_hits(cost, hits) >= limit:
		return INF
	for e: int in inc:
		var route_cost := _choose_route(e, skip, cost, hits, limit)
		if route_cost == INF:
			return INF
		cost += route_cost
		if _with_hits(cost, hits) >= limit:
			return INF
	for i in inc.size():
		for j in range(i + 1, inc.size()):
			cost += _pair_cost(_visible[inc[i]], _visible[inc[j]])
	cost += _ring_cost(n)
	for e: int in inc:
		var other := _edge_b[e] if _edge_a[e] == n else _edge_a[e]
		cost += _ring_cost(other)
	return _with_hits(cost, hits)


static func _with_hits(cost: float, hits: int) -> float:
	for _i in hits:
		cost += W_HIT
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


func _optimise(passes: Array = PASSES) -> void:
	_index_neighbourhoods()
	for e in _routes.size():
		_choose_route(e, {e: true})
	for e in _routes.size():
		_choose_route(e, {})
	for pass_info: Array in passes:
		var step: int = pass_info[0]
		var radius: int = pass_info[1]
		for n in _key.size():
			if _kind[n] == Kind.PORT:
				continue
			_move_node(n, step, radius)
		for e in _routes.size():
			_choose_route(e, {})


func _move_node(n: int, step: int, radius: int) -> void:
	var start := _pos[n]
	var inc: Array = _incident[n]
	var poly: PackedVector2Array = _poly_nodes[_hex[n]] if _kind[n] != Kind.PORT \
		else hex_polygon(_centre[_hex[n]])
	var best_cost := _cost_around(n)
	var best_pos := start
	var best_routes: Array = _snapshot_routes(inc)
	for dy in range(-radius, radius + 1, step):
		for dx in range(-radius, radius + 1, step):
			if dx == 0 and dy == 0:
				continue
			var p := start + Vector2(dx, dy)
			if not Geometry2D.is_point_in_polygon(p, poly):
				continue
			_pos[n] = p
			var cost := _cost_around(n, best_cost - 0.01)
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
			var box := site_box(String(site["name"]), members.size(), marked.has(_key[n]))
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
				# VP за полный контроль и где в коробке столбик значков маркера.
				"marker_vp": int(ControlMarkers.marker_for(state, _key[n]).get("total_control_vp", 0)),
				"icons_at": [corner.x + (box.get("icons_at", Vector2.ZERO) as Vector2).x, corner.y + (box.get("icons_at", Vector2.ZERO) as Vector2).y],
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

	# Какая печатная плитка стоит в каждом гексе схемы и с каким поворотом —
	# нужно только фоновому арту (SchematicPainter._paint_background):
	# трассы и рамки сами по себе от id и поворота плитки не зависят.
	var hex_by_slot: Dictionary = state.layout.get("hex_by_slot", {})
	var rotations: Dictionary = state.layout.get("rotations", {})
	var hexes := {}
	for hex: String in _centre.keys():
		hexes[hex] = {
			"tile": String(hex_by_slot.get(hex, "")),
			"rotation": float(rotations.get(hex, 0.0)),
			"x": (_centre[hex] as Vector2).x + shift.x,
			"y": (_centre[hex] as Vector2).y + shift.y,
		}
	return {
		"size": [size.x, size.y], "traces": traces, "rings": rings, "sites": sites, "slots": slots,
		# for checks and debugging: which nodes each trace joins, edge midpoints, hex centres
		"trace_ends": trace_ends, "ports": ports, "hex_centres": centres, "hexes": hexes,
		"fallback_routes": _fallback_routes,
	}
