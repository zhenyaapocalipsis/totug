class_name SetupScreen
extends Control

## Главное меню по образцу Dota 2 (макет владельца, 2026-10-06):
##
##   сверху полоса с названием игры;
##   под ней строка кнопок PROFILE, PLAY, SETTINGS, EXIT;
##   ниже окно с тем, что открыла кнопка:
##     PROFILE  — профиль (ProfileScreen): столбец STATS / EMBLEM / CHAT /
##                COLLECTION слева;
##     PLAY     — столбец ONLINE / LOBBY / HOTSEAT / HOW TO PLAY слева, большая
##                кнопка в правом нижнем углу (SEARCH, CREATE ROOM / HOST, JOIN,
##                START); HOW TO PLAY — само обучение прямо в окне;
##     SETTINGS — звук, экран, клавиши, игровые мелочи (SettingsPanel);
##   EXIT закрывает игру.
##
## Подсказок при наведении нет (владелец, 2026-10-06): что нужно знать — сразу
## текстом в окне.
##
## Страница меню — вкладка или раздел PLAY (current_page, show_page).
## GameScreen получает уже готовый список цветов — экран партии ничего не
## знает про меню. Вёрстка кодом по той же причине, что и в game_screen.gd:
## .tscn в этом проекте правится вслепую, без редактора.

## bots — за всех, кроме первого цвета, играют боты (BotPlayer).
signal started(player_ids: Array[String], mode: String, bots: bool)
## Сетевая игра. kind: "create" / "join_code" — через сервер с кодами комнат,
## "host" / "join_ip" — напрямую по IP (локальная сеть, Radmin VPN),
## "find" — поиск игры на сервере (режим по размеру стола: NetSession.match_mode),
## "resume" — вернуться в незаконченную онлайн-партию (NetSession.saved_game).
## address — код комнаты (join_code) или IP хоста (join_ip), набранные в меню.
signal online_requested(kind: String, player_count: int, mode: String, address: String)
## WATCH в истории партий профиля — открыть реплей (файл ReplayBook).
signal replay_requested(file: String)

const MODE_TITLES := {
	"standard": "STANDARD",
	"double": "DOUBLE",
	"random3": "RANDOM 3",
	"random4": "RANDOM 4",
	"random6": "RANDOM 6",
	"newera": "NEW ERA",
}
const MODE_NOTES := {
	"standard": "Market: two random half-decks.",
	"double": "Market: one random half-deck, taken twice.",
	"random3": "Market: 3 random half-decks, 20 cards of each aspect.",
	"random4": "Market: 4 random half-decks, 20 cards of each aspect.",
	"random6": "Market: 6 random half-decks, 20 cards of each aspect.",
	"newera": "Market: the new Celestial Order half-deck + 1 random half-deck.",
}

## Вкладки (кнопки под названием).
const PAGE_PROFILE := "profile"
const PAGE_PLAY := "play"
const PAGE_SETTINGS := "settings"
const TABS: Array[String] = [PAGE_PROFILE, PAGE_PLAY, PAGE_SETTINGS]
## Разделы PLAY (столбец слева в окне).
const PAGE_ONLINE := "online"
const PAGE_LOBBY := "lobby"
const PAGE_HOTSEAT := "hotseat"
const PAGE_HOW_TO_PLAY := "how_to_play"
const PLAY_SECTIONS: Array[String] = [PAGE_ONLINE, PAGE_LOBBY, PAGE_HOTSEAT, PAGE_HOW_TO_PLAY]
const SECTION_TITLES := {PAGE_ONLINE: "ONLINE", PAGE_LOBBY: "LOBBY", PAGE_HOTSEAT: "HOTSEAT",
	PAGE_HOW_TO_PLAY: "HOW TO PLAY"}

const GAP := 2
const TAB_HEIGHT := 16.0
## Кнопки столбца слева — и в PLAY, и в профиле: столбцы одной ширины.
const SIDE_BUTTON := Vector2(76, 16)
const CORNER_BUTTON := Vector2(70, 16)
const BUTTON_SIZE := Vector2(90, 16)
const MENU_WIDTH := 400.0
const DOT := 7.0
## Задник, обучение и настройки подключены файлом, а не по глобальному имени класса:
## глобальные имена собирает редактор, а проект часто запускается из
## командной строки, где нового имени ещё нет в кэше.
const UnderdarkBg := preload("res://scenes/ui/underdark_bg.gd")
const HowToPlay := preload("res://scenes/ui/how_to_play_screen.gd")
const SettingsPanel := preload("res://scenes/ui/settings_panel.gd")

var _mode: String = GameSetup.MODE_STANDARD
var _count: int = GameScreen.MIN_PLAYERS
## HOTSEAT: соперники — боты (иначе люди за этим же компьютером).
var _bots := false
var _hotseat_note: Label
## На сколько человек искать стол (SEARCH) — отдельно от своей комнаты.
var _match_count: int = GameScreen.MIN_PLAYERS
## LOBBY: войти к друзьям (иначе — своя игра), своя игра — напрямую по IP
## (иначе через сервер с кодом комнаты), вход — по IP (иначе по коду).
var _lobby_join := false
var _lobby_direct := false
var _join_by_ip := false
## Страница обучения, на которой остановились.
var _learn_page := 0
var _tab := PAGE_PLAY
var _section := PAGE_ONLINE
## С какой страницы меню открыли (к ней возвращаемся после замера окна).
var _first_page := PAGE_ONLINE
## Окно под кнопками и его содержимое по вкладкам (строится при первом показе).
var _window: PanelContainer
var _tabs: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _section_buttons: Dictionary = {}
## Содержимое раздела PLAY — пересобирается при смене раздела.
var _col: VBoxContainer
## Низ окна PLAY: черта и строка с большой кнопкой в правом углу.
var _bottom: Array[Control] = []
var _action: Button
var _action_call := Callable()
## Надписи и фишки, которые меняются вместе с выбором режима и игроков.
var _mode_note: Label
var _dots: HBoxContainer
var _learn: HowToPlay


## page — какую вкладку или раздел PLAY открыть (возврат из лобби).
func _init(page: String = PAGE_ONLINE) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PixelTheme.theme()

	# Живой задник во всю силу: меню — единственное место, где фону не мешают
	# ни доска, ни карты.
	add_child(UnderdarkBg.make())

	# Меню — компактный блок по центру экрана, не на весь экран (владелец,
	# 2026-10-06).
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", GAP)
	centre.add_child(col)

	var title_bar := PanelContainer.new()
	# Под заглавными буквами у шрифта запас на хвосты строчных (вдвое больший
	# у крупного шрифта) — столько же отступа сверху, и надпись посередине.
	var title_box := GameScreen.zone_style(1)
	title_box.content_margin_top = 1 + 3 * PixelTheme.CAPS_SHIFT
	title_box.content_margin_bottom = 0
	title_bar.add_theme_stylebox_override("panel", title_box)
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
		var b := _tab_button(tab.to_upper())
		b.toggle_mode = true
		b.button_group = group
		b.pressed.connect(_show_tab.bind(tab))
		bar.add_child(b)
		_tab_buttons[tab] = b
	var quit := _tab_button("EXIT")
	quit.pressed.connect(func(): get_tree().quit())
	bar.add_child(quit)

	_window = PanelContainer.new()
	_window.add_theme_stylebox_override("panel", GameScreen.zone_style(GAP))
	col.add_child(_window)

	_first_page = page
	show_page(page)


## Окно — по самому большому содержимому из всех вкладок и разделов, чтобы
## оно не прыгало при переключении. Мерить можно только в сцене: надписи
## перемеряются пиксельным шрифтом темы — поэтому на кадр позже.
func _ready() -> void:
	_fit_window.call_deferred()


func _fit_window() -> void:
	var need := Vector2.ZERO
	for tab: String in TABS:
		_show_tab(tab)
		var content: Control = _tabs[tab]
		if tab == PAGE_PLAY:
			for section: String in PLAY_SECTIONS:
				_show_section(section)
				need = need.max(content.get_combined_minimum_size())
				if section == PAGE_HOW_TO_PLAY:
					# Страницы обучения разной высоты — окно по самой высокой.
					var page := _learn_page
					for i in _learn.page_count():
						_learn.show_page(i)
						need = need.max(content.get_combined_minimum_size())
					_learn.show_page(page)
		elif tab == PAGE_PROFILE:
			# Профиль — простой Control, его размер — у строки внутри.
			var profile: ProfileScreen = content
			for page: String in ProfileScreen.TABS:
				profile._show_tab(page)
				if page == "COLLECTION":
					# Разделы коллекции равняются по самому большому при показе
					# раздела — теперь, когда надписи уже перемерены.
					profile._collection.show_section(CollectionPage.SECTIONS[0])
				need = need.max(profile._row.get_combined_minimum_size())
			profile._show_tab(ProfileScreen.TABS[0])
		else:
			need = need.max(content.get_combined_minimum_size())
	_window.custom_minimum_size = need + _window.get_theme_stylebox("panel").get_minimum_size()
	_section = _first_page if PLAY_SECTIONS.has(_first_page) else PAGE_ONLINE
	show_page(_first_page)


func current_page() -> String:
	return _section if _tab == PAGE_PLAY else _tab


## Вкладка (PAGE_PROFILE…) или раздел PLAY (PAGE_ONLINE…); PAGE_PLAY — последний
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
			PAGE_PROFILE:
				var profile := ProfileScreen.new()
				profile.replay_requested.connect(func(file: String): replay_requested.emit(file))
				content = profile
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


# --- PLAY -------------------------------------------------------------------

func _build_play() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 2)
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
		side.add_child(b)
		_section_buttons[section] = b
	row.add_child(VSeparator.new())

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 2)
	row.add_child(right)
	# Содержимое раздела — по центру окна (владелец, 2026-10-06).
	var centre := CenterContainer.new()
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(centre)
	_col = VBoxContainer.new()
	# Ширина постоянная: иначе описание режима, меняясь, двигало бы раздел.
	_col.custom_minimum_size.x = MENU_WIDTH
	_col.add_theme_constant_override("separation", 2)
	centre.add_child(_col)

	var line := HSeparator.new()
	right.add_child(line)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(bottom)
	_action = Button.new()
	_action.custom_minimum_size = CORNER_BUTTON
	_style_button(_action)
	_action.pressed.connect(func():
		if _action_call.is_valid():
			_action_call.call())
	bottom.add_child(_action)
	_bottom = [line, bottom]
	return row


func _show_section(section: String) -> void:
	_section = section
	for key: String in _section_buttons:
		(_section_buttons[key] as Button).set_pressed_no_signal(key == section)
	if _learn != null:
		_learn_page = _learn.current_page()
	for child in _col.get_children():
		_col.remove_child(child)
		child.queue_free()
	_mode_note = null
	_dots = null
	_learn = null
	# У обучения своя листалка внизу — большая кнопка в углу ему не нужна.
	for c: Control in _bottom:
		c.visible = section != PAGE_HOW_TO_PLAY
	match section:
		PAGE_LOBBY:
			_build_lobby()
		PAGE_HOTSEAT:
			_build_hotseat()
		PAGE_HOW_TO_PLAY:
			_build_how_to_play()
		_:
			_build_online()


## Большая кнопка в углу: надпись и что делает.
func _set_action(text: String, action: Callable) -> void:
	_action.text = text
	_action_call = action


## Поиск игры: случайные соперники, выбрать можно только, на сколько человек
## стол; режим маркета от него зависит (NetSession.match_mode).
func _build_online() -> void:
	_add_dim("Play with random people who are looking for a game too.")
	var market := _add_dim(_match_market_text())
	_col.add_child(HSeparator.new())
	var counts: Array = []
	var group := ButtonGroup.new()
	for count in range(GameScreen.MIN_PLAYERS, GameScreen.MAX_PLAYERS + 1):
		var b := _toggle(str(count), group, count == _match_count, 24)
		b.pressed.connect(func():
			_match_count = count
			market.text = _match_market_text())
		counts.append(b)
	_col.add_child(_heading("PLAYERS"))
	_col.add_child(_row(counts))
	_add_dim("The game starts as soon as the table is full.")
	# Незаконченная онлайн-партия (игру закрыли или она упала) — вернуться в неё.
	if not NetSession.saved_game().is_empty():
		_col.add_child(HSeparator.new())
		_add_dim("Your online game is not over yet.")
		var back := _button("RETURN TO GAME", func(): online_requested.emit("resume", 0, "", ""))
		back.custom_minimum_size = SIDE_BUTTON
		_col.add_child(back)
	_set_action("SEARCH", func():
		online_requested.emit("find", _match_count, NetSession.match_mode(_match_count), ""))


func _match_market_text() -> String:
	return "Market: %s." % MODE_TITLES[NetSession.match_mode(_match_count)]


## Игра с друзьями: сверху выбор CREATE / JOIN, под ним — только то, что нужно
## для выбранного; кнопка в углу делает именно это (владелец, 2026-10-06).
func _build_lobby() -> void:
	var group := ButtonGroup.new()
	var create := _toggle("CREATE", group, not _lobby_join, 70)
	create.pressed.connect(func(): _set_lobby(false, _lobby_direct, _join_by_ip))
	var join := _toggle("JOIN", group, _lobby_join, 70)
	join.pressed.connect(func(): _set_lobby(true, _lobby_direct, _join_by_ip))
	_col.add_child(_row([create, join]))
	_col.add_child(HSeparator.new())
	if _lobby_join:
		_build_lobby_join()
	else:
		_build_lobby_create()


func _set_lobby(join: bool, direct: bool, by_ip: bool) -> void:
	# Щелчок по уже выбранному — ничего не пересобирать (набранное в поле
	# не стирать).
	if join == _lobby_join and direct == _lobby_direct and by_ip == _join_by_ip:
		return
	_lobby_join = join
	_lobby_direct = direct
	_join_by_ip = by_ip
	_show_section(PAGE_LOBBY)


## Своя игра: режим, игроки и как друзья войдут — по коду комнаты на нашем
## сервере или прямо по IP этого компьютера.
func _build_lobby_create() -> void:
	_add_game_options()
	_col.add_child(_heading("CONNECTION"))
	var group := ButtonGroup.new()
	var server := _toggle("SERVER", group, not _lobby_direct, 70)
	server.pressed.connect(func(): _set_lobby(false, false, _join_by_ip))
	var direct := _toggle("DIRECT IP", group, _lobby_direct, 70)
	direct.pressed.connect(func(): _set_lobby(false, true, _join_by_ip))
	_col.add_child(_row([server, direct]))
	if _lobby_direct:
		_add_dim("Friends join by your IP: home network or Radmin VPN.")
		_set_action("HOST", func(): online_requested.emit("host", _count, _mode, ""))
	else:
		_add_dim("You get a room code on our server. Send it to friends.")
		_set_action("CREATE ROOM", func(): online_requested.emit("create", _count, _mode, ""))


## Войти к друзьям: по коду комнаты или по IP того, кто открыл игру (HOST).
func _build_lobby_join() -> void:
	var group := ButtonGroup.new()
	var by_code := _toggle("BY CODE", group, not _join_by_ip, 70)
	by_code.pressed.connect(func(): _set_lobby(true, _lobby_direct, false))
	var by_ip := _toggle("BY IP", group, _join_by_ip, 70)
	by_ip.pressed.connect(func(): _set_lobby(true, _lobby_direct, true))
	_col.add_child(_row([by_code, by_ip]))
	var edit := LineEdit.new()
	edit.custom_minimum_size = Vector2(120, 16)
	edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _join_by_ip:
		_col.add_child(_heading("HOST IP"))
		edit.placeholder_text = "e.g. 26.12.34.56"
		edit.text = LobbyScreen._load("last_ip", "")
		_col.add_child(edit)
		_add_dim("The friend who pressed HOST sees their IP.")
	else:
		_col.add_child(_heading("ROOM CODE"))
		edit.max_length = NetSession.CODE_LENGTH
		edit.placeholder_text = "ABCD"
		_col.add_child(edit)
		_add_dim("The friend who pressed CREATE ROOM got the code.")
	var kind := "join_ip" if _join_by_ip else "join_code"
	var go := func(): online_requested.emit(kind, 0, _mode, edit.text.strip_edges())
	edit.text_submitted.connect(func(_t: String): go.call())
	_set_action("JOIN", go)


func _build_hotseat() -> void:
	_col.add_child(_heading("OPPONENTS"))
	var group := ButtonGroup.new()
	var people := _toggle("PEOPLE", group, not _bots, 60)
	var bots := _toggle("BOTS", group, _bots, 60)
	people.pressed.connect(func(): _select_bots(false))
	bots.pressed.connect(func(): _select_bots(true))
	_col.add_child(_row([people, bots]))
	_hotseat_note = _add_dim("")
	_select_bots(_bots)
	_col.add_child(HSeparator.new())
	_add_game_options()
	_set_action("START", func(): started.emit(GameScreen.player_ids_for(_count), _mode, _bots))


func _select_bots(on: bool) -> void:
	_bots = on
	if _hotseat_note != null:
		_hotseat_note.text = "You play against bots.\nThe first player is drawn at random." if on \
			else "Players take turns at this computer.\nThe first player is drawn at random."


## Обучение — прямо в окне (владелец, 2026-10-06: без лишней кнопки OPEN),
## с той страницы, где остановились.
func _build_how_to_play() -> void:
	_learn = HowToPlay.new(_learn_page)
	_learn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_col.add_child(_learn)


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
	# С переносом слов надпись без ширины считает себя очень высокой (по
	# слову в строке) и раздувает окно при замере — ширина задана заранее.
	_mode_note.custom_minimum_size.x = MENU_WIDTH

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
		_dots.add_child(dot)


# --- SETTINGS ---------------------------------------------------------------

## Все настройки игры (SettingsPanel — та же панель, что в меню по Esc).
func _build_settings() -> Control:
	var centre := CenterContainer.new()
	centre.add_child(SettingsPanel.new())
	return centre


# --- мелкие детали вёрстки ---------------------------------------------------

## Кнопка под названием: все четыре одной ширины, вместе — во всю ширину меню.
func _tab_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = TAB_HEIGHT
	_style_button(b)
	return b


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


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_SIZE
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_button(b)
	b.pressed.connect(action)
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


func _row(items: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
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
