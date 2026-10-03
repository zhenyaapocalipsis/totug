class_name PlayersPanel
extends PanelContainer

## Расклад по игрокам в правой колонке под бараками (решение владельца,
## 2026-09-27: переехал сюда из меню по Tab на место зоны сыгранных карт —
## сыгранные карты и так видны в сводке ходов слева).
##
## Таблица: по две строки на игрока в порядке хода (первый блок — первый
## игрок). Первая строка — фишка с эмблемой и ник, вторая — все цифры игрока
## в одну линию (владелец, 2026-09-28): числа по столбцам шапки и за ними зал
## трофеев. Колонка шириной в рынок (две мелкие карты), и ник с цифрами в одну
## строку не влезает. Ходящий — блок на светлой подложке. Скрытых
## сведений нет: рука и сброс противника — только числом карт (так их и
## отдаёт StateView). Зал трофеев — по цифре на каждый цвет убитых фишек, цифра
## того же цвета. Вопрос стартовой расстановки — строкой над доской
## (DecisionDialog), не здесь.

## Числовые столбцы: ключ в срезе игрока, заголовок, подсказка к заголовку.
const COLUMNS: Array[Array] = [
	["vp_tokens", "VP", "Victory point tokens"],
	["hand_size", "HD", "Cards in hand"],
	["deck_size", "DK", "Cards in deck"],
	["discard_size", "DS", "Cards in discard pile"],
	["inner_circle", "IC", "Cards in Inner Circle"],
]
## Фишка войска с эмблемой (9 пикселей и 2 отступа); строка цифр начинается
## от левого края панели. Числовой столбец — 2 знака.
const TOKEN_W := 11.0
const NUM_W := 12.0
const COL_GAP := 3
## Лишний зазор перед залом трофеев: иначе последняя цифра IC читается как
## первая цифра зала.
const HALL_GAP := 3.0
## Строка цифр наезжает на пустой низ строки ника: глиф 7 пикселей в
## строке 11, так четыре блока с шапкой влезают над рынком.
const LINE_OVERLAP := 2
## Сколько пикселей от правого края панели до конца видимой части таблицы
## (рамка и отступ зоны).
const TROPHY_RIGHT_PAD := 2.0
## Нейтральные (белые) убитые войска — серой цифрой.
const NEUTRAL_COLOR := Color(0.6, 0.6, 0.6)

## Карта спросила "выбери игрока" (target_player): щелчок по строке игрока.
signal player_chosen(player_id: String)
## Карта спросила "возьми войско из трофейного зала": номер варианта.
signal trophy_chosen(index: int)

var _list: VBoxContainer
var _rows: Dictionary = {}   # player_id -> {"block": PanelContainer, "name": Label, "values": {key: Label}, "trophies": HBoxContainer}
var _current_style: StyleBoxFlat
var _plain_style: StyleBoxEmpty
## Выбор игрока прямо в таблице (решение владельца, 2026-09-27): поверх строк,
## которые можно выбрать, — прозрачные кнопки в золотой рамке. Строка таблицы —
## это несколько ячеек сетки, поэтому кнопка отдельная и кладётся по их месту.
var _overlay: Control
var _choice_buttons: Dictionary = {}   # player_id -> Button
var _choice: Array = []
var _blink_time := 0.0
## Рамки на цифрах трофеев: [Button, цифра (Label или SmallNumber)].
var _trophy_buttons: Array = []


func _init() -> void:
	add_theme_stylebox_override("panel", GameScreen.zone_style(2))
	_current_style = PixelTheme.box(PixelTheme.PANEL_HI, PixelTheme.PANEL_HI, 0, 0, 0)
	_plain_style = StyleBoxEmpty.new()
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 0)
	add_child(_list)

	# Шапка — над строкой чисел: те же отступ и ширины столбцов.
	var head_row := _numbers_row()
	_list.add_child(head_row)
	for column: Array in COLUMNS:
		head_row.add_child(_head(String(column[1]), String(column[2]), NUM_W,
			HORIZONTAL_ALIGNMENT_RIGHT))
	var hall_head := _head("HALL", "Trophy hall: killed troops, a number per colour",
		0.0, HORIZONTAL_ALIGNMENT_LEFT)
	hall_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(_hall_gap())
	head_row.add_child(hall_head)

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
	var block := PanelContainer.new()
	block.add_theme_stylebox_override("panel", _plain_style)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_child(block)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", -LINE_OVERLAP)
	block.add_child(lines)
	# Первая строка: фишка войска с эмблемой игрока (как на доске, решение
	# владельца 2026-09-27) и ник.
	var name_cell := HBoxContainer.new()
	name_cell.add_theme_constant_override("separation", 0)
	lines.add_child(name_cell)
	var token := TextureRect.new()
	token.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	# Заглавные пиксельного шрифта сидят выше середины строки — фишку
	# поднимаем: прямоугольник на 4 пикселя ниже фишки, по центру его она
	# выступает вверх на 2. Так центр фишки на одной линии с серединой ника и
	# чисел (владелец, 2026-09-28).
	token.custom_minimum_size = Vector2(TOKEN_W, BoardSchematic.SLOT_R * 2 + 1 - 4)
	token.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	token.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	name_cell.add_child(token)
	var name_label := _cell("", 0.0, colour, HORIZONTAL_ALIGNMENT_LEFT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_STOP  # подсказка — полное имя
	# Щелчок по имени — карточка игрока (звание, рейтинг, партии).
	ProfileCard.attach(name_label, pid, func(): return (PlayerProfile.seats.get(pid, {}) as Dictionary))
	name_cell.add_child(name_label)
	# Вторая строка — все цифры игрока в одну линию: числа по столбцам шапки,
	# за ними зал трофеев (владелец, 2026-09-28).
	var numbers := _numbers_row()
	lines.add_child(numbers)
	var values: Dictionary = {}
	for column: Array in COLUMNS:
		var value := _cell("0", NUM_W, PixelTheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		numbers.add_child(value)
		values[String(column[0])] = value
	var trophies := HBoxContainer.new()
	trophies.add_theme_constant_override("separation", 3)
	trophies.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trophies.clip_contents = true
	trophies.mouse_filter = Control.MOUSE_FILTER_STOP
	numbers.add_child(_hall_gap())
	numbers.add_child(trophies)
	_rows[pid] = {"block": block, "name": name_label, "token": token, "token_key": null,
		"values": values, "trophies": trophies}


## Строка столбцов (шапка или цифры игрока): от левого края панели, без
## отступа под фишку (владелец, 2026-10-03), столбцы через COL_GAP.
static func _numbers_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", COL_GAP)
	return row


## Цифра трофея: без обрезки — с clip_text ширина Label схлопывается в ноль.
## small — мелкий шрифт 3x5 (как VP на доске), запасной: столбец рассчитан
## на четыре двузначных числа обычным шрифтом, мелкий — если вдруг не влезут.
static func _digit(text: String, colour: Color, small: bool = false) -> Control:
	if small:
		return SmallNumber.new(text, colour)
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", colour)
	return label


## Число мелким пиксельным шрифтом 3x5, по высоте строки таблицы.
class SmallNumber extends Control:
	var text: String
	var colour: Color

	func _init(t: String, c: Color) -> void:
		text = t
		colour = c
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(PixelFontSmall.text_width(t), PixelTheme.LINE_H)

	func _draw() -> void:
		# Низ цифр — на уровне низа обычных цифр строки.
		var y0 := int(size.y) - PixelFontSmall.HEIGHT - 4
		for i in text.length():
			var rows: Array = PixelFontSmall.glyph(text[i])
			for ry in rows.size():
				var row: String = rows[ry]
				for rx in row.length():
					if row[rx] == "1":
						draw_rect(Rect2(i * PixelFontSmall.ADVANCE + rx, y0 + ry, 1, 1), colour)


## Цифры трофеев: сначала нейтральные, потом игроки в порядке хода.
## Пустой зал — серый 0. В подсказке — то же словами. Возвращает цифры по
## цвету — по ним ставятся рамки выбора трофея (Orcus, Lich).
static func _fill_trophies(box: HBoxContainer, trophies: Dictionary, order: Array,
		small: bool = false) -> Dictionary:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	# Через 3 пикселя: рамки выбора на соседних числах не слипаются.
	box.add_theme_constant_override("separation", 3)
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
			else BoardPanel.PLAYER_COLORS.get(String(colour_id), NEUTRAL_COLOR), small)
		box.add_child(digit)
		digits[String(colour_id)] = digit
		parts.append("%s %d" % ["neutral" if white else EventLogPanel.player_name(String(colour_id)), count])
	if parts.is_empty():
		box.add_child(_digit("0", PixelTheme.TEXT_OFF, small))
	box.tooltip_text = "Trophies: " + (", ".join(parts) if not parts.is_empty() else "none")
	return digits


## Трофей засчитан: его цифра вспыхивает и гаснет, как барак, принявший фишку.
func flash_trophy(pid: String, colour_id: String) -> void:
	if not _rows.has(pid):
		return
	var digit: Control = (_rows[pid].get("digits", {}) as Dictionary).get(colour_id)
	var target: Control = digit if digit != null and is_instance_valid(digit) \
		else _rows[pid]["trophies"]
	var bright := BarracksBar.KICK_BRIGHT
	target.modulate = Color(bright, bright, bright)
	target.create_tween().tween_property(target, "modulate", Color.WHITE, BarracksBar.KICK_TIME)


## Блок игрока на экране (для облачка фразы чата); null — строки нет.
func row_rect(pid: String) -> Variant:
	if not _rows.has(pid):
		return null
	return ((_rows[pid] as Dictionary)["block"] as Control).get_global_rect()


func update_from_view(view: Dictionary) -> void:
	var order: Array = view.get("turn_order", [])
	var current := GameScreen.acting_player(view)
	if _rows.is_empty():
		for pid in order:
			_add_row(String(pid))
	for pid: String in _rows:
		var p: Dictionary = (view["players"] as Dictionary).get(pid, {})
		if p.is_empty():
			continue
		var row: Dictionary = _rows[pid]
		(row["block"] as PanelContainer).add_theme_stylebox_override("panel",
			_current_style if pid == current else _plain_style)
		(row["name"] as Label).text = EventLogPanel.player_name(pid).to_upper()
		# Эмблема может смениться (игрок по сети прислал профиль) — фишку
		# перерисовываем только тогда.
		var emblem := PlayerProfile.emblem_of(pid)
		if row["token_key"] == null or String(row["token_key"]) != emblem:
			row["token_key"] = emblem
			(row["token"] as TextureRect).texture = ImageTexture.create_from_image(
				SchematicPainter.token(BoardPanel.troop_colour(pid), emblem))
		(row["name"] as Label).tooltip_text = EventLogPanel.player_name(pid)
		var values: Dictionary = row["values"]
		for column: Array in COLUMNS:
			var key := String(column[0])
			var raw: Variant = p.get(key, 0)
			var shown: int = (raw as Array).size() if raw is Array else int(raw)
			(values[key] as Label).text = str(shown)
		row["digits"] = _fill_trophies(row["trophies"], p.get("trophies", {}), order)
	# Не влезают числа хотя бы одного зала — все залы мелким шрифтом, чтобы
	# строки были одинаковыми. Место считаем по постоянным ширинам: строка сама
	# раздвигается под числа и уходит за край панели (там её обрезает), а
	# раскладки на момент обновления ещё может не быть.
	var small := false
	var room := size.x - 2.0 * TROPHY_RIGHT_PAD - (NUM_W + COL_GAP) * COLUMNS.size() \
		- HALL_GAP
	for pid: String in _rows:
		var box: HBoxContainer = _rows[pid]["trophies"]
		if size.x > 0.0 and box.get_combined_minimum_size().x > room:
			small = true
	if small:
		for pid: String in _rows:
			var p2: Dictionary = (view["players"] as Dictionary).get(pid, {})
			if not p2.is_empty():
				_rows[pid]["digits"] = _fill_trophies(_rows[pid]["trophies"], p2.get("trophies", {}), order, true)

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
## цифрах зала (HALL) — щелчок по цифре берёт войско этого цвета из зала
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
		var digit: Control = (_rows[parts[0]].get("digits", {}) as Dictionary).get(parts[1])
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


## Кнопка выбора — по блоку игрока (обе его строки).
func _place_choice() -> void:
	var origin := _overlay.get_global_position()
	for pid: String in _choice_buttons:
		var b: Button = _choice_buttons[pid]
		if not b.visible:
			continue
		var r := (_rows[pid]["block"] as Control).get_global_rect().grow(1)
		b.position = r.position - origin
		b.size = r.size
	# Рамка трофея — вокруг числа с пикселем запаса: соседние числа стоят через
	# 3-4 пикселя, и рамки с большим запасом наезжали друг на друга.
	for pair: Array in _trophy_buttons:
		var r := (pair[1] as Control).get_global_rect().grow_individual(1, 0, 1, 0)
		(pair[0] as Button).position = r.position - origin
		(pair[0] as Button).size = r.size



## Промежуток перед залом трофеев в строке столбцов (HALL_GAP плюс COL_GAP ряда).
static func _hall_gap() -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(HALL_GAP, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap
