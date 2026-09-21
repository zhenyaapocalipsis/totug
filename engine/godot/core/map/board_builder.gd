class_name BoardBuilder
extends RefCounted

## Собирает MapGraph из данных гексов и раскладки доски.
##
## ВНУТРИ ГЕКСА — по РАЗМЕЧЕННЫМ ВРУЧНУЮ данным (data/board/manual_adjacency.json).
##   Геометрическое правило «кольцо принадлежит ближайшей локации» системно
##   неверно: на C4 у кольца r0 настоящие соседи — Red Gate и Caer Sidi, а два
##   ближайших по расстоянию — Caer Sidi и Iblith, причём Red Gate не входит
##   даже в пару ближайших. Автоматическая трассировка туннелей по картинке
##   тоже не сходится: арт непоследователен от тайла к тайлу — у C1 карточка и
##   туннели образуют одну белую область, у C7 их разделяет чёрная обводка.
##   Полный разбор и список провалившихся подходов — в claude/art-verification.md.
##
## МЕЖДУ ГЕКСАМИ — «порты рёбер», а не сшивание колец.
##   Наивная идея «кольцо на общем ребре одного гекса ↔ кольцо другого» не работает:
##   туннельные кольца в исходных данных — это маркеры изгибов пути, а не выходы на
##   рёбра. У C3 туннели на всех 6 рёбрах, но колец всего 2 — то есть кольца
##   покрывают рёбра НЕ полностью, и сшивание по ним рвёт доску.
##   Поэтому источником истины о рёбрах служит demonwebEdgeConnByTile (данные
##   полные, по 6 рёбер на все 27 гексов), а «портом» ребра назначается тот узел
##   тайла — кольцо или слот локации — который дальше всех выдаётся в сторону
##   этого ребра. Два соседних гекса сшиваются порт-в-порт по общему ребру.
##
## Сшивание по рёбрам не зависит от масштаба тайла: в исходных данных масштаб тайла
## и шаг размещения гексов независимы (в Lua прямо оговорено, что TTS не рендерит
## тайл ровно в размер его scale), поэтому мировые расстояния между гексами
## не откалиброваны и сшивать по ним нельзя.
##
## ВАЖНО: собранная доска НЕ обязана быть одной связной компонентой. На X1 и X2
## есть локации, которых не касается ни один туннель (The Barrens, Indifference).
## Это не дефект сборки: по правилам шпиона можно поставить на ЛЮБУЮ локацию без
## Присутствия, а шпион уже даёт Присутствие — через него такие локации и
## разыгрываются.

## Убирать ли тупиковые тоннели — кольца, у которых сосед только один сайт
## и больше никого. На схеме они выглядят линией в никуда и занимают место,
## которого в упакованной карте и так нет (проба по добру владельца,
## 2026-09-21: «проверь, если убрать будет ли лучше»).
##
## ВНИМАНИЕ: это изменение ПРАВИЛ, а не только картинки — из игры уходят
## настоящие места под войска (на четверых около двух десятков).
const DROP_DEAD_END_TUNNELS := true

const DIR_CYCLE: Array[String] = ["N", "NE", "SE", "S", "SW", "NW"]
const OPPOSITE_DIR: Dictionary = {
	"N": "S", "NE": "SW", "SE": "NW", "S": "N", "SW": "NE", "NW": "SE",
}
## Единичные векторы 6 направлений в локальных координатах гекса (ось Z — «вверх»).
const DIR_VECTORS: Dictionary = {
	"N": Vector2(0.0, 1.0),
	"NE": Vector2(0.8660254, 0.5),
	"SE": Vector2(0.8660254, -0.5),
	"S": Vector2(0.0, -1.0),
	"SW": Vector2(-0.8660254, -0.5),
	"NW": Vector2(-0.8660254, 0.5),
}

## Слоты одного сайта считаются смежными, если расстояние между ними не больше этого.
## Печатные круги внутри сайта стоят с шагом ~1.3 (в единицах арта гекса).
const INTRA_SITE_MAX_DIST := 1.6

var _site_data: Dictionary
var _route_data: Dictionary
var _hex_edges: Dictionary
var _layouts: Dictionary
var _manual: Dictionary


func _init(site_data: Dictionary, route_data: Dictionary, hex_edges: Dictionary,
		layouts: Dictionary, manual_adjacency: Dictionary = {}) -> void:
	_site_data = site_data
	_route_data = route_data
	_hex_edges = hex_edges
	_layouts = layouts
	_manual = manual_adjacency


## Разметка для гекса, с учётом ссылки _same_as (A5/A6/A8 делят шаблон A4).
## Идентификаторы колец переписываются под нужный гекс: в шаблоне они вида
## "A4_route0", а на A5 тот же слот называется "A5_route0".
func _manual_for(hex_id: String) -> Dictionary:
	var entry: Dictionary = _manual.get(hex_id, {})
	var source_id := hex_id
	if entry.has("_same_as"):
		source_id = str(entry["_same_as"])
		entry = _manual.get(source_id, {})
	if source_id == hex_id:
		return entry

	var remapped: Dictionary = {"ring_sites": {}, "ring_rings": [], "site_sites": [],
		"edge_only": []}
	for ring_id: String in (entry.get("ring_sites", {}) as Dictionary).keys():
		remapped["ring_sites"][ring_id.replace(source_id + "_", hex_id + "_")] = \
			entry["ring_sites"][ring_id]
	for pair: Array in entry.get("ring_rings", []):
		remapped["ring_rings"].append([
			str(pair[0]).replace(source_id + "_", hex_id + "_"),
			str(pair[1]).replace(source_id + "_", hex_id + "_"),
		])
	for pair: Array in entry.get("site_sites", []):
		remapped["site_sites"].append(pair)
	for ring_id: String in entry.get("edge_only", []):
		remapped["edge_only"].append(ring_id.replace(source_id + "_", hex_id + "_"))
	return remapped


## Поворот локального смещения на угол размещения гекса.
## Соответствует левосторонней конвенции rotY из TTS (по часовой стрелке — положительная).
static func rotate_local(p: Vector2, rot_deg: float) -> Vector2:
	var rad := deg_to_rad(rot_deg)
	return Vector2(
		p.x * cos(rad) + p.y * sin(rad),
		-p.x * sin(rad) + p.y * cos(rad)
	)


## Куда смотрит печатное ребро raw_dir у гекса, повёрнутого на rot_deg.
static func world_dir_of_raw_edge(raw_dir: String, rot_deg: float) -> String:
	var shift := int(round(rot_deg / 60.0)) % 6
	var raw_idx := DIR_CYCLE.find(raw_dir)
	return DIR_CYCLE[(raw_idx + shift + 6) % 6]


## Обратное отображение: какое печатное ребро смотрит в мировом направлении world_dir.
static func raw_edge_facing_world(world_dir: String, rot_deg: float) -> String:
	var shift := int(round(rot_deg / 60.0)) % 6
	var world_idx := DIR_CYCLE.find(world_dir)
	return DIR_CYCLE[((world_idx - shift) % 6 + 6) % 6]


## Есть ли у гекса туннельный выход в мировом направлении world_dir при повороте rot_deg.
func hex_has_connection_facing(hex_id: String, world_dir: String, rot_deg: float) -> bool:
	if not _hex_edges.has(hex_id):
		return false
	var open_edges: Array = _hex_edges[hex_id]
	return open_edges.has(raw_edge_facing_world(world_dir, rot_deg))


## hex_by_slot: имя слота раскладки -> id гекса ("B1", "C3", ...)
## rotation_by_slot: имя слота раскладки -> поворот в градусах (кратен 60)
func build(player_count: int, hex_by_slot: Dictionary, rotation_by_slot: Dictionary) -> MapGraph:
	var graph := MapGraph.new()
	var layout: Dictionary = _layouts[str(player_count)]

	# Ключи слотов графа уникальны по слоту раскладки: один и тот же гекс
	# может встретиться в раскладке дважды (C-тайлы тянутся из общего пула).
	# local_positions[layout_slot][slot_id] = позиция ДО поворота — по ней
	# выбираются порты рёбер (печатные рёбра тоже берутся до поворота).
	var local_positions: Dictionary = {}
	var site_id_by_name: Dictionary = {}   # layout_slot -> {имя локации -> site_id}

	for layout_slot: String in hex_by_slot.keys():
		var hex_id: String = hex_by_slot[layout_slot]
		var rot: float = rotation_by_slot.get(layout_slot, 0.0)
		var prefix := layout_slot + ":"
		var locals: Dictionary = {}
		var by_name: Dictionary = {}

		for site: Dictionary in _site_data.get(hex_id, []):
			var site_id: String = prefix + site["id"]
			graph.add_site(site_id, site["name"], int(site["vp"]), hex_id)
			by_name[str(site["name"])] = site_id
			for slot: Dictionary in site["troop_slots"]:
				var local := Vector2(slot["x"], slot["z"])
				var slot_id: String = prefix + slot["id"]
				graph.add_slot(slot_id, hex_id, rotate_local(local, rot), site_id)
				locals[slot_id] = local

		for slot: Dictionary in _route_data.get(hex_id, []):
			var local := Vector2(slot["x"], slot["z"])
			var slot_id: String = prefix + slot["id"]
			graph.add_slot(slot_id, hex_id, rotate_local(local, rot), "")
			locals[slot_id] = local

		local_positions[layout_slot] = locals
		site_id_by_name[layout_slot] = by_name

	for layout_slot: String in hex_by_slot.keys():
		_link_within_hex(graph, layout_slot, hex_by_slot[layout_slot],
			local_positions[layout_slot], site_id_by_name[layout_slot])

	_sew_neighbours(graph, layout, hex_by_slot, rotation_by_slot, local_positions)

	if DROP_DEAD_END_TUNNELS:
		graph.drop_dead_end_tunnels()

	graph.finalize()
	return graph


## Радиус вписанной окружности тайла в единицах арта: расстояние от центра
## гекса до СЕРЕДИНЫ ребра (у шестиугольника это R·cos30°). WORLD_RADIUS
## взят из data/board/view_meta.json ("world_radius": 8.5).
const WORLD_RADIUS := 8.5
const EDGE_MID_DISTANCE := WORLD_RADIUS * 0.8660254


## Порт ребра: узел тайла, ближайший к СЕРЕДИНЕ этого печатного ребра.
## Возвращает "" если у тайла вообще нет узлов.
##
## Раньше здесь бралась максимальная проекция на направление ребра, и это
## давало осечки, когда два узла почти одинаково выдаются вперёд, но один
## сильно смещён вбок. Найдено владельцем игры на настоящей партии: у C1
## северное ребро получало кольцо C1_route3 (z=2.693) вместо самой локации
## The Twilight (z=2.662) — разница в 0.03 при боковом сдвиге в 2.7 единицы.
## На арте туннель с северного ребра ведёт именно в The Twilight, а кольцо
## обслуживает совсем другое, северо-восточное ребро. Из-за этого войско в
## The Twilight не давало Присутствия в соседнем гексе, хотя по картинке
## туннель туда идёт напрямую.
##
## Расстояние до середины ребра — правильный признак: туннель пересекает
## ребро посередине, и подключаться к нему должен ближайший к этой точке узел.
## Смена правила затрагивает 8 рёбер из 27 тайлов; шесть из них — это переход
## на другой слот ТОЙ ЖЕ локации (уточнение), и два содержательных: C1 N и
## C8 SE. Оба сверены с печатным артом.
func _port_for_raw_edge(locals: Dictionary, raw_dir: String) -> String:
	var edge_mid: Vector2 = DIR_VECTORS[raw_dir] * EDGE_MID_DISTANCE
	var best := ""
	var best_distance := INF
	for slot_id: String in locals.keys():
		var distance: float = (locals[slot_id] as Vector2).distance_squared_to(edge_mid)
		if distance < best_distance:
			best_distance = distance
			best = slot_id
	return best


## Порт ребра с учётом ручной разметки: manual_adjacency.json -> "edge_ports"
## {ребро: имя локации или id кольца}. Нужна там, где ближайший к середине
## ребра узел не совпадает с артом (C4 SW: туннель идёт в Red Gate, а ближе
## к ребру стоит кольцо C4_route0 — из-за этого войско за ребром давало
## Присутствие на кольце между Red Gate и Caer Sidi).
func _port(hex_id: String, locals: Dictionary, raw_dir: String, prefix: String) -> String:
	var override = (_manual_for(hex_id).get("edge_ports", {}) as Dictionary).get(raw_dir, "")
	if override != "":
		var ring_id: String = prefix + str(override)
		if locals.has(ring_id):
			return ring_id
		for site: Dictionary in _site_data.get(hex_id, []):
			if site["name"] == override:
				# ближайший к ребру слот этой локации
				var site_locals := {}
				for slot: Dictionary in site["troop_slots"]:
					site_locals[prefix + slot["id"]] = locals[prefix + slot["id"]]
				return _port_for_raw_edge(site_locals, raw_dir)
		push_warning("edge_ports %s %s: нет узла '%s'" % [hex_id, raw_dir, override])
	return _port_for_raw_edge(locals, raw_dir)


## Диагностика (tests/diagnose_ports.gd): id узла без префикса раскладки.
func port_name(hex_id: String, raw_dir: String) -> String:
	var locals := {}
	for site: Dictionary in _site_data.get(hex_id, []):
		for slot: Dictionary in site["troop_slots"]:
			locals[":" + slot["id"]] = Vector2(slot["x"], slot["z"])
	for slot: Dictionary in _route_data.get(hex_id, []):
		locals[":" + slot["id"]] = Vector2(slot["x"], slot["z"])
	return _port(hex_id, locals, raw_dir, ":").trim_prefix(":")


func _sew_neighbours(
	graph: MapGraph,
	layout: Dictionary,
	hex_by_slot: Dictionary,
	rotation_by_slot: Dictionary,
	local_positions: Dictionary
) -> void:
	for edge: Dictionary in layout["adjacency"]:
		var a: String = edge["a"]
		var b: String = edge["b"]
		if not (hex_by_slot.has(a) and hex_by_slot.has(b)):
			continue
		var world_dir: String = edge["dir"]              # направление от a к b
		var back_dir: String = OPPOSITE_DIR[world_dir]
		var rot_a: float = rotation_by_slot.get(a, 0.0)
		var rot_b: float = rotation_by_slot.get(b, 0.0)

		# сшиваем только если оба тайла реально печатают туннель на это ребро
		if not hex_has_connection_facing(hex_by_slot[a], world_dir, rot_a):
			continue
		if not hex_has_connection_facing(hex_by_slot[b], back_dir, rot_b):
			continue

		var port_a := _port(hex_by_slot[a], local_positions[a], raw_edge_facing_world(world_dir, rot_a), a + ":")
		var port_b := _port(hex_by_slot[b], local_positions[b], raw_edge_facing_world(back_dir, rot_b), b + ":")
		if port_a != "" and port_b != "":
			graph.connect_slots(port_a, port_b)
			# Site-to-site tunnel across the hex edge (no ring between): the
			# sites are adjacent as a whole, not just via these two port slots.
			# Without this, a troop in a non-port slot of the site gave no
			# Presence in the neighbouring site.
			var site_a := graph.site_of_slot(port_a)
			var site_b := graph.site_of_slot(port_b)
			if site_a != "" and site_b != "":
				graph.connect_sites(site_a, site_b)


## Внутренняя топология гекса берётся из РАЗМЕЧЕННЫХ ВРУЧНУЮ данных
## (data/board/manual_adjacency.json), а не выводится геометрически.
##
## Геометрическое правило «кольцо принадлежит ближайшей локации» системно
## неверно: на C4 у кольца r0 настоящие соседи — Red Gate и Caer Sidi, а два
## ближайших по расстоянию — Caer Sidi и Iblith, причём Red Gate не входит даже
## в пару ближайших. Автоматическая трассировка туннелей по картинке тоже не
## сходится: арт непоследователен, у C1 карточка и туннели — одна белая область,
## у C7 они разделены чёрной обводкой. Подробности — в claude/art-verification.md.
##
## Единственное, что здесь всё ещё считается по геометрии, — связи между
## слотами ОДНОЙ локации: они стоят рядом печатным рядом, и тут ошибиться негде.
func _link_within_hex(graph: MapGraph, layout_slot: String, hex_id: String,
		locals: Dictionary, site_id_by_name: Dictionary) -> void:
	var slot_ids: Array[String] = []
	for slot_id: String in locals.keys():
		slot_ids.append(slot_id)

	# 1. слоты одной локации — между собой
	for i in slot_ids.size():
		for j in range(i + 1, slot_ids.size()):
			var a := slot_ids[i]
			var b := slot_ids[j]
			var site_a := graph.site_of_slot(a)
			if site_a == "" or site_a != graph.site_of_slot(b):
				continue
			if locals[a].distance_to(locals[b]) <= INTRA_SITE_MAX_DIST:
				graph.connect_slots(a, b)

	var manual := _manual_for(hex_id)
	if manual.is_empty():
		push_warning("нет разметки смежности для гекса " + hex_id)
		return
	var prefix := layout_slot + ":"

	# 2. кольцо -> локация. Кольцо связывается со ВСЕМИ слотами локации: по
	#    правилам маршрутный слот смежен с локацией как целым, а не с каким-то
	#    одним её местом под войска.
	for ring_id: String in (manual.get("ring_sites", {}) as Dictionary).keys():
		var ring_slot := prefix + ring_id
		if not graph.slots.has(ring_slot):
			push_warning("разметка ссылается на неизвестное кольцо " + ring_id)
			continue
		for site_name: String in manual["ring_sites"][ring_id]:
			if not site_id_by_name.has(site_name):
				push_warning("разметка %s: нет локации '%s'" % [hex_id, site_name])
				continue
			for site_slot in graph.slots_of_site(site_id_by_name[site_name]):
				graph.connect_slots(ring_slot, site_slot)

	# 3. кольцо -> кольцо
	for pair: Array in manual.get("ring_rings", []):
		var a := prefix + str(pair[0])
		var b := prefix + str(pair[1])
		if graph.slots.has(a) and graph.slots.has(b):
			graph.connect_slots(a, b)

	# 4. локация -> локация напрямую (туннель без троп-слотов между ними)
	for pair: Array in manual.get("site_sites", []):
		var name_a := str(pair[0])
		var name_b := str(pair[1])
		if site_id_by_name.has(name_a) and site_id_by_name.has(name_b):
			graph.connect_sites(site_id_by_name[name_a], site_id_by_name[name_b])
		else:
			push_warning("разметка %s: не найдены локации '%s' / '%s'"
				% [hex_id, name_a, name_b])
