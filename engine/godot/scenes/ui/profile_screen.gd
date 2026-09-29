class_name ProfileScreen
extends Control

## Профиль игрока: имя и герб. Герб рисуется в маленьком пиксельном
## редакторе, холст которого — сама фишка войска 9x9 (PlayerProfile): ободок
## не красится, пустые пиксели на доске будут цветом места игрока. Целиком
## закрасить нельзя — хотя бы PlayerProfile.MIN_SEAT_PIXELS остаются пустыми.
##
## Левая кнопка мыши — красить, правая — стирать (можно вести с зажатой
## кнопкой). Вёрстка кодом, как у остальных экранов меню.
##
## Вкладка STATS — звание по рейтингу, партии/победы и последние онлайн-партии
## (PlayerProfile.cached_stats / history).
##
## Вкладка COLLECTION — образы карт, рубашки и фон: лутбоксы, пыль, создание и выбор
## (CollectionPage, SkinCollection).

signal closed

## Палитра DawnBringer 32 — классический набор для пиксель-арта; любой другой
## цвет — щелчком по образцу кисти (ColorPickerButton).
const PALETTE := [
	"000000", "222034", "45283c", "663931", "8f563b", "df7126", "d9a066", "eec39a",
	"fbf236", "99e550", "6abe30", "37946e", "4b692f", "524b24", "323c39", "3f3f74",
	"306082", "5b6ee1", "639bff", "5fcde4", "cbdbfc", "ffffff", "9badb7", "847e87",
	"696a6a", "595652", "76428a", "ac3232", "d95763", "d77bba", "8f974a", "8a6f30",
]
const CELL := 18
const SWATCH := 14
const PREVIEW_ZOOM := 3
const RIM := Color(0.04, 0.03, 0.06)
const BUTTON_SIZE := Vector2(70, 16)
const PLACES := ["1ST", "2ND", "3RD", "4TH"]
## Подписи статей VP (PlayerProfile.VP_PARTS) и ширина полоски доли.
const VP_PART_NAMES := {"sites": "SITES", "total_control": "TOTAL CONTROL", "trophies": "TROPHIES",
	"deck": "DECK", "inner_circle": "INNER CIRCLE", "tokens": "VP TOKENS"}
const BAR_W := 60
const UnderdarkBg := preload("res://scenes/ui/underdark_bg.gd")

var _pixels: Array[Color] = []
var _brush := Color("ffffff")
var _seat := "red"
var _name_edit: LineEdit
var _canvas: Control
var _custom: ColorPickerButton
var _previews: Array[TextureRect] = []
var _saved_note: Label
## Сколько пикселей ещё можно закрасить (PlayerProfile.MIN_SEAT_PIXELS).
var _counter: Label
var _first_run := false
## Вкладки: редактор имени и герба / звание, рейтинг и история партий.
var _look: VBoxContainer
var _stats: Control
var _tab_buttons: Array[Button] = []
## Вкладка CHAT: поля фраз колеса чата (PlayerProfile.load_phrases).
var _chat: Control
var _phrase_edits: Array[LineEdit] = []
var _page := "STATS"
## Вкладка COLLECTION: образы карт (CollectionPage).
var _collection: CollectionPage
## Любимый цвет места ("" — любой, PlayerProfile.clean_colour) и рамки его выбора.
var _colour := ""
var _frames: Dictionary = {}
var _any_button: Button


## first_run — первый запуск игры: профиля ещё нет, имя обязательно, CANCEL нет.
func _init(first_run: bool = false) -> void:
	_first_run = first_run
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PixelTheme.theme()
	add_child(UnderdarkBg.make())

	var local := PlayerProfile.load_local()
	_pixels = PlayerProfile.emblem_pixels(String(local["emblem"]))
	_colour = String(local["colour"])
	if _colour != "":
		_seat = _colour

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", GameScreen.zone_style(6))
	centre.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)

	var title := Label.new()
	title.text = "CREATE YOUR PROFILE" if _first_run else "PLAYER PROFILE"
	title.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
	title.add_theme_color_override("font_color", PixelTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	if _first_run:
		var welcome := Label.new()
		welcome.text = "Welcome! Choose a name and draw your emblem."
		welcome.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
		welcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(welcome)

	# Вкладки: EMBLEM — редактор (имя и герб), STATS — звание, рейтинг и история.
	# При первом запуске статистики ещё нет — только редактор.
	_look = VBoxContainer.new()
	_look.add_theme_constant_override("separation", 4)
	if not _first_run:
		var tabs := HBoxContainer.new()
		tabs.alignment = BoxContainer.ALIGNMENT_CENTER
		tabs.add_theme_constant_override("separation", 6)
		col.add_child(tabs)
		var group := ButtonGroup.new()
		# STATS первой и открыта сразу (решение владельца, 2026-09-28).
		for tab: String in ["STATS", "EMBLEM", "CHAT", "COLLECTION"]:
			var b := _button(tab, _show_tab.bind(tab))
			b.toggle_mode = true
			b.button_group = group
			b.button_pressed = tab == "STATS"
			tabs.add_child(b)
			_tab_buttons.append(b)
		_stats = _stats_page()
		col.add_child(_stats)
		_chat = _chat_page()
		col.add_child(_chat)
		_chat.visible = false
		# Образы карт: лутбоксы, пыль, создание и выбор (SkinCollection).
		_collection = CollectionPage.new()
		col.add_child(_collection)
		_collection.visible = false
		_look.visible = false
	col.add_child(_look)

	_look.add_child(GameScreen.section_label("NAME (ONLINE, EVERY NAME IS UNIQUE)"))
	_name_edit = LineEdit.new()
	_name_edit.max_length = PlayerProfile.NAME_MAX
	_name_edit.placeholder_text = "Your name"
	_name_edit.text = String(local["name"])
	_name_edit.custom_minimum_size = Vector2(160, 0)
	_name_edit.text_submitted.connect(func(_t: String): _save())
	if _first_run:
		_name_edit.grab_focus.call_deferred()
	_name_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_look.add_child(_name_edit)

	_look.add_child(HSeparator.new())
	_look.add_child(GameScreen.section_label("EMBLEM: YOUR TROOP ON THE BOARD"))
	var editor := HBoxContainer.new()
	editor.add_theme_constant_override("separation", 10)
	editor.alignment = BoxContainer.ALIGNMENT_CENTER
	_look.add_child(editor)

	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(CELL * PlayerProfile.SIZE + 1, CELL * PlayerProfile.SIZE + 1)
	_canvas.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_canvas)
	_canvas.gui_input.connect(_canvas_input)
	editor.add_child(_canvas)

	editor.add_child(_tools())

	# Ряд фишек всех цветов — он же выбор любимого цвета (рамка у выбранного;
	# ANY — без предпочтения).
	_look.add_child(GameScreen.section_label("YOUR COLOUR (CLICK TO CHOOSE)"))
	var previews := HBoxContainer.new()
	previews.add_theme_constant_override("separation", 8)
	previews.alignment = BoxContainer.ALIGNMENT_CENTER
	_look.add_child(previews)
	for pid: String in GameRoom.PLAYER_IDS:
		var frame := PanelContainer.new()
		frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		previews.add_child(frame)
		_frames[pid] = frame
		var big := TextureRect.new()
		big.custom_minimum_size = Vector2.ONE * PlayerProfile.SIZE * PREVIEW_ZOOM
		big.stretch_mode = TextureRect.STRETCH_SCALE
		big.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		big.tooltip_text = pid.capitalize()
		big.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				choose_colour(pid))
		frame.add_child(big)
		var small := TextureRect.new()
		small.custom_minimum_size = Vector2.ONE * PlayerProfile.SIZE
		small.stretch_mode = TextureRect.STRETCH_KEEP
		small.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		small.mouse_filter = Control.MOUSE_FILTER_IGNORE
		previews.add_child(small)
		_previews.append(big)
		_previews.append(small)
	_any_button = _button("ANY", func(): choose_colour(""))
	_any_button.toggle_mode = true
	_any_button.custom_minimum_size = Vector2(30, 16)
	_any_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_any_button.tooltip_text = "No favourite colour."
	previews.add_child(_any_button)

	var hint := Label.new()
	hint.text = "Left mouse: paint. Right mouse: erase.\nOnline you get your colour if nobody chose it first."
	hint.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_look.add_child(hint)

	col.add_child(HSeparator.new())
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 6)
	col.add_child(buttons)
	buttons.add_child(_button("CREATE" if _first_run else "SAVE", _save))
	if not _first_run:
		buttons.add_child(_button("CANCEL", func(): closed.emit()))
	_saved_note = Label.new()
	_saved_note.add_theme_color_override("font_color", PixelTheme.GOLD)
	_saved_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_saved_note)

	_refresh_previews()
	_refresh_counter()
	_refresh_frames()


## Выбрать любимый цвет ("" — любой). Холст показывает герб на этом цвете.
func choose_colour(colour: String) -> void:
	_colour = PlayerProfile.clean_colour(colour)
	if _colour != "":
		_seat = _colour
		_canvas.queue_redraw()
	_refresh_frames()


func _refresh_frames() -> void:
	for pid: String in _frames:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0, 0, 0, 0)
		box.border_color = PixelTheme.GOLD if pid == _colour else Color(0, 0, 0, 0)
		box.set_border_width_all(1)
		box.set_content_margin_all(2)
		(_frames[pid] as PanelContainer).add_theme_stylebox_override("panel", box)
	_any_button.set_pressed_no_signal(_colour == "")


## Палитра, текущий цвет (он же выбор любого цвета) и ERASE ALL.
func _tools() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 1)
	grid.add_theme_constant_override("v_separation", 1)
	box.add_child(grid)
	for hex: String in PALETTE:
		var swatch := ColorRect.new()
		swatch.color = Color(hex)
		swatch.custom_minimum_size = Vector2(SWATCH, SWATCH)
		swatch.tooltip_text = "#" + hex
		swatch.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_set_brush(Color(hex)))
		grid.add_child(swatch)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	box.add_child(row)
	var label := Label.new()
	label.text = "BRUSH"
	label.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	row.add_child(label)
	# Сам образец кисти — кнопка выбора любого цвета.
	_custom = ColorPickerButton.new()
	_custom.edit_alpha = false
	_custom.color = _brush
	_custom.custom_minimum_size = Vector2(SWATCH * 3, SWATCH)
	_custom.tooltip_text = "Click to pick any colour"
	SetupScreen._style_button(_custom)
	_custom.color_changed.connect(_set_brush)
	row.add_child(_custom)
	var any := Label.new()
	any.text = "< any colour"
	any.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	row.add_child(any)

	_counter = Label.new()
	box.add_child(_counter)

	box.add_child(_button("ERASE ALL", func():
		_pixels.fill(Color(0, 0, 0, 0))
		_changed()))
	return box


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_SIZE
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	SetupScreen._style_button(b)
	b.pressed.connect(action)
	return b


func _set_brush(colour: Color) -> void:
	_brush = Color(colour, 1.0)
	_custom.color = _brush


func _canvas_input(event: InputEvent) -> void:
	var mask := 0
	if event is InputEventMouseButton and event.pressed:
		mask = MOUSE_BUTTON_MASK_LEFT if event.button_index == MOUSE_BUTTON_LEFT \
			else MOUSE_BUTTON_MASK_RIGHT if event.button_index == MOUSE_BUTTON_RIGHT else 0
	elif event is InputEventMouseMotion:
		mask = event.button_mask
	if mask == 0:
		return
	var cell := Vector2i((event.position / CELL).floor())
	paint(cell.x, cell.y, _brush if mask & MOUSE_BUTTON_MASK_LEFT else Color(0, 0, 0, 0))
	_canvas.accept_event()


## Покрасить одну клетку (прозрачный цвет — стереть). Вне кружка — ничего.
func paint(x: int, y: int, colour: Color) -> void:
	if x < 0 or y < 0 or x >= PlayerProfile.SIZE or y >= PlayerProfile.SIZE:
		return
	if not PlayerProfile.paintable(x, y):
		return
	var i := y * PlayerProfile.SIZE + x
	if _pixels[i] == colour:
		return
	# Новый закрашенный пиксель — только пока цвета места остаётся достаточно.
	if colour.a > 0.0 and _pixels[i].a == 0.0 \
			and PlayerProfile.painted_count(_pixels) >= PlayerProfile.max_painted():
		_saved_note.text = "Keep at least %d pixels in your seat colour." % PlayerProfile.MIN_SEAT_PIXELS
		return
	_pixels[i] = colour
	_changed()


func _changed() -> void:
	_saved_note.text = ""
	_canvas.queue_redraw()
	_refresh_previews()
	_refresh_counter()


func _refresh_counter() -> void:
	var left := PlayerProfile.max_painted() - PlayerProfile.painted_count(_pixels)
	_counter.text = "Pixels left to paint: %d" % left
	_counter.add_theme_color_override("font_color", PixelTheme.GOLD if left == 0 else PixelTheme.TEXT_DIM)


func emblem() -> String:
	return PlayerProfile.emblem_from_pixels(_pixels)


func _draw_canvas() -> void:
	var seat_colour: Color = BoardPanel.PLAYER_COLORS.get(_seat, Color.GRAY)
	var r := PlayerProfile.RADIUS
	for y in PlayerProfile.SIZE:
		for x in PlayerProfile.SIZE:
			var rect := Rect2(x * CELL + 1, y * CELL + 1, CELL - 1, CELL - 1)
			var dx := x - r
			var dy := y - r
			var colour := PixelTheme.PANEL_LO if (x + y) % 2 == 0 else PixelTheme.PANEL
			if PlayerProfile.paintable(x, y):
				var px := _pixels[y * PlayerProfile.SIZE + x]
				colour = px if px.a > 0.0 else seat_colour
			elif dx * dx + dy * dy <= r * r + r:
				colour = RIM
			_canvas.draw_rect(rect, colour)
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.custom_minimum_size), PixelTheme.BORDER, false, 1.0)


func _refresh_previews() -> void:
	var e := emblem()
	for i in _previews.size():
		var pid: String = GameRoom.PLAYER_IDS[i / 2]
		var tex := ImageTexture.create_from_image(
			SchematicPainter.token(BoardPanel.PLAYER_COLORS.get(pid, Color.GRAY), e))
		_previews[i].texture = tex


func _save() -> void:
	var name_text := PlayerProfile.clean_name(_name_edit.text)
	_name_edit.text = name_text
	if _first_run and name_text == "":
		_saved_note.text = "Enter a name (letters and digits)."
		if _name_edit.is_inside_tree():
			_name_edit.grab_focus()
		return
	var err := PlayerProfile.save_local({"name": name_text, "emblem": emblem(), "colour": _colour})
	if err == OK and not _phrase_edits.is_empty():
		err = PlayerProfile.save_phrases(phrases())
	if err == OK:
		closed.emit()
	else:
		_saved_note.text = "Could not save the profile (error %d)." % err


## Размеры страниц выравниваются, только когда экран уже в сцене и надписи
## перемерены пиксельным шрифтом темы — поэтому на кадр позже.
func _ready() -> void:
	if _stats != null:
		_show_tab.call_deferred(_page)


## page — STATS, EMBLEM, CHAT или COLLECTION.
func _show_tab(page: String) -> void:
	_page = page
	var pages := {"STATS": _stats, "EMBLEM": _look, "CHAT": _chat, "COLLECTION": _collection}
	# Окно не прыгает: все страницы одного размера — большей из них
	# (решение владельца, 2026-09-30: и COLLECTION тоже).
	var need := Vector2.ZERO
	for p: Control in pages.values():
		p.custom_minimum_size = Vector2.ZERO
	for p: Control in pages.values():
		need = need.max(p.get_combined_minimum_size())
	for key: String in pages:
		(pages[key] as Control).custom_minimum_size = need
		(pages[key] as Control).visible = key == page
	if _collection.visible:
		_collection.refresh()
	for b: Button in _tab_buttons:
		b.set_pressed_no_signal(b.text == page)


## Вкладка CHAT: фразы колеса чата (Tab зажат в партии), по одной на сторону.
## Пустая строка — фраза по умолчанию (она же видна подсказкой в поле).
func _chat_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 4)
	page.add_child(GameScreen.section_label("CHAT WHEEL: HOLD TAB IN A GAME, MOVE THE MOUSE, RELEASE"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page.add_child(grid)
	var phrases := PlayerProfile.load_phrases()
	for i in PlayerProfile.PHRASE_COUNT:
		var side := Label.new()
		side.text = ["UP", "RIGHT", "DOWN", "LEFT"][i]
		side.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
		grid.add_child(side)
		var edit := LineEdit.new()
		edit.max_length = PlayerProfile.PHRASE_MAX
		edit.placeholder_text = PlayerProfile.DEFAULT_PHRASES[i]
		edit.text = phrases[i]
		edit.custom_minimum_size = Vector2(6 * PlayerProfile.PHRASE_MAX + 8, 0)
		edit.text_submitted.connect(func(_t: String): _save())
		grid.add_child(edit)
		_phrase_edits.append(edit)
	var hint := Label.new()
	hint.text = "Up to %d characters. An empty line gets the default phrase.\nTap TAB in a game to ping the spot under the mouse." \
		% PlayerProfile.PHRASE_MAX
	hint.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(hint)
	return page


func phrases() -> Array[String]:
	var out: Array[String] = []
	for edit in _phrase_edits:
		out.append(PlayerProfile.clean_phrase(edit.text))
	return out


## Вкладка STATS: звание, рейтинг, партии/победы и последние онлайн-партии.
## Всё — как сервер сообщил в последний раз (PlayerProfile.cached_stats/history).
func _stats_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 4)
	var stats := PlayerProfile.cached_stats()
	var rating := int(stats["rating"])

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(head)
	head.add_child(rank_badge(rating, 3))
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	head.add_child(words)
	var title := Label.new()
	title.text = PlayerProfile.rank_title(rating)
	title.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
	title.add_theme_color_override("font_color", PlayerProfile.rank_colour(rating))
	words.add_child(title)
	var sub := Label.new()
	sub.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	words.add_child(sub)
	if rating < 0:
		sub.text = "Play an online game to get a rating."
		return page
	var i := PlayerProfile.rank_index(rating)
	sub.text = "RATING %d" % rating
	if i + 1 < PlayerProfile.RANKS.size():
		sub.text += "   NEXT: %s AT %d" % [PlayerProfile.RANKS[i + 1][1], PlayerProfile.RANKS[i + 1][0]]

	var games := int(stats["games"])
	var wins := int(stats["wins"])
	var numbers := HBoxContainer.new()
	numbers.alignment = BoxContainer.ALIGNMENT_CENTER
	numbers.add_theme_constant_override("separation", 16)
	page.add_child(numbers)
	for pair in [["GAMES", str(games)], ["WINS", str(wins)],
			["WIN RATE", "%d%%" % roundi(100.0 * wins / games) if games > 0 else "-"]]:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		numbers.add_child(box)
		var value := Label.new()
		value.text = pair[1]
		value.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
		value.add_theme_color_override("font_color", PixelTheme.TEXT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(value)
		var caption := Label.new()
		caption.text = pair[0]
		caption.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(caption)

	page.add_child(HSeparator.new())
	# Ниже две колонки: слева — статистика по самой игре, справа — история.
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(body)
	body.add_child(_game_stats())
	body.add_child(VSeparator.new())
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	body.add_child(right)
	right.add_child(GameScreen.section_label("LAST ONLINE GAMES"))
	var list := PlayerProfile.history()
	if list.is_empty():
		right.add_child(_cell("No games recorded yet.", PixelTheme.TEXT_DIM))
		return page
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 2)
	right.add_child(grid)
	for header in ["DATE", "PLAYERS", "PLACE", "VP", "RATING"]:
		grid.add_child(_cell(header, PixelTheme.TEXT_DIM))
	for game: Dictionary in list:
		grid.add_child(_cell(_date(int(game.get("time", 0))), PixelTheme.TEXT_DIM))
		grid.add_child(_history_players(game))
		var place := int(game.get("place", 0))
		grid.add_child(_cell(PLACES[clampi(place - 1, 0, PLACES.size() - 1)],
			PixelTheme.GOLD if place == 1 else PixelTheme.TEXT))
		grid.add_child(_cell(str(int(game.get("vp", 0))), PixelTheme.TEXT))
		var delta := int(game.get("delta", 0))
		var rating_row := HBoxContainer.new()
		rating_row.add_theme_constant_override("separation", 4)
		rating_row.add_child(_cell(str(int(game.get("rating", 0))), PixelTheme.TEXT))
		rating_row.add_child(_cell("%+d" % delta, Color("5fd36a") if delta > 0
			else (PixelTheme.DANGER if delta < 0 else PixelTheme.TEXT_DIM)))
		grid.add_child(rating_row)
	return page


## Статистика по самой игре (PlayerProfile.totals): средние VP по статьям с
## полосками, полуколоды с процентом побед, рекорды.
func _game_stats() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	var t := PlayerProfile.totals()
	var games := int(t["games"])
	col.add_child(GameScreen.section_label("AVERAGE PER GAME"))
	if games == 0:
		col.add_child(_cell("Play an online game\nto collect statistics.", PixelTheme.TEXT_DIM))
		return col

	var avg := float(t["vp"]) / games
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 2)
	col.add_child(grid)
	grid.add_child(_cell("VP", PixelTheme.GOLD))
	grid.add_child(_cell("%.1f" % avg, PixelTheme.GOLD))
	grid.add_child(Control.new())
	for key: String in PlayerProfile.VP_PARTS:
		var value := float(t["parts"].get(key, 0)) / games
		grid.add_child(_cell(String(VP_PART_NAMES[key]), PixelTheme.TEXT_DIM))
		grid.add_child(_cell("%.1f" % value, PixelTheme.TEXT))
		grid.add_child(_bar(value / maxf(avg, 1.0), PixelTheme.GOLD))

	col.add_child(GameScreen.section_label("HALF-DECKS"))
	var decks: Dictionary = t["decks"]
	var names: Array = decks.keys()
	names.sort_custom(func(a, b) -> bool: return int(decks[a]["games"]) > int(decks[b]["games"]))
	var deck_grid := GridContainer.new()
	deck_grid.columns = 3
	deck_grid.add_theme_constant_override("h_separation", 6)
	deck_grid.add_theme_constant_override("v_separation", 2)
	col.add_child(deck_grid)
	for deck: String in names:
		var d: Dictionary = decks[deck]
		var played := int(d["games"])
		var colour: Color = UnderdarkBg.DECK_COLOURS.get(deck, PixelTheme.TEXT).lightened(0.35)
		deck_grid.add_child(_cell(deck.to_upper(), colour))
		deck_grid.add_child(_cell("%d games" % played, PixelTheme.TEXT_DIM))
		deck_grid.add_child(_cell("%d%% wins" % roundi(100.0 * int(d["wins"]) / played), PixelTheme.TEXT))

	col.add_child(GameScreen.section_label("RECORDS"))
	for pair in [["BEST VP", t["best_vp"]], ["MOST TROPHIES", t["most_trophies"]],
			["MOST INNER CIRCLE", t["most_ic"]]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(_cell(String(pair[0]), PixelTheme.TEXT_DIM))
		row.add_child(_cell(str(int(pair[1])), PixelTheme.GOLD))
		col.add_child(row)
	return col



## Полоска доли (0..1) шириной до BAR_W — сплошная, пиксель-арт.
func _bar(share: float, colour: Color) -> Control:
	var back := ColorRect.new()
	back.color = PixelTheme.PANEL_LO
	back.custom_minimum_size = Vector2(BAR_W, 5)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := ColorRect.new()
	fill.color = colour
	fill.size = Vector2(roundf(BAR_W * clampf(share, 0.0, 1.0)), 5)
	back.add_child(fill)
	return back


func _cell(text: String, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", colour)
	return label


## "28.09 14:05" по местному времени.
static func _date(unix: int) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var d := Time.get_datetime_dict_from_unix_time(unix + bias * 60)
	return "%02d.%02d %02d:%02d" % [d["day"], d["month"], d["hour"], d["minute"]]


## Фишки всех игроков партии (победитель первым); подсказка — имена и VP.
func _history_players(game: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	for p: Dictionary in game.get("players", []):
		var icon := token_icon(String(p.get("seat", "")), String(p.get("emblem", "")))
		var who := String(p.get("name", ""))
		if String(p.get("seat", "")) == String(game.get("seat", "")):
			who += " (you)"
		icon.tooltip_text = "%s: %d VP%s" % [who, int(p.get("vp", 0)), ", winner" if p.get("won", false) else ""]
		row.add_child(icon)
	return row


## Значок звания (камень цвета звания), zoom — во сколько раз крупнее.
static func rank_badge(rating: int, zoom: int = 1) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = ImageTexture.create_from_image(PlayerProfile.rank_icon(rating))
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2.ONE * PlayerProfile.RANK_ICON * zoom
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.tooltip_text = PlayerProfile.rank_title(rating)
	return icon


## Значок фишки игрока (цвет места + его герб) для списков в меню и лобби.
static func token_icon(pid: String, emblem_hex: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = ImageTexture.create_from_image(
		SchematicPainter.token(BoardPanel.PLAYER_COLORS.get(pid, Color.GRAY), emblem_hex))
	icon.stretch_mode = TextureRect.STRETCH_KEEP
	icon.custom_minimum_size = Vector2.ONE * PlayerProfile.SIZE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon
