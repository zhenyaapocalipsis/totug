class_name CardFx
extends RefCounted

## Эффекты розыгрыша уникальных карт (в колоде одна копия): когда такую карту
## играют, витрина (CardShowcase) показывает её крупно и рисует вокруг свой
## спрайтовый эффект — например щупальца Ulitharid из-за карты. Кадры лежат в
## assets/card_fx/<card_id>/, сценарии — в таблице FX.
##
## Пиксельное правило то же: спрайты 1:1, повороты только на 90 градусов.

const FRAMES_PATH := "res://assets/card_fx/%s/%s_%d.png"
## Сколько секунд висит карта с эффектом (обычная — CardShowcase.HOLD_TIME).
const HOLD_TIME := 1.7
const FPS := 10.0
const GROW_TIME := 0.4
const RETRACT_AT := 1.25

## card_id -> сценарий. sprite — имя кадров, frames — их число, tint — цвет
## вспышки при появлении, sound — звук (см. Sfx), parts — места спрайтов.
const FX := {
	"48701": {
		"sprite": "tentacle", "frames": 9, "tint": Color("b05ad8"), "sound": "sink",
		# base — точка основания в долях карты, rot — куда смотрит (градусы,
		# 0 = вверх), reach — доля длины спрайта, delay — задержка выхода.
		"parts": [
			{"base": Vector2(0.23, 0.12), "rot": 0, "reach": 0.8, "delay": 0.00, "phase": 0},
			{"base": Vector2(0.77, 0.16), "rot": 0, "reach": 0.7, "delay": 0.08, "phase": 4},
			{"base": Vector2(0.17, 0.32), "rot": -90, "reach": 1.0, "delay": 0.04, "phase": 2},
			{"base": Vector2(0.17, 0.76), "rot": -90, "reach": 0.9, "delay": 0.12, "phase": 6},
			{"base": Vector2(0.83, 0.44), "rot": 90, "reach": 1.0, "delay": 0.10, "phase": 1},
			{"base": Vector2(0.83, 0.80), "rot": 90, "reach": 0.9, "delay": 0.02, "phase": 5},
			{"base": Vector2(0.34, 0.88), "rot": 180, "reach": 0.7, "delay": 0.14, "phase": 3},
			{"base": Vector2(0.66, 0.86), "rot": 180, "reach": 0.8, "delay": 0.06, "phase": 7},
		],
	},
}

static var _cache: Dictionary = {}


static func has(cid: String) -> bool:
	return FX.has(cid)


static func tint(cid: String) -> Color:
	return FX[cid]["tint"] if FX.has(cid) else Color.WHITE


static func sound(cid: String) -> String:
	return String(FX[cid]["sound"]) if FX.has(cid) else ""


static func _frame(cid: String, index: int) -> Texture2D:
	var name := String(FX[cid]["sprite"])
	var key := "%s/%s_%d" % [cid, name, index]
	if not _cache.has(key):
		_cache[key] = load(FRAMES_PATH % [cid, name, index])
	return _cache[key]


## Рисует эффект карты cid позади карты card на слое c; t — секунды с начала показа.
static func draw_behind(c: CanvasItem, cid: String, card: Rect2, t: float) -> void:
	if not FX.has(cid):
		return
	var fx: Dictionary = FX[cid]
	var frames := int(fx["frames"])
	for part: Dictionary in fx["parts"]:
		var delay := float(part["delay"])
		var grow := _ease_out((t - delay) / GROW_TIME)
		var gone := _ease_in((t - RETRACT_AT - delay * 0.5) / GROW_TIME)
		var visible := grow * (1.0 - gone) * float(part["reach"])
		var tex := _frame(cid, (int(t * FPS) + int(part["phase"])) % frames)
		if visible <= 0.0 or tex == null:
			continue
		var size := tex.get_size()
		var rows := roundf(size.y * visible)
		var base := (card.position + card.size * (part["base"] as Vector2)).round()
		# спрайт растёт из основания: показываем нижние rows строк
		c.draw_set_transform(base, deg_to_rad(float(part["rot"])))
		c.draw_texture_rect_region(tex, Rect2(-size.x * 0.5, -rows, size.x, rows),
			Rect2(0, size.y - rows, size.x, rows))
	c.draw_set_transform(Vector2.ZERO)


static func _ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - x) * (1.0 - x)


static func _ease_in(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x
