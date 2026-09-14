class_name BoardPanel
extends PanelContainer

## Доска: настоящие тайлы с их поворотами, поверх — войска, шпионы и подсветка
## доступных целей.
##
## До этого доска рисовалась схемой из кружков и была нечитаемой: игрок не
## видел ни поворотов гексов, ни локаций, ни туннелей, и всё накладывалось
## друг на друга. Накладывалось не из-за схемы — координаты слотов брались из
## графа, где записано положение ВНУТРИ гекса, поэтому девять тайлов
## оказывались в одной точке. Теперь координаты приходят из BoardGeometry
## (мировые пиксели), а под слотами лежит тот же арт, что и в просмотрщике
## доски этапа 1.
##
## Панель по-прежнему не знает правил: что подсвечивать, ей сообщает
## view["legal"], посчитанный сервером.
##
## Управление: колесо — масштаб, перетаскивание — сдвиг, двойной щелчок по
## пустому месту — вернуть обзор всей доски.

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

var _board: Dictionary = {}
var _view: Dictionary = {}
var _viewer_id: String = ""
var _textures: Dictionary = {}   # hex_id -> Texture2D

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
	style.bg_color = Color(0.05, 0.05, 0.07)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(520, 300)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_font = ThemeDB.fallback_font


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


# --- преобразование мир <-> экран --------------------------------------------

func _fit_zoom() -> float:
	var tiles: Array = _board.get("tiles", [])
	if tiles.is_empty():
		return 0.2
	var radius: float = float(_board.get("hex_radius_px", 254.0))
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for tile: Dictionary in tiles:
		var c := Vector2(float(tile["x"]), float(tile["y"]))
		min_p = min_p.min(c - Vector2(radius, radius))
		max_p = max_p.max(c + Vector2(radius, radius))
	var span: Vector2 = max_p - min_p
	if span.x <= 0.0 or span.y <= 0.0:
		return 0.2
	return minf(size.x / span.x, maxf(size.y - top_inset, 100.0) / span.y)


func _board_centre() -> Vector2:
	var tiles: Array = _board.get("tiles", [])
	if tiles.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for tile: Dictionary in tiles:
		sum += Vector2(float(tile["x"]), float(tile["y"]))
	return sum / tiles.size()


func _ensure_view() -> void:
	if _zoom <= 0.0:
		_zoom = _fit_zoom()
		_pan = _board_centre()


## Центр видимой части: сверху её может занимать плашка решения (top_inset).
func _view_centre() -> Vector2:
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

	var slots: Dictionary = _board.get("slots", {})
	var troops: Dictionary = _view.get("troops", {})
	var legal: Dictionary = _view.get("legal", {})
	var deployable: Array = legal.get("deploy_slots", [])
	var killable: Array = legal.get("assassinate_slots", [])
	var radius: float = maxf(SLOT_RADIUS_WORLD * _zoom, 3.0)

	for slot_id: String in slots.keys():
		var slot: Dictionary = slots[slot_id]
		var pos := _to_screen(Vector2(float(slot["x"]), float(slot["y"])))
		if pos.x < -radius or pos.y < -radius or pos.x > size.x + radius or pos.y > size.y + radius:
			continue
		var owner := String(troops.get(slot_id, ""))
		if owner == "":
			# Пустое место ничем не рисуем: круги под войска и так напечатаны
			# на арте тайла, а закрашенная точка поверх них читалась как будто
			# место занято чем-то чёрным. Куда можно ставить — показывает
			# зелёная подсветка ниже.
			pass
		else:
			var colour: Color = NEUTRAL_TROOP_COLOR if owner == GameState.WHITE \
				else PLAYER_COLORS.get(owner, Color(0.6, 0.6, 0.6))
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


## Шпионы стоят не в троп-слотах, а «у названия локации» (рулбук стр. 12),
## поэтому рисуем их ромбиками над центром локации.
func _draw_spies() -> void:
	var spies: Dictionary = _view.get("spies", {})
	if spies.is_empty():
		return
	var sites: Dictionary = _board.get("sites", {})
	var slots: Dictionary = _board.get("slots", {})
	var radius: float = maxf(SLOT_RADIUS_WORLD * _zoom, 3.0)
	for site_id: String in spies.keys():
		var owners: Array = spies[site_id]
		if owners.is_empty() or not sites.has(site_id):
			continue
		var members: Array = (sites[site_id] as Dictionary)["slots"]
		if members.is_empty():
			continue
		var centre := Vector2.ZERO
		var counted := 0
		for slot_id in members:
			if slots.has(slot_id):
				centre += Vector2(float(slots[slot_id]["x"]), float(slots[slot_id]["y"]))
				counted += 1
		if counted == 0:
			continue
		var pos := _to_screen(centre / counted) - Vector2(0, radius * 2.2)
		for i in range(owners.size()):
			var colour: Color = PLAYER_COLORS.get(String(owners[i]), Color(0.7, 0.7, 0.7))
			var at := pos + Vector2((i - (owners.size() - 1) * 0.5) * radius * 1.4, 0)
			var d := radius * 0.6
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

	var slots: Dictionary = _board.get("slots", {})
	var radius: float = maxf(SLOT_RADIUS_WORLD * _zoom, 3.0)
	for slot_id: String in slot_targets.keys():
		if not slots.has(slot_id):
			continue
		var pos := _to_screen(Vector2(float(slots[slot_id]["x"]), float(slots[slot_id]["y"])))
		draw_arc(pos, radius + 3.0, 0, TAU, 24, DECISION_COLOR, maxf(2.0, radius * 0.2))

	var sites: Dictionary = _board.get("sites", {})
	for site_id: String in site_targets.keys():
		if not sites.has(site_id):
			continue
		var members: Array = (sites[site_id] as Dictionary)["slots"]
		var centre := Vector2.ZERO
		var counted := 0
		for slot_id: String in members:
			if slots.has(slot_id):
				centre += Vector2(float(slots[slot_id]["x"]), float(slots[slot_id]["y"]))
				counted += 1
		if counted == 0:
			continue
		var pos := _to_screen(centre / counted)
		draw_arc(pos, radius * 2.4, 0, TAU, 32, DECISION_COLOR, maxf(2.0, radius * 0.22))


## Вражеские шпионы, которых можно вернуть за 3 Power, — оранжевым кольцом
## вокруг локации (раньше их ничем не выделяли, и действие было не найти).
func _draw_spy_targets() -> void:
	var targets: Array = (_view.get("legal", {}) as Dictionary).get("return_spy", [])
	var radius: float = maxf(SLOT_RADIUS_WORLD * _zoom, 3.0)
	for t in targets:
		var centre: Variant = _site_centre(String((t as Dictionary)["site_id"]))
		if centre != null:
			draw_arc(_to_screen(centre), radius * 2.4, 0, TAU, 32, KILL_COLOR, maxf(2.0, radius * 0.22))


## Центр локации в мировых координатах (среднее её слотов) или null.
func _site_centre(site_id: String) -> Variant:
	var sites: Dictionary = _board.get("sites", {})
	var slots: Dictionary = _board.get("slots", {})
	if not sites.has(site_id):
		return null
	var centre := Vector2.ZERO
	var counted := 0
	for slot_id in ((sites[site_id] as Dictionary)["slots"] as Array):
		if slots.has(slot_id):
			centre += Vector2(float(slots[slot_id]["x"]), float(slots[slot_id]["y"]))
			counted += 1
	return centre / counted if counted > 0 else null


func _draw_hint() -> void:
	var text := "wheel: zoom · drag: pan · double-click: fit board"
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(_font, Vector2(size.x - width - 8, size.y - 8), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.6, 0.66, 0.7))

	# Легенда колец — только те цвета, что сейчас есть на доске.
	var legal: Dictionary = _view.get("legal", {})
	var entries: Array = []
	var pending_type := String((_view.get("pending_decision", {}) as Dictionary).get("choice_type", ""))
	if DecisionDialog.BOARD_CHOICES.has(pending_type):
		entries.append([DECISION_COLOR, "card target"])
	if not (legal.get("deploy_slots", []) as Array).is_empty():
		entries.append([DEPLOY_COLOR, "Deploy (1 Power)"])
	if not (legal.get("assassinate_slots", []) as Array).is_empty() \
			or not (legal.get("return_spy", []) as Array).is_empty():
		entries.append([KILL_COLOR, "Assassinate / return spy (3 Power)"])
	var at := Vector2(12, size.y - 12)
	for entry in entries:
		draw_arc(at + Vector2(6, -5), 6.0, 0, TAU, 16, entry[0], 2.5)
		draw_string(_font, at + Vector2(18, 0), String(entry[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.9, 0.9, 0.92))
		at.x += 30 + _font.get_string_size(String(entry[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x


## Навести обзор на точку доски с заданным масштабом. Нужно интерфейсу
## (например, показать место, где что-то произошло) и проверкам скриншотами.
func focus_on(world_point: Vector2, zoom_level: float) -> void:
	_zoom = clampf(zoom_level, ZOOM_MIN, ZOOM_MAX)
	_pan = world_point
	queue_redraw()


# --- ввод ---------------------------------------------------------------------

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
	_zoom = clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	# точка под курсором должна остаться на месте
	_pan += before - _to_world(screen_point)
	queue_redraw()


## Попадание по ближайшему слоту, а если рядом слота нет — по локации
## (клик по локации нужен, чтобы вернуть вражеского шпиона).
func _click_at(screen_point: Vector2) -> void:
	var slots: Dictionary = _board.get("slots", {})
	var reach: float = maxf(SLOT_RADIUS_WORLD * _zoom * 1.4, 10.0)
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
	var best_site := ""
	var best_site_dist: float = maxf(SLOT_RADIUS_WORLD * _zoom * 3.0, 24.0)
	for site_id: String in sites.keys():
		var members: Array = (sites[site_id] as Dictionary)["slots"]
		if members.is_empty():
			continue
		var centre := Vector2.ZERO
		var counted := 0
		for slot_id in members:
			if slots.has(slot_id):
				centre += Vector2(float(slots[slot_id]["x"]), float(slots[slot_id]["y"]))
				counted += 1
		if counted == 0:
			continue
		var d2 := screen_point.distance_to(_to_screen(centre / counted))
		if d2 < best_site_dist:
			best_site_dist = d2
			best_site = site_id
	if best_site != "":
		site_clicked.emit(best_site)
