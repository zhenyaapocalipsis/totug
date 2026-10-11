class_name ForcedGlow
extends Control

## Рамка по краю всего экрана цветом отвечающего, пока чужая карта заставляет
## его действовать — сбросить карту, повысить Ambassador и т. п. (владелец,
## 2026-10-11: игроки не замечали, что от них чего-то ждут посреди чужого хода).
## Сначала FLASHES ярких вспышек, потом ровное мерцание до ответа. Мышь не
## ловит. Толщина — целые пиксели, пиксель-арт не мылится.

const THICK := 3
## Вспышки в начале: каждая — от белого к цвету игрока.
const FLASHES := 3
const FLASH_TIME := 0.22
## Потом мерцание: прозрачность от LOW до 1 с частотой RATE в секунду.
const LOW := 0.45
const RATE := 1.5

var _colour := Color.WHITE
var _time := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Над витриной и баннером хода, под диалогами (999+).
	z_index = 970
	visible = false
	set_process(false)


## Включить рамку цветом colour (с вспышками заново) или выключить.
func set_active(on: bool, colour: Color = Color.WHITE) -> void:
	if on and (not visible or colour != _colour):
		_colour = colour
		_time = 0.0
	visible = on
	set_process(on)
	queue_redraw()


func is_active() -> bool:
	return visible


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var c := _colour
	var flash_end := FLASHES * FLASH_TIME
	if _time < flash_end:
		var t := fmod(_time, FLASH_TIME) / FLASH_TIME
		c = Color.WHITE.lerp(_colour, t)
	else:
		c.a = LOW + (1.0 - LOW) * (0.5 + 0.5 * cos((_time - flash_end) * TAU * RATE))
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, THICK), c)
	draw_rect(Rect2(0, h - THICK, w, THICK), c)
	draw_rect(Rect2(0, THICK, THICK, h - THICK * 2), c)
	draw_rect(Rect2(w - THICK, THICK, THICK, h - THICK * 2), c)
