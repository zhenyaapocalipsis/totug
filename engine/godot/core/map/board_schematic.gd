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
## Свободные пиксели между низом кругов мест и нижней рамкой коробки (решение
## владельца, 2026-09-29): без них нижний пиксель круга ложился прямо на рамку.
const SLOT_BOTTOM_GAP := 1
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

enum Kind { SITE, RING, PORT, LEGEND }

## Табличка ярусов бонуса A2 (BoardPanel рисует в ней три строки значков):
## размер в пикселях схемы и имя узла внутри гекса.
const A2_LEGEND := Vector2(42, 26)
const A2_LEGEND_KEY := "a2_legend"

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
## Доска во всю свою зону (решение владельца, 2026-10-03): собранные гексы
## раздвигаются целиком — содержимое гекса не трогается, растут только щели
## между гексами, и туннели переходят через щель (см. _spread). ZONE — зона
## доски на экране 960x540 (GameScreen, после Stage Mini-1), в пикселях схемы
## при 1:1. Пока только на четверых: на 2-3 игроков щели вышли бы широкими,
## это владелец решит по скриншотам.
const ZONE := Vector2(697, 456)
## Верх зоны занимает вопрос «X decides — click a gold site on the board» в
## две строки (DecisionDialog у верхнего края), низ во время хода — счётчик
## Power/Influence над рукой (владелец, 2026-10-04: доска на них не заходит).
## Доска раздвигается между ними, BoardPanel ставит её по центру этой части.
const PROMPT_STRIP := 36.0
const BOTTOM_STRIP := 26.0
const SPREAD_PLAYERS := [4]
## Запас по краю зоны: _repair после раздвигания может чуть сдвинуть трассу.
const SPREAD_SLACK := 4.0
## Рамки городов разных гексов при раздвигании стремятся разойтись хотя бы на
## столько (по большей из осей) — группы гексов читаются отдельно.
const BOX_ZONE_GAP := 32.0


## Кратчайший прямой отрезок «ступеньки» в щели между диагональными соседями:
## скругление угла съедает по 3 px с каждой стороны.
const JOG_MIN := 6
## Сколько раз растаскивать оставшиеся пересечения (_push_apart).
const PUSH_ROUNDS := 10
const PUSH_GAP := 3.0      # least gap between boxes after _push_apart (see there)

var _key: Array[String] = []
var _kind: Array[int] = []
var _hex: Array[String] = []
var _pos: Array[Vector2] = []
var _home: Array[Vector2] = []
var _half: Array[Vector2] = []
var _index: Dictionary = {}          # key -> node index
var _centre: Dictionary = {}         # layout slot -> Vector2
var _lattice_centre: Dictionary = {} # то же до раздвигания (_spread): кто кому сосед
var _marked: Dictionary = {}         # node -> true: город с маркером контроля
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
	if SPREAD_PLAYERS.has(players):
		schematic._spread(ZONE - Vector2(0, PROMPT_STRIP + BOTTOM_STRIP))
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
	# Нижний пиксель последнего ряда кругов, под ним зазор и рамка.
	if slot_count > 0:
		h = maxi(h, top + rows * SLOT_PITCH - 1 + SLOT_BOTTOM_GAP + 2)
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
		_lattice_centre[layout_slot] = _centre[layout_slot]

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
		var site_node := _add_node(site_id, Kind.SITE, hex, home, Vector2(int(box["w"]) / 2, int(box["h"]) / 2))
		if ControlMarkers.is_marked(String(site["hex"]), String(site["name"])):
			_marked[site_node] = true
	# Табличка ярусов бонуса A2 — узел без туннелей рядом с его тремя
	# городами: раскладка сама найдёт ей место, соседи и туннели её обходят.
	var a2_homes := {}
	for site_id: String in graph.sites.keys():
		if ClusterBonus.SITE_NAMES.has(String(graph.sites[site_id]["name"])):
			var hex_a2 := site_id.get_slice(":", 0)
			if not a2_homes.has(hex_a2):
				a2_homes[hex_a2] = []
			(a2_homes[hex_a2] as Array).append(_home[_index[site_id]])
	for hex_a2: String in a2_homes:
		var homes: Array = a2_homes[hex_a2]
		if homes.size() != ClusterBonus.SITE_NAMES.size():
			continue
		var centre := Vector2.ZERO
		for h: Vector2 in homes:
			centre += h
		_add_node(hex_a2 + ":" + A2_LEGEND_KEY, Kind.LEGEND, hex_a2, centre / homes.size(), A2_LEGEND / 2.0)
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
		for kind in [Kind.RING, Kind.LEGEND, Kind.SITE]:
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
## Рамки растаскиваются до зазора PUSH_GAP, а не до касания: у рамки нечётной
## ширины (45) _half округлён вниз, и на экране она на пиксель шире, чем
## _node_rect. «Касающиеся» по расчёту Red Gate и Caer Sidi рисовались с общей
## линией рамки — слипались (жалоба владельца, 2026-09-30).
func _push_apart() -> void:
	var pushed := {}
	for _round in PUSH_ROUNDS:
		var moved := false
		for n in _key.size():
			if _kind[n] == Kind.PORT:
				continue
			for m: int in _near[_hex[n]]:
				if m <= n or _kind[m] == Kind.PORT:
					continue
				var over := _node_rect(n, PUSH_GAP * 0.5).intersection(_node_rect(m, PUSH_GAP * 0.5))
				if over.size.x <= 0.0 or over.size.y <= 0.0:
					continue
				# Двигаем один узел на целое число шагов сетки: половина
				# перекрытия у соседних рамок бывает меньше шага, и _snap
				# возвращал бы узел на прежнее место.
				# Уступает меньший: кольцу подвинуться проще, чем рамке локации.
				var small := m if _node_rect(m).get_area() <= _node_rect(n).get_area() else n
				var other := n if small == m else m
				# Сначала по короткой оси; если сдвиг кладёт узел на третьего
				# соседа (узел зажат между двумя), пробуем второй узел пары и
				# другую ось — иначе пара качалась бы туда-сюда до конца раундов.
				var short_x := over.size.x <= over.size.y
				var first := _pos[small]
				var first_set := false
				var placed := false
				for axis: Vector2 in ([Vector2.RIGHT, Vector2.DOWN] if short_x else [Vector2.DOWN, Vector2.RIGHT]):
					var by: float = over.size.x if axis.x != 0.0 else over.size.y
					var steps := ceilf((by + 1.0) / float(GRID)) * float(GRID)
					for mover: int in [small, other]:
						var still := other if mover == small else small
						var away: float = (_pos[mover] - _pos[still]).dot(axis)
						var to := _snap(_pos[mover] + axis * steps * (1.0 if away >= 0.0 else -1.0))
						if not first_set:
							first_set = true
							first = to
						if _free_at(mover, to):
							_pos[mover] = to
							pushed[mover] = true
							placed = true
							break
					if placed:
						break
				if not placed:
					_pos[small] = first
					pushed[small] = true
				moved = true
		if not moved:
			break
	# Туннели сдвинутых узлов заканчивались бы на прежнем месте рамки.
	for n: int in pushed:
		for e: int in _incident[n]:
			_choose_route(e, {})


## Встанет ли узел n в точку at с зазором PUSH_GAP до всех соседей.
func _free_at(n: int, at: Vector2) -> bool:
	var was := _pos[n]
	_pos[n] = at
	var rect := _node_rect(n, PUSH_GAP * 0.5)
	var free := true
	for m: int in _near[_hex[n]]:
		if m == n or _kind[m] == Kind.PORT:
			continue
		var over := rect.intersection(_node_rect(m, PUSH_GAP * 0.5))
		if over.size.x > 0.0 and over.size.y > 0.0:
			free = false
			break
	_pos[n] = was
	return free


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
			if _kind[n] != Kind.PORT and (_lattice_centre[hex] as Vector2).distance_to(_lattice_centre[_hex[n]]) < K * 2.1:
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


# --- spread ------------------------------------------------------------------------

## Раздвигает готовую доску до зоны. Каждый гекс сдвигается целиком, внутри
## гексов ничего не меняется, растут только щели между ними. Туннель через
## ребро идёт через щель: прямо, если соседи сдвинулись одинаково вбок, иначе
## «ступенькой» из двух поворотов (_bridge_path). Точка встречи (узел PORT)
## лежит на прямом участке, и обе половины сходятся в ней встречно.
##
## Сдвиги ищет _spread_offsets (решение владельца, 2026-10-03, по рисунку):
## внешние гексы уходят наружу до края зоны — угловые по диагонали, в углы;
## гексы вокруг центра отходят «чуть дальше», пока щель до центра не
## сравняется со щелью до внешних соседей. Центральный гекс стоит на месте.
func _spread(zone: Vector2) -> void:
	var ports := _spread_ports()
	var off := _spread_offsets(ports, zone)
	if off.is_empty():
		return
	for hex: String in off.keys():
		_centre[hex] = (_lattice_centre[hex] as Vector2) + (off[hex] as Vector2)
	for n in _key.size():
		if _kind[n] != Kind.PORT:
			_pos[n] += off[_hex[n]]
			_home[n] += off[_hex[n]]
	for e in _routes.size():
		var by: Vector2 = off[_hex[_edge_b[e]]]
		var points := _routes[e]
		for i in points.size():
			points[i] += by
		_routes[e] = points
	for i in ports.size():
		var port: Dictionary = ports[i]
		var m_a: Vector2 = (port["p"] as Vector2) + (off[port["a"]] as Vector2)
		var m_b: Vector2 = (port["p"] as Vector2) + (off[port["b"]] as Vector2)
		if _grid_full.has(i) and int(_grid_full[i]) != 0:
			# развилка у стыка осталась на месте, трасса другой стороны — от неё
			var from_a := int(_grid_full[i]) == 1
			_pos[port["node"]] = m_a if from_a else m_b
			_home[port["node"]] = _pos[port["node"]]
			var whole_path: PackedVector2Array = _grid_paths[i]
			if from_a:
				_set_route(port["edges_b"][0], whole_path)
			else:
				whole_path = whole_path.duplicate()
				whole_path.reverse()
				_set_route(port["edges_a"][0], whole_path)
			continue
		if _grid_full.has(i):
			# трасса проложена целиком: делится в точке встречи на две
			var whole := _split_path(_grid_paths[i])
			_pos[port["node"]] = (whole["a"] as PackedVector2Array)[0]
			_home[port["node"]] = _pos[port["node"]]
			_set_route(port["edges_a"][0], whole["a"])
			_set_route(port["edges_b"][0], whole["b"])
			continue
		var path := _split_path(_grid_paths[i]) if _grid_paths.has(i) \
			else _bridge_path(m_a, m_b, port["u"], int(port.get("mode", 0)), port["run_a"], port["run_b"])
		var meet: Vector2 = (path["a"] as PackedVector2Array)[0]
		_pos[port["node"]] = meet
		_home[port["node"]] = meet
		for e: int in port["edges_a"]:
			_bridge(e, m_a, path["a"])
		for e: int in port["edges_b"]:
			_bridge(e, m_b, path["b"])
	# трассы внутри гексов, проложенные заново (от узла _edge_a до _edge_b)
	for j: int in _grid_full:
		if j >= ports.size():
			_set_route(_rt_inner[j - ports.size()], _grid_paths[j])
	# _repair здесь не нужен и вреден: _sp_ok уже не пустил ни одного касания,
	# а цена трассы (_local_cost) штрафует мостик за выход из своего гекса —
	# _repair переложил бы его через полдоски поперёк чужих трасс.
	_index_neighbourhoods()


## Путь через щель от середины ребра гекса A (m_a) до середины ребра гекса B
## (m_b); u — направление от A к B, в нём трассы входят в рёбра. run_a, run_b —
## длина прямого последнего участка трассы до ребра: ступенька может стоять
## и на нём, а не только в щели (так соседи расходятся вбок, даже когда щели
## вдоль u нет). mode — где ступенька поворачивает: 0 посередине щели, 1 у
## гекса A, 2 у B (_sp_ok выбирает тот, что ни на что не ложится).
## Ответ: "a" — от точки встречи к трассе A (кончается на её прямом участке),
## "b" — к трассе B, "check" — только новые отрезки (для проверок).
const BRIDGE_MODES := 3

static func _bridge_path(m_a: Vector2, m_b: Vector2, u: Vector2, mode := 0,
		run_a := 0.0, run_b := 0.0) -> Dictionary:
	var along := (m_b - m_a).dot(u)
	var side := (m_b - m_a) - u * along
	if side.length() < 0.5:
		var mid := m_a + u * roundf(along / 2.0)
		return {"a": PackedVector2Array([mid, m_a]), "b": PackedVector2Array([mid, m_b]),
			"check": PackedVector2Array([m_a, m_b])}
	var e_a := m_a - u * run_a
	var e_b := m_b + u * run_b
	var span := run_a + along + run_b
	var t := run_a + roundf(along / 2.0)
	if mode == 1:
		t = JOG_MIN
	elif mode == 2:
		t = span - JOG_MIN
	t = clampf(t, JOG_MIN, span - JOG_MIN)
	var turn := e_a + u * t
	var turn2 := turn + side
	var check := PackedVector2Array([m_a if t >= run_a else turn, turn, turn2,
		m_b if span - t >= run_b else turn2])
	# точка встречи — посередине более длинного прямого участка
	if t >= span - t:
		var meet := e_a + u * roundf(t / 2.0)
		return {"a": PackedVector2Array([meet, e_a]), "b": PackedVector2Array([meet, turn, turn2, e_b]),
			"check": check}
	var meet2 := turn2 + u * roundf((span - t) / 2.0)
	return {"a": PackedVector2Array([meet2, turn2, turn, e_a]), "b": PackedVector2Array([meet2, e_b]),
		"check": check}


## Узлы PORT, которые соединяют ровно два гекса: {node, a, b, p, u, edges_a, edges_b}.
func _spread_ports() -> Array:
	var ports: Array = []
	for n in _key.size():
		if _kind[n] != Kind.PORT:
			continue
		var by_hex := {}
		for e: int in _incident[n]:
			var hex: String = _hex[_edge_b[e]]
			if not by_hex.has(hex):
				by_hex[hex] = []
			(by_hex[hex] as Array).append(e)
		if by_hex.size() != 2:
			push_warning("schematic: port %s does not join two hexes" % _key[n])
			continue
		var a: String = by_hex.keys()[0]
		var b: String = by_hex.keys()[1]
		ports.append({"node": n, "a": a, "b": b, "p": _pos[n],
			"u": DIRS[_edge_dir[(by_hex[b] as Array)[0]]],
			"edges_a": by_hex[a], "edges_b": by_hex[b],
			"run_a": _last_run(by_hex[a], _pos[n]), "run_b": _last_run(by_hex[b], _pos[n])})
	return ports


## Самый короткий прямой участок, которым трассы edges подходят к точке at.
func _last_run(edges: Array, at: Vector2) -> float:
	var shortest := INF
	for e: int in edges:
		var pts := _routes[e]
		if pts.size() < 2:
			return 0.0
		var near := pts[0] if pts[0].distance_to(at) <= pts[pts.size() - 1].distance_to(at) else pts[pts.size() - 1]
		var next := pts[1] if near == pts[0] else pts[pts.size() - 2]
		shortest = minf(shortest, near.distance_to(next))
	return 0.0 if shortest == INF else shortest


# Состояние поиска сдвигов (_spread_offsets и проверки при нём).
var _sp_off := {}          # hex -> Vector2
var _sp_items := {}        # hex -> Array of [Rect2, edge or -1]: рамки, кольца, отрезки трасс
var _sp_box := {}          # hex -> Rect2 вокруг всех его _sp_items
var _sp_sites := {}        # hex -> Array[Rect2] рамок его городов
var _sp_ports: Array = []
var _sp_port_edges: Array = []   # port index -> {edge: true}
var _sp_ports_of: Dictionary = {}  # hex -> Array of port indices
var _sp_zone := Vector2.ZERO
var _sp_start_size := Vector2.ZERO   # доска до раздвигания (без полей картинки)
var _grid_paths := {}      # port index -> путь от m_a до m_b (сетка 5x3, _grid_try)


## Сдвиг каждого гекса шагами JOG_MIN: тогда и вбок, и вдоль щели между
## соседями выходит 0 или не меньше JOG_MIN — ступенька всегда помещается.
## Внешний слой раздвигается до края зоны по очереди, по шагу за круг (так
## доска растёт во все стороны поровну), внутренние слои — до равных щелей.
## Пустой ответ — двигать нечего.
func _spread_offsets(ports: Array, zone: Vector2) -> Dictionary:
	var hexes: Array = _lattice_centre.keys()
	var mean := Vector2.ZERO
	for hex: String in hexes:
		mean += _lattice_centre[hex] as Vector2
	mean /= float(hexes.size())
	var centre_hex: String = hexes[0]
	for hex: String in hexes:
		if (_lattice_centre[hex] as Vector2).distance_to(mean) < (_lattice_centre[centre_hex] as Vector2).distance_to(mean):
			centre_hex = hex
	var row_step := float(K) * sqrt(3.0) / SQUEEZE
	var cell := {}
	for hex: String in hexes:
		var d: Vector2 = (_lattice_centre[hex] as Vector2) - (_lattice_centre[centre_hex] as Vector2)
		cell[hex] = Vector2i(roundi(d.x / K), roundi(d.y / row_step))
	var layer := {}
	var max_layer := 0
	for hex: String in hexes:
		layer[hex] = _hex_steps(cell[hex], Vector2i.ZERO)
		max_layer = maxi(max_layer, int(layer[hex]))
	var adj := {}
	for hex: String in hexes:
		adj[hex] = []
		for other: String in hexes:
			if other != hex and _hex_steps(cell[hex], cell[other]) == 1:
				(adj[hex] as Array).append(other)

	_sp_zone = zone
	_sp_ports = ports
	_sp_off = {}
	_sp_items = {}
	_sp_box = {}
	_sp_sites = {}
	_sp_ports_of = {}
	_sp_port_edges = []
	for hex: String in hexes:
		_sp_off[hex] = Vector2.ZERO
		_sp_items[hex] = []
		_sp_sites[hex] = []
		_sp_ports_of[hex] = []
	for n in _key.size():
		if _kind[n] != Kind.PORT:
			# с запасом _obstacles: трасса проходит не ближе 2 px от рамки
			(_sp_items[_hex[n]] as Array).append([_node_rect(n, 2.0), -1])
		if _kind[n] == Kind.SITE:
			(_sp_sites[_hex[n]] as Array).append(_node_rect(n))
	for e in _routes.size():
		var pts := _routes[e]
		for i in pts.size() - 1:
			(_sp_items[_hex[_edge_b[e]]] as Array).append([Rect2(pts[i], Vector2.ZERO).expand(pts[i + 1]).grow(1.0), e])
	for hex: String in hexes:
		var items: Array = _sp_items[hex]
		var box: Rect2 = items[0][0] if not items.is_empty() else Rect2()
		for item: Array in items:
			box = box.merge(item[0])
		_sp_box[hex] = box
	# тем же счётом, что и в _sp_ok (по _sp_box)
	var start := Rect2()
	for hex: String in hexes:
		start = _sp_box[hex] if start.size == Vector2.ZERO else start.merge(_sp_box[hex])
	_sp_start_size = start.size
	for i in ports.size():
		var own := {}
		for e: int in ports[i]["edges_a"]:
			own[e] = true
		for e: int in ports[i]["edges_b"]:
			own[e] = true
		_sp_port_edges.append(own)
		(_sp_ports_of[ports[i]["a"]] as Array).append(i)
		(_sp_ports_of[ports[i]["b"]] as Array).append(i)

	# Сетка 5x3 с трассами между гексами, проложенными заново (владелец,
	# 2026-10-04); не легла — раздвигаем по-старому, мостиками-ступеньками.
	if _grid_try(cell):
		return _sp_off
	var outer: Array = []
	for hex: String in hexes:
		if layer[hex] == max_layer:
			outer.append(hex)
	# внешний слой — наружу до края зоны, по шагу за круг
	for _round in 200:
		var moved := false
		for hex: String in outer:
			var c: Vector2i = cell[hex]
			for step: Vector2 in _spread_steps(Vector2(signi(c.x), signi(c.y))):
				var was: Vector2 = _sp_off[hex]
				_sp_off[hex] = was + step * JOG_MIN
				if _sp_ok(hex):
					moved = true
					break
				_sp_off[hex] = was
		if not moved:
			break
	_sp_edges(outer, cell)
	# внутренние слои (решение владельца, 2026-10-03: «раздвинь на возможный
	# максимум, чтобы они были равноудалены от всего») — каждый гекс встаёт
	# туда, где самая узкая щель до соседей шире всего
	for level in range(max_layer - 1, 0, -1):
		var group: Array = []
		for hex: String in hexes:
			if layer[hex] == level:
				group.append(hex)
		_sp_ring_apart(group, adj, cell)
		_sp_maximin(group, adj)
		_sp_fill(group, adj, layer, cell)
	# слой у центра разошёлся: кольцо — в колонки, у краёв — снова на линии
	_sp_columns(cell)
	_sp_edges(outer, cell)
	# повороты ступенек могли остаться от отменённых проб (выравнивание
	# откатывает сдвиги): ещё раз подобрать их под итоговые сдвиги
	for hex: String in hexes:
		_sp_ok(hex)
	for hex: String in hexes:
		if not (_sp_off[hex] as Vector2).is_zero_approx():
			return _sp_off
	return {}


## Доска — сетка 5 колонок x 3 ряда гексов (владелец, 2026-10-04, рисунок с
## красными рамками): колонка по клетке гекса (_sp_col). Крайние города стоят
## по краям доски на одной линии: верхний ряд — по верху рамок, нижний — по
## низу, левая колонка — по левому краю, правая — по правому.
func _sp_edges(outer: Array, cell: Dictionary) -> void:
	var top: Array = []
	var bottom: Array = []
	var left: Array = []
	var right: Array = []
	var corners: Array = []   # им можно чуть сдвинуться вдоль линии
	var sides: Array = []
	for hex: String in outer:
		var c: Vector2i = cell[hex]
		if c.y < 0:
			top.append(hex)
		elif c.y > 0:
			bottom.append(hex)
		if c.x <= -3:
			left.append(hex)
		elif c.x >= 3:
			right.append(hex)
		if c.x != 0 and c.y != 0:
			corners.append(hex)
		elif c.y == 0:
			sides.append(hex)
	_sp_line_up(top, 2, corners)
	_sp_line_up(bottom, 3, corners)
	_sp_line_up(left, 0, sides)
	_sp_line_up(right, 1, sides)


## Колонка сетки 0..4 по клетке гекса: края (|столбец| >= 3), кольцо, центр.
static func _sp_col(c: Vector2i) -> int:
	if c.x <= -3:
		return 0
	if c.x < 0:
		return 1
	if c.x == 0:
		return 2
	return 3 if c.x < 3 else 4


## Рамка вокруг всех городов гекса (со сдвигом).
func _sp_frames(hex: String) -> Rect2:
	var off: Vector2 = _sp_off[hex]
	var out := Rect2()
	var first := true
	for r: Rect2 in _sp_sites[hex]:
		var moved := Rect2(r.position + off, r.size)
		out = moved if first else out.merge(moved)
		first = false
	return out


## Край рамки городов: 0 левый, 1 правый, 2 верх, 3 низ, 4 середина по x,
## 5 середина по y.
func _sp_edge(hex: String, side: int) -> float:
	var f := _sp_frames(hex)
	match side:
		0:
			return f.position.x
		1:
			return f.end.x
		2:
			return f.position.y
		3:
			return f.end.y
	if side == 5:
		return f.position.y + floorf(f.size.y / 2.0)
	return f.position.x + floorf(f.size.x / 2.0)


## Ставит края side гексов hexes на одну линию. Линии пробуются через GRID px:
## у краёв доски — сначала самая внешняя, у середины колонки — ближайшая к
## средней. Гексы из slide могут ещё сдвинуться поперёк (вдоль линии) на шаг
## JOG_MIN, чтобы их ступеньки разошлись. Не встаёт ни одна — всё как было.
func _sp_line_up(hexes: Array, side: int, slide: Array) -> bool:
	if hexes.size() < 2:
		return false
	var axis := 1 if side == 2 or side == 3 else 0
	var start := {}
	var vals := {}
	var mean := 0.0
	for hex: String in hexes:
		start[hex] = _sp_off[hex]
		vals[hex] = _sp_edge(hex, side)
		mean += float(vals[hex]) / hexes.size()
	var lo: float = vals.values().min()
	var hi: float = vals.values().max()
	var target := mean
	if side == 0 or side == 2:
		target = lo
	elif side == 1 or side == 3:
		target = hi
	var lines: Array = []
	var v := lo
	while v < hi:
		lines.append(v)
		v += float(GRID)
	lines.append(hi)
	lines.sort_custom(func(a: float, b: float) -> bool: return absf(a - target) < absf(b - target))
	var across: Array[float] = [0.0]
	for k in range(1, 5):
		across.append(-k * JOG_MIN)
		across.append(k * JOG_MIN)
	for line: float in lines:
		for hex: String in hexes:
			var o: Vector2 = start[hex]
			o[axis] += line - float(vals[hex])
			_sp_off[hex] = o
		var all_fit := true
		for hex: String in hexes:
			var on_line: Vector2 = _sp_off[hex]
			var fits := false
			for d: float in (across if slide.has(hex) else [0.0]):
				var o := on_line
				o[1 - axis] += d
				_sp_off[hex] = o
				if _sp_ok(hex):
					fits = true
					break
			if not fits:
				all_fit = false
				break
		if all_fit:
			# сдвиг поперёк одного мог помешать уже поставленному соседу
			for hex: String in hexes:
				if not _sp_ok(hex):
					all_fit = false
					break
		if all_fit:
			return true
		for hex: String in hexes:
			_sp_off[hex] = start[hex]
	return false


## Средние колонки (красные рамки владельца): гексы кольца стоят друг под
## другом на всю высоту — верхний поднимается, нижний опускается, пока можно,
## средний встаёт посередине между ними; потом все трое — на одну середину.
func _sp_columns(cell: Dictionary) -> void:
	for col in [1, 3]:
		var hexes: Array = []
		for hex: String in cell:
			if _sp_col(cell[hex]) == col:
				hexes.append(hex)
		hexes.sort_custom(func(a: String, b: String) -> bool: return (cell[a] as Vector2i).y < (cell[b] as Vector2i).y)
		if hexes.size() != 3:
			continue
		for pair: Array in [[hexes[0], -1.0], [hexes[2], 1.0]]:
			var hex: String = pair[0]
			for _step in 40:
				var was: Vector2 = _sp_off[hex]
				_sp_off[hex] = was + Vector2(0, float(pair[1]) * JOG_MIN)
				if not _sp_ok(hex):
					_sp_off[hex] = was
					break
		var mid: String = hexes[1]
		for _step in 40:
			var up := _sp_edge(mid, 2) - _sp_edge(hexes[0], 3)
			var down := _sp_edge(hexes[2], 2) - _sp_edge(mid, 3)
			if absf(up - down) <= JOG_MIN:
				break
			var was: Vector2 = _sp_off[mid]
			_sp_off[mid] = was + Vector2(0, JOG_MIN if down > up else -JOG_MIN)
			if not _sp_ok(mid):
				_sp_off[mid] = was
				break
		if not _sp_line_up(hexes, 4, hexes):
			_sp_toward(hexes)
	var centre_col: Array = []
	for hex: String in cell:
		if _sp_col(cell[hex]) == 2:
			centre_col.append(hex)
	_sp_line_up(centre_col, 4, [])


## Ровно на одну середину колонка не встала: гексы подходят к средней из их
## середин, пока можно (ближе — уже лучше).
func _sp_toward(hexes: Array) -> void:
	var mean := 0.0
	for hex: String in hexes:
		mean += _sp_edge(hex, 4) / hexes.size()
	_sp_toward_line(hexes, roundf(mean / GRID) * GRID)


## Каждый гекс подходит к линии: сразу на место, иначе шагом JOG_MIN
## (ступенька к соседу — 0 или не меньше JOG_MIN), последние пиксели по GRID.
func _sp_toward_line(hexes: Array, line: float) -> void:
	for _round in 60:
		var moved := false
		for hex: String in hexes:
			var gap := line - _sp_edge(hex, 4)
			if absf(gap) < 0.5:
				continue
			var was: Vector2 = _sp_off[hex]
			var tries: Array[float] = [absf(gap)]
			for k in range(4, 0, -1):
				if k * JOG_MIN < absf(gap):
					tries.append(k * JOG_MIN)
			tries.append(minf(absf(gap), GRID))
			for t in tries:
				_sp_off[hex] = was + Vector2(signf(gap) * t, 0)
				if _sp_ok(hex):
					moved = true
					break
				_sp_off[hex] = was
		if not moved:
			return


## Сетка 5x3 (владелец, 2026-10-04, красные рамки на скриншоте): каждый гекс
## встаёт в свою клетку — колонка по _sp_col, ряд по знаку ряда гекса. Крайние
## колонки — по внешнему краю рамок городов у края доски, остальные — по
## середине рамок; в одном ряду соседи (с трассами и кольцами) не сходятся,
## щели между ними равные. Верхний ряд — по верху рамок у верха доски, нижний —
## по низу у низа, средний — посередине. Трассы между гексами потом
## прокладываются заново (_grid_route). Не вышло — false, сдвиги нулевые.
const GRID_MIN_GAP := 12.0   # щель между рядами под трассы
## Между колонками может быть и уже: трассы идут и сквозь гексы, где пусто.
const GRID_MIN_GAP_X := 2.0
## Полоса вдоль верха и низа доски: стык трассы у края, смотрящий наружу,
## выходит в неё и обходит свой гекс.
const ROUTE_EDGE := 8.0

func _grid_try(cell: Dictionary) -> bool:
	_grid_paths = {}
	_grid_full = {}
	var slot := {}   # Vector2i(колонка, ряд) -> hex
	for hex: String in cell:
		var c: Vector2i = cell[hex]
		var key := Vector2i(_sp_col(c), signi(c.y))
		if slot.has(key):
			return false
		slot[key] = hex
	if slot.size() != 15:
		return false
	var room := _sp_zone - Vector2(IMAGE_MARGIN, IMAGE_MARGIN) * 2 - Vector2(SPREAD_SLACK, SPREAD_SLACK)
	var centre: Vector2 = (_sp_box[slot[Vector2i(2, 0)]] as Rect2).get_center()
	var r := Rect2(((centre - room / 2.0) / 2.0).round() * 2.0, (room / 2.0).floor() * 2.0)

	# по x: соседние колонки расходятся так, чтобы в каждом ряду их гексы (с
	# трассами и кольцами) не сошлись; остаток ширины — поровну между ними
	var xkey := {}
	var lw := {}   # hex -> от левого края его содержимого до линии колонки
	var rw := {}
	for key: Vector2i in slot:
		var hex: String = slot[key]
		var side := 0 if key.x == 0 else (1 if key.x == 4 else 4)
		xkey[hex] = _sp_edge(hex, side)
		lw[hex] = float(xkey[hex]) - (_sp_box[hex] as Rect2).position.x
		rw[hex] = (_sp_box[hex] as Rect2).end.x - float(xkey[hex])
	var first := 0.0
	var last := 0.0
	var need: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for row in [-1, 0, 1]:
		first = maxf(first, float(lw[slot[Vector2i(0, row)]]))
		last = maxf(last, float(rw[slot[Vector2i(4, row)]]))
		for c in 4:
			need[c] = maxf(need[c], float(rw[slot[Vector2i(c, row)]]) + float(lw[slot[Vector2i(c + 1, row)]]))
	var used := first + last
	for c in 4:
		used += need[c]
	var gap_x := (r.size.x - used) / 4.0
	if gap_x < GRID_MIN_GAP_X:
		return false
	var lines_x: Array[float] = [r.position.x + first]
	for c in 4:
		lines_x.append(lines_x[c] + need[c] + gap_x)

	# по y: верх и низ — к краям, средний ряд — где самая узкая щель шире всего
	var ykey := {}
	var top_line := -INF
	var bottom_line := INF
	for key: Vector2i in slot:
		var hex: String = slot[key]
		ykey[hex] = _sp_edge(hex, 2 if key.y < 0 else (3 if key.y > 0 else 5))
		var box: Rect2 = _sp_box[hex]
		if key.y < 0:
			top_line = maxf(top_line, r.position.y + ROUTE_EDGE + float(ykey[hex]) - box.position.y)
		elif key.y > 0:
			bottom_line = minf(bottom_line, r.end.y - ROUTE_EDGE - (box.end.y - float(ykey[hex])))
	var min_a := INF   # щель над средним рядом = M + a
	var min_b := INF   # щель под ним = b - M
	for c in 5:
		var top: String = slot[Vector2i(c, -1)]
		var mid: String = slot[Vector2i(c, 0)]
		var bot: String = slot[Vector2i(c, 1)]
		var top_bottom := top_line - float(ykey[top]) + (_sp_box[top] as Rect2).end.y
		var bot_top := bottom_line - float(ykey[bot]) + (_sp_box[bot] as Rect2).position.y
		min_a = minf(min_a, (_sp_box[mid] as Rect2).position.y - float(ykey[mid]) - top_bottom)
		min_b = minf(min_b, bot_top - ((_sp_box[mid] as Rect2).end.y - float(ykey[mid])))
	if (min_a + min_b) / 2.0 < GRID_MIN_GAP:
		return false
	var mid_line := (min_b - min_a) / 2.0

	for key: Vector2i in slot:
		var hex: String = slot[key]
		var y_line := top_line if key.y < 0 else (bottom_line if key.y > 0 else mid_line)
		var o := Vector2(lines_x[key.x] - float(xkey[hex]), y_line - float(ykey[hex]))
		_sp_off[hex] = (o / 2.0).round() * 2.0   # чётный сдвиг: стыки трасс на сетке 2 px
	_grid_nudge(slot)
	if not _grid_route(r):
		for hex: String in cell:
			_sp_off[hex] = Vector2.ZERO
		_grid_paths = {}
		_grid_full = {}
		return false
	return true


## Стыки двух гексов почти напротив (вбок на 2..NUDGE_MAX px) дали бы мостику
## ступеньку: гекс сдвигается на эти пиксели, чтобы мостик шёл прямо
## (владелец, 2026-10-04: «можно обойтись без этого»). Гекс у края доски
## двигается только вдоль своей линии; сдвиг от клетки сетки — не больше
## NUDGE_MAX; содержимое гексов не сходится. Жадно: гекс за гексом, где больше
## стыков встаёт ровно.
const NUDGE_MAX := 8.0

func _grid_nudge(slot: Dictionary) -> void:
	var base := _sp_off.duplicate()
	var lock := {}   # hex -> Vector2(1 — ось x свободна, 1 — y)
	for key: Vector2i in slot:
		lock[slot[key]] = Vector2(0.0 if key.x == 0 or key.x == 4 else 1.0, 0.0 if key.y != 0 else 1.0)
	for _round in 3:
		var moved := false
		for hex: String in _sp_off:
			var best := _nudge_score(hex)
			var best_off: Vector2 = _sp_off[hex]
			var start: Vector2 = _sp_off[hex]
			for dx in range(-int(NUDGE_MAX), int(NUDGE_MAX) + 1, GRID):
				for dy in range(-int(NUDGE_MAX), int(NUDGE_MAX) + 1, GRID):
					var d := Vector2(dx, dy) * (lock[hex] as Vector2)
					if d != Vector2(dx, dy):
						continue
					var cand: Vector2 = (base[hex] as Vector2) + d
					if cand == start:
						continue
					_sp_off[hex] = cand
					var sc := _nudge_score(hex)
					if sc > best + 0.01 and not _nudge_hits(hex):
						best = sc
						best_off = cand
			_sp_off[hex] = best_off
			if best_off != start:
				moved = true
		if not moved:
			return


## Сколько стыков гекса встало ровно напротив, минус почти напротив; чуть-чуть
## штраф за уход от клетки сетки (из равных — ближе к ней).
func _nudge_score(hex: String) -> float:
	var score := 0.0
	for i: int in _sp_ports_of[hex]:
		var port: Dictionary = _sp_ports[i]
		var d: Vector2 = (_sp_off[port["b"]] as Vector2) - (_sp_off[port["a"]] as Vector2)
		var u: Vector2 = port["u"]
		var side := absf((d - u * d.dot(u)).x) + absf((d - u * d.dot(u)).y)
		if side < 0.5:
			score += 1.0
		elif side <= NUDGE_MAX + 0.5:
			score -= 1.0
	return score


## Сошлось ли содержимое гекса с чужим (с запасом в клетку на трассу).
func _nudge_hits(hex: String) -> bool:
	var own := Rect2((_sp_box[hex] as Rect2).position + (_sp_off[hex] as Vector2), (_sp_box[hex] as Rect2).size)
	for other: String in _sp_off:
		if other == hex:
			continue
		var b := Rect2((_sp_box[other] as Rect2).position + (_sp_off[other] as Vector2), (_sp_box[other] as Rect2).size)
		if not own.grow(float(GRID)).intersects(b):
			continue
		for item: Array in _sp_items[hex]:
			var r := Rect2((item[0] as Rect2).position + (_sp_off[hex] as Vector2), (item[0] as Rect2).size).grow(float(GRID))
			if not r.intersects(b):
				continue
			for item2: Array in _sp_items[other]:
				if r.intersects(Rect2((item2[0] as Rect2).position + (_sp_off[other] as Vector2), (item2[0] as Rect2).size)):
					return true
	return false


## Трассы между гексами сетки: поиск пути по клеткам GRID px вокруг всего, что
## уже стоит (рамки, кольца, трассы гексов и уже проложенные мостики), только
## по осям, поворот не ближе JOG_MIN от прошлого. От m_a трасса не идёт назад
## (-u), в m_b не входит против u. Короткие — первыми. Хоть одна не легла — false.
const ROUTE_BEND := 16.0
const ROUTE_NEAR := 8.0      # у своих концов трассы гексов не мешают
const ROUTE_MARGIN := 80.0   # ищем в рамке концов с таким запасом (по всей доске — долго)
## Поиск тянется к цели сильнее точного (путь чуть длиннее лучшего, зато
## клеток перебирается в разы меньше: доска строится при старте партии).
const ROUTE_GREED := 2.0

var _rt_origin := Vector2.ZERO
var _rt_size := Vector2i.ZERO
var _rt_hard := PackedInt32Array()  # рамки и кольца: узел + 1 (-1 — запасы нескольких узлов)
var _rt_soft := PackedInt32Array()  # трассы гексов: ребро + 1, -1 — несколько (у своих концов своя не мешает)
var _rt_bridge := PackedByteArray() # уже проложенные мостики
var _rt_keep := PackedInt32Array()  # клетки перед стыками: номер порта + 1
const ROUTE_KEEP := 4               # клеток перед стыком
## Стык, к которому с каждой стороны подходит одна трасса, прокладывается
## целиком — от кольца или города гекса A до кольца или города гекса B
## (владелец, 2026-10-04, вариант «В»): старые куски трасс внутри гексов не
## держат мостик, и крючков у колец нет. Не легла — стык мостиком по-старому.
## Так же заново прокладываются и трассы внутри гекса — между его кольцами и
## городами (владелец, 2026-10-04); не легла — остаётся старая.
## Задание j: j < числа портов — стык, дальше — трасса _rt_inner[j - портов].
var _rt_full := {}    # задание -> true: прокладывается целиком
var _rt_skip := {}    # их рёбра: старые трассы не мешают, они прокладываются заново
var _rt_inner: Array[int] = []   # рёбра внутри гексов (кольцо или город с обеих сторон)
var _rt_ring_keep := PackedInt32Array()   # клетки перед выходами колец: узел + 1
var _grid_full := {}  # то же после удачной прокладки: путь в _grid_paths — от узла A до узла B
const RING_CELLS := (RING_R + 2) / GRID   # клеток от середины кольца до края его запаса
const PORT_CELLS := 1   # клеток у развилки, где её трассы рядом (TRACE_GAP)

func _grid_route(r: Rect2) -> bool:
	_rt_origin = r.position
	_rt_size = Vector2i(int(r.size.x / GRID) + 1, int(r.size.y / GRID) + 1)
	# у стыка с одной трассой с каждой стороны она прокладывается целиком;
	# не легла — этот стык мостиком по-старому, и всё заново
	# с двумя трассами с одной стороны — развилка у стыка остаётся, а трасса
	# другой стороны идёт от неё целиком (_rt_full: 1 — развилка у A, 2 — у B)
	_rt_full = {}
	for i in _sp_ports.size():
		var one_a := (_sp_ports[i]["edges_a"] as Array).size() == 1
		var one_b := (_sp_ports[i]["edges_b"] as Array).size() == 1
		if one_a or one_b:
			_rt_full[i] = 0 if one_a and one_b else (2 if one_a else 1)
	_rt_inner = []
	for e in _routes.size():
		if _kind[_edge_a[e]] in [Kind.RING, Kind.SITE] and _kind[_edge_b[e]] in [Kind.RING, Kind.SITE] \
				and _hex[_edge_a[e]] == _hex[_edge_b[e]] and _sp_off.has(_hex[_edge_a[e]]) \
				and _route_excess(_routes[e]) > 1.0:
			_rt_full[_sp_ports.size() + _rt_inner.size()] = 0
			_rt_inner.append(e)
	var started := Time.get_ticks_msec()
	while true:
		var failed := _grid_route_once(started)
		if failed == -1:
			_grid_full = _rt_full.duplicate()
			return true
		if not _rt_full.has(failed):
			return false
		_rt_full.erase(failed)
	return false


## Насколько трасса длиннее пути по осям между её концами (крюки и петли;
## у прямой и у ступеньки — 0). Только такие трассы внутри гекса — заново.
static func _route_excess(pts: PackedVector2Array) -> float:
	if pts.size() < 2:
		return 0.0
	var length := 0.0
	for k in pts.size() - 1:
		length += pts[k].distance_to(pts[k + 1])
	var d := pts[pts.size() - 1] - pts[0]
	return length - absf(d.x) - absf(d.y)


## Одна прокладка всех трасс при данном _rt_full: -1 — легли, иначе порт,
## что не лёг последним (-2 — вышло время).
func _grid_route_once(started: int) -> int:
	_rt_skip = {}
	for j: int in _rt_full:
		for end: Array in _rt_job_ends(j):
			if int(end[0]) >= 0:
				_rt_skip[end[0]] = true
	_rt_hard = PackedInt32Array()
	_rt_hard.resize(_rt_size.x * _rt_size.y)
	_rt_soft = PackedInt32Array()
	_rt_soft.resize(_rt_size.x * _rt_size.y)
	_rt_bridge = PackedByteArray()
	_rt_bridge.resize(_rt_size.x * _rt_size.y)
	for hex: String in _sp_items:
		var off: Vector2 = _sp_off[hex]
		for item: Array in _sp_items[hex]:
			var rect := Rect2((item[0] as Rect2).position + off, (item[0] as Rect2).size)
			if int(item[1]) >= 0 and not _rt_skip.has(int(item[1])):
				_rt_mark_edge(rect.grow(float(TRACE_GAP) - 1.0), int(item[1]))
	for n in _key.size():
		if _kind[n] != Kind.PORT and _sp_off.has(_hex[n]):
			var nr := _node_rect(n, 2.0)
			_rt_mark_hard(Rect2(nr.position + (_sp_off[_hex[n]] as Vector2), nr.size), n)
	var order: Array = range(_sp_ports.size())
	for j: int in _rt_full:
		if j >= _sp_ports.size():
			order.append(j)
	var ends := {}
	for i: int in order:
		if _rt_full.has(i):
			var je := _rt_job_ends(i)
			ends[i] = [_pos[je[0][1]] + (_sp_off[je[0][2]] as Vector2), _pos[je[1][1]] + (_sp_off[je[1][2]] as Vector2)]
		else:
			var port: Dictionary = _sp_ports[i]
			ends[i] = [(port["p"] as Vector2) + (_sp_off[port["a"]] as Vector2),
				(port["p"] as Vector2) + (_sp_off[port["b"]] as Vector2)]
	# перед каждым выходом из кольца — несколько клеток только для трасс этого
	# кольца (выходов у него мало, чужая трасса вплотную запрёт его)
	_rt_keep = PackedInt32Array()
	_rt_keep.resize(_rt_size.x * _rt_size.y)
	_rt_ring_keep = PackedInt32Array()
	_rt_ring_keep.resize(_rt_size.x * _rt_size.y)
	var rings_done := {}
	for i: int in order:
		if not _rt_full.has(i):
			continue
		for end: Array in _rt_job_ends(i):
			var n: int = end[1]
			if (_kind[n] != Kind.RING and _kind[n] != Kind.PORT) or rings_done.has(n):
				continue
			rings_done[n] = true
			for exit: Array in _rt_exits(end[0], n, end[2], i):
				for k in ROUTE_KEEP:
					var c: Vector2i = (exit[3] as Vector2i) + Vector2i(DIRS[int(exit[1])]) * k
					if c.x >= 0 and c.y >= 0 and c.x < _rt_size.x and c.y < _rt_size.y:
						var ki := c.y * _rt_size.x + c.x
						_rt_ring_keep[ki] = n + 1 if _rt_ring_keep[ki] == 0 or _rt_ring_keep[ki] == n + 1 else -1
	# перед каждым стыком — несколько клеток только для его трассы: иначе
	# проложенная раньше чужая проходит вплотную поперёк и запирает стык
	for i: int in order:
		if _rt_full.has(i):
			continue
		var su := Vector2i(_sp_ports[i]["u"])
		var ca := Vector2i((((ends[i][0] as Vector2) - _rt_origin) / GRID).round())
		var cb := Vector2i((((ends[i][1] as Vector2) - _rt_origin) / GRID).round())
		for k in ROUTE_KEEP + 1:
			for c: Vector2i in [ca + su * k, cb - su * k]:
				if c.x >= 0 and c.y >= 0 and c.x < _rt_size.x and c.y < _rt_size.y:
					var ki := c.y * _rt_size.x + c.x
					# у двух стыков сразу — свободна для обоих (-1)
					_rt_keep[ki] = i + 1 if _rt_keep[ki] == 0 or _rt_keep[ki] == i + 1 else -1
	# сначала мостики, которым нужен обход (B не впереди по u — трасса
	# разворачивается), потом короткие
	var key := func(i: int) -> float:
		var d: Vector2 = (ends[i][1] as Vector2) - (ends[i][0] as Vector2)
		var ahead := _rt_full.has(i) or d.dot(_sp_ports[i]["u"]) > JOG_MIN
		if i >= _sp_ports.size():
			return absf(d.x) + absf(d.y) + 10000.0
		return absf(d.x) + absf(d.y) + (0.0 if not ahead else 10000.0)
	order.sort_custom(func(a: int, b: int) -> bool: return key.call(a) < key.call(b))
	# не легла — она первой, остальные заново (ROUTE_RETRIES раз, не дольше
	# ROUTE_BUDGET_MS: доска строится при старте партии)
	for _attempt in ROUTE_RETRIES:
		if Time.get_ticks_msec() - started > ROUTE_BUDGET_MS:
			return -2
		var failed := _rt_route_all(order, ends)
		if failed < 0:
			return -1
		# трасса внутри гекса не легла — сразу остаётся старая
		if failed >= _sp_ports.size():
			return failed
		order.erase(failed)
		order.push_front(failed)
	return order[0]


const ROUTE_RETRIES := 6
const ROUTE_BUDGET_MS := 2500

## Прокладывает мостики по порядку; ответ — порт, что не лёг, или -1.
func _rt_route_all(order: Array, ends: Dictionary) -> int:
	_grid_paths = {}
	_rt_bridge.fill(0)
	for i: int in order:
		var path := _rt_find_full(i) if _rt_full.has(i) else _rt_find(i)
		if path.is_empty():
			return i
		_grid_paths[i] = path
		for k in path.size() - 1:
			_rt_mark(_rt_bridge, Rect2(path[k], Vector2.ZERO).expand(path[k + 1]).grow(float(TRACE_GAP) - 1.0))
	return -1


## Занять клетки, чьи точки лежат в rect (с краями).
func _rt_mark(grid: PackedByteArray, rect: Rect2) -> void:
	var x0 := maxi(0, int(ceil((rect.position.x - _rt_origin.x) / GRID)))
	var y0 := maxi(0, int(ceil((rect.position.y - _rt_origin.y) / GRID)))
	var x1 := mini(_rt_size.x - 1, int(floor((rect.end.x - _rt_origin.x) / GRID)))
	var y1 := mini(_rt_size.y - 1, int(floor((rect.end.y - _rt_origin.y) / GRID)))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			grid[y * _rt_size.x + x] = 1


## Как _rt_mark, но в _rt_hard — с номером узла (запасы двух узлов — -1).
func _rt_mark_hard(rect: Rect2, n: int) -> void:
	var x0 := maxi(0, int(ceil((rect.position.x - _rt_origin.x) / GRID)))
	var y0 := maxi(0, int(ceil((rect.position.y - _rt_origin.y) / GRID)))
	var x1 := mini(_rt_size.x - 1, int(floor((rect.end.x - _rt_origin.x) / GRID)))
	var y1 := mini(_rt_size.y - 1, int(floor((rect.end.y - _rt_origin.y) / GRID)))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var i := y * _rt_size.x + x
			_rt_hard[i] = n + 1 if _rt_hard[i] == 0 or _rt_hard[i] == n + 1 else -1


## Как _rt_mark, но в _rt_soft — с номером ребра (две разные трассы — -1).
func _rt_mark_edge(rect: Rect2, e: int) -> void:
	var x0 := maxi(0, int(ceil((rect.position.x - _rt_origin.x) / GRID)))
	var y0 := maxi(0, int(ceil((rect.position.y - _rt_origin.y) / GRID)))
	var x1 := mini(_rt_size.x - 1, int(floor((rect.end.x - _rt_origin.x) / GRID)))
	var y1 := mini(_rt_size.y - 1, int(floor((rect.end.y - _rt_origin.y) / GRID)))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var i := y * _rt_size.x + x
			_rt_soft[i] = e + 1 if _rt_soft[i] == 0 or _rt_soft[i] == e + 1 else -1


## Клетки старой трассы, с которых мостик порта i может начаться (сторона A)
## или где кончиться (B): {клетка: направление трассы в ней}. Последний прямой
## участок у стыка — без JOG_MIN у его начала; если трасса к стыку одна и
## перед этим участком поворот, то и предпоследний участок: мостик тогда
## сдвигает последний участок целиком вбок на пару пикселей вместо ступеньки.
## Хвост до этой клетки _bridge отрезает.
func _rt_tail(i: int, side_b: bool) -> Dictionary:
	var port: Dictionary = _sp_ports[i]
	var hex: String = port["b" if side_b else "a"]
	var m: Vector2 = (port["p"] as Vector2) + (_sp_off[hex] as Vector2)
	var u: Vector2 = port["u"]
	var edges: Array = port["edges_b" if side_b else "edges_a"]
	var out := {}
	var tail := _rt_cells_back(m, u, float(port["run_b" if side_b else "run_a"]), side_b)
	for c: Vector2i in tail:
		out[c] = _dir_index(u)
	if edges.size() != 1:
		return out
	var pts := _routes[edges[0]]
	if pts.size() < 3:
		_rt_slide(edges[0], hex, m, u, side_b, out)
		return out
	pts = pts.duplicate()
	var off: Vector2 = _sp_off[hex]
	for k in pts.size():
		pts[k] += off
	if pts[pts.size() - 1].distance_to(m) < pts[0].distance_to(m):
		pts.reverse()
	# pts[0] — стык, pts[1] — поворот, pts[2] — дальше в гекс
	# поворот не на сетке 2 px (у трасс тайлов бывают нечётные и дробные
	# углы) — клетки мимо его линии, склейка не сойдётся: не сдвигаем
	if not (pts[1] / float(GRID)).is_equal_approx((pts[1] / float(GRID)).round()):
		return out
	var along := (pts[1] - pts[2]).normalized()   # A: трасса идёт к pts[1]
	if not side_b:
		var len1 := pts[1].distance_to(pts[2])
		for c: Vector2i in _rt_cells_back(pts[1], along, len1, false):
			out[c] = _dir_index(along)
	else:
		var len1 := pts[1].distance_to(pts[2])
		for c: Vector2i in _rt_cells_back(pts[1], -along, len1, true):
			out[c] = _dir_index(-along)
	return out


## Трасса идёт к стыку прямо из рамки города: её можно сдвинуть вбок целиком
## на 1..SLIDE_CELLS клеток (точка выхода скользит по стороне рамки, не ближе
## PIN_MARGIN к углу) — вместо ступеньки у стыка. Мостик тогда начинается
## (A) или кончается (B) в рамке, на сдвинутой линии; кусок внутри рамки не
## виден, сквозь свою рамку мостик идёт только по этой линии (_rt_inbox), а
## у её края чужих трасс не касается.
const SLIDE_CELLS := 4
var _rt_inbox := {}

func _rt_slide(e: int, hex: String, m: Vector2, u: Vector2, side_b: bool, out: Dictionary) -> void:
	var n := _edge_b[e] if _kind[_edge_b[e]] != Kind.PORT else _edge_a[e]
	if _kind[n] != Kind.SITE:
		return
	var off: Vector2 = _sp_off[hex]
	var box := Rect2(_node_rect(n).position + off, _node_rect(n).size)
	var v := Vector2(absf(u.y), absf(u.x))
	var su := Vector2i(u) * (-1 if side_b else 1)   # от середины рамки наружу
	var pts := _routes[e]
	var pin := (pts[0] if pts[0].distance_to(m - off) > pts[pts.size() - 1].distance_to(m - off) else pts[pts.size() - 1]) + off
	for k in range(-SLIDE_CELLS, SLIDE_CELLS + 1):
		if k == 0:
			continue
		var shift := v * float(k * GRID)
		var line := (m + shift).dot(v)
		if line < box.position.dot(v) + PIN_MARGIN or line > box.end.dot(v) - PIN_MARGIN:
			continue
		# конец трассы — точка выхода на краю рамки, сдвинутая вдоль края; на
		# клетку — на 1-2 px внутрь рамки (кусочек внутри не виден)
		var inward := -u if not side_b else u
		var q := pin.dot(u.abs()) + inward.dot(u.abs())
		if posmod(int(q), GRID) != 0:
			q += inward.dot(u.abs())
		var c0 := Vector2i(((u.abs() * q + v * line - _rt_origin) / GRID).round())
		if c0.x < 0 or c0.y < 0 or c0.x >= _rt_size.x or c0.y >= _rt_size.y:
			continue
		out[c0] = _dir_index(u)
		var c := c0
		while c.x >= 0 and c.y >= 0 and c.x < _rt_size.x and c.y < _rt_size.y \
				and box.grow(float(TRACE_GAP)).has_point(_rt_origin + Vector2(c) * GRID):
			# 1 — в самой рамке (чужие трассы там не видны), 2 — в запасе вокруг
			_rt_inbox[c] = 1 if box.has_point(_rt_origin + Vector2(c) * GRID) else 2
			c += su


## Клетки от точки m по прямой: A — назад против dir (трасса шла по dir и
## кончалась в m), B — вперёд по dir (трасса из m уходит по dir); не ближе
## JOG_MIN к другому концу участка длиной run.
func _rt_cells_back(m: Vector2, dir: Vector2, run: float, forward: bool) -> Array:
	var out: Array = []
	var c0 := Vector2i(((m - _rt_origin) / GRID).round())
	var step := Vector2i(dir) * (1 if forward else -1)
	for t in int(maxf(0.0, run - JOG_MIN) / GRID) + 1:
		var c := c0 + step * t
		if c.x < 0 or c.y < 0 or c.x >= _rt_size.x or c.y >= _rt_size.y:
			break
		out.append(c)
	return out


## Путь по осям от трассы A до трассы B или [] — точки поворотов. Начало и
## конец — клетки хвостов (_rt_tail), по ним ходить можно только вдоль их
## трассы. Состояние: клетка, направление (DIRS), шагов с поворота.
func _rt_find(i: int) -> PackedVector2Array:
	var port: Dictionary = _sp_ports[i]
	var u: Vector2 = port["u"]
	_rt_inbox = {}
	var starts := _rt_tail(i, false)
	var goals := _rt_tail(i, true)
	if starts.is_empty() or goals.is_empty():
		return PackedVector2Array()
	var ca := Vector2i(((((port["p"] as Vector2) + (_sp_off[port["a"]] as Vector2)) - _rt_origin) / GRID).round())
	var cb := Vector2i(((((port["p"] as Vector2) + (_sp_off[port["b"]] as Vector2)) - _rt_origin) / GRID).round())
	var su := Vector2i(u)
	var a_lo := ca
	var a_hi := ca
	for c: Vector2i in starts:
		a_lo = a_lo.min(c)
		a_hi = a_hi.max(c)
	var b_lo := cb
	var b_hi := cb
	for c: Vector2i in goals:
		b_lo = b_lo.min(c)
		b_hi = b_hi.max(c)
	var m := int(ROUTE_MARGIN / GRID)
	var lo := Vector2i(maxi(0, mini(a_lo.x, b_lo.x) - m), maxi(0, mini(a_lo.y, b_lo.y) - m))
	var hi := Vector2i(mini(_rt_size.x - 1, maxi(a_hi.x, b_hi.x) + m), mini(_rt_size.y - 1, maxi(a_hi.y, b_hi.y) + m))
	var w := hi.x - lo.x + 1
	var h := hi.y - lo.y + 1
	var runs := JOG_MIN / GRID   # шагов от поворота до поворота
	var states := 4 * (runs + 1)
	var g := PackedFloat32Array()
	g.resize(w * h * states)
	g.fill(INF)
	var parent := PackedInt32Array()
	parent.resize(w * h * states)
	parent.fill(-1)
	var near := int(ROUTE_NEAR / GRID)
	var hard_a := _rt_hard[ca.y * _rt_size.x + ca.x] != 0
	var hard_b := _rt_hard[cb.y * _rt_size.x + cb.x] != 0
	var free_a := _ring_free_dirs(i, false) if hard_a else []
	var free_b := _ring_free_dirs(i, true) if hard_b else []
	var d_in := _dir_index(u)
	var step_of: Array[Vector2i] = []
	for d in 4:
		step_of.append(Vector2i(DIRS[d]))
	var own_line := {}   # клетки на линиях трасс, которые этот мостик продолжает
	for e: int in _sp_port_edges[i]:
		var off: Vector2 = _sp_off[_hex[_edge_b[e]]]
		var pts := _routes[e]
		for k in pts.size() - 1:
			var p0 := Vector2i(((pts[k] + off - _rt_origin) / GRID).round())
			var p1 := Vector2i(((pts[k + 1] + off - _rt_origin) / GRID).round())
			var step := (p1 - p0).sign()
			var q := p0
			while true:
				if q.x >= 0 and q.y >= 0 and q.x < _rt_size.x and q.y < _rt_size.y:
					own_line[q] = true
				if q == p1 or step == Vector2i.ZERO:
					break
				q += step
	var heap_s := PackedInt32Array()
	var heap_f := PackedFloat32Array()
	for c0: Vector2i in starts:
		if c0.x < lo.x or c0.y < lo.y or c0.x > hi.x or c0.y > hi.y:
			continue
		var s0 := (((c0.y - lo.y) * w + (c0.x - lo.x)) * 4 + int(starts[c0])) * (runs + 1) + runs
		g[s0] = 0.0
		_rt_push(heap_s, heap_f, s0, float(_seg_dist(c0, b_lo, b_hi)) * ROUTE_GREED)
	# кольцо на самом стыке: выйти из него можно в любую его свободную сторону
	if hard_a:
		for d0: int in free_a:
			var s1 := (((ca.y - lo.y) * w + (ca.x - lo.x)) * 4 + d0) * (runs + 1) + runs
			g[s1] = 0.0
			_rt_push(heap_s, heap_f, s1, float(_seg_dist(ca, b_lo, b_hi)) * ROUTE_GREED)
	var goal := -1
	while not heap_s.is_empty():
		var s := heap_s[0]
		var f := heap_f[0]
		_rt_pop(heap_s, heap_f)
		var run := s % (runs + 1)
		var d := (s / (runs + 1)) % 4
		var cell_i := s / states
		var c := Vector2i(lo.x + cell_i % w, lo.y + cell_i / w)
		if f > g[s] + float(_seg_dist(c, b_lo, b_hi)) * ROUTE_GREED + 0.01:
			continue
		if goals.has(c):
			goal = s
			break
		for nd in 4:
			if nd == (d + 2) % 4:
				continue
			var turn := nd != d
			if turn and run < runs:
				continue
			var nc := c + step_of[nd]
			if nc.x < lo.x or nc.y < lo.y or nc.x > hi.x or nc.y > hi.y:
				continue
			var idx := nc.y * _rt_size.x + nc.x
			if _rt_bridge[idx] != 0 or (_rt_keep[idx] > 0 and _rt_keep[idx] != i + 1):
				continue
			var nrun := 1 if turn else mini(run + 1, runs)
			# по своим старым трассам не ходить: в хвост B — только чтобы
			# кончить (вдоль его трассы или с поворотом после JOG_MIN), по хвосту
			# A — только вдоль от начала, прочее — никак
			if goals.has(nc):
				var gd: int = goals[nc]
				if hard_b and nc == cb:
					# в кольцо на стыке — по любой его свободной стороне
					if not free_b.has((nd + 2) % 4):
						continue
				elif nd == (gd + 2) % 4 or (nd != gd and (hard_b or nrun < runs)):
					continue
			elif starts.has(nc):
				if not starts.has(c) or nd != int(starts[nc]) or nd != int(starts[c]):
					continue
			elif own_line.has(nc):
				continue
			# кольцо на самом стыке (из него расходятся и другие трассы гекса):
			# в него трасса входит и из него выходит только по его свободным
			# сторонам (_ring_free_dirs), по прямой от середины
			var ring_line := (hard_a and free_a.has(nd) and _on_ray(nc - ca, step_of[nd], 0, RING_CELLS)) \
				or (hard_b and free_b.has((nd + 2) % 4) and _on_ray(nc - cb, step_of[(nd + 2) % 4], 0, RING_CELLS))
			var through_box := nd == d_in and _rt_inbox.has(nc)
			if _rt_hard[idx] != 0 and not ring_line and not through_box:
				continue
			var soft := _rt_soft[idx]
			if soft != 0 and not ring_line and not (through_box and int(_rt_inbox[nc]) == 1) and not (soft > 0 and _sp_port_edges[i].has(soft - 1) \
					and (_seg_dist(nc, a_lo, a_hi) <= near or _seg_dist(nc, b_lo, b_hi) <= near)):
				continue
			var ns := (((nc.y - lo.y) * w + (nc.x - lo.x)) * 4 + nd) * (runs + 1) + nrun
			var ng := g[s] + 1.0 + (ROUTE_BEND / GRID if turn else 0.0)
			if ng < g[ns]:
				g[ns] = ng
				parent[ns] = s
				_rt_push(heap_s, heap_f, ns, ng + float(_seg_dist(nc, b_lo, b_hi)) * ROUTE_GREED)
	if goal < 0:
		return PackedVector2Array()
	var cells: Array[Vector2] = []
	var s2 := goal
	while s2 >= 0:
		var cell_i := s2 / states
		cells.append(_rt_origin + Vector2(lo.x + cell_i % w, lo.y + cell_i / w) * GRID)
		s2 = parent[s2]
	cells.reverse()
	var out := PackedVector2Array([cells[0]])
	for k in range(1, cells.size() - 1):
		var d1 := cells[k] - cells[k - 1]
		var d2 := cells[k + 1] - cells[k]
		if not is_zero_approx(d1.cross(d2)):
			out.append(cells[k])
	if cells.size() > 1:
		out.append(cells[cells.size() - 1])
	return out


## Откуда трасса e выходит из своего кольца или города n в гексе hex: массив
## [клетка начала, направление наружу, точка на узле, первая клетка за запасом
## узла]. Из кольца — из его середины, по сторонам, куда не уходят другие его
## трассы: сквозь запас кольца прямо (кольца стоят и вплотную к рамкам). Из
## города — с любой стороны рамки, не ближе PIN_MARGIN к углу, конец на 1 px
## внутри рамки (как _ends), начало — первая клетка за запасом рамки.
func _rt_exits(e: int, n: int, hex: String, i: int) -> Array:
	var off: Vector2 = _sp_off[hex]
	var out: Array = []
	if _kind[n] == Kind.PORT:
		# развилка: по сторонам, куда не уходят её трассы в этом гексе; первые
		# клетки у самой точки — трассы развилки рядом, им можно
		var p: Vector2 = _pos[n] + off
		var pc := Vector2i(((p - _rt_origin) / GRID).round())
		var side := "a" if _sp_ports[i]["a"] == hex else "b"
		var taken := {}
		for e2: int in _sp_ports[i]["edges_" + side]:
			var pts := _routes[e2]
			if pts.size() < 2:
				continue
			var leave := _leave_dir(pts, _pos[n], 1.0)
			if leave >= 0:
				taken[leave] = true
		for d in 4:
			if taken.has(d):
				continue
			var cell := pc + Vector2i(DIRS[d]) * (PORT_CELLS + 1)
			if _rt_open(cell, i, n, n):
				out.append([pc, d, p, cell])
		return out
	if _kind[n] == Kind.RING:
		var c := _pos[n] + off
		var c0 := Vector2i(((c - _rt_origin) / GRID).round())
		var used := {}
		for e2: int in _incident[n]:
			if e2 == e or _rt_skip.has(e2):
				continue
			var pts := _routes[e2]
			if pts.size() < 2:
				continue
			var leave := _leave_dir(pts, _pos[n], float(RING_R + 1))
			if leave >= 0:
				used[leave] = true
		for d in 4:
			if used.has(d):
				continue
			var step := Vector2i(DIRS[d])
			var cell := c0
			while _rt_owner(cell) == n + 1:
				cell += step
			if _rt_open(cell, i, n, n):
				out.append([c0, d, c, cell])
		return out
	if _kind[n] != Kind.SITE:
		return out
	var box := Rect2(_node_rect(n).position + off, _node_rect(n).size)
	for d in 4:
		var dv: Vector2 = DIRS[d]
		var ax := dv.abs()
		var along := Vector2(ax.y, ax.x)
		var sign_d := dv.dot(ax)
		var edge := box.end.dot(ax) if sign_d > 0.0 else box.position.dot(ax)
		var o_ax := _rt_origin.dot(ax)
		var o_al := _rt_origin.dot(along)
		# рамка в сетке препятствий — с запасом 2 px (_node_rect(n, 2))
		var k := floori((edge + 2.0 - o_ax) / GRID) + 1 if sign_d > 0.0 else ceili((edge - 2.0 - o_ax) / GRID) - 1
		for t in range(ceili((box.position.dot(along) + PIN_MARGIN - o_al) / GRID),
				floori((box.end.dot(along) - PIN_MARGIN - o_al) / GRID) + 1):
			var cell := Vector2i(ax * float(k) + along * float(t))
			if _rt_open(cell, i, n, n):
				out.append([cell, d, ax * (edge - sign_d) + along * (o_al + float(t * GRID)), cell])
	return out


## Куда трасса pts уходит от точки centre (своего конца): направление отрезка,
## на котором она отходит дальше r (у плиток бывает шажок в 1 px у самого
## кольца — он не в счёт); -1 — не отходит.
static func _leave_dir(pts: PackedVector2Array, centre: Vector2, r: float) -> int:
	var walk := pts
	if pts[pts.size() - 1].distance_to(centre) < pts[0].distance_to(centre):
		walk = pts.duplicate()
		walk.reverse()
	for k in range(1, walk.size()):
		if walk[k].distance_to(centre) > r:
			return _dir_index(walk[k] - walk[k - 1])
	return -1


## Клетка c — в запасе конца n трассы целиком: кольца (его клетки в _rt_hard)
## или развилки с серединой centre (PORT_CELLS вокруг).
func _rt_zone(c: Vector2i, n: int, centre: Vector2i) -> bool:
	if _kind[n] == Kind.RING:
		return _rt_owner(c) == n + 1
	if _kind[n] == Kind.PORT:
		return absi(c.x - centre.x) <= PORT_CELLS and absi(c.y - centre.y) <= PORT_CELLS
	return false


## Чей запас в клетке: узел + 1, 0 — ничей, -1 — нескольких (или вне сетки).
func _rt_owner(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= _rt_size.x or c.y >= _rt_size.y:
		return -1
	return _rt_hard[c.y * _rt_size.x + c.x]


## Клетка внутри сетки и свободна для задания i с узлами na, nb на концах.
func _rt_open(c: Vector2i, i: int, na: int, nb: int) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= _rt_size.x or c.y >= _rt_size.y:
		return false
	var idx := c.y * _rt_size.x + c.x
	var rk := _rt_ring_keep[idx]
	return _rt_hard[idx] == 0 and _rt_bridge[idx] == 0 and _rt_soft[idx] == 0 \
		and (_rt_keep[idx] <= 0 or _rt_keep[idx] == i + 1) \
		and (rk <= 0 or rk == na + 1 or rk == nb + 1)


## Концы задания j: [[ребро, узел, гекс] у A, то же у B]. Стык — по трассе с
## каждой его стороны, трасса внутри гекса — её два узла. Развилка у стыка
## (_rt_full 1 или 2) — сам узел стыка, ребра нет (-1).
func _rt_job_ends(j: int) -> Array:
	if j < _sp_ports.size():
		var port: Dictionary = _sp_ports[j]
		var mode: int = _rt_full.get(j, 0)
		var a_end: Array = [-1, port["node"], port["a"]] if mode == 1 \
			else [port["edges_a"][0], _edge_b[port["edges_a"][0]], port["a"]]
		var b_end: Array = [-1, port["node"], port["b"]] if mode == 2 \
			else [port["edges_b"][0], _edge_b[port["edges_b"][0]], port["b"]]
		return [a_end, b_end]
	var e := _rt_inner[j - _sp_ports.size()]
	return [[e, _edge_a[e], _hex[_edge_a[e]]], [e, _edge_b[e], _hex[_edge_b[e]]]]


## Путь задания i целиком (_rt_full): от точки на узле A до точки на узле B, по
## осям, повороты не ближе JOG_MIN; первый и последний прямые участки не короче
## JOG_MIN. Сквозь запас своего кольца — только прямо от середины (или к ней),
## поворот в нём нельзя. Из равных — выход ближе к середине стороны рамки.
func _rt_find_full(i: int) -> PackedVector2Array:
	var je := _rt_job_ends(i)
	var na: int = je[0][1]
	var nb: int = je[1][1]
	var starts := _rt_exits(je[0][0], na, je[0][2], i)
	var goal_list := _rt_exits(je[1][0], nb, je[1][2], i)
	if starts.is_empty() or goal_list.is_empty():
		return PackedVector2Array()
	var goals := {}   # Vector3i(клетка, направление прихода) -> выход
	var a_lo := Vector2i(1 << 20, 1 << 20)
	var a_hi := -a_lo
	for exit: Array in starts:
		a_lo = a_lo.min(exit[3] as Vector2i)
		a_hi = a_hi.max(exit[3] as Vector2i)
	var b_lo := Vector2i(1 << 20, 1 << 20)
	var b_hi := -b_lo
	for exit: Array in goal_list:
		var gc: Vector2i = exit[0]
		goals[Vector3i(gc.x, gc.y, (int(exit[1]) + 2) % 4)] = exit
		b_lo = b_lo.min(exit[3] as Vector2i)
		b_hi = b_hi.max(exit[3] as Vector2i)
	# свой запас у концов: кольцо (его клетки) или развилка (PORT_CELLS вокруг)
	var centre_a := Vector2i(-1, -1)
	var centre_b := Vector2i(-1, -1)
	if _kind[na] == Kind.PORT:
		centre_a = starts[0][0]
	if _kind[nb] == Kind.RING or _kind[nb] == Kind.PORT:
		centre_b = goal_list[0][0]
	var m := int(ROUTE_MARGIN / GRID)
	var lo := Vector2i(maxi(0, mini(a_lo.x, b_lo.x) - m), maxi(0, mini(a_lo.y, b_lo.y) - m))
	var hi := Vector2i(mini(_rt_size.x - 1, maxi(a_hi.x, b_hi.x) + m), mini(_rt_size.y - 1, maxi(a_hi.y, b_hi.y) + m))
	var w := hi.x - lo.x + 1
	var h := hi.y - lo.y + 1
	var runs := JOG_MIN / GRID
	var states := 4 * (runs + 1)
	var g := PackedFloat32Array()
	g.resize(w * h * states)
	g.fill(INF)
	var parent := PackedInt32Array()
	parent.resize(w * h * states)
	parent.fill(-1)
	var heap_s := PackedInt32Array()
	var heap_f := PackedFloat32Array()
	var start_of := {}   # состояние -> выход
	for exit: Array in starts:
		var c0: Vector2i = exit[0]
		if c0.x < lo.x or c0.y < lo.y or c0.x > hi.x or c0.y > hi.y:
			continue
		var s0 := (((c0.y - lo.y) * w + (c0.x - lo.x)) * 4 + int(exit[1])) * (runs + 1)
		var g0 := _rt_pin_cost(na, je[0][2], exit)
		if g0 < g[s0]:
			g[s0] = g0
			start_of[s0] = exit
			_rt_push(heap_s, heap_f, s0, g0 + float(_seg_dist(c0, b_lo, b_hi)) * ROUTE_GREED)
	var goal := -1
	var goal_exit: Array = []
	var best := INF
	while not heap_s.is_empty():
		var s := heap_s[0]
		var f := heap_f[0]
		_rt_pop(heap_s, heap_f)
		if f >= best:
			break
		var run := s % (runs + 1)
		var d := (s / (runs + 1)) % 4
		var cell_i := s / states
		var c := Vector2i(lo.x + cell_i % w, lo.y + cell_i / w)
		if f > g[s] + float(_seg_dist(c, b_lo, b_hi)) * ROUTE_GREED + 0.01:
			continue
		var key := Vector3i(c.x, c.y, d)
		if goals.has(key) and run >= runs and not start_of.has(s):
			var total := g[s] + _rt_pin_cost(nb, je[1][2], goals[key])
			if total < best:
				best = total
				goal = s
				goal_exit = goals[key]
			continue
		if c == centre_b:
			continue
		var za := _rt_zone(c, na, centre_a)
		var zb := _rt_zone(c, nb, centre_b)
		for nd in 4:
			if nd == (d + 2) % 4:
				continue
			var turn := nd != d
			if turn and (run < runs or za or zb):
				continue
			var nc := c + Vector2i(DIRS[nd])
			if nc.x < lo.x or nc.y < lo.y or nc.x > hi.x or nc.y > hi.y:
				continue
			if _rt_zone(nc, na, centre_a):
				# из своего кольца (развилки) — только наружу, обратно не входить
				if not za:
					continue
			elif _rt_zone(nc, nb, centre_b):
				# в кольцо (развилку) B — прямо к середине, по свободной стороне
				var rel := nc - centre_b
				var on_line := rel.x * int(DIRS[nd].y) - rel.y * int(DIRS[nd].x) == 0
				if not zb and not (on_line and goals.has(Vector3i(centre_b.x, centre_b.y, nd))):
					continue
			elif not _rt_open(nc, i, na, nb):
				continue
			var nrun := 1 if turn else mini(run + 1, runs)
			var ns := (((nc.y - lo.y) * w + (nc.x - lo.x)) * 4 + nd) * (runs + 1) + nrun
			var ng := g[s] + 1.0 + (ROUTE_BEND / GRID if turn else 0.0)
			if ng < g[ns]:
				g[ns] = ng
				parent[ns] = s
				_rt_push(heap_s, heap_f, ns, ng + float(_seg_dist(nc, b_lo, b_hi)) * ROUTE_GREED)
	if goal < 0:
		return PackedVector2Array()
	var cells: Array[Vector2i] = []
	var s2 := goal
	var root := goal
	while s2 >= 0:
		var ci := s2 / states
		cells.append(Vector2i(lo.x + ci % w, lo.y + ci / w))
		root = s2
		s2 = parent[s2]
	cells.reverse()
	var start_exit: Array = start_of[root]
	var pts := PackedVector2Array()
	for k in cells.size():
		if k == 0 or k == cells.size() - 1 or (cells[k] - cells[k - 1]) != (cells[k + 1] - cells[k]):
			pts.append(_rt_origin + Vector2(cells[k]) * GRID)
	if pts.size() < 2:
		return PackedVector2Array()
	var a_at: Vector2 = start_exit[2]
	var b_at: Vector2 = goal_exit[2]
	# середина кольца может стоять и не на чётном пикселе: первый (последний)
	# прямой участок — по линии узла; у прямого пути город подстраивается под кольцо
	var across_a := Vector2(absf(DIRS[int(start_exit[1])].y), absf(DIRS[int(start_exit[1])].x))
	var across_b := Vector2(absf(DIRS[int(goal_exit[1])].y), absf(DIRS[int(goal_exit[1])].x))
	if pts.size() == 2 and absf(a_at.dot(across_a) - b_at.dot(across_a)) > 0.1:
		if _kind[nb] == Kind.SITE:
			b_at += across_a * (a_at.dot(across_a) - b_at.dot(across_a))
		elif _kind[na] == Kind.SITE:
			a_at += across_a * (b_at.dot(across_a) - a_at.dot(across_a))
		else:
			return PackedVector2Array()
	for k in [0, 1]:
		pts[k] += across_a * (a_at.dot(across_a) - pts[k].dot(across_a))
	for k in [pts.size() - 1, pts.size() - 2]:
		pts[k] += across_b * (b_at.dot(across_b) - pts[k].dot(across_b))
	# у кольца (развилки) клетка середины — сама середина с точностью до
	# пикселя: заменить, а не добавлять (иначе шажок назад на 1 px)
	if _kind[na] == Kind.SITE:
		pts.insert(0, a_at)
	else:
		pts[0] = a_at
	if _kind[nb] == Kind.SITE:
		pts.append(b_at)
	else:
		pts[pts.size() - 1] = b_at
	var out := PackedVector2Array([pts[0]])
	for q in pts:
		var last := out.size() - 1
		if out[last].is_equal_approx(q):
			continue
		if last >= 1 and is_zero_approx((out[last] - out[last - 1]).cross(q - out[last])) \
				and (out[last] - out[last - 1]).dot(q - out[last]) > 0.0:
			out[last] = q
			continue
		out.append(q)
	return out


## Небольшая цена выхода из рамки города вдали от середины её стороны.
func _rt_pin_cost(n: int, hex: String, exit: Array) -> float:
	if _kind[n] != Kind.SITE:
		return 0.0
	var mid: Vector2 = _pos[n] + (_sp_off[hex] as Vector2)
	var along := Vector2(absf(DIRS[int(exit[1])].y), absf(DIRS[int(exit[1])].x))
	return absf(((exit[2] as Vector2) - mid).dot(along)) / GRID * 0.25


## Кольцо, стоящее прямо на стыке порта i (сторона A или B): стороны (DIRS),
## куда из него не уходит ни одна другая трасса — по ним мостик может выйти из
## кольца или войти в него. Сторона к стыку (u у A, -u у B) свободна всегда.
func _ring_free_dirs(i: int, side_b: bool) -> Array:
	var port: Dictionary = _sp_ports[i]
	var u: Vector2 = port["u"]
	var toward := _dir_index(-u if side_b else u)
	var free: Array = [toward]
	var used := {}
	for e: int in port["edges_b" if side_b else "edges_a"]:
		var n := _edge_b[e] if _kind[_edge_b[e]] != Kind.PORT else _edge_a[e]
		if _kind[n] != Kind.RING or _pos[n].distance_to(port["p"]) > 1.0:
			continue
		for e2: int in _incident[n]:
			if e2 == e:
				continue
			var pts := _routes[e2]
			if pts.size() < 2:
				continue
			var from := pts[0] if pts[0].distance_to(_pos[n]) <= pts[pts.size() - 1].distance_to(_pos[n]) else pts[pts.size() - 1]
			var next := pts[1] if from == pts[0] else pts[pts.size() - 2]
			if next.distance_to(from) > 0.5:
				used[_dir_index((next - from).normalized())] = true
	for d in 4:
		if d != toward and not used.has(d) and d != (toward + 2) % 4:
			free.append(d)
	return free


## Лежит ли клетка rel (от начала луча) на прямой su между from и to шагами.
static func _on_ray(rel: Vector2i, su: Vector2i, from: int, to: int) -> bool:
	if rel.x * su.y - rel.y * su.x != 0:
		return false
	var t := rel.x * su.x + rel.y * su.y
	return t >= from and t <= to


## Клеток по осям от c до прямоугольника lo..hi (0 — внутри).
static func _seg_dist(c: Vector2i, lo: Vector2i, hi: Vector2i) -> int:
	return maxi(0, maxi(lo.x - c.x, c.x - hi.x)) + maxi(0, maxi(lo.y - c.y, c.y - hi.y))


static func _rt_push(heap_s: PackedInt32Array, heap_f: PackedFloat32Array, s: int, f: float) -> void:
	heap_s.append(s)
	heap_f.append(f)
	var i := heap_s.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if heap_f[p] <= heap_f[i]:
			break
		var ts := heap_s[p]
		heap_s[p] = heap_s[i]
		heap_s[i] = ts
		var tf := heap_f[p]
		heap_f[p] = heap_f[i]
		heap_f[i] = tf
		i = p


static func _rt_pop(heap_s: PackedInt32Array, heap_f: PackedFloat32Array) -> void:
	var last := heap_s.size() - 1
	heap_s[0] = heap_s[last]
	heap_f[0] = heap_f[last]
	heap_s.resize(last)
	heap_f.resize(last)
	var i := 0
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var m := i
		if l < last and heap_f[l] < heap_f[m]:
			m = l
		if r < last and heap_f[r] < heap_f[m]:
			m = r
		if m == i:
			break
		var ts := heap_s[m]
		heap_s[m] = heap_s[i]
		heap_s[i] = ts
		var tf := heap_f[m]
		heap_f[m] = heap_f[i]
		heap_f[i] = tf
		i = m


## Путь m_a..m_b делится в точке встречи — посередине самого длинного отрезка
## (там трассы двух гексов сходятся встречно): {"a": от встречи к m_a, "b": к m_b}.
static func _split_path(path: PackedVector2Array) -> Dictionary:
	if path.size() < 2:
		return {"a": PackedVector2Array([path[0]]), "b": PackedVector2Array([path[0]])}
	var best := 0
	for k in path.size() - 1:
		if path[k].distance_to(path[k + 1]) > path[best].distance_to(path[best + 1]):
			best = k
	# по отрезку от его начала (у трассы целиком первый отрезок может стоять
	# и на нечётном пикселе — от середины кольца)
	var seg := path[best + 1] - path[best]
	var meet := path[best] + seg.normalized() * roundf(seg.length() / 2.0 / float(GRID)) * float(GRID)
	var a := PackedVector2Array([meet])
	for k in range(best, -1, -1):
		a.append(path[k])
	var b := PackedVector2Array([meet])
	for k in range(best + 1, path.size()):
		b.append(path[k])
	return {"a": a, "b": b}


## Слой целиком расходится от центра — по одному его гексы друг друга держат
## (шаг одного даёт ступеньку 6x6 прямо у тесного ребра). Гекс в клетке
## (c, r) сдвигается на (знак c * ew, 0), если он в ряду центра, иначе на
## (знак c * dx, -вверх или +вниз). Четыре числа (кратны JOG_MIN) растут по шагу,
## пока растёт оценка: сначала самая узкая щель слоя, потом сумма щелей.
## Высоты у доски мало (зона между вопросом и счётчиком), и вверх-вниз слой
## уходит не дальше крайних гексов — дальше ступенька к ним не помещается.
func _sp_ring_apart(group: Array, adj: Dictionary, cell: Dictionary) -> void:
	var start := {}
	for hex: String in group:
		start[hex] = _sp_off[hex]
	var params := Vector4.ZERO   # ew, dx, вверх, вниз
	var best := _sp_ring_score(group, adj)
	var steps: Array[Vector4] = [Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0),
		Vector4(0, 0, 0, 1), Vector4(0, 0, 1, 1), Vector4(1, 1, 0, 0), Vector4(0, 1, 1, 0),
		Vector4(0, 1, 0, 1), Vector4(0, 1, 1, 1), Vector4(1, 1, 1, 1)]
	# по кругу: каждое направление шага пробуется по разу за круг, так все
	# четыре числа растут вместе (иначе первое уходит далеко, и ступенька
	# между соседями слоя выходит широкой и ни во что не вписывается)
	for _round in 40:
		var improved := false
		for step in steps:
			for k in [1, 2]:
				var cand := params + step * float(k)
				_sp_ring_place(group, cell, start, cand)
				var score := _sp_ring_score(group, adj)
				if score <= best + 0.5:
					continue
				var all_ok := true
				for hex: String in group:
					if not _sp_ok(hex):
						all_ok = false
						break
				if all_ok:
					best = score
					params = cand
					improved = true
					break
		if not improved:
			break
	_sp_ring_place(group, cell, start, params)


func _sp_ring_place(group: Array, cell: Dictionary, start: Dictionary, params: Vector4) -> void:
	for hex: String in group:
		var c: Vector2i = cell[hex]
		var by := Vector2(signi(c.x) * params.x, 0) if c.y == 0 \
			else Vector2(signi(c.x) * params.y, -params.z if c.y < 0 else params.w)
		_sp_off[hex] = (start[hex] as Vector2) + by * JOG_MIN


## Оценка слоя. Главное — зазор между рамками городов соседних гексов (до
## BOX_ZONE_GAP: под каждой рамкой свой пол, между ними две стены): самый
## узкий, потом сумма; затем самая узкая щель между всем содержимым и сумма.
func _sp_ring_score(group: Array, adj: Dictionary) -> float:
	var box_low := INF
	var box_total := 0.0
	var low := INF
	var total := 0.0
	for hex: String in group:
		var box_gap := minf(_sp_box_gap(hex, adj[hex]), BOX_ZONE_GAP)
		box_low = minf(box_low, box_gap)
		box_total += box_gap
		var gap := _sp_min_gap(hex, adj[hex], -INF)
		low = minf(low, gap)
		total += gap
	return box_low * 1.0e6 + box_total * 1.0e3 + low * 10.0 + total * 0.01


## Оценка одного гекса для _sp_maximin — так же: рамки городов, потом всё.
func _sp_hex_score(hex: String, adj: Array) -> float:
	return minf(_sp_box_gap(hex, adj), BOX_ZONE_GAP) * 1000.0 + _sp_min_gap(hex, adj, -INF)


## Самый узкий зазор между рамками городов гекса и его соседей — по большей
## из осей: рамки, разошедшиеся хоть по одной оси на BOX_ZONE_GAP, получают
## каждая свой пол.
func _sp_box_gap(hex: String, adj: Array) -> float:
	var best := INF
	var own_off: Vector2 = _sp_off[hex]
	for other: String in adj:
		var other_off: Vector2 = _sp_off[other]
		for r: Rect2 in _sp_sites[hex]:
			var a := Rect2(r.position + own_off, r.size)
			for r2: Rect2 in _sp_sites[other]:
				var b := Rect2(r2.position + other_off, r2.size)
				var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
				var dy := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
				best = minf(best, maxf(dx, dy))
	return best


## Гексы группы по очереди сдвигаются (на шаг JOG_MIN в любую из восьми
## сторон), пока самая узкая щель до соседей растёт.
func _sp_maximin(group: Array, adj: Dictionary) -> void:
	var dirs: Array[Vector2] = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
		Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]
	for _round in 60:
		var moved := false
		for hex: String in group:
			var start: Vector2 = _sp_off[hex]
			var best := _sp_hex_score(hex, adj[hex])
			var best_off := start
			for d in dirs:
				_sp_off[hex] = start + d * JOG_MIN
				var gap := _sp_hex_score(hex, adj[hex])
				if gap > best + 0.5 and _sp_ok(hex):
					best = gap
					best_off = _sp_off[hex]
			_sp_off[hex] = best_off
			if best_off != start:
				moved = true
		if not moved:
			return


## Пустоты между углами и кольцом (владелец, 2026-10-04): гекс слоя уходит
## наружу, пока его рамки ближе к внутренним соседям (центр и свой слой), чем
## к внешним, — так он встаёт посередине между центром и краем.
const FILL_MIN_GAP := 8.0   # ближе этого содержимое соседей при шаге не сходится

func _sp_fill(group: Array, adj: Dictionary, layer: Dictionary, cell: Dictionary) -> void:
	for _round in 60:
		var moved := false
		for hex: String in group:
			var inner: Array = []
			var outer: Array = []
			for other: String in adj[hex]:
				(outer if int(layer[other]) > int(layer[hex]) else inner).append(other)
			if outer.is_empty():
				continue
			var c: Vector2i = cell[hex]
			for step: Vector2 in _spread_steps(Vector2(signi(c.x), signi(c.y))).slice(0, 3):
				var was: Vector2 = _sp_off[hex]
				if _sp_box_gap(hex, inner) >= _sp_box_gap(hex, outer) - JOG_MIN:
					break
				_sp_off[hex] = was + step * JOG_MIN
				if _sp_box_gap(hex, inner) <= _sp_box_gap(hex, outer) + 0.5 \
						and _sp_min_gap(hex, adj[hex], FILL_MIN_GAP) > FILL_MIN_GAP and _sp_ok(hex):
					moved = true
					break
				_sp_off[hex] = was
		if not moved:
			return


## Самая узкая щель между содержимым гекса и его соседей. Как только щель
## не больше stop — дальше не считаем (кандидат уже хуже).
func _sp_min_gap(hex: String, adj: Array, stop: float) -> float:
	var best := INF
	var own_off: Vector2 = _sp_off[hex]
	for other: String in adj:
		var other_off: Vector2 = _sp_off[other]
		for item: Array in _sp_items[hex]:
			var r := Rect2((item[0] as Rect2).position + own_off, (item[0] as Rect2).size)
			for item2: Array in _sp_items[other]:
				var gap := _rect_gap(r, Rect2((item2[0] as Rect2).position + other_off, (item2[0] as Rect2).size))
				if gap < best:
					best = gap
					if best <= stop:
						return best
	return best


static func _rect_gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return sqrt(dx * dx + dy * dy)


## Куда пробовать сдвинуть гекс (в шагах JOG_MIN), от коротких к длинным,
## наружу от центра — d: знаки его столбца и ряда. Длинные шаги нужны для
## тупиков: гекс и его диагональный сосед держат друг друга (шаг вбок без
## шага вдоль щели — ступенька не помещается), а шаг сразу на 2-3 клетки
## перешагивает такое место.
static func _spread_steps(d: Vector2) -> Array:
	var out: Array = []
	for total in range(1, 5):
		for i in range(total, -1, -1):
			var j := total - i
			if (i > 0 and d.x == 0.0) or (j > 0 and d.y == 0.0):
				continue
			out.append(Vector2(d.x * i, d.y * j))
	# сначала по диагонали (в угол), потом по одной оси
	out.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		var la := absf(a.x) + absf(a.y)
		var lb := absf(b.x) + absf(b.y)
		if la != lb:
			return la < lb
		return absf(absf(a.x) - absf(a.y)) < absf(absf(b.x) - absf(b.y)))
	return out


## Шагов между двумя клетками сетки гексов (столбец — полшага, ряд — шаг).
static func _hex_steps(a: Vector2i, b: Vector2i) -> int:
	var dc := absi(a.x - b.x)
	var dr := absi(a.y - b.y)
	return maxi(dr, (dc + dr) / 2)


## Bridge of port i at the current offsets, as grown segment rects ([] = no gap).
func _sp_bridge_rects(i: int, mode := -1) -> Array:
	var port: Dictionary = _sp_ports[i]
	var off_a: Vector2 = _sp_off[port["a"]]
	var off_b: Vector2 = _sp_off[port["b"]]
	if off_a == off_b:
		return []
	if mode < 0:
		mode = int(port.get("mode", 0))
	var m_a: Vector2 = (port["p"] as Vector2) + off_a
	var m_b: Vector2 = (port["p"] as Vector2) + off_b
	var path: PackedVector2Array = _bridge_path(m_a, m_b, port["u"], mode, port["run_a"], port["run_b"])["check"]
	# Концы у m_a и m_b — продолжение своих трасс, которые уже легли: рамка, от
	# которой трасса отходит, может стоять в 1 px позади середины ребра (короткая
	# трасса в соседний гекс), и проверка с запасом приняла бы её за касание.
	var last := path.size() - 1
	if last >= 1:
		if path[0].is_equal_approx(m_a) or path[0].is_equal_approx(m_b):
			path[0] = path[0].move_toward(path[1], 2.0)
		if path[last].is_equal_approx(m_a) or path[last].is_equal_approx(m_b):
			path[last] = path[last].move_toward(path[last - 1], 2.0)
	var rects: Array = []
	for k in path.size() - 1:
		if not path[k].is_equal_approx(path[k + 1]):
			rects.append(Rect2(path[k], Vector2.ZERO).expand(path[k + 1]).grow(1.0))
	return rects


## Годится ли доска после сдвига гекса hex: щели не отрицательные и ступеньки
## помещаются, всё влезает в зону, ничто гекса не касается чужого, мостики
## ни на что не ложатся.
func _sp_ok(hex: String) -> bool:
	for i: int in _sp_ports_of[hex]:
		var port: Dictionary = _sp_ports[i]
		var d: Vector2 = (_sp_off[port["b"]] as Vector2) - (_sp_off[port["a"]] as Vector2)
		var along := d.dot(port["u"])
		var side := (d - (port["u"] as Vector2) * along).length()
		# Гексы зашли друг за друга вдоль u: годится, только если они разошлись
		# вбок — ступенька встаёт на прямые участки обеих трасс (span ниже),
		# а хвосты трасс за ней _bridge отрезает.
		if along < -0.5 and side < 0.5:
			return false
		# ступенька встаёт на прямые участки трасс и щель между ними
		var span := float(port["run_a"]) + along + float(port["run_b"])
		if side > 0.5 and (span < JOG_MIN * 2 - 0.5 or side < JOG_MIN - 0.5):
			return false

	var own_off: Vector2 = _sp_off[hex]
	var own_box := Rect2((_sp_box[hex] as Rect2).position + own_off, (_sp_box[hex] as Rect2).size)
	for other: String in _sp_box.keys():
		var other_off: Vector2 = _sp_off[other]
		if other == hex or other_off == own_off:
			continue
		var other_box := Rect2((_sp_box[other] as Rect2).position + other_off, (_sp_box[other] as Rect2).size)
		if not own_box.intersects(other_box):
			continue
		for item: Array in _sp_items[hex]:
			var r := Rect2((item[0] as Rect2).position + own_off, (item[0] as Rect2).size)
			if not r.intersects(other_box):
				continue
			for item2: Array in _sp_items[other]:
				if r.intersects(Rect2((item2[0] as Rect2).position + other_off, (item2[0] as Rect2).size)):
					return false

	# мостики чужих щелей стоят как стояли: на них не должно лечь ничто гекса
	var bridges := {}
	var mine: Array = _sp_ports_of[hex]
	for i in _sp_ports.size():
		if mine.has(i):
			continue
		var rects := _sp_bridge_rects(i)
		if rects.is_empty():
			continue
		bridges[i] = rects
		if _sp_rects_hit(rects, [hex], _sp_port_edges[i]):
			return false
	# свои мостики: для каждого — первый поворот ступеньки, что ни на что не ложится
	var modes := {}
	for i: int in mine:
		var current := int((_sp_ports[i] as Dictionary).get("mode", 0))
		var placed := false
		for k in BRIDGE_MODES:
			var mode := (current + k) % BRIDGE_MODES
			var rects := _sp_bridge_rects(i, mode)
			if rects.is_empty():
				placed = true
				break
			if _sp_rects_hit(rects, _sp_box.keys(), _sp_port_edges[i]):
				continue
			var crossed := false
			for j: int in bridges:
				for r: Rect2 in rects:
					for r2: Rect2 in bridges[j]:
						if r.intersects(r2):
							crossed = true
							break
					if crossed:
						break
				if crossed:
					break
			if crossed:
				continue
			bridges[i] = rects
			modes[i] = mode
			placed = true
			break
		if not placed:
			return false

	var all := Rect2()
	var first := true
	for other: String in _sp_box.keys():
		var b := Rect2((_sp_box[other] as Rect2).position + (_sp_off[other] as Vector2), (_sp_box[other] as Rect2).size)
		all = b if first else all.merge(b)
		first = false
	for i: int in bridges:
		for r: Rect2 in bridges[i]:
			all = all.merge(r)
	# доска, которая уже до раздвигания выше (шире) зоны, по этой оси не растёт,
	# но по другой раздвигается
	var room := (_sp_zone - Vector2(IMAGE_MARGIN, IMAGE_MARGIN) * 2 - Vector2(SPREAD_SLACK, SPREAD_SLACK)) \
		.max(_sp_start_size)
	if all.size.x > room.x + 0.5 or all.size.y > room.y + 0.5:
		return false
	for i: int in modes:
		(_sp_ports[i] as Dictionary)["mode"] = modes[i]
	return true


## Ложится ли какой-то из прямоугольников на содержимое гексов hexes (кроме
## трасс own — тех, что этот мостик продолжает).
func _sp_rects_hit(rects: Array, hexes: Array, own: Dictionary) -> bool:
	for r: Rect2 in rects:
		for other: String in hexes:
			var off: Vector2 = _sp_off[other]
			if not r.intersects(Rect2((_sp_box[other] as Rect2).position + off, (_sp_box[other] as Rect2).size)):
				continue
			for item: Array in _sp_items[other]:
				if own.has(item[1]):
					continue
				if r.intersects(Rect2((item[0] as Rect2).position + off, (item[0] as Rect2).size)):
					return true
	return false


func _set_route(e: int, points: PackedVector2Array) -> void:
	_routes[e] = points
	_visible[e] = _clip(e, points)
	_bbox[e] = _bounds(_visible[e])


## Route e ended at the old edge midpoint, now at `at`; it starts with the
## bridge instead (bridge runs from the meeting point to `at`).
func _bridge(e: int, at: Vector2, bridge: PackedVector2Array) -> void:
	var points := _routes[e]
	if points.is_empty():
		return
	var reversed := points[points.size() - 1].distance_to(at) < points[0].distance_to(at)
	if reversed:
		points.reverse()
	# мостик кончается на одном из первых отрезков трассы (у стыка или, при
	# сдвиге последнего участка вбок, на следующем): всё до этой точки — прочь
	var tip := bridge[bridge.size() - 1]
	var cut := -1
	for k in points.size() - 1:
		if Geometry2D.get_closest_point_to_segment(tip, points[k], points[k + 1]).distance_to(tip) < 0.5:
			cut = k + 1
			break
	# не на трассе — мостик сдвинул её единственный отрезок вбок целиком
	# (_rt_slide) и сам кончается в рамке: старой трассы не остаётся
	if cut < 0:
		cut = 1 if points.size() > 2 else points.size()
	var joined := bridge.duplicate()
	joined.append_array(points.slice(cut))
	# точка посреди прямого отрезка (стык мостика и трассы) не нужна
	var out := PackedVector2Array()
	for q in joined:
		var last := out.size() - 1
		if last >= 0 and out[last].is_equal_approx(q):
			continue
		if last >= 1:
			var d1 := out[last] - out[last - 1]
			var d2 := q - out[last]
			if is_zero_approx(d1.cross(d2)) and d1.dot(d2) > 0.0:
				out[last] = q
				continue
		out.append(q)
	if reversed:
		out.reverse()
	_routes[e] = out
	_visible[e] = _clip(e, out)
	_bbox[e] = _bounds(_visible[e])


# --- export ------------------------------------------------------------------------

## Everything drawn: boxes, rings and traces, without the image margin.
func _extent() -> Rect2:
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
	return Rect2(lo, hi - lo)


func _export(state: GameState) -> Dictionary:
	var extent := _extent()
	var lo := extent.position
	var pad := float(IMAGE_MARGIN)
	var shift := (-lo + Vector2(pad, pad)).round()
	var size := (extent.size + Vector2(pad, pad) * 2).ceil()

	var starting := GameSetup.STARTING_SITE_NAMES
	var marked := ControlMarkers.marked_sites(state)
	var sites := {}
	var slots := {}
	var rings := {}
	var a2_legend: Array = []
	for n in _key.size():
		var at := _pos[n] + shift
		if _kind[n] == Kind.RING:
			rings[_key[n]] = [at.x, at.y]
			slots[_key[n]] = {"x": at.x, "y": at.y}
		elif _kind[n] == Kind.LEGEND:
			var corner_l := at - _half[n]
			a2_legend = [corner_l.x, corner_l.y, _half[n].x * 2.0, _half[n].y * 2.0]
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
		# табличка ярусов бонуса A2 [x, y, w, h]; пусто, если гекса A2 нет
		"a2_legend": a2_legend,
	}

