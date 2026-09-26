class_name TurnRecap
extends PanelContainer

## Сводка ходов соперников: когда ход приходит к зрителю, у левого края доски
## на несколько секунд выезжает колонка маленьких карт — что каждый соперник
## купил, промоутил и съел, пока зритель ждал. Для тех, кто отвернулся:
## читать ничего не надо, только картинки с подписью BOUGHT / PROMOTED /
## DEVOURED. Карты — обычные CardView: по наведению и Alt их видно крупно.
##
## Колонкой слева (решение владельца, 2026-09-26): так сводка не закрывает
## середину доски и руку. Сверху вниз — по порядку ходов, внутри игрока — по
## порядку действий. Не влезает по высоте — отбрасываются самые старые карты.
##
## Мышь над колонкой держит её на экране; щелчок убирает сразу.

const SHOW_TIME := 5.0
const FADE_TIME := 0.18
## На сколько пикселей колонка выезжает слева.
const SLIDE := 12.0
const CARD := Vector2(80, 76)

var _col: VBoxContainer
var _left := 0.0
var _fade := 0.0
var _home := Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 2)
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_col)
	set_process(false)


## groups — [{"pid": ..., "items": [{"cid": ..., "tag": "BOUGHT"}, ...]}, ...]
## по порядку ходов. Колонка встаёт левым верхним углом в top_left и не
## выше max_height.
func show_groups(groups: Array, top_left: Vector2, max_height: float) -> void:
	for child in _col.get_children():
		_col.remove_child(child)
		child.queue_free()
	var border := PixelTheme.BORDER
	var cells: Array[Control] = []   # от старых к новым — лишние убираем с начала
	for group: Dictionary in groups:
		var pid := String(group["pid"])
		var colour: Color = BoardPanel.PLAYER_COLORS.get(pid, PixelTheme.TEXT)
		if groups.size() == 1:
			border = colour
		var title := Label.new()
		title.text = "%s'S TURN" % EventLogPanel.player_name(pid).to_upper()
		title.add_theme_color_override("font_color", colour.lightened(0.3))
		_col.add_child(title)
		for item: Dictionary in (group["items"] as Array):
			var cell := _cell(String(item["cid"]), String(item["tag"]))
			_col.add_child(cell)
			cells.append(cell)
	add_theme_stylebox_override("panel", PixelTheme.box(Color(0.05, 0.04, 0.08, 0.94), border, 1, 3, 3))
	# Не влезает — убираем самые старые карты, пока колонка не станет по росту.
	while cells.size() > 1 and get_combined_minimum_size().y > max_height:
		var old: Control = cells.pop_front()
		_col.remove_child(old)
		old.queue_free()
	visible = true
	reset_size()
	size = get_combined_minimum_size()
	_home = top_left.round()
	_left = SHOW_TIME
	_fade = 0.0
	_apply()
	set_process(true)


func _cell(cid: String, tag: String) -> Control:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 0)
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
	for child in _col.get_children():
		if child is VBoxContainer:
			n += 1
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


## Выезд слева и проявление — только целыми пикселями.
func _apply() -> void:
	var k := 1.0 - (1.0 - _fade) * (1.0 - _fade)
	position = _home - Vector2(roundf(SLIDE * (1.0 - k)), 0)
	modulate.a = k


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dismiss()
		accept_event()
