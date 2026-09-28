class_name PingLayer
extends Control

## Метки пингов (короткое нажатие Tab, решение владельца, 2026-09-29): под
## курсором трижды расходится кольцо цвета игрока, в центре — точка. Слой
## поверх экрана, мышь не ловит.

const LIFE := 1.8
const WAVES := 3
const RADIUS := 14.0
const DOT := 3.0

## Живые метки: {pos, colour, t}.
var _pings: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## pos — точка этого слоя.
func ping(pos: Vector2, colour: Color) -> void:
	_pings.append({"pos": pos.round(), "colour": colour, "t": 0.0})
	queue_redraw()


func count() -> int:
	return _pings.size()


func _process(delta: float) -> void:
	if _pings.is_empty():
		return
	for p: Dictionary in _pings:
		p["t"] = float(p["t"]) + delta
	_pings = _pings.filter(func(p: Dictionary) -> bool: return float(p["t"]) < LIFE)
	queue_redraw()


func _draw() -> void:
	var wave_len := LIFE / WAVES
	for p: Dictionary in _pings:
		var t := float(p["t"])
		var colour: Color = p["colour"]
		var pos: Vector2 = p["pos"]
		# Кольцо волны: растёт и тает; радиус целый — пиксели не мылятся.
		var k := fmod(t, wave_len) / wave_len
		var r := roundf(2.0 + (RADIUS - 2.0) * k)
		# Под цветным кольцом — тёмное пошире: так оно видно и на светлой доске.
		draw_arc(pos, r, 0.0, TAU, 32, Color(PixelTheme.BG, 0.8 * (1.0 - k)), 3.0, false)
		draw_arc(pos, r, 0.0, TAU, 32, Color(colour, 1.0 - k), 1.0, false)
		var fade := clampf((LIFE - t) / 0.3, 0.0, 1.0)
		draw_rect(Rect2(pos - Vector2.ONE * (DOT + 1.0), Vector2.ONE * (DOT * 2.0 + 2.0)), Color(PixelTheme.BG, fade))
		draw_rect(Rect2(pos - Vector2.ONE * DOT, Vector2.ONE * DOT * 2.0), Color(colour, fade))
