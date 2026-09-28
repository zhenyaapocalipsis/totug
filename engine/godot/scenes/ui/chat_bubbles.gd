class_name ChatBubbles
extends Control

## Фразы из колеса чата (решение владельца, 2026-09-29): облачко в рамке
## цвета игрока слева от его строки в таблице игроков, ~3 секунды. Новая фраза
## того же игрока заменяет старую.

const HOLD_TIME := 3.0
const OUT_TIME := 0.4
const GAP := 3.0

## player_id -> {"box": PanelContainer, "label": Label, "tween": Tween}
var _bubbles: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## anchor — строка игрока в координатах этого слоя; облачко встаёт слева от неё.
func say(pid: String, text: String, anchor: Rect2, colour: Color) -> void:
	if not _bubbles.has(pid):
		var box := PanelContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := GameScreen.zone_style(3)
		style.border_color = colour
		box.add_theme_stylebox_override("panel", style)
		var label := Label.new()
		box.add_child(label)
		add_child(box)
		_bubbles[pid] = {"box": box, "label": label, "tween": null}
	var b: Dictionary = _bubbles[pid]
	var box: PanelContainer = b["box"]
	(b["label"] as Label).text = text
	box.reset_size()
	var need := box.get_combined_minimum_size()
	box.size = need
	box.position = Vector2(anchor.position.x - GAP - need.x,
		anchor.position.y + (anchor.size.y - need.y) * 0.5).round()
	box.position.x = maxf(box.position.x, 0.0)
	box.modulate.a = 1.0
	box.visible = true
	var old: Tween = b["tween"]
	if old != null:
		old.kill()
	var tween := create_tween()
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(box, "modulate:a", 0.0, OUT_TIME)
	tween.tween_callback(func(): box.visible = false)
	b["tween"] = tween


## Текст облачка игрока, пока оно видно ("" — облачка нет).
func text_of(pid: String) -> String:
	if not _bubbles.has(pid):
		return ""
	var b: Dictionary = _bubbles[pid]
	return (b["label"] as Label).text if (b["box"] as Control).visible else ""
