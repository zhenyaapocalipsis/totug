extends Node2D

## Просмотр собранной доски.
##
## Показывает РЕЗУЛЬТАТ РАБОТЫ ЯДРА: доска собирается тем же BoardBuilder и
## RotationOptimizer, что и в игре, а не отдельной «красивой» версией. Если
## ядро соберёт доску неправильно, это будет видно здесь.
##
## Управление: перетаскивание мышью — сдвиг, колесо — масштаб,
## пробел — пересобрать доску с новым случайным сидом,
## S — показать/скрыть точки троп-слотов, Esc — выход.

const HEX_TEXTURES := "res://assets/hexes/"
const WORLD_RADIUS := 8.5      # радиус гекса в мировых единицах раскладки

## Раскладка на 2 игроков: центр, кольцо из C-тайлов, два угловых B-тайла.
const TWO_PLAYER_HEXES := {
	"a": "A1",
	"c_n1": "C1", "c_n2": "C2", "c_n3": "C3",
	"c_s1": "C4", "c_s2": "C5", "c_s3": "C6",
	"b1": "B1", "b2": "B2",
}
## Поворот Menzoberranzan НЕ фиксируется.
##
## В моде TTS тайл B1 всегда клали повёрнутым на 240°. Владелец игры подтвердил,
## что в настоящей игре общее правило «поверни так, чтобы дать максимум
## соединений» действует и на него — фиксируется только МЕСТО (угол раскладки),
## а не поворот. С жёстким якорем 6 случайных раскладок из 180 разваливались:
## угловой тайл оставался вообще без стыковок. Без якоря — 0 из 180.
const FIXED_ROTATIONS := {}

var _meta: Dictionary
var _data: Dictionary
var _graph: MapGraph
var _rotations: Dictionary
var _slot_points: Array[Dictionary] = []
var _show_slots := true
var _seed := 12345

@onready var _camera: Camera2D = $Camera2D
@onready var _status: Label = $UI/Status
## Точки слотов рисуются отдельным узлом ПОВЕРХ тайлов: собственная отрисовка
## Node2D идёт до его детей, поэтому спрайты гексов её перекрывали.
var _overlay: Node2D


func _ready() -> void:
	# Служебный экран, но шрифт в нём тот же пиксельный, что и в игре.
	($UI as Control).theme = PixelTheme.theme()
	_overlay = SlotOverlay.new()
	_overlay.z_index = 100
	add_child(_overlay)
	_meta = _load_json("res://data/board/view_meta.json")
	_data = BoardData.load_all()
	_build(_seed)
	_maybe_screenshot()


## Режим автоснимка: godot --path godot -- --screenshot=/путь/board.png
## Нужен, чтобы проверять картинку автоматически, а не «на глаз, вроде похоже».
func _maybe_screenshot() -> void:
	var target := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--screenshot="):
			target = argument.split("=", true, 1)[1]
	if target.is_empty():
		return
	# дать кадру отрисоваться целиком
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(target)
	if error != OK:
		push_error("не удалось сохранить снимок: %d" % error)
	else:
		print("снимок сохранён: " + target)
	get_tree().quit()


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("не читается " + path)
		return {}
	return JSON.parse_string(text) as Dictionary


func _build(seed_value: int) -> void:
	for child in get_children():
		if child is Sprite2D:
			child.queue_free()
	_slot_points.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var layout: Dictionary = (_data["layouts"] as Dictionary)["2"]
	_rotations = RotationOptimizer.optimize(
		TWO_PLAYER_HEXES, layout["adjacency"], FIXED_ROTATIONS, _data["edges"], rng)

	var builder := BoardData.make_builder()
	_graph = builder.build(2, TWO_PLAYER_HEXES, _rotations)

	# мировые единицы раскладки -> пиксели текстур
	var px_per_world: float = float(_meta["neighbour_step"]) / (sqrt(3.0) * WORLD_RADIUS)

	var sites: Dictionary = _data["sites"]
	var routes: Dictionary = _data["routes"]
	var centres: Array[Vector2] = []

	for layout_slot: String in TWO_PLAYER_HEXES.keys():
		var hex_id: String = TWO_PLAYER_HEXES[layout_slot]
		var hex_meta: Dictionary = (_meta["hexes"] as Dictionary)[hex_id]
		var rot: float = _rotations[layout_slot]
		var place: Dictionary = layout["slots"][layout_slot]
		var centre := Vector2(float(place["x"]), -float(place["z"])) * px_per_world
		centres.append(centre)

		var sprite := Sprite2D.new()
		sprite.texture = load(HEX_TEXTURES + "hex_%s.png" % hex_id)
		sprite.position = centre
		# поворот вокруг ГЕОМЕТРИЧЕСКОГО центра шестиугольника: при повороте
		# вокруг начала координат арта тайлы разъезжаются (было до 27 px зазора)
		var texture_size := Vector2(
			float(hex_meta["texture_size"][0]), float(hex_meta["texture_size"][1]))
		var hex_centre := Vector2(
			float(hex_meta["hex_centre"][0]), float(hex_meta["hex_centre"][1]))
		sprite.offset = texture_size * 0.5 - hex_centre
		sprite.rotation = deg_to_rad(rot)
		add_child(sprite)

		# троп-слоты: смещение от центра шестиугольника, повёрнутое так же
		var art_centre := Vector2(
			float(hex_meta["art_centre"][0]), float(hex_meta["art_centre"][1]))
		var art_scale: float = float(hex_meta["art_scale"])
		var art_offset := art_centre - hex_centre

		for site: Dictionary in sites.get(hex_id, []):
			for slot: Dictionary in site["troop_slots"]:
				_add_slot_point(centre, art_offset, art_scale, rot,
					float(slot["x"]), float(slot["z"]), true)
		for slot: Dictionary in routes.get(hex_id, []):
			_add_slot_point(centre, art_offset, art_scale, rot,
				float(slot["x"]), float(slot["z"]), false)

	_frame_board(centres)
	_update_status()
	_overlay.points = _slot_points
	_overlay.visible = _show_slots
	_overlay.queue_redraw()


func _add_slot_point(centre: Vector2, art_offset: Vector2, art_scale: float,
		rot: float, x: float, z: float, is_site: bool) -> void:
	var d := art_offset + Vector2(x, -z) * art_scale
	_slot_points.append({
		"pos": centre + d.rotated(deg_to_rad(rot)),
		"site": is_site,
	})


class SlotOverlay extends Node2D:
	var points: Array[Dictionary] = []

	func _draw() -> void:
		for point: Dictionary in points:
			var colour: Color = (Color(0.16, 0.86, 0.35) if point["site"]
				else Color(1.0, 0.58, 0.12))
			draw_circle(point["pos"], 17.0, Color(0, 0, 0, 0.9))
			draw_circle(point["pos"], 12.0, colour)


## Рамка считается по САМИМ ТАЙЛАМ (центры плюс радиус), а не по троп-слотам:
## слоты расположены внутри тайлов несимметрично, и доска съезжала в сторону.
func _frame_board(centres: Array[Vector2]) -> void:
	if centres.is_empty():
		return
	var radius: float = float(_meta["hex_radius"])
	var min_p: Vector2 = centres[0]
	var max_p: Vector2 = centres[0]
	for centre in centres:
		min_p = min_p.min(centre)
		max_p = max_p.max(centre)
	min_p -= Vector2.ONE * radius
	max_p += Vector2.ONE * radius
	var size := (max_p - min_p) * 1.06
	var viewport := get_viewport_rect().size
	_camera.position = (min_p + max_p) * 0.5
	_camera.zoom = Vector2.ONE * minf(viewport.x / size.x, viewport.y / size.y)


func _update_status() -> void:
	var connected := _graph.connected_component_count()
	var cross := 0
	for slot_id: String in _graph.slots.keys():
		for neighbour in _graph.adjacent_slots(slot_id):
			if slot_id.split(":")[0] != neighbour.split(":")[0]:
				cross += 1
	_status.text = ("Доска на 2 игроков · сид %d\n" % _seed
		+ "гексов %d · сайтов %d · троп-слотов %d\n"
			% [TWO_PLAYER_HEXES.size(), _graph.site_count(), _graph.slot_count()]
		+ "связей между гексами %d · компонент связности %d\n" % [cross / 2, connected]
		+ "\nмышь — сдвиг · колесо — масштаб\nпробел — пересобрать · S — точки · Esc — выход")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_camera.position -= event.relative / _camera.zoom
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera.zoom *= 1.1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.zoom /= 1.1
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_seed = randi()
				_build(_seed)
			KEY_S:
				_show_slots = not _show_slots
				_overlay.visible = _show_slots
			KEY_ESCAPE:
				get_tree().quit()
