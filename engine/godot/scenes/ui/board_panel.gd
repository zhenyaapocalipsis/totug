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
## Доска зафиксирована (решение владельца, 2026-09-19): ни масштаба колесом,
## ни перетаскивания, ни переключения вида. Она сама вписывается в отведённую
## зону и остаётся в ней, а мышь нужна только чтобы выбрать войско или локацию.
##
## Масштаб схемы подбирается не «как влезет», а так, чтобы один её пиксель
## занимал ЦЕЛОЕ число экранных (см. _fit_zoom). Иначе картинка мылилась:
## экран 960x540 растягивается на окно вдвое, и дробный масштаб размывал бы
## и трассы, и подписи локаций.

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

## Доска дёргается, когда на ней что-то случилось: убили войско, вытеснили
## чужое, захватили локацию. Дёргается ОТРИСОВКА (вся картинка целиком), а не
## узел: панель обрезает содержимое по себе, клики считаются по неподвижным
## координатам, а раскладку экрана тряска не трогает вовсе.
const SHAKE_TIME := 0.32
const SHAKE_FREQ := 52.0

## Искры: из точки события разлетаются несколько квадратиков, падают и гаснут.
## Квадратики целого размера и на целых координатах — иначе на пиксельной
## схеме они расплываются в грязь.
const SPARK_COUNT := 9
const SPARK_LIFE := 0.55
const SPARK_SPEED := 85.0
const SPARK_GRAVITY := 150.0

## Локация сменила хозяина — её обводка коротко вспыхивает в цвет захватчика.
## Отдельного события «захват» движок не шлёт: контроль пересчитывается из
## расстановки войск, поэтому панель сравнивает site_control с прошлым видом.
const CAPTURE_TIME := 1.2

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
var top_inset := 0.0

var _shake_left := 0.0
var _shake_power := 0.0          # амплитуда тряски в пикселях панели
## Кто чем владел в прошлый раз (site_id -> player_id) и что сейчас вспыхивает
## (site_id -> сколько ещё гореть).
var _control: Dictionary = {}
var _control_known := false
var _captures: Dictionary = {}
## Летящие искры: pos и vel в координатах панели, не в мировых — живут они
## доли секунды, и доска за это время никуда не уедет.
var _sparks: Array[Dictionary] = []


func _init() -> void:
	var style := StyleBoxFlat.new()
	# Подложка прозрачная: за доской видно живой фон экрана.
	style.bg_color = Color(SchematicPainter.BG, 0.0)
	style.set_corner_radius_all(0)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(200, 120)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	set_process(false)


func update_from_view(view: Dictionary, viewer_id: String, board: Dictionary) -> void:
	_view = view
	_viewer_id = viewer_id
	if board != _board:
		_board = board
		_load_textures()
		_zoom = 0.0  # новая доска — пересчитать обзор
	_note_captures(view.get("site_control", {}))
	queue_redraw()


## Сравнивает, кто владеет локациями, с прошлым видом: сменившие хозяина
## вспыхивают, доска коротко дёргается. Самый первый вид ничего не зажигает —
## это не захват, а стартовая расстановка.
func _note_captures(control: Dictionary) -> void:
	if not _control_known:
		_control = control.duplicate()
		_control_known = true
		return
	var captured := false
	var taken: Array[String] = []
	for site_id: String in control:
		if String(_control.get(site_id, "")) != String(control[site_id]):
			_captures[site_id] = CAPTURE_TIME
			taken.append(site_id)
			captured = true
	_control = control.duplicate()
	for site_id in taken:
		spark_at_site(site_id, PLAYER_COLORS.get(String(control[site_id]), Color(0.8, 0.8, 0.8)))
	if captured:
		shake(3.0)
		set_process(true)


## Искры из места войска — туда, где его убили или вытеснили.
func spark_at_slot(slot_id: String, colour: Color) -> void:
	var at: Variant = _slot_world(slot_id)
	if at != null:
		_burst(_to_screen(at), colour)


## Искры из середины локации — её только что захватили.
func spark_at_site(site_id: String, colour: Color) -> void:
	var centre: Variant = _site_centre(site_id)
	if centre != null:
		_burst(_to_screen(centre), colour)


func _burst(at: Vector2, colour: Color) -> void:
	for i in range(SPARK_COUNT):
		var angle := TAU * i / SPARK_COUNT + randf() * 0.5
		var speed := SPARK_SPEED * (0.5 + randf() * 0.8)
		var life := SPARK_LIFE * (0.7 + randf() * 0.5)
		_sparks.append({
			"pos": at,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"left": life,
			"life": life,
			"colour": colour,
		})
	set_process(true)
	queue_redraw()


## Для проверок: сколько искр сейчас в полёте.
func spark_count() -> int:
	return _sparks.size()


## Для проверок: сколько локаций сейчас вспыхивает захватом.
func capture_flashes() -> int:
	return _captures.size()


## Для проверок: доска сейчас трясётся.
func is_shaking() -> bool:
	return _shake_left > 0.0


## Тряхнуть доску: power — амплитуда в пикселях панели.
func shake(power: float) -> void:
	_shake_power = maxf(_shake_power * (_shake_left / SHAKE_TIME), power)
	_shake_left = SHAKE_TIME
	set_process(true)


func _process(delta: float) -> void:
	_shake_left = maxf(_shake_left - delta, 0.0)
	for site_id: String in _captures.keys():
		var left: float = float(_captures[site_id]) - delta
		if left <= 0.0:
			_captures.erase(site_id)
		else:
			_captures[site_id] = left
	for i in range(_sparks.size() - 1, -1, -1):
		var s: Dictionary = _sparks[i]
		s["left"] = float(s["left"]) - delta
		if float(s["left"]) <= 0.0:
			_sparks.remove_at(i)
			continue
		var vel: Vector2 = (s["vel"] as Vector2) + Vector2(0, SPARK_GRAVITY) * delta
		s["vel"] = vel
		s["pos"] = (s["pos"] as Vector2) + vel * delta

	if _shake_left <= 0.0 and _captures.is_empty() and _sparks.is_empty():
		set_process(false)
	queue_redraw()


## Смещение всей картинки доски при тряске. Только целые пиксели: на дробном
## сдвиге пиксельная схема мылится.
func _shake_offset() -> Vector2:
	if _shake_left <= 0.0:
		return Vector2.ZERO
	var k := _shake_left / SHAKE_TIME
	var a := _shake_power * k * k
	return Vector2(
		roundf(sin(_shake_left * SHAKE_FREQ) * a),
		roundf(cos(_shake_left * SHAKE_FREQ * 1.37) * a * 0.7))


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
		# Без пустых полей картинки (IMAGE_MARGIN): доска на четверых бывает на
		# пару пикселей шире зоны, и из-за полей её ужимало бы вдвое. Поля же
		# пусть лучше уйдут за край — зона доски их обрезает.
		return Rect2(Vector2.ZERO, _schematic_texture.get_size()) \
			.grow(-float(BoardSchematic.IMAGE_MARGIN))
	var tiles: Array = _board.get("tiles", [])
	if tiles.is_empty():
		return Rect2()
	var radius: float = float(_board.get("hex_radius_px", 254.0))
	var rect := Rect2(Vector2(float(tiles[0]["x"]), float(tiles[0]["y"])), Vector2.ZERO)
	for tile: Dictionary in tiles:
		var c := Vector2(float(tile["x"]), float(tile["y"]))
		rect = rect.expand(c - Vector2(radius, radius)).expand(c + Vector2(radius, radius))
	return rect


## Во сколько раз окно растягивает расчётный экран 960x540. Игра стартует в
## полный экран на 1920x1080, то есть обычно это 2; в окне 960x540 — 1.
func window_scale() -> float:
	var vp := get_viewport()
	if vp == null:
		return 1.0
	var scale: float = vp.get_final_transform().get_scale().x
	return maxf(roundf(scale), 1.0)


## Масштаб схемы: самый крупный из тех, при которых один пиксель схемы
## занимает ЦЕЛОЕ число экранных пикселей и вся доска ещё влезает в зону.
## При растяжении окна вдвое это шаги 1/2: схема на четверых идёт 1:1, схема
## на двоих и троих — тоже 1:1 (до 1,5 им не хватает места), и каждый её
## пиксель ложится ровно в два экранных и остаётся чётким.
func _fit_zoom() -> float:
	var span := _board_rect().size
	if span.x <= 0.0 or span.y <= 0.0:
		return 0.2
	var limits := _zoom_limits()
	var fit := minf(size.x / span.x, size.y / span.y)
	if not _schematic_on():
		return clampf(fit, limits.x, limits.y)
	var scale := window_scale()
	var steps := floori(fit * scale + 0.001)
	if steps >= 1:
		return clampf(float(steps) / scale, limits.x, limits.y)
	# Окно меньше самой схемы (расчётный размер один к одному): показываем
	# её целиком — пусть мягко, но без обрезанных краёв.
	return clampf(fit, limits.x, limits.y)


func _board_centre() -> Vector2:
	return _board_rect().get_center()


func _ensure_view() -> void:
	if _zoom <= 0.0:
		_zoom = _fit_zoom()
		# Центр обзора — в целых мировых пикселях: тогда и войска, и рамки
		# локаций ложатся на ту же сетку, что и сама картинка схемы.
		_pan = _board_centre().round()


## Центр видимой части: сверху её может занимать плашка решения (top_inset).
## Если схема и так помещается целиком, сдвигать её под плашку не нужно —
## иначе нижний край уезжает за пределы зоны.
func _view_centre() -> Vector2:
	var span_y := _board_rect().size.y * _zoom
	var centre := Vector2(size.x * 0.5, (size.y + top_inset) * 0.5)
	if span_y <= size.y:
		# Схема влезает целиком: сдвигаем её вниз из-под плашки ровно
		# настолько, насколько есть запас, и ни пикселем больше.
		centre.y = clampf(centre.y, span_y * 0.5, size.y - span_y * 0.5)
	# Центр кладём на сетку ЭКРАННЫХ пикселей: иначе схема съезжает на треть
	# пикселя и nearest рисует соседние ряды разной толщины.
	var scale := window_scale()
	return (centre * scale).round() / scale


## Сколько пикселей сверху закрыто плашкой решения. Масштаб от этого не
## меняется (доска зафиксирована) — она лишь сдвигается вниз на свободное
## место, если оно есть.
func set_top_inset(value: float) -> void:
	if is_equal_approx(value, top_inset):
		return
	top_inset = value
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

	# Вся доска рисуется со смещением тряски: дальше координаты считаются как
	# обычно, и ни один расчёт о тряске не знает.
	var shake := _shake_offset()
	if shake != Vector2.ZERO:
		draw_set_transform(shake)

	if _schematic_on():
		# Пиксель-арт: пока пиксель схемы занимает целое число экранных,
		# рисуем nearest — «жёсткими» квадратами. Мягкий фильтр остаётся
		# только для запасного случая (окно меньше самой схемы).
		var scale := window_scale()
		var steps := _zoom * scale
		var crisp: bool = absf(steps - roundf(steps)) < 0.01
		var filter := TEXTURE_FILTER_NEAREST if crisp else TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if texture_filter != filter:
			texture_filter = filter
		var origin := _to_screen(Vector2.ZERO)
		origin = (origin * scale).round() / scale
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
			draw_set_transform(centre + shake, deg_to_rad(float(tile["rotation_deg"])), Vector2(_zoom, _zoom))
			draw_texture(texture, -Vector2(float(tile["tex_centre_x"]), float(tile["tex_centre_y"])))
		draw_set_transform(shake, 0.0, Vector2.ONE)

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
			_mark_slot(pos, DEPLOY_COLOR, owner != "")
		elif killable.has(slot_id):
			_mark_slot(pos, KILL_COLOR, owner != "")

	_draw_spies()
	_draw_spy_targets()
	_draw_decision_targets()
	_draw_captures()
	_draw_sparks()


## Искры рисуются последними — поверх войск и подсветок. Пока искра молодая,
## она в два пикселя, дальше — в один.
func _draw_sparks() -> void:
	# Размер искры считается в пикселях СХЕМЫ: когда доска приближена, её
	# пиксель занимает несколько экранных, и искра должна расти вместе с ней.
	var unit: float = maxf(1.0, roundf(_zoom))
	for s in _sparks:
		var k: float = float(s["left"]) / float(s["life"])
		var side: float = unit * (2.0 if k > 0.45 else 1.0)
		draw_rect(Rect2((s["pos"] as Vector2).round(), Vector2(side, side)),
			Color((s["colour"] as Color).lightened(0.2), k))


## Только что захваченные локации: обводка в цвет нового хозяина, гаснущая
## вместе со вспышкой. Толщина в два пикселя — обводка выбора цели рисуется
## в один, и их не спутать.
func _draw_captures() -> void:
	for site_id: String in _captures:
		var owner := String(_control.get(site_id, ""))
		var colour: Color = PLAYER_COLORS.get(owner, Color(0.8, 0.8, 0.8))
		var k: float = float(_captures[site_id]) / CAPTURE_TIME
		_outline_site(site_id, Color(colour.lightened(0.25), k))


## Радиус кольца подсветки на схеме, в мировых пикселях: по самому кружку
## места, а вокруг фишки — на полпикселя шире (кружок 9 px при шаге 9).
## Больше делать нельзя: шаг между
## местами BoardSchematic.SLOT_PITCH, и кольца соседей начнут пересекаться
## (проверяется тестом).
static func highlight_radius_world(occupied: bool) -> float:
	return BoardSchematic.SLOT_R + (0.5 if occupied else 0.0)


## Подсветка одного места: пустое — бледной «заготовкой» войска внутри самого
## кружка, занятое — тонким кольцом вплотную вокруг фишки.
##
## Раньше вокруг каждого места рисовалась окружность радиусом слот+3 px. Шаг
## между местами на схеме — 10 px, поэтому в локации с восемью местами (Wells
## of Darkness) кольца налезали друг на друга и превращались в зелёное месиво,
## закрывавшее название локации. Теперь подсветка не выходит за половину шага,
## а её линия ложится на целые экранные пиксели — как и вся остальная схема.
func _mark_slot(pos: Vector2, colour: Color, occupied: bool) -> void:
	var scale := window_scale()
	var at := (pos * scale).round() / scale
	var width: float
	var r: float
	if _schematic_on():
		width = maxf(1.0, roundf(_zoom))
		r = highlight_radius_world(occupied) * _zoom
	else:
		r = _slot_radius_world() * _zoom * (1.18 if occupied else 1.0)
		width = maxf(2.0, r * 0.16)
	# Пустое место лишь слегка подкрашиваем: если залить его ярко, оно будет
	# неотличимо от фишки зелёного игрока.
	if not occupied:
		draw_circle(at, maxf(r - width * 0.5, 1.0), Color(colour, 0.22))
	draw_arc(at, r, 0, TAU, 24, colour, width)


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
		# Рамка идёт по целым экранным пикселям и отступает от коробки ровно на
		# свою толщину — иначе линия «плывёт» и местами двоится.
		var scale := window_scale()
		var width: float = maxf(1.0, roundf(_zoom))
		var top_left := (_to_screen(r.position) * scale).round() / scale
		var bottom_right := (_to_screen(r.end) * scale).round() / scale
		draw_rect(Rect2(top_left, bottom_right - top_left).grow(width), colour, false, width)
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

	var troops: Dictionary = _view.get("troops", {})
	for slot_id: String in slot_targets.keys():
		var at: Variant = _slot_world(slot_id)
		if at != null:
			_mark_slot(_to_screen(at), DECISION_COLOR, String(troops.get(slot_id, "")) != "")
	for site_id: String in site_targets.keys():
		_outline_site(site_id, DECISION_COLOR)


## Вражеские шпионы, которых можно вернуть за 3 Power, — оранжевой рамкой
## вокруг локации (раньше их ничем не выделяли, и действие было не найти).
func _draw_spy_targets() -> void:
	var targets: Array = (_view.get("legal", {}) as Dictionary).get("return_spy", [])
	for t in targets:
		_outline_site(String((t as Dictionary)["site_id"]), KILL_COLOR)


## Навести обзор на точку доски с заданным масштабом. Нужно интерфейсу
## (например, показать место, где что-то произошло) и проверкам скриншотами.
func focus_on(world_point: Vector2, zoom_level: float) -> void:
	var limits := _zoom_limits()
	_zoom = clampf(zoom_level, limits.x, limits.y)
	_pan = world_point
	queue_redraw()


# --- ввод ---------------------------------------------------------------------

## Размер зоны изменился (окно, полноэкранный режим) — доску вписываем заново.
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_zoom = 0.0
		queue_redraw()


## Единственное действие мышью: выбрать войско или локацию. Масштаба и
## перетаскивания у зафиксированной доски нет.
func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		_click_at(mb.position)
		accept_event()


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
