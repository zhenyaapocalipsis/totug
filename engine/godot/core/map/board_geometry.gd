class_name BoardGeometry
extends RefCounted

## Где что лежит НА ДОСКЕ в пикселях: тайлы с их поворотами и троп-слоты.
##
## Зачем отдельный класс. `MapGraph.slots[...]["pos"]` — это координаты слота
## ВНУТРИ своего гекса (повёрнутые, но без смещения гекса на доску). Для
## правил этого достаточно: там важна только смежность. А интерфейс, взяв эти
## координаты напрямую, рисовал все девять гексов друг поверх друга — доска
## выглядела кашей из кружков. Мировые координаты считаются здесь, один раз,
## по той же геометрии, что и просмотрщик доски этапа 1
## (`scenes/board_view.gd`), чтобы у игры и у просмотрщика картинка совпадала.
##
## Формулы (data/board/view_meta.json):
##   px_per_world  = neighbour_step / (sqrt(3) * world_radius)
##   центр тайла   = (x, -z) раскладки * px_per_world
##   слот          = центр + (art_offset + (x, -z) * art_scale), повёрнутое на rot
##   art_offset    = art_centre - hex_centre   (арт нарисован не по центру тайла)
##
## Поворот — вокруг ГЕОМЕТРИЧЕСКОГО центра шестиугольника: вокруг начала
## координат арта тайлы разъезжаются до 27 px (claude/progress.md, ошибка 12).

const META_PATH := "res://data/board/view_meta.json"
const TEXTURE_DIR := "res://assets/hexes/"


## Возвращает:
## {
##   "tiles": [ {hex_id, x, y, rotation_deg, texture, tex_centre_x, tex_centre_y} ],
##   "slots": { slot_id: {x, y, site_id, hex} },
##   "hex_radius_px": float,
## }
static func build(state: GameState) -> Dictionary:
	var meta: Dictionary = _load_json(META_PATH)
	if meta.is_empty():
		return {"tiles": [], "slots": {}, "hex_radius_px": 1.0}
	var data := BoardData.load_all()
	var layout_info: Dictionary = state.layout
	var hex_by_slot: Dictionary = layout_info.get("hex_by_slot", {})
	var rotations: Dictionary = layout_info.get("rotations", {})
	var players: int = int(layout_info.get("player_count", state.turn_order.size()))
	if hex_by_slot.is_empty():
		return {"tiles": [], "slots": {}, "hex_radius_px": 1.0}

	var layout: Dictionary = (data["layouts"] as Dictionary)[str(players)]
	var places: Dictionary = layout["slots"]
	var world_radius: float = float(meta.get("world_radius", 8.5))
	var px_per_world: float = float(meta["neighbour_step"]) / (sqrt(3.0) * world_radius)

	var sites: Dictionary = data["sites"]
	var routes: Dictionary = data["routes"]

	var tiles: Array = []
	var slots: Dictionary = {}

	for layout_slot: String in hex_by_slot.keys():
		var hex_id: String = hex_by_slot[layout_slot]
		var hex_meta: Dictionary = (meta["hexes"] as Dictionary)[hex_id]
		var rot: float = float(rotations.get(layout_slot, 0.0))
		var place: Dictionary = places[layout_slot]
		var centre := Vector2(float(place["x"]), -float(place["z"])) * px_per_world
		var hex_centre := Vector2(
			float(hex_meta["hex_centre"][0]), float(hex_meta["hex_centre"][1]))

		tiles.append({
			"hex_id": hex_id,
			"x": centre.x,
			"y": centre.y,
			"rotation_deg": rot,
			"texture": TEXTURE_DIR + "hex_%s.png" % hex_id,
			"tex_centre_x": hex_centre.x,
			"tex_centre_y": hex_centre.y,
		})

		var art_centre := Vector2(
			float(hex_meta["art_centre"][0]), float(hex_meta["art_centre"][1]))
		var art_scale: float = float(hex_meta["art_scale"])
		var art_offset := art_centre - hex_centre
		var prefix := layout_slot + ":"

		for site: Dictionary in sites.get(hex_id, []):
			var site_id: String = prefix + String(site["id"])
			for slot: Dictionary in site["troop_slots"]:
				slots[prefix + String(slot["id"])] = _slot_entry(
					centre, art_offset, art_scale, rot, slot, site_id, hex_id)
		for slot2: Dictionary in routes.get(hex_id, []):
			slots[prefix + String(slot2["id"])] = _slot_entry(
				centre, art_offset, art_scale, rot, slot2, "", hex_id)

	return {
		"tiles": tiles,
		"slots": slots,
		"hex_radius_px": float(meta["hex_radius"]),
	}


static func _slot_entry(centre: Vector2, art_offset: Vector2, art_scale: float,
		rot: float, slot: Dictionary, site_id: String, hex_id: String) -> Dictionary:
	var local := art_offset + Vector2(float(slot["x"]), -float(slot["z"])) * art_scale
	var world := centre + local.rotated(deg_to_rad(rot))
	return {"x": world.x, "y": world.y, "site_id": site_id, "hex": hex_id}


static func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("не читается " + path)
		return {}
	var parsed = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
