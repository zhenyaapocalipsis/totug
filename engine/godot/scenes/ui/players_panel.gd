class_name PlayersPanel
extends PanelContainer

## Расклад по игрокам в правой колонке под бараками (решение владельца,
## 2026-09-27: переехал сюда из меню по Tab на место зоны сыгранных карт —
## сыгранные карты и так видны в сводке ходов слева).
##
## Таблица: строка на игрока в порядке хода (первая строка — первый
## игрок), у ходящего перед именем «>». Скрытых сведений нет: рука и сброс
## противника — только числом карт (так их и отдаёт StateView). Зал трофеев —
## по цифре на каждый цвет убитых фишек, цифра того же цвета. Во время
## стартовой расстановки под таблицей стоит сам вопрос «выбери стартовую
## локацию».

## Числовые столбцы: ключ в срезе игрока, заголовок, подсказка к заголовку.
const COLUMNS: Array[Array] = [
	["vp_tokens", "VP", "Victory point tokens"],
	["hand_size", "HD", "Cards in hand"],
	["deck_size", "DK", "Cards in deck"],
	["discard_size", "DS", "Cards in discard pile"],
	["inner_circle", "IC", "Cards in Inner Circle"],
]
## Ширина столбца имени (6 знаков шрифта по 6 пикселей) и числового (2 знака).
## Трофеям — всё, что осталось справа.
const NAME_W := 36.0
const NUM_W := 12.0
const COL_GAP := 3
const TROPHY_INDENT := 4
## Нейтральные (белые) убитые войска — серой цифрой.
const NEUTRAL_COLOR := Color(0.6, 0.6, 0.6)

## Карта спросила "выбери игрока" (target_player): щелчок по строке игрока.
signal player_chosen(player_id: String)
## Карта спросила "возьми войско из трофейного зала": номер варианта.
signal trophy_chosen(index: int)

var _grid: GridContainer
var _rows: Dictionary = {}   # player_id -> {"name": Label, "values": {key: Label}, "trophies": HBoxContainer}
## Выбор игрока прямо в таблице (решение владельца, 2026-09-27): поверх строк,
## которые можно выбрать, — прозрачные кнопки в золотой рамке. Строка таблицы —
## это несколько ячеек сетки, поэтому кнопка отдельная и кладётся по их месту.
var _overlay: Control
var _choice_buttons: Dictionary = {}   # player_id -> Button
var _choice: Array = []
var _blink_time := 0.0
## Рамки на цифрах трофеев: [Button, Label цифры].
var _trophy_buttons: Array = []
## Вопрос стартовой расстановки — показывает game_screen.
var setup_label: Label


func _init() -> void:
	add_theme_stylebox_override("panel", GameScreen.zone_style(2))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	add_child(col)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS.size() + 2
	_grid.add_theme_constant_override("h_separation", COL_GAP)
	_grid.add_theme_constant_override("v_separation", 0)
	col.add_child(_grid)
	_grid.add_child(_cell("", NAME_W, PixelTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	for column: Array in COLUMNS:
		_grid.add_child(_head(String(column[1]), String(column[2]), NUM_W,
			HORIZONTAL_ALIGNMENT_RIGHT))
	var trophy_head := _head("TROPHY", "Trophy hall: killed troops, a number per colour",
		0.0, HORIZONTAL_ALIGNMENT_LEFT)
	trophy_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_child(_indented(trophy_head))

	setup_label = Label.new()
	setup_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	setup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	setup_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	setup_label.visible = false
	col.add_child(setup_label)

	# Слой кнопок выбора: PanelContainer растягивает его на всю панель, кнопки
	# внутри стоят по месту строк (_place_choice).
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	resized.connect(func(): _place_choice.call_deferred())


static func _cell(text: String, width: float, colour: Color,
		align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(width, 0)
	label.horizontal_alignment = align
	label.clip_text = true
	label.add_theme_color_override("font_color", colour)
	return label


static func _head(text: String, hint: String, width: float, align: HorizontalAlignment) -> Label:
	var head := _cell(text, width, PixelTheme.TEXT_DIM, align)
	head.tooltip_text = hint
	head.mouse_filter = Control.MOUSE_FILTER_STOP  # чтобы работала подсказка
	return head


func _add_row(pid: String) -> void:
	var colour: Color = BoardPanel.PLAYER_COLORS.get(pid, PixelTheme.TEXT)
	var name_label := _cell("", NAME_W, colour, HORIZONTAL_ALIGNMENT_LEFT)
	name_label.mouse_filter = Control.MOUSE_FILTER_STOP  # подсказка — полное имя
	_grid.add_child(name_label)
	var values: Dictionary = {}
	for column: Array in COLUMNS:
		var value := _cell("0", NUM_W, PixelTheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		_grid.add_child(value)
		values[String(column[0])] = value
	var trophies := HBoxContainer.new()
	trophies.add_theme_constant_override("separation", 4)
	trophies.clip_contents = true
	trophies.mouse_filter = Control.MOUSE_FILTER_STOP
	_grid.add_child(_indented(trophies))
	_rows[pid] = {"name": name_label, "values": values, "trophies": trophies}


## Цифра трофея: без обрезки — с clip_text ширина Label схлопывается в ноль.
static func _digit(text: String, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", colour)
	return label


## Цифры трофеев: сначала нейтральные, потом игроки в порядке хода.
## Пустой зал — серый 0. В подсказке — то же словами. Возвращает цифры по
## цвету — по ним ставятся рамки выбора трофея (Orcus, Lich).
static func _fill_trophies(box: HBoxContainer, trophies: Dictionary, order: Array) -> Dictionary:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var digits: Dictionary = {}
	var parts: Array[String] = []
	var colours: Array = ["white"]
	colours.append_array(order)
	for colour_id in colours:
		var count := int(trophies.get(String(colour_id), 0))
		if count <= 0:
			continue
		var white := String(colour_id) == "white"
		var digit := _digit(str(count), NEUTRAL_COLOR if white \
			else BoardPanel.PLAYER_COLORS.get(String(colour_id), NEUTRAL_COLOR))
		box.add_child(digit)
		digits[String(colour_id)] = digit
		parts.append("%s %d" % ["neutral" if white else EventLogPanel.player_name(String(colour_id)), count])
	if parts.is_empty():
		box.add_child(_digit("0", PixelTheme.TEXT_OFF))
	box.tooltip_text = "Trophies: " + (", ".join(parts) if not parts.is_empty() else "none")
	return digits


func update_from_view(view: Dictionary) -> void:
	var order: Array = view.get("turn_order", [])
	var current := String(view["current_player"])
	if _rows.is_empty():
		for pid in order:
			_add_row(String(pid))
	for pid: String in _rows:
		var p: Dictionary = (view["players"] as Dictionary).get(pid, {})
		if p.is_empty():
			continue
		var row: Dictionary = _rows[pid]
		var name_text := EventLogPanel.player_name(pid).to_upper()
		(row["name"] as Label).text = (">" + name_text) if pid == current else name_text
		(row["name"] as Label).tooltip_text = EventLogPanel.player_name(pid)
		var values: Dictionary = row["values"]
		for column: Array in COLUMNS:
			var key := String(column[0])
			var raw: Variant = p.get(key, 0)
			var shown: int = (raw as Array).size() if raw is Array else int(raw)
			(values[key] as Label).text = str(shown)
		row["digits"] = _fill_trophies(row["trophies"], p.get("trophies", {}), order)

	# Вопрос "выбери игрока": варианты сервер присылает только решающему, так
	# что у остальных кнопок нет. "" (отказ) — это Skip в строке вопроса.
	var pd: Dictionary = view.get("pending_decision", {})
	_update_trophy_choice(pd)
	_choice = []
	if String(pd.get("choice_type", "")) == "target_player":
		for o in pd.get("legal_options", []):
			if _rows.has(String(o)):
				_choice.append(String(o))
	for pid: String in _rows:
		if not _choice_buttons.has(pid):
			_choice_buttons[pid] = _make_choice_button(pid)
		(_choice_buttons[pid] as Button).visible = _choice.has(pid)
	_place_choice.call_deferred()


func _make_choice_button(pid: String) -> Button:
	var b := _frame_button("Choose %s" % EventLogPanel.player_name(pid))
	b.pressed.connect(func(): player_chosen.emit(pid))
	b.visible = false
	return b


## Прозрачная кнопка в золотой рамке на слое выбора; под курсором — золотой
## подсветкой.
func _frame_button(hint: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = hint
	var normal := PixelTheme.box(Color(PixelTheme.GOLD, 0.0), PixelTheme.GOLD, 1, 0, 0)
	var hover := PixelTheme.box(Color(PixelTheme.GOLD, 0.25), PixelTheme.GOLD, 1, 0, 0)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_overlay.add_child(b)
	return b


## Вопрос "возьми войско из трофейного зала" (Orcus, Lich): рамки прямо на
## цифрах столбца TROPHY — щелчок по цифре берёт войско этого цвета из зала
## этого игрока (решение владельца, 2026-09-27). Вариант i в data.trophies —
## "зал|цвет", в ответ уходит его номер. Отказ (-1) — Skip в строке вопроса.
func _update_trophy_choice(pd: Dictionary) -> void:
	for pair: Array in _trophy_buttons:
		_overlay.remove_child(pair[0])
		(pair[0] as Button).queue_free()
	_trophy_buttons = []
	if String(pd.get("tag", "")) != "trophy_hall":
		return
	var options: Array = (pd.get("data", {}) as Dictionary).get("trophies", [])
	for i in options.size():
		var parts := String(options[i]).split("|")
		if parts.size() != 2 or not _rows.has(parts[0]):
			continue
		var digit: Label = (_rows[parts[0]].get("digits", {}) as Dictionary).get(parts[1])
		if digit == null:
			continue
		var colour_name := "neutral" if parts[1] == "white" else EventLogPanel.player_name(parts[1])
		var b := _frame_button("Take a %s troop from %s's trophy hall"
			% [colour_name, EventLogPanel.player_name(parts[0])])
		var index := i
		b.pressed.connect(func(): trophy_chosen.emit(index))
		_trophy_buttons.append([b, digit])


## Рамки выбора мерцают, пока идёт выбор: таблица далеко от строки вопроса,
## и неподвижную рамку легко не заметить (решение владельца, 2026-09-27).
func _process(delta: float) -> void:
	if _choice.is_empty() and _trophy_buttons.is_empty():
		return
	_blink_time += delta
	var a := 0.35 + 0.65 * (0.5 + 0.5 * cos(_blink_time * TAU * 1.5))
	for pid: String in _choice:
		(_choice_buttons[pid] as Button).self_modulate.a = a
	for pair: Array in _trophy_buttons:
		(pair[0] as Button).self_modulate.a = a


## Кнопка выбора — во всю ширину таблицы по высоте строки игрока.
func _place_choice() -> void:
	var origin := _overlay.get_global_position()
	var grid_rect := _grid.get_global_rect()
	for pid: String in _choice_buttons:
		var b: Button = _choice_buttons[pid]
		if not b.visible:
			continue
		var name_rect := (_rows[pid]["name"] as Label).get_global_rect()
		b.position = Vector2(grid_rect.position.x - 1, name_rect.position.y - 1) - origin
		b.size = Vector2(grid_rect.size.x + 2, name_rect.size.y + 1)
	# Рамка трофея — вокруг цифры, с запасом: цифра шириной в 5 пикселей, в
	# такую трудно попасть.
	for pair: Array in _trophy_buttons:
		var r := (pair[1] as Label).get_global_rect().grow_individual(2, 0, 2, 0)
		(pair[0] as Button).position = r.position - origin
		(pair[0] as Button).size = r.size


## Столбец трофеев чуть отодвинут от IC: иначе первая цифра читается как
## вторая цифра соседнего числа.
static func _indented(control: Control) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", TROPHY_INDENT)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(control)
	return margin
