class_name LootBoxReveal
extends Control

## Раскрытие лутбокса (Loot-1, решение владельца, 2026-10-06): экран затемняется,
## сундук трясётся, три плашки EPIC / LEGENDARY / ULTRA перебираются всё
## медленнее и замирают на выпавшей ступени, вспышка цвета ступени, сундук
## распахивается, и вылетает награда: арт карты, образ-шейдер на карте или пыль.
##
## Результаты уже записаны в профиль (SkinCollection.open_box) — оверлей только
## показывает их, закрыть его можно в любой миг. Один лутбокс — показ с кнопкой
## OK (и OPEN NEXT, если боксы остались). Несколько (OPEN ALL) — боксы идут один
## за другим вдвое быстрее, затем итоговая сетка наград; SKIP сразу к ней.
##
## Пиксельное правило: карта — всегда 1:1 (CardView.PIXEL_SIZE), сундук рисуется
## квадратами по 8 пикселей.

## Окно закрыто; again — игрок хочет открыть следующий лутбокс.
signal closed(again: bool)

const SHAKE_TIME := 0.8
const ROLL_TIME := 1.5
const FLASH_TIME := 0.16
const RISE_TIME := 0.3
const BATCH_SHOW_TIME := 0.9
const BATCH_SPEED := 2.0
const DIM_SPEED := 5.0
## Рулетка: ROLL_TICKS переключений (с поправкой, чтобы остановиться на выпавшей
## ступени), интервалы растут как t^ROLL_POWER.
const ROLL_TICKS := 12
const ROLL_POWER := 1.6
const GLOW_TIME_EPIC := 0.45
const PARTICLES := 28
const PARTICLE_LIFE := 1.0
const PIXEL := 8.0
const SCREEN := Vector2(960, 540)
const SLOT_SIZE := Vector2(120, 22)
const SLOT_GAP := 8.0
const BUTTON_SIZE := Vector2(90, 18)
const CELL_WIDTH := 104.0
const SUMMARY_MAX_HEIGHT := 360.0
## До стольких наград в итоге показываются мелкие карты, дальше — только строки.
const SUMMARY_THUMBS := 10

var _results: Array[Dictionary] = []
## Сколько лутбоксов ещё осталось в профиле (для OPEN NEXT).
var _left := 0
## Карта, на которой показывается шейдер (любимая).
var _card := ""
var _index := 0
var _phase := ""
var _t := 0.0
var _speed := 1.0
var _dim := 0.0
var _flash := 0.0
var _burst := 0.0
var _tick := 0
var _particles: Array[Dictionary] = []
var _warm: Array[Texture2D] = []
var _title: Label
var _sub: Label
var _slots: Array[Label] = []
var _skip_button: Button
var _ok_button: Button
var _again_button: Button
var _layer: CardLayer
var _scroll: ScrollContainer


## Слой карты-награды: рисует её тем, что решит оверлей (_draw_card); на нём
## материал шейдера, если выпал шейдер.
class CardLayer extends Control:
	var host: LootBoxReveal

	func _init(reveal: LootBoxReveal) -> void:
		host = reveal
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		host._draw_card(self)


func _init() -> void:
	top_level = true
	position = Vector2.ZERO
	size = SCREEN
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_layer = CardLayer.new(self)
	_layer.size = SCREEN
	add_child(_layer)
	_title = _label(PixelTheme.TEXT, PixelTheme.SIZE_BIG)
	_sub = _label(PixelTheme.TEXT_DIM)
	for i in SkinCollection.TIERS.size():
		var slot := _label(PixelTheme.TEXT_DIM)
		slot.text = String(SkinCollection.TIER_TITLES[SkinCollection.TIERS[i]])
		slot.size = SLOT_SIZE
		slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_slots.append(slot)
	_skip_button = _button("SKIP", skip)
	_ok_button = _button("OK", press_ok)
	_again_button = _button("OPEN NEXT", press_again)
	set_process(true)


func _ready() -> void:
	if is_inside_tree():
		size = get_viewport_rect().size
		_layer.size = size


func _label(colour: Color, font_size: int = 0) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", colour)
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	add_child(l)
	return l


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_SIZE
	b.size = BUTTON_SIZE
	SetupScreen._style_button(b)
	b.pressed.connect(action)
	b.visible = false
	add_child(b)
	return b


## results — открытые боксы (SkinCollection.open_box), left — сколько ещё лежит в
## профиле, card — карта, на которой показывается шейдер.
func setup(results: Array[Dictionary], left: int, card: String) -> void:
	_results = results
	_left = left
	_card = card
	_speed = BATCH_SPEED if _results.size() > 1 else 1.0
	# Свежезагруженная текстура в первых кадрах рисуется белой: прогреваем, пока
	# сундук трясётся.
	for r in _results:
		for tex in [_face(r), _mini(r)]:
			if tex != null:
				_warm.append(tex)
	_begin(0)


func phase() -> String:
	return _phase


func index() -> int:
	return _index


func batch() -> bool:
	return _results.size() > 1


# --- состояние ----------------------------------------------------------------

func _begin(i: int) -> void:
	_index = i
	_tick = 0
	_enter("shake")


func _enter(phase: String) -> void:
	_phase = phase
	_t = 0.0
	match phase:
		"shake":
			Sfx.play("lift")
		"flash":
			_flash = FLASH_TIME
			_burst = 0.0
			_spawn_particles()
			Sfx.play(_outcome_sound())
		"show":
			_burst = maxf(_burst, 0.0)
			_prepare_card()
		"summary":
			_build_summary()
	_refresh()


func _outcome_sound() -> String:
	if not is_new(_result()):
		return "coins"
	return "capture" if _tier() == "epic" else "victory"


func step(delta: float) -> void:
	var d := delta * _speed
	_t += d
	_flash = maxf(0.0, _flash - d)
	_burst += d
	_dim = move_toward(_dim, 1.0, delta * DIM_SPEED)
	match _phase:
		"shake":
			if _t >= SHAKE_TIME:
				_enter("roll")
		"roll":
			var k := _roll_tick(_t)
			if k != _tick:
				_tick = k
				Sfx.play("ping", true, k % 12)
				_refresh()
			if _t >= ROLL_TIME:
				_enter("flash")
		"flash":
			if _t >= FLASH_TIME:
				_enter("show")
		"show":
			if batch() and _t >= BATCH_SHOW_TIME:
				_next()
	queue_redraw()
	_layer.queue_redraw()


func _process(delta: float) -> void:
	step(delta)


## Сколько переключений плашек уже случилось к моменту t рулетки.
func _roll_tick(t: float) -> int:
	var total := _roll_total()
	return mini(total, int(floorf(float(total) * pow(clampf(t / ROLL_TIME, 0.0, 1.0), 1.0 / ROLL_POWER))))


## Всего переключений: последнее приходится ровно на выпавшую ступень.
func _roll_total() -> int:
	var want := SkinCollection.TIERS.find(_tier())
	return ROLL_TICKS + posmod(want - ROLL_TICKS, SkinCollection.TIERS.size())


## Какая плашка рулетки подсвечена сейчас.
func highlighted() -> int:
	return _tick % SkinCollection.TIERS.size()


func _next() -> void:
	if _index + 1 < _results.size():
		_begin(_index + 1)
	else:
		_enter("summary")


## Промотать: один бокс — сразу к награде, несколько — сразу к итогу.
func skip() -> void:
	if _phase == "summary":
		return
	if batch():
		_enter("summary")
	elif _phase == "shake" or _phase == "roll":
		_enter("flash")
	elif _phase == "flash":
		_enter("show")


func press_ok() -> void:
	_close(false)


func press_again() -> void:
	_close(true)


func _close(again: bool) -> void:
	closed.emit(again)
	if is_inside_tree():
		queue_free()


# --- результат ------------------------------------------------------------------

func _result() -> Dictionary:
	return _results[_index]


func _tier() -> String:
	return String(_result()["tier"])


func _colour() -> Color:
	return Color(SkinCollection.TIER_COLOURS[_tier()])


## Выпало что-то новое (не повтор и не одна пыль).
static func is_new(r: Dictionary) -> bool:
	return not bool(r["duplicate"]) and (String(r["art"]) != "" or String(r["shader"]) != "")


static func item_name(r: Dictionary) -> String:
	if String(r["art"]) != "":
		return EventLogPanel.card_name(AltArts.card_of(String(r["art"])))
	if String(r["shader"]) != "":
		return String(SkinCollection.SHADER_TITLES[String(r["shader"])])
	return "DUST"


func _face(r: Dictionary) -> Texture2D:
	if String(r["art"]) != "":
		return AltArts.full_texture(String(r["art"]))
	if String(r["shader"]) != "":
		return CardView.pixel_texture(_card)
	return null


func _mini(r: Dictionary) -> Texture2D:
	if String(r["art"]) != "":
		return AltArts.mini_texture(String(r["art"]))
	if String(r["shader"]) != "":
		return CardView.mini_texture(_card)
	return null


## Материал образа для карты-награды: шейдер — на любой карте, арты — без него.
func _skin_material(r: Dictionary, small: bool) -> ShaderMaterial:
	var shader := String(r["shader"])
	if shader == "":
		return null
	var mat := ShaderMaterial.new()
	CardView.configure_skin(mat, SkinCollection.SHADER_INDEX[shader], small)
	return mat


func _prepare_card() -> void:
	_layer.material = _skin_material(_result(), false)


## Заголовок и подпись для награды на показе.
func reveal_title() -> String:
	var r := _result()
	var tier := String(SkinCollection.TIER_TITLES[_tier()])
	if String(r["shader"]) != "":
		return ("NEW SHADER: " if is_new(r) else "SHADER: ") + item_name(r)
	if String(r["art"]) != "":
		return ("NEW %s ART!" % tier) if is_new(r) else "%s ART" % tier
	return "%s: DUST" % tier


func reveal_sub() -> String:
	var r := _result()
	var dust := int(r["dust"])
	if is_new(r):
		return item_name(r) if String(r["art"]) != "" else "ULTRA - applies to your whole deck"
	if String(r["art"]) != "" or String(r["shader"]) != "":
		return "%s - already owned: +%d DUST" % [item_name(r), dust]
	return "+%d DUST" % dust


# --- надписи и кнопки -------------------------------------------------------------

func _refresh() -> void:
	var v := _view()
	var c := v * 0.5
	var in_box := _phase == "shake" or _phase == "roll" or _phase == "flash"
	match _phase:
		"shake", "roll", "flash":
			_title.text = ("BOX %d / %d" % [_index + 1, _results.size()]) if batch() else "OPENING BOX..."
			_title.add_theme_color_override("font_color", PixelTheme.TEXT)
			_sub.text = ""
		"show":
			_title.text = reveal_title()
			_title.add_theme_color_override("font_color", _colour())
			_sub.text = reveal_sub()
			_sub.add_theme_color_override("font_color", PixelTheme.TEXT)
		"summary":
			_title.text = "OPENED %d BOXES" % _results.size()
			_title.add_theme_color_override("font_color", PixelTheme.GOLD)
			var new := 0
			var dust := 0
			for r in _results:
				new += 1 if is_new(r) else 0
				dust += int(r["dust"])
			_sub.text = "%d NEW, +%d DUST" % [new, dust]
			_sub.add_theme_color_override("font_color", PixelTheme.TEXT)
	_title.size = Vector2(v.x, 20)
	_title.position = Vector2(0, 52)
	_sub.size = Vector2(v.x, 12)
	_sub.position = Vector2(0, v.y - 112) if _phase == "show" else Vector2(0, 80)
	var total_w := SLOT_SIZE.x * 3.0 + SLOT_GAP * 2.0
	for i in _slots.size():
		_slots[i].visible = _phase == "roll" or _phase == "flash"
		_slots[i].position = Vector2(c.x - total_w * 0.5 + (SLOT_SIZE.x + SLOT_GAP) * float(i), c.y + 108.0)
		var on := i == highlighted() if _phase == "roll" else i == SkinCollection.TIERS.find(_tier())
		_slots[i].add_theme_color_override("font_color",
			Color(SkinCollection.TIER_COLOURS[SkinCollection.TIERS[i]]) if on else PixelTheme.TEXT_OFF)
	_layer.visible = _phase == "show"
	_skip_button.visible = _phase != "summary" and not (_phase == "show" and not batch())
	_ok_button.visible = (_phase == "show" and not batch()) or _phase == "summary"
	_again_button.visible = _ok_button.visible and _left > 0
	var shown: Array[Button] = []
	for b in [_skip_button, _ok_button, _again_button]:
		if b.visible:
			shown.append(b)
	var w := BUTTON_SIZE.x * float(shown.size()) + SLOT_GAP * float(maxi(0, shown.size() - 1))
	for i in shown.size():
		shown[i].position = Vector2(c.x - w * 0.5 + (BUTTON_SIZE.x + SLOT_GAP) * float(i), v.y - 54.0)
	if _scroll != null:
		_scroll.visible = _phase == "summary"
	if in_box:
		queue_redraw()


func _view() -> Vector2:
	return size if size.x > 0.0 else SCREEN


## Итоговая сетка наград: цветная рамка ступени, мелкая карта (если наград не
## много), название и «NEW» или «+N DUST».
func _build_summary() -> void:
	if _scroll != null:
		_scroll.queue_free()
	var thumbs := _results.size() <= SUMMARY_THUMBS
	var cols := 5 if thumbs else 6
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	_scroll.add_child(grid)
	for r in _results:
		grid.add_child(_cell(r, thumbs))
	var rows := ceili(float(_results.size()) / float(cols))
	var cell_h := 140.0 if thumbs else 40.0
	var v := _view()
	var w := (CELL_WIDTH + 4.0) * float(cols) + 8.0
	_scroll.custom_minimum_size = Vector2(w, minf(float(rows) * (cell_h + 4.0), SUMMARY_MAX_HEIGHT))
	_scroll.size = _scroll.custom_minimum_size
	_scroll.position = Vector2(roundf((v.x - w) * 0.5), 108.0)
	add_child(_scroll)


func _cell(r: Dictionary, thumbs: bool) -> Control:
	var colour := Color(SkinCollection.TIER_COLOURS[String(r["tier"])])
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(CELL_WIDTH, 0)
	cell.add_theme_stylebox_override("panel", PixelTheme.box(colour.darkened(0.65), colour, 1, 4, 3))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	cell.add_child(box)
	if thumbs and _mini(r) != null:
		var pic := TextureRect.new()
		pic.texture = _mini(r)
		pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		pic.custom_minimum_size = CardView.MINI_SIZE
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.material = _skin_material(r, true)
		box.add_child(pic)
	box.add_child(_cell_text(String(SkinCollection.TIER_TITLES[String(r["tier"])]), colour))
	box.add_child(_cell_text(item_name(r), PixelTheme.TEXT))
	var status := "NEW" if is_new(r) else "+%d DUST" % int(r["dust"])
	box.add_child(_cell_text(status, PixelTheme.GOLD if is_new(r) else PixelTheme.TEXT_DIM))
	return cell


func _cell_text(text: String, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(CELL_WIDTH - 10.0, 0)
	l.add_theme_color_override("font_color", colour)
	return l


# --- отрисовка --------------------------------------------------------------------

func _draw() -> void:
	var v := _view()
	draw_rect(Rect2(Vector2.ZERO, v), Color(PixelTheme.DIM, PixelTheme.DIM.a * _dim))
	if _phase == "summary" or _phase == "":
		return
	var c := (v * 0.5).round()
	if _phase == "shake" or _phase == "roll" or _phase == "flash":
		var offset := Vector2.ZERO
		var glow := Color(0, 0, 0, 0)
		var lift := 0.0
		match _phase:
			"shake":
				var amp := 1.0 + 5.0 * clampf(_t / SHAKE_TIME, 0.0, 1.0)
				offset = Vector2(roundf(sin(_t * 60.0) * amp), 0)
			"roll":
				var col := Color(SkinCollection.TIER_COLOURS[SkinCollection.TIERS[highlighted()]])
				glow = Color(col, 0.55)
				offset = Vector2(0, roundf(sin(_t * 14.0) * 2.0))
			"flash":
				glow = Color(_colour(), 0.8)
				lift = 6.0 * PIXEL * clampf(_t / FLASH_TIME, 0.0, 1.0)
		_draw_box(c + offset, lift, glow)
	if _phase == "flash" or _phase == "show":
		_draw_particles(c)
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, v), Color(_colour().lerp(Color.WHITE, 0.6), 0.6 * _flash / FLASH_TIME))


## Сундук квадратами по PIXEL: корпус, крышка, железные полосы, замок.
func _draw_box(c: Vector2, lift: float, glow: Color) -> void:
	var u := PIXEL
	var body := Rect2(c + Vector2(-7, 0) * u, Vector2(14, 8) * u)
	var lid := Rect2(c + Vector2(-7, -5) * u - Vector2(0, lift), Vector2(14, 5) * u)
	if glow.a > 0.0:
		var full := body.merge(Rect2(c + Vector2(-7, -5) * u, Vector2(14, 5) * u)).grow(u * 2.0)
		draw_rect(full, Color(glow, 0.15))
		draw_rect(full, glow, false, 4.0)
	var outline := PixelTheme.PANEL
	var wood := Color("7a4a24")
	var wood_hi := Color("8f5a2c")
	var wood_lo := Color("4e2d14")
	var iron := Color("a8a8c0")
	draw_rect(body.grow(u * 0.5), outline)
	draw_rect(body, wood)
	draw_rect(Rect2(body.position + Vector2(0, 3.0 * u), Vector2(body.size.x, u * 0.5)), wood_lo)
	draw_rect(lid.grow(u * 0.5), outline)
	draw_rect(lid, wood_hi)
	for x in [-5.0, 3.0]:
		draw_rect(Rect2(body.position + Vector2((x + 7.0) * u, 0), Vector2(2, 8) * u), iron)
		draw_rect(Rect2(lid.position + Vector2((x + 7.0) * u, 0), Vector2(2, 5) * u), iron)
	draw_rect(Rect2(c + Vector2(-1, -2) * u - Vector2(0, lift * 0.5), Vector2(2, 3) * u), PixelTheme.GOLD)


func _spawn_particles() -> void:
	_particles.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s%d" % [String(_result().get("art", "")), _index])
	for i in PARTICLES:
		var angle := rng.randf() * TAU
		var speed := rng.randf_range(80.0, 260.0)
		_particles.append({"v": Vector2(cos(angle), sin(angle) - 0.5) * speed,
			"gold": i % 3 == 0, "big": i % 4 == 0})


func _draw_particles(c: Vector2) -> void:
	var age := _burst
	if age >= PARTICLE_LIFE:
		return
	for p in _particles:
		var pos: Vector2 = c + (p["v"] as Vector2) * age + Vector2(0, 160.0 * age * age)
		var col: Color = PixelTheme.GOLD if p["gold"] else _colour()
		col.a = 1.0 - age / PARTICLE_LIFE
		var s := 8.0 if p["big"] else 4.0
		draw_rect(Rect2(pos.round(), Vector2(s, s)), col)


## Карта-награда: всплывает снизу, с обводкой ступени (EPIC вспыхивает и гаснет,
## LEGENDARY и ULTRA пульсируют, пока висит).
func _draw_card(c: CardLayer) -> void:
	if _phase != "show" or _results.is_empty():
		return
	var face := _face(_result())
	var r := _result()
	var v := _view()
	var p := 1.0 - pow(1.0 - clampf(_t / RISE_TIME, 0.0, 1.0), 2.0)
	if face == null:
		# Одна пыль: пять золотых монет-квадратов.
		var base := (v * 0.5).round() + Vector2(-40, -10 + (1.0 - p) * 30.0)
		for i in 5:
			c.draw_rect(Rect2(base + Vector2(i * 16, -(i % 2) * 6), Vector2(12, 12)), Color(PixelTheme.GOLD, p))
		return
	var rect := Rect2(((v - CardView.PIXEL_SIZE) * 0.5).round() + Vector2(0, -6 + (1.0 - p) * 40.0), CardView.PIXEL_SIZE)
	c.draw_texture_rect(face, rect, false, Color(1, 1, 1, p))
	var a := 0.0
	if _tier() == "epic":
		a = clampf(1.0 - _t / GLOW_TIME_EPIC, 0.0, 1.0)
	else:
		a = 0.55 + 0.45 * sin(_t * 9.0)
	if is_new(r) and a > 0.0:
		c.draw_rect(rect.grow(2.0), Color(_colour(), a * p), false, 2.0)
