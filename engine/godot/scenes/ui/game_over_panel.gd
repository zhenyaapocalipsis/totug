class_name GameOverPanel
extends Control

## Итоги партии: счёт каждого игрока по статьям финального подсчёта (рулбук,
## стр. 14) и победитель. Появляется сам, когда партия окончена. VIEW BOARD
## прячет итоги, чтобы посмотреть доску; Esc показывает их снова.

signal main_menu_requested

const BUTTON_SIZE := Vector2(90, 16)
const COL_W := 34
## Полоса посередине под таблицу итогов — колоды раскладываются по бокам от неё.
const CENTRE_W := 340.0
const MARGIN := 6.0
const CARD := Vector2(80, 76)  # мелкое лицо карты
const CARD_GAP := 2.0
## Шаг лесенки: видны имя, цена и VP карты. Если карт много — шаг меньше.
const STEP_MAX := 18.0
const STEP_MIN := 9.0
## Статьи подсчёта: ключ в view["final_scores"][игрок] и подпись столбца.
const COLUMNS := [
	["sites", "SITES"],
	["total_control", "CTRL"],
	["trophies", "TROPH"],
	["deck", "DECK"],
	["inner_circle", "INNER"],
	["tokens", "VP"],
]

var _head: Label
var _title: Label
var _grid: GridContainer
var _decks: Control
var _shown_once := false
## Рейтинг после онлайн-партии (NetSession.rating_changed): место -> {rating, delta}.
var _ratings: Dictionary = {}
var _view: Dictionary = {}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Над экраном партии и меню по Tab, но под меню паузы (1100).
	z_index = 1050
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	var dim := ColorRect.new()
	dim.color = PixelTheme.DIM
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	# Без рамки и плашки — итоги прямо на затемнении (как окна выбора карт).
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	centre.add_child(col)

	# Колоды игроков по углам: лесенкой, видна шапка каждой карты; Alt —
	# увеличенная карта, как везде.
	_decks = Control.new()
	_decks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_decks.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_decks)

	_head = Label.new()
	_head.text = "GAME OVER"
	_head.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_head)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
	_title.add_theme_color_override("font_color", PixelTheme.GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS.size() + 3
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 3)
	col.add_child(_grid)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 6)
	col.add_child(buttons)
	buttons.add_child(_button("VIEW BOARD", func(): visible = false))
	buttons.add_child(_button("MAIN MENU", func(): main_menu_requested.emit()))


## Заполняет таблицу из среза состояния. Первый раз после конца партии
## открывается сам; дальше видимостью управляет игрок.
func update_from_view(view: Dictionary) -> void:
	if not bool(view.get("game_over", false)) or not view.has("final_scores"):
		return
	_view = view
	# Сетевая партия кончилась досрочно: кто-то отключился и не вернулся.
	var gone := String(view.get("abandoned_by", ""))
	_head.text = "GAME OVER" if gone == "" else \
		"GAME OVER: %s DID NOT COME BACK. RATING DOES NOT CHANGE" % EventLogPanel.player_name(gone).to_upper()
	var scores: Dictionary = view["final_scores"]
	var winners: Array = view.get("winners", [])

	var names: Array[String] = []
	for pid in winners:
		names.append(EventLogPanel.player_name(String(pid)).to_upper())
	if winners.size() == 1:
		_title.text = "%s WINS" % names[0]
		_title.add_theme_color_override("font_color", EventLogPanel.player_color(String(winners[0])))
	else:
		_title.text = "TIE: %s" % ", ".join(names)
		_title.add_theme_color_override("font_color", PixelTheme.GOLD)

	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_grid.add_child(_cell("", PixelTheme.TEXT_DIM, 0))
	for c in COLUMNS:
		_grid.add_child(_cell(c[1], PixelTheme.TEXT_DIM, COL_W))
	_grid.add_child(_cell("SUM", PixelTheme.GOLD, COL_W))
	_grid.add_child(_cell("RATING" if not _ratings.is_empty() else "", PixelTheme.TEXT_DIM, 0))

	# Строки — по убыванию счёта, при равенстве в порядке хода.
	var order: Array = view["turn_order"].duplicate()
	order.sort_custom(func(a, b):
		return int(scores[a]["total"]) > int(scores[b]["total"]))
	for pid in order:
		var s: Dictionary = scores[pid]
		var colour := EventLogPanel.player_color(String(pid))
		_grid.add_child(_cell(EventLogPanel.player_name(String(pid)).to_upper(), colour, 0,
				HORIZONTAL_ALIGNMENT_LEFT))
		for c in COLUMNS:
			_grid.add_child(_cell(str(int(s[c[0]])), PixelTheme.TEXT, COL_W))
		_grid.add_child(_cell(str(int(s["total"])),
				PixelTheme.GOLD if winners.has(pid) else PixelTheme.TEXT, COL_W))
		_grid.add_child(_rating_cell(String(pid)))

	_build_decks(view)

	if not _shown_once:
		_shown_once = true
		visible = true


## Угол на игрока по порядку хода: левый верх, правый верх, левый низ, правый
## низ. На двоих углы занимают всю высоту экрана.
func _build_decks(view: Dictionary) -> void:
	for child in _decks.get_children():
		_decks.remove_child(child)
		child.queue_free()
	var decks: Dictionary = view.get("final_decks", {})
	var order: Array = view["turn_order"]
	# Растяжение keep: экран партии всегда в расчётном размере проекта.
	var screen := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width", 960),
			ProjectSettings.get_setting("display/window/size/viewport_height", 540))
	var w := (screen.x - CENTRE_W) / 2.0 - MARGIN * 2.0
	var h := screen.y - MARGIN * 2.0 if order.size() <= 2 else screen.y / 2.0 - MARGIN * 1.5
	for i in order.size():
		var pid := String(order[i])
		if not decks.has(pid):
			continue
		var x := MARGIN if i % 2 == 0 else screen.x - MARGIN - w
		var y := MARGIN if i < 2 else screen.y / 2.0 + MARGIN * 0.5
		_build_corner(pid, decks[pid], Rect2(x, y, w, h))


func _build_corner(pid: String, cards: Dictionary, area: Rect2) -> void:
	var deck: Array = cards["deck"].duplicate()
	var inner: Array = cards["inner"].duplicate()
	var by_name := func(a, b): return EventLogPanel.card_name(String(a)) < EventLogPanel.card_name(String(b))
	deck.sort_custom(by_name)
	inner.sort_custom(by_name)

	var head := _cell("%s  DECK %d  INNER %d" % [
			EventLogPanel.player_name(pid).to_upper(), deck.size(), inner.size()],
			EventLogPanel.player_color(pid), 0, HORIZONTAL_ALIGNMENT_LEFT)
	head.position = area.position
	_decks.add_child(head)

	var top := area.position.y + PixelTheme.LINE_H + 2.0
	var columns := maxi(1, int((area.size.x + CARD_GAP) / (CARD.x + CARD_GAP)))
	# Столбцы делятся между колодой и Внутренним кругом (у круга — свой,
	# отмеченный золотом); в столбце карт поровну, шаг — чтобы влезло по высоте.
	var inner_cols := 1 if not inner.is_empty() and columns > 1 else 0
	var deck_cols := columns - inner_cols
	var groups := [[deck, deck_cols, ""]]
	if inner_cols > 0:
		groups.append([inner, inner_cols, "INNER"])
	elif not inner.is_empty():
		deck.append_array(inner)
	var col_x := area.position.x
	for g in groups:
		var ids: Array = g[0]
		var n_cols: int = g[1]
		var per_col := maxi(1, ceili(float(ids.size()) / float(n_cols)))
		var y0 := top
		if String(g[2]) != "":
			var tag := _cell(String(g[2]), PixelTheme.GOLD, 0, HORIZONTAL_ALIGNMENT_LEFT)
			tag.position = Vector2(col_x, top)
			_decks.add_child(tag)
			y0 += PixelTheme.LINE_H
		var room := area.end.y - y0 - CARD.y
		var step := STEP_MAX if per_col <= 1 else clampf(room / float(per_col - 1), STEP_MIN, STEP_MAX)
		for k in ids.size():
			var card := CardView.new(String(ids[k]), int(CARD.x), int(CARD.y))
			card.set_card_owner(pid)
			card.set_clickable(false, false)
			card.position = Vector2(col_x + float(k / per_col) * (CARD.x + CARD_GAP),
					y0 + float(k % per_col) * step)
			_decks.add_child(card)
		col_x += float(n_cols) * (CARD.x + CARD_GAP)


func _cell(text: String, colour: Color, width: int,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.custom_minimum_size.x = width
	label.add_theme_color_override("font_color", colour)
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	SetupScreen._style_button(button)
	button.pressed.connect(action)
	return button


## Сервер пересчитал рейтинг — таблица получает столбец RATING.
func set_ratings(result: Dictionary) -> void:
	_ratings = result
	if not _view.is_empty():
		update_from_view(_view)


## "1016 +16": новый рейтинг и изменение (рост — зелёным, падение — красным).
func _rating_cell(pid: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	if not _ratings.has(pid):
		return row
	var r: Dictionary = _ratings[pid]
	var delta := int(r["delta"])
	row.add_child(_cell(str(int(r["rating"])), PixelTheme.TEXT, 0, HORIZONTAL_ALIGNMENT_LEFT))
	var colour := Color("5fd36a") if delta > 0 else (PixelTheme.DANGER if delta < 0 else PixelTheme.TEXT_DIM)
	row.add_child(_cell("%+d" % delta, colour, 0, HORIZONTAL_ALIGNMENT_LEFT))
	return row
