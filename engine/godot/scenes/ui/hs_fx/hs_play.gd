class_name HsPlay
extends Control

## Розыгрыш карты как в Hearthstone (решения владельца 2026-10-19/20): без витрины и
## без затемнения; нажатую карту рука прячет сразу, и идёт эффект Hearthstone, затем в
## центре доски на секунду проявляется миниатюра карты и гаснет — и только потом игра
## показывает действия карты (released).
##
## Эффект — запечённые кадры (assets/hs_fx/baked/<имя>/): Unity рисует оригинальные
## префабы Hearthstone из файлов игры его же шейдерами, частицами и Timeline, с камеры
## доски HS, и пишет кадры 960x540 с premultiplied-альфой (hs_unity, HsRender; рецепт —
## hs_unity/recipes/<имя>.json). Дорожка f### рисуется над картой, u### — под ней
## (подложка и горящий контур появления карты). Текстуры HS под его макет (рамка карты,
## портрет героя) при запекании заменены своими.

## Акт появления закончился, карта погасла: можно показывать действия и вопросы.
signal released
## Толчок доски (сила в пикселях, BoardPanel.shake).
signal shake(power: float)

const BAKED := "res://assets/hs_fx/baked/"
## Миниатюра карты в центре доски — в своём размере (владелец, 2026-10-20).
const MINI_SCALE := 1
## Сколько кадров вперёд подгружать в фоне (кадры идут 60 в секунду).
const AHEAD := 12

## Карта -> сценарий.
const RECIPES := {"48426": "worldbreaker"}
## Сценарий: len — длина (с); frames — папка запечённых кадров; card — появление
## миниатюры: reveal (секунда), sweep (проявляется снизу вверх), hold (стоит), out
## (гаснет), center (центр на экране 960x540 — центр квада Quad_CardGlow в кадрах);
## cues — звуки [секунда, файл в папке сценария], shakes — толчки доски [секунда, сила].
const SCRIPTS := {
	# Deathwing, Worldbreaker (CATA_190h): CATAFX_Deathwing_CustomSummon_Spell (тень
	# дракона с огненным шлейфом проносится над доской, пике в центр доски (1.13 с),
	# огненная волна, вспышка, дым, угли) и сразу за ударом CATAFX_Deathwing_Choice_Reveal
	# (одна карта вместо четырёх, с 1.15 с; миниатюра — через 0.45 с, WaitToShowCards).
	"worldbreaker": {"len": 4.6, "frames": "worldbreaker",
		"card": {"reveal": 1.6, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(480, 247)},
		"cues": [[0.0, "CATA_190h_Enter_01"], [0.0, "CATA_190h_Enter_Dragon_01"], [0.85, "CATA_190h_Enter_02"],
			[1.0, "CATA_190h_Enter_Dragon_02"], [1.15, "CATA_190h_CardReveal_01"]],
		"shakes": [[0.0, 3.0], [1.133, 5.0]]},
}

## Для снимков: шаг времени за кадр (0 — настоящее время).
static var fixed_dt := 0.0

var board_area: Control
var _queue: Array[Dictionary] = []
var _item: Dictionary = {}
var _script: Dictionary = {}
var _meta: Dictionary = {}
var _under: Dictionary = {}
var _t := 0.0
var _released := false
var _cue_t := -1.0
var _shown_frame := -1
var _cache: Dictionary = {}

var _under_layer := _FrameLayer.new()
var _card := _CardLayer.new()
var _over_layer := _FrameLayer.new()


static func has(cid: String) -> bool:
	return RECIPES.has(cid)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c: Control in [_under_layer, _card, _over_layer]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(c)
	visible = false
	set_process(false)


## Разыграть карту cid: face — её миниатюра, quiet — чужая (тише).
func play(cid: String, face: Texture2D, quiet: bool = false) -> void:
	if not has(cid):
		return
	_queue.append({"cid": cid, "face": face, "quiet": quiet})
	if _item.is_empty():
		_next()


## Идёт ли розыгрыш, который ещё держит действия карты.
func is_busy() -> bool:
	return not _item.is_empty() and not _released


## Готов ли розыгрыш (для снимков и превью).
func is_ready() -> bool:
	return not _item.is_empty()


func _next() -> void:
	_item = {}
	_cache.clear()
	_under_layer.show_frame(null)
	_over_layer.show_frame(null)
	_card.show_card(null, Rect2(), 0.0, 1.0)
	visible = false
	set_process(false)
	if _queue.is_empty():
		return
	_item = _queue.pop_front()
	_script = SCRIPTS[RECIPES[_item["cid"]]]
	var dir := BAKED + String(_script["frames"]) + "/"
	_meta = JSON.parse_string(FileAccess.get_file_as_string(dir + "meta.json"))
	_under = {}
	for i in _meta.get("under", []):
		_under[int(i)] = true
	_t = 0.0
	_released = false
	_cue_t = -1.0
	_shown_frame = -1
	visible = true
	set_process(true)
	_frame()


func _process(delta: float) -> void:
	# Godot сам включает _process при входе в дерево — без розыгрыша выключаем
	if _item.is_empty():
		set_process(false)
		return
	_t += fixed_dt if fixed_dt > 0.0 else delta
	var cs: Dictionary = _script["card"]
	if not _released and _t >= float(cs["reveal"]) + float(cs["sweep"]) + float(cs["hold"]) + float(cs["out"]):
		_released = true
		released.emit()
	if _t >= float(_script["len"]):
		_next()
		return
	_cues(_t)
	_frame()


## Кадр в момент t (секунды от начала розыгрыша), без звуков — для снимков.
func debug_seek(t: float) -> void:
	_t = t
	_frame()


## Звуки и толчки сценария — каждый, когда время его проходит.
func _cues(t: float) -> void:
	for c: Array in _script["cues"]:
		if _cue_t < float(c[0]) and t >= float(c[0]):
			Sfx.play_file("res://assets/hs_fx/%s/%s.wav" % [_script["frames"], c[1]], bool(_item["quiet"]))
	for s: Array in _script["shakes"]:
		if _cue_t < float(s[0]) and t >= float(s[0]):
			shake.emit(float(s[1]))
	_cue_t = t


func _frame() -> void:
	var n := int(_meta["frames"])
	var i := mini(floori(_t * float(_meta["fps"])), n - 1)
	if i != _shown_frame:
		_shown_frame = i
		_over_layer.show_frame(_texture("f", i))
		_under_layer.show_frame(_texture("u", i) if _under.has(i) else null)
		for k in range(i + 1, mini(i + 1 + AHEAD, n)):
			_request("f", k)
			if _under.has(k):
				_request("u", k)
		for key: String in _cache.keys():
			if int(key.substr(1)) < i:
				_cache.erase(key)
	_render_card()


func _path(track: String, i: int) -> String:
	return BAKED + String(_script["frames"]) + "/%s%03d.png" % [track, i]


func _request(track: String, i: int) -> void:
	var key := track + str(i)
	if _cache.has(key):
		return
	_cache[key] = null
	ResourceLoader.load_threaded_request(_path(track, i), "Texture2D")


func _texture(track: String, i: int) -> Texture2D:
	var key := track + str(i)
	var path := _path(track, i)
	if _cache.has(key):
		var t: Texture2D = _cache[key]
		if t == null:
			t = ResourceLoader.load_threaded_get(path)
			_cache[key] = t
		return t
	var tex := load(path) as Texture2D
	_cache[key] = tex
	return tex


## Миниатюра: проявляется снизу вверх, стоит, гаснет.
func _render_card() -> void:
	var cs: Dictionary = _script["card"]
	var t0 := float(cs["reveal"])
	if _t < t0:
		_card.show_card(null, Rect2(), 0.0, 1.0)
		return
	var shown := clampf((_t - t0) / float(cs["sweep"]), 0.0, 1.0)
	var out_at := t0 + float(cs["sweep"]) + float(cs["hold"])
	var a := 1.0 - clampf((_t - out_at) / float(cs["out"]), 0.0, 1.0)
	_card.show_card(_item["face"], _card_rect(), a, shown)


## Где миниатюра на экране: центр сценария в координатах 960x540 -> размер HsPlay.
func _card_rect() -> Rect2:
	var k := size / Vector2(960, 540)
	var s := CardView.MINI_SIZE * MINI_SCALE * k
	var c := Vector2(_script["card"]["center"]) * k
	return Rect2((c - s * 0.5).round(), s.round())


## Кадр эффекта на весь экран: premultiplied-альфа (One, OneMinusSrcAlpha).
class _FrameLayer extends Control:
	var _tex: Texture2D

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
		material = m

	func show_frame(tex: Texture2D) -> void:
		_tex = tex
		queue_redraw()

	func _draw() -> void:
		if _tex != null:
			draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)


## Карта: видна нижняя часть shown (0..1) — огонь проявляет её снизу вверх.
class _CardLayer extends Control:
	var _face: Texture2D
	var _rect := Rect2()
	var _alpha := 0.0
	var _shown := 1.0

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func show_card(face: Texture2D, r: Rect2, a: float, shown: float) -> void:
		_face = face
		_rect = r
		_alpha = a
		_shown = shown
		queue_redraw()

	func _draw() -> void:
		if _face == null or _alpha <= 0.0 or _shown <= 0.0:
			return
		var h := roundf(_rect.size.y * _shown)
		var src := Rect2(0.0, float(_face.get_height()) * (1.0 - h / _rect.size.y), float(_face.get_width()),
			float(_face.get_height()) * h / _rect.size.y)
		draw_texture_rect_region(_face, Rect2(_rect.position.x, _rect.end.y - h, _rect.size.x, h), src, Color(1, 1, 1, _alpha))
