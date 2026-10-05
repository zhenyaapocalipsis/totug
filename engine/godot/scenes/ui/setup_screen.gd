class_name SetupScreen
extends Control

## Главное меню по образцу Dota 2 (макет владельца, 2026-10-06):
##
##   сверху полоса с названием игры;
##   под ней строка кнопок NEWS, PROFILE, PLAY, SETTINGS, EXIT;
##   ниже, на весь остаток экрана, окно с тем, что открыла кнопка:
##     NEWS     — патчноуты: заголовки коммитов по дням (PatchNotes), прокрутка;
##     PROFILE  — профиль (ProfileScreen): столбец STATS / EMBLEM / CHAT /
##                COLLECTION слева;
##     PLAY     — столбец ONLINE / LOBBY / HOTSEAT / HOW TO PLAY слева, большая
##                кнопка в правом нижнем углу (SEARCH, CREATE ROOM, START, OPEN),
##                рядом с ней строка-подсказка: что сделает кнопка под мышью;
##     SETTINGS — громкость звуков и музыки, полный экран;
##   EXIT закрывает игру.
##
## Страница меню — вкладка или раздел PLAY (current_page, show_page).
## GameScreen получает уже готовый список цветов — экран партии ничего не
## знает про меню. Вёрстка кодом по той же причине, что и в game_screen.gd:
## .tscn в этом проекте правится вслепую, без редактора.

signal started(player_ids: Array[String], mode: String)
## Сетевая игра. kind: "create" / "join_code" — через сервер с кодами комнат,
## "host" / "join_ip" — напрямую по IP (локальная сеть, Radmin VPN),
## "find" — поиск игры на сервере (режим по размеру стола: NetSession.match_mode),
## "resume" — вернуться в незаконченную онлайн-партию (NetSession.saved_game).
signal online_requested(kind: String, player_count: int, mode: String)
## Открыть обучение для новичков (how_to_play_screen.gd).
signal how_to_play_requested

const MODE_TITLES := {
	"standard": "STANDARD",
	"double": "DOUBLE",
	"random3": "RANDOM 3",
	"random4": "RANDOM 4",
	"random6": "RANDOM 6",
}
const MODE_NOTES := {
	"standard": "Market: two random half-decks.",
	"double": "Market: one random half-deck, taken twice.",
	"random3": "Market: 3 random half-decks, 20 cards of each aspect.",
	"random4": "Market: 4 random half-decks, 20 cards of each aspect.",
	"random6": "Market: 6 random half-decks, 20 cards of each aspect.",
}

## Вкладки (кнопки под названием).
const PAGE_NEWS := "news"
const PAGE_PROFILE := "profile"
const PAGE_PLAY := "play"
const PAGE_SETTINGS := "settings"
const TABS: Array[String] = [PAGE_NEWS, PAGE_PROFILE, PAGE_PLAY, PAGE_SETTINGS]
## Ширины кнопок вкладок и EXIT — доли, как на макете владельца.
const TAB_RATIOS := {PAGE_NEWS: 2.1, PAGE_PROFILE: 3.0, PAGE_PLAY: 6.1, PAGE_SETTINGS: 3.4, "exit": 4.0}
## Разделы PLAY (столбец слева в окне).
const PAGE_ONLINE := "online"
const PAGE_LOBBY := "lobby"
const PAGE_HOTSEAT := "hotseat"
const PAGE_HOW_TO_PLAY := "how_to_play"
const PLAY_SECTIONS: Array[String] = [PAGE_ONLINE, PAGE_LOBBY, PAGE_HOTSEAT, PAGE_HOW_TO_PLAY]
const SECTION_TITLES := {PAGE_ONLINE: "ONLINE", PAGE_LOBBY: "LOBBY", PAGE_HOTSEAT: "HOTSEAT",
	PAGE_HOW_TO_PLAY: "HOW TO PLAY"}
const SECTION_HINTS := {
	PAGE_ONLINE: "Play with random people who are looking for a game too.",
	PAGE_LOBBY: "Create a room for friends or join theirs.",
	PAGE_HOTSEAT: "2-4 players take turns at this computer.",
	PAGE_HOW_TO_PLAY: "Rules for beginners, page by page.",
}

const GAP := 6
const TAB_HEIGHT := 20.0
## Кнопки столбца слева — и в PLAY, и в профиле.
const SIDE_BUTTON := Vector2(110, 22)
const CORNER_BUTTON := Vector2(140, 24)
const MENU_WIDTH := 400.0
const BUTTON_SIZE := Vector2(90, 16)
const DOT := 7.0
## Задник и патчноуты подключены файлом, а не по глобальному имени класса:
## глобальные имена собирает редактор, а проект часто запускается из
## командной строки, где нового имени ещё нет в кэше.
const UnderdarkBg := preload("res://scenes/ui/underdark_bg.gd")
const PatchNotes := preload("res://scenes/ui/patch_notes.gd")

var _mode: String = GameSetup.MODE_STANDARD
var _count: int = GameScreen.MIN_PLAYERS
## На сколько человек искать стол (SEARCH) — отдельно от своей комнаты.
var _match_count: int = GameScreen.MIN_PLAYERS
var _tab := PAGE_PLAY
var _section := PAGE_ONLINE
## Окно под кнопками и его содержимое по вкладкам (строится при первом показе).
var _window: PanelContainer
var _tabs: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _section_buttons: Dictionary = {}
## Содержимое раздела PLAY — пересобирается при смене раздела.
var _col: VBoxContainer
## Строка-подсказка внизу окна PLAY (текст кнопки под мышью).
var _hint: Label
var _hint_default := ""
## Большая кнопка в правом нижнем углу окна PLAY и что она делает.
var _action: Button
var _action_call := Callable()
var _action_hint := ""
## Надписи и фишки, которые меняются вместе с выбором режима и игроков.
var _mode_note: Label
var _dots: HBoxContainer


## page — какую вкладку или раздел PLAY открыть (возврат из обучения, лобби).
func _init(page: String = PAGE_ONLINE) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PixelTheme.theme()

	# Живой задник во всю силу: меню — единственное место, где фону не мешают
	# ни доска, ни карты.
	add_child(UnderdarkBg.make())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, GAP)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", GAP)
	margin.add_child(col)

	var title_bar := PanelContainer.new()
	title_bar.add_theme_stylebox_override("panel", GameScreen.zone_style(4))
	col.add_child(title_bar)
	var title := Label.new()
	# Заголовок — тот же шрифт ровно вдвое крупнее (пиксель остаётся квадратным).
	title.text = "TYRANTS OF THE UNDERDARK"
	title.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
	title.add_theme_color_override("font_color", PixelTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_bar.add_child(title)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", GAP)
	col.add_child(bar)
	var group := ButtonGroup.new()
	for tab: String in TABS:
		var b := _tab_button(tab.to_upper().replace("_", " "), TAB_RATIOS[tab])
		b.toggle_mode = true
		b.button_group = group
		b.pressed.connect(_show_tab.bind(tab))
		bar.add_child(b)
		_tab_buttons[tab] = b
	var quit := _tab_button("EXIT", TAB_RATIOS["exit"])
	quit.pressed.connect(func(): get_tree().quit())
	bar.add_child(quit)

	_window = PanelContainer.new()
	_window.add_theme_stylebox_override("panel", GameScreen.zone_style(GAP))
	_window.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_window)

	show_page(page)


func current_page() -> String:
	return _section if _tab == PAGE_PLAY else _tab


## Вкладка (PAGE_NEWS…) или раздел PLAY (PAGE_ONLINE…); PAGE_PLAY — последний
## открытый раздел.
func show_page(page: String) -> void:
	if PLAY_SECTIONS.has(page):
		_section = page
		_show_tab(PAGE_PLAY)
	elif TABS.has(page):
		_show_tab(page)
	else:
		_show_tab(PAGE_PLAY)


func _show_tab(tab: String) -> void:
	_tab = tab
	if not _tabs.has(tab):
		var content: Control
		match tab:
			PAGE_NEWS:
				content = _build_news()
			PAGE_PROFILE:
				content = ProfileScreen.new()
			PAGE_SETTINGS:
				content = _build_settings()
			_:
				content = _build_play()
		_tabs[tab] = content
		_window.add_child(content)
	for key: String in _tabs:
		(_tabs[key] as Control).visible = key == tab
	for key: String in _tab_buttons:
		(_tab_buttons[key] as Button).set_pressed_no_signal(key == tab)
	if tab == PAGE_PLAY:
		_show_section(_section)


# --- NEWS -------------------------------------------------------------------

func _build_news() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.add_child(_heading("PATCH NOTES", PixelTheme.GOLD))
	col.add_child(HSeparator.new())
	var notes := RichTextLabel.new()
	notes.bbcode_enabled = true
	notes.scroll_active = true
	notes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notes.add_theme_color_override("default_color", PixelTheme.TEXT)
	notes.add_theme_constant_override("line_separation", 2)
	var list := PatchNotes.entries()
	notes.text = PatchNotes.bbcode(list) if not list.is_empty() else "No patch notes yet."
	col.add_child(notes)
	return col


# --- PLAY -------------------------------------------------------------------

func _build_play() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 4)
	row.add_child(side)
	var group := ButtonGroup.new()
	for section: String in PLAY_SECTIONS:
		var b := Button.new()
		b.text = SECTION_TITLES[section]
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = SIDE_BUTTON
		_style_button(b)
		b.pressed.connect(_show_section.bind(section))
		b.mouse_entered.connect(func(): _set_hint(SECTION_HINTS[section]))
		b.mouse_exited.connect(func(): _set_hint(_hint_default))
		side.add_child(b)
		_section_buttons[section] = b
	row.add_child(VSeparator.new())

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	row.add_child(right)
	var centre := CenterContainer.new()
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(centre)
	_col = VBoxContainer.new()
	# Ширина постоянная: иначе содержимое (оно по центру) прыгало бы при
	# смене описания режима.
	_col.custom_minimum_size.x = MENU_WIDTH
	_col.add_theme_constant_override("separation", 4)
	centre.add_child(_col)

	right.add_child(HSeparator.new())
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", GAP)
	right.add_child(bottom)
	_hint = Label.new()
	_hint.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom.add_child(_hint)
	_action = Button.new()
	_action.custom_minimum_size = CORNER_BUTTON
	_style_button(_action)
	_action.pressed.connect(func():
		if _action_call.is_valid():
			_action_call.call())
	_action.mouse_entered.connect(func(): _set_hint(_action_hint))
	_action.mouse_exited.connect(func(): _set_hint(_hint_default))
	bottom.add_child(_action)
	return row


func _show_section(section: String) -> void:
	_section = section
	for key: String in _section_buttons:
		(_section_buttons[key] as Button).set_pressed_no_signal(key == section)
	for child in _col.get_children():
		_col.remove_child(child)
		child.queue_free()
	_mode_note = null
	_dots = null
	_add_title(SECTION_TITLES[section])
	match section:
		PAGE_LOBBY:
			_build_lobby()
		PAGE_HOTSEAT:
			_build_hotseat()
		PAGE_HOW_TO_PLAY:
			_build_how_to_play()
		_:
			_build_online()


## Большая кнопка в углу: надпись, подсказка и что делает.
func _set_action(text: String, hint: String, action: Callable) -> void:
	_action.text = text
	_action_hint = hint
	_action_call = action


func _set_default_hint(text: String) -> void:
	_hint_default = text
	_set_hint(text)


## Поиск игры: случайные соперники, выбрать можно только, на сколько человек
## стол; режим маркета от него зависит (NetSession.match_mode).
func _build_online() -> void:
	var market := _add_dim(_match_market_text())
	_col.add_child(HSeparator.new())
	var counts: Array = []
	var group := ButtonGroup.new()
	for count in range(GameScreen.MIN_PLAYERS, GameScreen.MAX_PLAYERS + 1):
		var b := _toggle(str(count), group, count == _match_count, 24)
		b.pressed.connect(func():
			_match_count = count
			market.text = _match_market_text())
		b.mouse_entered.connect(func(): _set_hint("Look for a table of %d players." % count))
		b.mouse_exited.connect(func(): _set_hint(_hint_default))
		counts.append(b)
	_col.add_child(_heading("PLAYERS"))
	_col.add_child(_row(counts))
	# Незаконченная онлайн-партия (игру закрыли или она упала) — вернуться в неё.
	if not NetSession.saved_game().is_empty():
		_col.add_child(HSeparator.new())
		var back := _button("RETURN TO GAME", "Your online game is not over yet: go back to your seat.",
			func(): online_requested.emit("resume", 0, ""))
		back.custom_minimum_size = SIDE_BUTTON
		_col.add_child(back)
	_set_default_hint("The game starts as soon as the table is full. Other players will see your name and emblem.")
	_set_action("SEARCH", "Wait in line until enough players are found.",
		func(): online_requested.emit("find", _match_count, NetSession.match_mode(_match_count)))


func _match_market_text() -> String:
	return "Random opponents. Market: %s." % MODE_TITLES[NetSession.match_mode(_match_count)]


## Игра с друзьями: своя комната (CREATE ROOM в углу, HOST BY IP) или вход в чужую.
func _build_lobby() -> void:
	_col.add_child(HSeparator.new())
	_col.add_child(_heading("NEW GAME WITH FRIENDS", PixelTheme.GOLD))
	_add_game_options()
	_col.add_child(_button("HOST BY IP", "Home network or Radmin VPN: friends join by your IP.",
		func(): online_requested.emit("host", _count, _mode)))
	_col.add_child(HSeparator.new())
	_col.add_child(_heading("JOIN A FRIEND'S GAME", PixelTheme.GOLD))
	_col.add_child(_pair(
		_button("JOIN BY CODE", "Type the room code your friend got.",
			func(): online_requested.emit("join_code", 0, _mode)),
		_button("JOIN BY IP", "Type the IP of the friend who pressed HOST BY IP.",
			func(): online_requested.emit("join_ip", 0, _mode))))
	_set_default_hint("Room code: through our server. IP: home network or Radmin VPN.")
	_set_action("CREATE ROOM", "Get a room code on our server and send it to friends.",
		func(): online_requested.emit("create", _count, _mode))


func _build_hotseat() -> void:
	_add_dim("Players take turns at this computer.")
	_col.add_child(HSeparator.new())
	_add_game_options()
	_set_default_hint("The first player is drawn at random.")
	_set_action("START", "Deal the cards and begin.",
		func(): started.emit(GameScreen.player_ids_for(_count), _mode))


func _build_how_to_play() -> void:
	_add_dim("Rules for beginners, page by page:\nturns, cards, troops, spies and how to win.")
	_set_default_hint("Arrows turn the pages, Esc brings you back here.")
	_set_action("OPEN", "Open the rules.", func(): how_to_play_requested.emit())


## Режим рынка и число игроков — общие для hotseat и новой сетевой партии.
func _add_game_options() -> void:
	_col.add_child(_heading("GAME MODE"))
	var modes: Array[Button] = []
	var group := ButtonGroup.new()
	for mode: String in GameSetup.MODES:
		var b := _toggle(MODE_TITLES[mode], group, mode == _mode, 60)
		b.pressed.connect(func(): _select_mode(mode))
		modes.append(b)
	_col.add_child(_row(modes))
	_mode_note = _add_dim(MODE_NOTES[_mode])
	_mode_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_col.add_child(_heading("PLAYERS"))
	var counts: Array[Button] = []
	group = ButtonGroup.new()
	for count in range(GameScreen.MIN_PLAYERS, GameScreen.MAX_PLAYERS + 1):
		var b := _toggle(str(count), group, count == _count, 24)
		b.pressed.connect(func(): _select_count(count))
		counts.append(b)
	var row := _row(counts)
	# Фишки тех, кто сядет за стол: блок постоянной ширины (место под все
	# четыре), чтобы кнопки не прыгали при смене числа игроков.
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 3)
	_dots.custom_minimum_size = Vector2(
		DOT * GameScreen.MAX_PLAYERS + 3.0 * (GameScreen.MAX_PLAYERS - 1), 0)
	row.add_child(_dots)
	_col.add_child(row)
	_refresh_dots()


func _select_mode(mode: String) -> void:
	_mode = mode
	if _mode_note != null:
		_mode_note.text = MODE_NOTES[mode]


func _select_count(count: int) -> void:
	_count = count
	_refresh_dots()


func _refresh_dots() -> void:
	if _dots == null:
		return
	for child in _dots.get_children():
		_dots.remove_child(child)
		child.queue_free()
	for pid: String in GameScreen.player_ids_for(_count):
		var dot := ColorRect.new()
		dot.color = BoardPanel.PLAYER_COLORS.get(pid, Color.GRAY)
		dot.custom_minimum_size = Vector2(DOT, DOT)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.tooltip_text = EventLogPanel.player_name(pid)
		_dots.add_child(dot)


# --- SETTINGS ---------------------------------------------------------------

## Все настройки игры: громкость (как в меню по Esc) и полный экран (как F11).
func _build_settings() -> Control:
	var centre := CenterContainer.new()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	centre.add_child(col)
	col.add_child(_heading("SETTINGS", PixelTheme.GOLD))
	col.add_child(HSeparator.new())
	# Громкость: щелчок — следующая ступень (100 → 75 → 50 → 25 → OFF).
	var sound := _setting_button(Sfx.volume_label())
	sound.pressed.connect(func():
		Sfx.cycle_volume()
		sound.text = Sfx.volume_label())
	col.add_child(sound)
	var music := _setting_button(Music.volume_label())
	music.pressed.connect(func():
		Music.cycle_volume()
		music.text = Music.volume_label())
	col.add_child(music)
	var screen := _setting_button(_screen_label())
	screen.pressed.connect(func():
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		screen.text = _screen_label())
	# F11 и Alt+Enter переключают экран и мимо этой кнопки.
	screen.visibility_changed.connect(func(): screen.text = _screen_label())
	col.add_child(screen)
	col.add_child(HSeparator.new())
	_add_dim_to(col, "Click a button for the next step.\nF11 or Alt+Enter: full screen or window.")
	return centre


static func _screen_label() -> String:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	return "SCREEN: FULL" if full else "SCREEN: WINDOW"


func _setting_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(140, 18)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_button(b)
	return b


# --- мелкие детали вёрстки ---------------------------------------------------

func _tab_button(text: String, ratio: float) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_stretch_ratio = ratio
	b.custom_minimum_size.y = TAB_HEIGHT
	_style_button(b)
	return b


func _add_title(text: String) -> void:
	var title := Label.new()
	title.text = text
	title.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
	title.add_theme_color_override("font_color", PixelTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(title)


func _add_dim(text: String) -> Label:
	return _add_dim_to(_col, text)


func _add_dim_to(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func _heading(text: String, colour: Color = PixelTheme.TEXT_DIM) -> Label:
	var label := GameScreen.section_label(text)
	label.add_theme_color_override("font_color", colour)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _set_hint(text: String) -> void:
	if _hint != null and is_instance_valid(_hint):
		_hint.text = text


func _button(text: String, hint: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_SIZE
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_button(b)
	b.pressed.connect(action)
	b.mouse_entered.connect(func(): _set_hint(hint))
	b.mouse_exited.connect(func(): _set_hint(_hint_default))
	return b


## Кнопка-переключатель: нажатая в своей группе остаётся подсвеченной.
func _toggle(text: String, group: ButtonGroup, on: bool, width: float) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.button_pressed = on
	b.custom_minimum_size = Vector2(width, 16)
	_style_button(b)
	return b


func _pair(a: Control, b: Control) -> HBoxContainer:
	var row := _row([a, b])
	row.add_theme_constant_override("separation", 6)
	return row


func _row(items: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for item: Control in items:
		row.add_child(item)
	return row


## Без своего стиля кнопки темы по умолчанию выглядят как простой текст —
## на тёмном фоне непонятно, что на них надо нажимать.
static func _style_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal",
		PixelTheme.button_box(PixelTheme.PANEL_HI, PixelTheme.BORDER))
	button.add_theme_stylebox_override("hover",
		PixelTheme.button_box(PixelTheme.BORDER, PixelTheme.GOLD))
	button.add_theme_stylebox_override("pressed",
		PixelTheme.button_box(PixelTheme.GOLD, PixelTheme.GOLD))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", PixelTheme.TEXT)
	button.add_theme_color_override("font_hover_color", PixelTheme.GOLD)
	button.add_theme_color_override("font_pressed_color", PixelTheme.BG)
