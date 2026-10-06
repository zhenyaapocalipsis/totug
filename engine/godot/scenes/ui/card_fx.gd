class_name CardFx
extends RefCounted

## Эффекты розыгрыша уникальных карт (в колоде одна копия): когда такую карту
## играют, витрина (CardShowcase) показывает её крупно и рисует вокруг свой
## спрайтовый эффект — например щупальца Ulitharid из-за карты. Спрайты лежат в
## assets/card_fx/<card_id>/, сценарии — в таблице FX.
##
## Живость даёт код, а не кадры анимации: спрайт щупальца один, а при рисовании
## его строки сдвигаются волной вдоль длины (корень на месте, кончик гуляет),
## выход идёт с перелётом и отдачей, карта вздрагивает, от неё расходится
## ударная волна. Сдвиги целые, повороты кратны 90 градусам — пиксель-арт цел.

const SPRITE_PATH := "res://assets/card_fx/%s/%s.png"
## Сколько секунд висит карта с эффектом (обычная — CardShowcase.HOLD_TIME).
const HOLD_TIME := 1.8
const OUT_TIME := 0.5
const RETRACT_AT := 1.4
const RETRACT_TIME := 0.28
## Высота полоски спрайта, которую сдвигает волна.
const STRIP := 2
## Ударная волна: квадрат вокруг карты расширяется и гаснет.
const RING_TIME := 0.45
const RING_GROW := 70.0
## Вздрагивание карты: сила (пикселей) и скорость затухания.
const JOLT := 2.0
const JOLT_DECAY := 12.0

## card_id -> сценарий. sprite — имя спрайта, tint — цвет ударной волны, sound —
## звук (см. Sfx), parts — места щупалец:
##   base — точка основания в долях карты; rot — куда смотрит (градусы, 0 = вверх);
##   delay — задержка выхода; phase — сдвиг волны; amp — размах волны (пиксели);
##   front — рисуется поверх карты (цепляется за неё); reach — до какой доли
##   длины вылезает (у передних щупалец меньше).
const FX := {
	"48701": {
		"sprite": "tentacle", "tint": Color("b05ad8"), "sound": "sink",
		"parts": [
			{"base": Vector2(0.23, 0.14), "rot": 0, "delay": 0.00, "phase": 0.0, "amp": 7.0, "reach": 0.7},
			{"base": Vector2(0.77, 0.18), "rot": 0, "delay": 0.08, "phase": 2.1, "amp": 8.0, "reach": 0.62},
			{"base": Vector2(0.18, 0.30), "rot": -90, "delay": 0.04, "phase": 4.2, "amp": 8.0},
			{"base": Vector2(0.18, 0.74), "rot": -90, "delay": 0.14, "phase": 1.0, "amp": 7.0},
			{"base": Vector2(0.82, 0.42), "rot": 90, "delay": 0.10, "phase": 3.3, "amp": 8.0},
			{"base": Vector2(0.82, 0.80), "rot": 90, "delay": 0.02, "phase": 5.5, "amp": 7.0},
			{"base": Vector2(0.34, 0.86), "rot": 180, "delay": 0.16, "phase": 0.7, "amp": 7.0, "reach": 0.66},
			{"base": Vector2(0.66, 0.84), "rot": 180, "delay": 0.06, "phase": 2.9, "amp": 8.0, "reach": 0.72},
			# передние: вцепились в углы карты и покачиваются поверх неё
			{"base": Vector2(0.03, 1.03), "rot": 0, "delay": 0.20, "phase": 1.7, "amp": 5.0,
				"front": true, "reach": 0.3},
			{"base": Vector2(0.97, -0.03), "rot": 180, "delay": 0.24, "phase": 4.6, "amp": 5.0,
				"front": true, "reach": 0.3},
		],
	},
}

static var _cache: Dictionary = {}


static func has(cid: String) -> bool:
	return FX.has(cid)


static func sound(cid: String) -> String:
	return String(FX[cid]["sound"]) if FX.has(cid) else ""


static func _sprite(cid: String) -> Texture2D:
	var name := String(FX[cid]["sprite"])
	var key := "%s/%s" % [cid, name]
	if not _cache.has(key):
		_cache[key] = load(SPRITE_PATH % [cid, name])
	return _cache[key]


## Позади карты (щупальца, что вылезают из-за неё) и ударная волна.
static func draw_behind(c: CanvasItem, cid: String, card: Rect2, t: float) -> void:
	_draw_ring(c, cid, card, t)
	_draw_parts(c, cid, card, t, false)


## Поверх карты (щупальца, что вцепились в неё).
static func draw_front(c: CanvasItem, cid: String, card: Rect2, t: float) -> void:
	_draw_parts(c, cid, card, t, true)


## На сколько пикселей вздрагивает карта: каждое щупальце, вылезая, толкает её.
static func card_shift(cid: String, t: float) -> Vector2:
	if not FX.has(cid):
		return Vector2.ZERO
	var shift := Vector2.ZERO
	for part: Dictionary in FX[cid]["parts"]:
		if bool(part.get("front", false)):
			continue
		var dt := t - float(part["delay"]) - OUT_TIME * 0.45
		if dt > 0.0:
			var dir := Vector2.UP.rotated(deg_to_rad(float(part["rot"])))
			shift -= dir * JOLT * exp(-dt * JOLT_DECAY) * sin(dt * 40.0 + float(part["phase"]))
	return shift.round()


static func _draw_ring(c: CanvasItem, cid: String, card: Rect2, t: float) -> void:
	var k := t / RING_TIME
	if k <= 0.0 or k >= 1.0:
		return
	var colour: Color = FX[cid]["tint"]
	colour.a = 0.7 * (1.0 - k)
	c.draw_rect(card.grow(roundf(RING_GROW * _ease_out(k))), colour, false, 2.0)


static func _draw_parts(c: CanvasItem, cid: String, card: Rect2, t: float, front: bool) -> void:
	var tex := _sprite(cid)
	if tex == null:
		return
	var w := int(tex.get_width())
	var h := int(tex.get_height())
	for part: Dictionary in FX[cid]["parts"]:
		if bool(part.get("front", false)) != front:
			continue
		var delay := float(part["delay"])
		var out := _ease_out_back((t - delay) / OUT_TIME)
		var gone := _ease_in((t - RETRACT_AT - delay * 0.5) / RETRACT_TIME)
		var reach := float(part.get("reach", 1.0))
		var length := out * (1.0 - gone) * reach
		if length <= 0.0:
			continue
		var base := (card.position + card.size * (part["base"] as Vector2)).round()
		var phase := float(part["phase"])
		var amp := float(part["amp"])
		# отдача: пока щупальце ещё выходит, оно изогнуто сильнее
		var lash := 1.0 + 1.6 * clampf(1.0 - (t - delay) / OUT_TIME, 0.0, 1.0)
		# спрайт сдвинут вдоль оси так, что наружу торчит доля length; ниже
		# основания (y > 0) строки не рисуются — щупальце «растёт из точки»
		var slide := roundf(h * (1.0 - length))
		c.draw_set_transform(base, deg_to_rad(float(part["rot"])))
		var r := 0
		while r < h:
			var y := -h + slide + r
			if y + STRIP > 0:
				break
			# d: 0 у корня, 1 у кончика — корень стоит, кончик гуляет
			var d := 1.0 - float(r) / float(h)
			var wave := sin(float(r) * 0.085 - t * 6.5 + phase) + 0.5 * sin(float(r) * 0.04 + t * 3.1 + phase * 1.7)
			var dx := roundf(amp * lash * pow(d, 1.4) * wave)
			c.draw_texture_rect_region(tex, Rect2(-w * 0.5 + dx, y, w, STRIP), Rect2(0, r, w, STRIP))
			r += STRIP
	c.draw_set_transform(Vector2.ZERO)


static func _ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - x) * (1.0 - x)


static func _ease_in(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x


## Выход с перелётом (~10% за край) и возвратом.
static func _ease_out_back(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)
