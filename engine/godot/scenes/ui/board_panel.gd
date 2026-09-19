class_name BoardPanel
extends PanelContainer

## Доска, поверх — войска, шпионы и подсветка доступных целей.
##
## Two looks (key H switches): the pixel-art schematic (default, see
## core/map/board_schematic.gd — tunnels as circuit traces, no hexes) and the
## real hex tiles with their rotations. Both come from the same board snapshot
## and the same slot ids, so clicks and highlights work the same way.
##
## До этого доска рисовалась схемой из кружков и была нечитаемой: координаты
## слотов брались из графа, где записано положение ВНУТРИ гекса, поэтому девять
## тайлов оказывались в одной точке. Теперь координаты приходят из
## BoardGeometry (арт гексов) и BoardSchematic (схема).
##
## Панель по-прежнему не знает правил: что подсвечивать, ей сообщает
## view["legal"], посчитанный сервером.
##
## Управление: колесо — масштаб, перетаскивание — сдвиг, двойной щелчок по
## пустому месту — вернуть обзор всей доски, H — схема / гексы.

signal slot_clicked(slot_id: String)
signal site_clicked(site_id: String)

const PLAYER_COLORS := {
	"red": Color(0.85, 0.22, 0.22),
	"blue": Color(0.25, 0.50, 0.90),
	"green": Color(0.28, 0.70, 0.34),
	"purple": Color(0.62, 0.35, 0.78),
}
const NEUTRAL_TROOP_COLOR := Color(0.55, 0.55, 0.58)
const EMPTY_SLOT_COLOR := Color(0.0, 0.0, 0.0, 0.45)
const DEPLOY_COLOR := Color(0.35, 0.95, 0.45)
const KILL_COLOR := Color(1.0, 0.55, 0.15)
## Подсветка целей текущего pending-решения (assassinate/supplant/move/
## return/place spy и т.п.) — выбор цели делается кликом по доске, а не
## кнопкой в диалоге (см. decision_dialog.gd, game_screen.gd).
const DECISION_COLOR := Color(0.95, 0.75, 0.15)

## Радиус кружка войска в МИРОВЫХ пикселях (печатные круги на арте примерно
## такого размера, шаг между слотами внутри локации ~47 px).
const SLOT_RADIUS_WORLD := 19.0
const ZOOM_MIN := 0.06
const ZOOM_MAX := 1.2
## The schematic is drawn at 1x pixels, so it zooms in much further.
const SCHEMATIC_ZOOM_MIN := 0.25
const SCHEMATIC_ZOOM_MAX := 6.0

var _board: Dictionary = {}
var _view: Dictionary = {}
var _viewer_id: String = ""
var _textures: Dictionary = {}   # hex_id -> Texture2D

var schematic_mode := true
var _schematic_texture: ImageTexture = null
var _tokens: Dictionary = {}     # colour html -> ImageTexture

var _zoom := 0.0                 # 0 = ещё не подобран, подберётся под размер панели
var _pan := Vector2.ZERO         # центр обзора в мировых координатах
var _dragging := false
var _drag_moved := false
var _drag_from := Vector2.ZERO
var _font: Font
var _user_moved := false         # игрок сам менял масштаб/сдвиг
var top_inset := 0.0


func _init() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = SchematicPainter.BG
	style.set_corner_radius_all(0)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(200, 120)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	# Подписи поверх доски — тем же пиксельным шрифтом, что и весь интерфейс.
	var pixel_font: Font = PixelTheme.theme().default_font
	_font = pixel_font if pixel_font != null else ThemeDB.fallback_font


func update_from_view(view: Dictionary, viewer_id: String, board: Dictionary) -> void:
	_view = view
	_viewer_id = viewer_id
	if board != _board:
		_board = board
		_load_textures()
		_zoom = 0.0  # новая доска — пересчитать обзор
	queue_redraw()


func _load_textures() -> void:
	_textures.clear()
	for tile: Dictionary in (_board.get("tiles", []) as Array):
		var hex_id := String(tile["hex_id"])
		if _textures.has(hex_id):
			continue
		var path := String(tile["texture"])
		if ResourceLoader.exists(path):
			_textures[hex_id] = load(path)
	_schematic_texture = null
	var schematic: Dictionary = _board.get("schematic", {})
	if not schematic.is_empty():
		var image := SchematicPainter.paint(schematic)
		image.generate_mipmaps()
		_schematic_texture = ImageTexture.create_from_image(image)


func _schematic_on() -> bool:
	return schematic_mode and _schematic_texture != null


func set_schematic_mode(on: bool) -> void:
	schematic_mode = on
	_zoom = 0.0
	_user_moved = false
	queue_redraw()


# --- что где лежит в текущем виде ---------------------------------------------

func _slots() -> Dictionary:
	if _schematic_on():
		return (_board["schematic"] as Dictionary).get("slots", {})
	return _board.get("slots", {})


func _slot_world(slot_id: String) -> Variant:
	var slots := _slots()
	if not slots.has(slot_id):
		return null
	return Vector2(float(slots[slot_id]["x"]), float(slots[slot_id]["y"]))


func _slot_radius_world() -> float:
	return BoardSchematic.SLOT_R + 0.5 if _schematic_on() else SLOT_RADIUS_WORLD


## Box of a site on the schematic, or null in hex view.
func _site_rect(site_id: String) -> Variant:
	if not _schematic_on():
		return null
	var site: Dictionary = ((_board["schematic"] as Dictionary).get("sites", {}) as Dictionary).get(site_id, {})
	if site.is_empty():
		return null
	var r: Array = site["rect"]
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


## Центр локации в мировых координатах (среднее её слотов) или null.
func _site_centre(site_id: String) -> Variant:
	var rect: Variant = _site_rect(site_id)
	if rect != null:
		return (rect as Rect2).get_center()
	var sites: Dictionary = _board.get("sites", {})
	if not sites.has(site_id):
		return null
	var centre := Vector2.ZERO
	var counted := 0
	for slot_id in ((sites[site_id] as Dictionary)["slots"] as Array):
		var at: Variant = _slot_world(String(slot_id))
		if at != null:
			centre += at
			counted += 1
	return centre / counted if counted > 0 else null


func _zoom_limits() -> Vector2:
	return Vector2(SCHEMATIC_ZOOM_MIN, SCHEMATIC_ZOOM_MAX) if _schematic_on() else Vector2(ZOOM_MIN, ZOOM_MAX)


# --- преобразование мир <-> экран --------------------------------------------

func _board_rect() -> Rect2:
	if _schematic_on():
		return Rect2(Vector2.ZERO, _schematic_texture.get_size())
	var tiles: Array = _board.get("tiles", [])
	if tiles.is_empty():
		return Rect2()
	var radius: float = float(_board.get("hex_radius_px", 254.0))
	var rect := Rect2(Vector2(float(tiles[0]["x"]), float(tiles[0]["y"])), Vector2.ZERO)
	for tile: Dictionary in tiles:
		var c := Vector2(float(tile["x"]), float(tile["y"]))
		rect = rect.expand(c - Vector2(radius, radius)).expand(c + Vector2(radius, radius))
	return rect


func _fit_zoom() -> float:
	var span := _board_rect().size
	if span.x <= 0.0 or span.y <= 0.0:
		return 0.2
	var limits := _zoom_limits()
	# Схема нарисована под то, чтобы влезать в зону доски целиком и читаться
	# без приближения. Поэтому сначала меряем по всей зоне: если помещается,
	# берём ЦЕЛЫЙ масштаб (пиксели остаются чёткими) и не ужимаем её из-за
	# плашки вопроса — она временная и полупрозрачная.
	if _schematic_on():
		var full := minf(size.x / span.x, size.y / span.y)
		if full >= 0.92:
			return clampf(maxf(floorf(full), 1.0), limits.x, limits.y)
	var fit := minf(size.x / span.x, maxf(size.y - top_inset, 100.0) / span.y)
	if _schematic_on() and fit >= 1.0:
		fit = floorf(fit)  # whole pixels stay crisp
	return clampf(fit, limits.x, limits.y)


func _board_centre() -> Vector2:
	return _board_rect().get_center()


func _ensure_view() -> void:
	if _zoom <= 0.0:
		_zoom = _fit_zoom()
		_pan = _board_centre()


## Центр видимой части: сверху её может занимать плашка решения (top_inset).
## Если схема и так помещается целиком, сдвигать её под плашку не нужно —
## иначе нижний край уезжает за пределы зоны.
func _view_centre() -> Vector2:
	var span_y := _board_rect().size.y * _zoom
	if span_y <= size.y:
		# Схема влезает целиком: сдвигаем её вниз из-под плашки ровно
		# настолько, насколько есть запас, и ни пикселем больше.
		return Vector2(size.x * 0.5,
			clampf((size.y + top_inset) * 0.5, span_y * 0.5, size.y - span_y * 0.5))
	return Vector2(size.x * 0.5, (size.y + top_inset) * 0.5)


## Сколько пикселей сверху закрыто плашкой решения. Пока обзор не трогали
## руками, доска заново вписывается в оставшееся место.
func set_top_inset(value: float) -> void:
	if is_equal_approx(value, top_inset):
		return
	top_inset = value
	if not _user_moved:
		_zoom = 0.0
	queue_redraw()


func _to_screen(world: Vector2) -> Vector2:
	return (world - _pan) * _zoom + _view_centre()


func _to_world(screen: Vector2) -> Vector2:
	return (screen - _view_centre()) / _zoom + _pan


# --- отрисовка ----------------------------------------------------------------

func _draw() -> void:
	if _board.is_empty():
		return
	_ensure_view()

	if _schematic_on():
		# pixel art: hard pixels when enlarged, smooth when shrunk below 1x
		var filter := TEXTURE_FILTER_NEAREST if _zoom >= 0.99 else TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if texture_filter != filter:
			texture_filter = filter
		var origin := _to_screen(Vector2.ZERO)
		draw_texture_rect(_schematic_texture, Rect2(origin, _schematic_texture.get_size() * _zoom), false)
	else:
		for tile: Dictionary in (_board.get("tiles", []) as Array):
			var texture: Texture2D = _textures.get(String(tile["hex_id"]))
			if texture == null:
				continue
			var centre := _to_screen(Vector2(float(tile["x"]), float(tile["y"])))
			# Рисуем в системе координат тайла: начало — геометрический центр
			# шестиугольника, поворот вокруг него же (вокруг начала координат арта
			# тайлы разъезжаются — claude/progress.md, ошибка 12).
			draw_set_transform(centre, deg_to_rad(float(tile["rotation_deg"])), Vector2(_zoom, _zoom))
			draw_texture(texture, -Vector2(float(tile["tex_centre_x"]), float(tile["tex_centre_y"])))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var slots := _slots()
	var troops: Dictionary = _view.get("troops", {})
	var legal: Dictionary = _view.get("legal", {})
	var deployable: Array = legal.get("deploy_slots", [])
	var killable: Array = legal.get("assassinate_slots", [])
	var radius: float = maxf(_slot_radius_world() * _zoom, 3.0)

	for slot_id: String in slots.keys():
		var pos := _to_screen(Vector2(float(slots[slot_id]["x"]), float(slots[slot_id]["y"])))
		if pos.x < -radius or pos.y < -radius or pos.x > size.x + radius or pos.y > size.y + radius:
			continue
		var owner := String(troops.get(slot_id, ""))
		# Пустое место ничем не рисуем: круги под войска уже есть на арте тайла
		# и на схеме. Куда можно ставить — показывает зелёная подсветка ниже.
		if owner != "":
			var colour: Color = NEUTRAL_TROOP_COLOR if owner == GameState.WHITE \
				else PLAYER_COLORS.get(owner, Color(0.6, 0.6, 0.6))
			if _schematic_on():
				var token := _token(colour)
				draw_texture_rect(token, Rect2(pos - token.get_size() * 0.5 * _zoom, token.get_size() * _zoom), false)
			else:
				draw_circle(pos, radius, Color(0, 0, 0, 0.75))
				draw_circle(pos, radius * 0.82, colour)

		if deployable.has(slot_id):
			draw_arc(pos, radius + 3.0, 0, TAU, 24, DEPLOY_COLOR, maxf(2.0, radius * 0.18))
		elif killable.has(slot_id):
			draw_arc(pos, radius + 3.0, 0, TAU, 24, KILL_COLOR, maxf(2.0, radius * 0.18))

	_draw_spies()
	_draw_spy_targets()
	_draw_decision_targets()
	_draw_hint()


func _token(colour: Color) -> ImageTexture:
	var key := colour.to_html()
	if not _tokens.has(key):
		_tokens[key] = ImageTexture.create_from_image(SchematicPainter.token(colour))
	return _tokens[key]


## Кольцо вокруг локации: на схеме — рамка вокруг её прямоугольника.
func _outline_site(site_id: String, colour: Color) -> void:
	var radius: float = maxf(_slot_radius_world() * _zoom, 3.0)
	var rect: Variant = _site_rect(site_id)
	if rect != null:
		var r := rect as Rect2
		var screen := Rect2(_to_screen(r.position), r.size * _zoom).grow(maxf(2.0, _zoom * 2.0))
		draw_rect(screen, colour, false, maxf(2.0, _zoom))
		return
	var centre: Variant = _site_centre(site_id)
	if centre != null:
		draw_arc(_to_screen(centre), radius * 2.4, 0, TAU, 32, colour, maxf(2.0, radius * 0.22))


## Шпионы стоят не в троп-слотах, а «у названия локации» (рулбук стр. 12),
## поэтому рисуем их ромбиками над локацией.
func _draw_spies() -> void:
	var spies: Dictionary = _view.get("spies", {})
	if spies.is_empty():
		return
	var radius: float = maxf(_slot_radius_world() * _zoom, 3.0)
	for site_id: String in spies.keys():
		var owners: Array = spies[site_id]
		var centre: Variant = _site_centre(site_id)
		if owners.is_empty() or centre == null:
			continue
		var pos := _to_screen(centre) - Vector2(0, radius * 2.2)
		var d := radius * 0.6
		var rect: Variant = _site_rect(site_id)
		if rect != null:
			# above the box, on the tunnel-free strip over its name
			d = maxf(4.0, _zoom * 4.0)
			pos = _to_screen(Vector2((rect as Rect2).get_center().x, (rect as Rect2).position.y)) - Vector2(0, d + 2.0)
		for i in range(owners.size()):
			var colour: Color = PLAYER_COLORS.get(String(owners[i]), Color(0.7, 0.7, 0.7))
			var at := pos + Vector2((i - (owners.size() - 1) * 0.5) * d * 2.4, 0)
			var diamond := PackedVector2Array([
				at + Vector2(0, -d), at + Vector2(d, 0), at + Vector2(0, d), at + Vector2(-d, 0)])
			draw_colored_polygon(diamond, colour)
			draw_polyline(diamond + PackedVector2Array([at + Vector2(0, -d)]), Color(0, 0, 0, 0.8), 1.5)


## Цели pending-решения (target_slot/target_site/target_return) подсвечиваются
## прямо на доске золотым кольцом — игрок выбирает клетку/локацию кликом, а не
## строкой в диалоге (см. decision_dialog.gd). target_return кодирует составные
## цели "troop|<slot_id>" и "spy|<site_id>|<owner>" — те же префиксы, что и в
## decision_dialog.gd::_board_label.
func _draw_decision_targets() -> void:
	var pending: Dictionary = _view.get("pending_decision", {})
	if pending.is_empty():
		return
	var choice_type := String(pending.get("choice_type", ""))
	if choice_type != "target_slot" and choice_type != "target_site" and choice_type != "target_return":
		return

	var slot_targets: Dictionary = {}
	var site_targets: Dictionary = {}
	for opt in (pending.get("legal_options", []) as Array):
		var raw := String(opt)
		if raw == "":
			continue
		if choice_type == "target_slot":
			slot_targets[raw] = true
		elif choice_type == "target_site":
			site_targets[raw] = true
		elif raw.begins_with("troop|"):
			slot_targets[raw.substr(6)] = true
		elif raw.begins_with("spy|"):
			var rest: PackedStringArray = raw.substr(4).rsplit("|", true, 1)
			if rest.size() == 2:
				site_targets[rest[0]] = true

	var radius: float = maxf(_slot_radius_world() * _zoom, 3.0)
	for slot_id: String in slot_targets.keys():
		var at: Variant = _slot_world(slot_id)
		if at != null:
			draw_arc(_to_screen(at), radius + 3.0, 0, TAU, 24, DECISION_COLOR, maxf(2.0, radius * 0.2))
	for site_id: String in site_targets.keys():
		_outline_site(site_id, DECISION_COLOR)


## Вражеские шпионы, которых можно вернуть за 3 Power, — оранжевой рамкой
## вокруг локации (раньше их ничем не выделяли, и действие было не найти).
func _draw_spy_targets() -> void:
	var targets: Array = (_view.get("legal", {}) as Dictionary).get("return_spy", [])
	for t in targets:
		_outline_site(String((t as Dictionary)["site_id"]), KILL_COLOR)


func _draw_hint() -> void:
	# Схема занимает зону целиком, поэтому подсказка про управление больше не
	# рисуется поверх неё, а живёт во всплывающей подсказке зоны.
	tooltip_text = "Wheel: zoom · drag: pan · double-click: fit the board\nH: %s · Alt over a card: enlarge it" % (
		"hex tiles" if _schematic_on() else "schematic map")

	# Легенда колец — только те цвета, что сейчас есть на доске.
	var legal: Dictionary = _view.get("legal", {})
	var entries: Array = []
	var pending_type := String((_view.get("pending_decision", {}) as Dictionary).get("choice_type", ""))
	if DecisionDialog.BOARD_CHOICES.has(pending_type):
		entries.append([DECISION_COLOR, "card target"])
	if not (legal.get("deploy_slots", []) as Array).is_empty():
		entries.append([DEPLOY_COLOR, "Deploy 1P"])
	if not (legal.get("assassinate_slots", []) as Array).is_empty() \
			or not (legal.get("return_spy", []) as Array).is_empty():
		entries.append([KILL_COLOR, "Kill/spy 3P"])
	# Легенда лежит поверх схемы, поэтому под ней — тёмная полоса, иначе
	# подписи сливаются с рамками локаций.
	var at := Vector2(3, size.y - 3)
	var legend_w := 0.0
	for entry in entries:
		legend_w += 14 + _font.get_string_size(
			String(entry[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, PixelTheme.SIZE).x
	if legend_w > 0.0:
		draw_rect(Rect2(0, size.y - 11, legend_w + 2, 11), Color(PixelTheme.BG, 0.85))
	for entry in entries:
		draw_arc(at + Vector2(3, -3), 3.0, 0, TAU, 12, entry[0], 1.0)
		draw_string(_font, at + Vector2(9, 0), String(entry[1]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, PixelTheme.SIZE, PixelTheme.TEXT)
		at.x += 14 + _font.get_string_size(
			String(entry[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, PixelTheme.SIZE).x


## Навести обзор на точку доски с заданным масштабом. Нужно интерфейсу
## (например, показать место, где что-то произошло) и проверкам скриншотами.
func focus_on(world_point: Vector2, zoom_level: float) -> void:
	var limits := _zoom_limits()
	_zoom = clampf(zoom_level, limits.x, limits.y)
	_pan = world_point
	queue_redraw()


# --- ввод ---------------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_H and is_visible_in_tree():
		set_schematic_mode(not schematic_mode)
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_zoom_at(mb.position, 1.15)
				accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_zoom_at(mb.position, 1.0 / 1.15)
				accept_event()
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					if mb.double_click:
						_zoom = 0.0  # вернуть обзор всей доски
						_user_moved = false
						queue_redraw()
						accept_event()
						return
					_dragging = true
					_drag_moved = false
					_drag_from = mb.position
				else:
					_dragging = false
					if not _drag_moved:
						_click_at(mb.position)
					accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		if mm.position.distance_to(_drag_from) > 4.0:
			_drag_moved = true
		_pan -= mm.relative / _zoom
		_user_moved = true
		queue_redraw()
		accept_event()


func _zoom_at(screen_point: Vector2, factor: float) -> void:
	_ensure_view()
	_user_moved = true
	var before := _to_world(screen_point)
	var limits := _zoom_limits()
	_zoom = clampf(_zoom * factor, limits.x, limits.y)
	# точка под курсором должна остаться на месте
	_pan += before - _to_world(screen_point)
	queue_redraw()


## Попадание по ближайшему слоту, а если рядом слота нет — по локации
## (клик по локации нужен, чтобы вернуть вражеского шпиона).
func _click_at(screen_point: Vector2) -> void:
	var slots := _slots()
	var reach: float = maxf(_slot_radius_world() * _zoom * 1.4, 10.0)
	var best := ""
	var best_dist := reach
	for slot_id: String in slots.keys():
		var pos := _to_screen(Vector2(float(slots[slot_id]["x"]), float(slots[slot_id]["y"])))
		var d := screen_point.distance_to(pos)
		if d < best_dist:
			best_dist = d
			best = slot_id
	if best != "":
		slot_clicked.emit(best)
		return

	var sites: Dictionary = _board.get("sites", {})
	var world := _to_world(screen_point)
	var best_site := ""
	var best_site_dist: float = maxf(_slot_radius_world() * _zoom * 3.0, 24.0)
	for site_id: String in sites.keys():
		var rect: Variant = _site_rect(site_id)
		if rect != null:
			if (rect as Rect2).grow(2.0).has_point(world):
				best_site = site_id
				break
			continue
		var centre: Variant = _site_centre(site_id)
		if centre == null:
			continue
		var d2 := screen_point.distance_to(_to_screen(centre))
		if d2 < best_site_dist:
			best_site_dist = d2
			best_site = site_id
	if best_site != "":
		site_clicked.emit(best_site)
