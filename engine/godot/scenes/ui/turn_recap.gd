class_name TurnRecap
extends PanelContainer

## Сводка ходов соперников: когда ход приходит к зрителю, над рукой на
## несколько секунд выезжает полоска маленьких карт — что каждый соперник
## купил, промоутил и съел, пока зритель ждал. Для тех, кто отвернулся:
## читать ничего не надо, только картинки с подписью BOUGHT / PROMOTED /
## DEVOURED. Карты — обычные CardView: по наведению и Alt их видно крупно.
##
## Мышь над полоской держит её на экране; щелчок убирает сразу.

const SHOW_TIME := 5.0
const FADE_TIME := 0.18
## На сколько пикселей полоска выезжает снизу.
const SLIDE := 10.0
## Больше карт в строке одного игрока не показываем — самые свежие.
const MAX_CARDS := 8
const CARD := Vector2(80, 76)

var _col: VBoxContainer
var _left := 0.0
var _fade := 0.0
var _home := Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 3)
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_col)
	set_process(false)


## groups — [{"pid": ..., "items": [{"cid": ..., "tag": "BOUGHT"}, ...]}, ...]
## по порядку ходов. Полоска встаёт нижним краем над bottom_centre.
func show_groups(groups: Array, bottom_centre: Vector2) -> void:
	for child in _col.get_children():
		child.queue_free()
	var border := PixelTheme.GOLD
	for group: Dictionary in groups:
		var pid := String(group["pid"])
		var colour: Color = BoardPanel.PLAYER_COLORS.get(pid, PixelTheme.TEXT)
		border = colour if groups.size() == 1 else PixelTheme.BORDER
		var title := Label.new()
		title.text = "%s'S TURN" % EventLogPanel.player_name(pid).to_upper()
		title.add_theme_color_override("font_color", colour.lightened(0.3))
		_col.add_child(title)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_col.add_child(row)
		var items: Array = group["items"]
		for item: Dictionary in items.slice(maxi(0, items.size() - MAX_CARDS)):
			row.add_child(_cell(String(item["cid"]), String(item["tag"])))
	add_theme_stylebox_override("panel", PixelTheme.box(Color(0.05, 0.04, 0.08, 0.94), border, 1, 4, 3))
	visible = true
	reset_size()
	size = get_combined_minimum_size()
	_home = Vector2(roundf(bottom_centre.x - size.x * 0.5), roundf(bottom_centre.y - size.y))
	_left = SHOW_TIME
	_fade = 0.0
	_apply()
	set_process(true)


func _cell(cid: String, tag: String) -> Control:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 1)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := CardView.new(cid, int(CARD.x), int(CARD.y))
	card.set_clickable(false, false)
	cell.add_child(card)
	var label := Label.new()
	label.text = tag
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color",
		PixelTheme.DANGER if tag == "DEVOURED" else PixelTheme.TEXT_DIM)
	cell.add_child(label)
	return cell


## Для проверок: сколько карт сейчас в сводке.
func card_count() -> int:
	var n := 0
	for row in _col.get_children():
		if row is HBoxContainer:
			n += row.get_child_count()
	return n


func dismiss() -> void:
	_left = minf(_left, 0.0)


func _process(delta: float) -> void:
	var hovered := get_global_rect().has_point(get_global_mouse_position())
	if not hovered:
		_left -= delta
	_fade = move_toward(_fade, 1.0 if _left > 0.0 else 0.0, delta / FADE_TIME)
	_apply()
	if _left <= 0.0 and _fade <= 0.0:
		visible = false
		set_process(false)


## Выезд снизу и проявление — только целыми пикселями.
func _apply() -> void:
	var k := 1.0 - (1.0 - _fade) * (1.0 - _fade)
	position = _home + Vector2(0, roundf(SLIDE * (1.0 - k)))
	modulate.a = k


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dismiss()
		accept_event()
