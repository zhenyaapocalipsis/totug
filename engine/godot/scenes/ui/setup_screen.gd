class_name SetupScreen
extends Control

## Главное меню — дерево коротких страниц, на каждой две-три большие кнопки
## (решение владельца, 2026-09-26):
##
##   главная      — профиль сверху, PLAY, LIBRARY, QUIT;
##   play         — ONLINE, HOTSEAT;
##   hotseat      — режим рынка, сколько игроков, START GAME;
##   online       — MATCHMAKING, LOBBY;
##   matchmaking  — на сколько человек стол, FIND GAME (случайные соперники);
##   lobby        — своя партия для друзей (CREATE ROOM / HOST BY IP)
##                  и вход в чужую (JOIN BY CODE / JOIN BY IP);
##   library      — HOW TO PLAY, CARDS (все карты игры).
##
## Esc и BACK на вложенной странице возвращают на страницу выше
## (PAGE_PARENTS). Под кнопками строка-подсказка: что сделает кнопка под мышью.
##
## GameScreen получает уже готовый список цветов — экран партии ничего не
## знает про меню. Вёрстка кодом по той же причине, что и в game_screen.gd:
## .tscn в этом проекте правится вслепую, без редактора.

signal started(player_ids: Array[String], mode: String)
## Сетевая игра. kind: "create" / "join_code" — через сервер с кодами комнат,
## "host" / "join_ip" — напрямую по IP (локальная сеть, Radmin VPN),
## "find" — поиск игры на сервере (режим всегда NetSession.MATCH_MODE),
## "resume" — вернуться в незаконченную онлайн-партию (NetSession.saved_game).
signal online_requested(kind: String, player_count: int, mode: String)
## Открыть профиль игрока (имя, герб, рубашка, статистика — ProfileScreen).
signal profile_requested
## Открыть обучение для новичков (how_to_play_screen.gd).
signal how_to_play_requested
## Открыть библиотеку карт (card_library_screen.gd).
signal cards_requested

const MODE_TITLES := {
	"standard": "STANDARD",
	"double": "DOUBLE",
	"random4": "RANDOM 4",
	"random6": "RANDOM 6",
}
const MODE_NOTES := {
	"standard": "Market: two random half-decks.",
	"double": "Market: one random half-deck, taken twice.",
	"random4": "Market: 4 random half-decks, 20 cards of each aspect.",
	"random6": "Market: 6 random half-decks, 20 cards of each aspect.",
}

const PAGE_MAIN := "main"
const PAGE_PLAY := "play"
const PAGE_HOTSEAT := "hotseat"
const PAGE_ONLINE := "online"
const PAGE_MATCHMAKING := "matchmaking"
const PAGE_LOBBY := "lobby"
const PAGE_LIBRARY := "library"
## Куда ведут BACK и Esc с каждой вложенной страницы.
const PAGE_PARENTS := {
	PAGE_PLAY: PAGE_MAIN,
	PAGE_HOTSEAT: PAGE_PLAY,
	PAGE_ONLINE: PAGE_PLAY,
	PAGE_MATCHMAKING: PAGE_ONLINE,
	PAGE_LOBBY: PAGE_ONLINE,
	PAGE_LIBRARY: PAGE_MAIN,
}
## Подсказка внизу страницы, пока мышь не над кнопкой.
const PAGE_HINTS := {
	PAGE_MAIN: "Point at a button to see what it does.",
	PAGE_PLAY: "Point at a button to see what it does.",
	PAGE_HOTSEAT: "The first player is drawn at random.",
	PAGE_ONLINE: "Other players will see your name and emblem.",
	PAGE_MATCHMAKING: "The game starts as soon as the table is full.",
	PAGE_LOBBY: "Room code: through our server. IP: home network or Radmin VPN.",
	PAGE_LIBRARY: "Point at a button to see what it does.",
}

const BIG_BUTTON := Vector2(170, 22)
const MENU_WIDTH := 400.0
const BUTTON_SIZE := Vector2(90, 16)
const DOT := 7.0
## Задник экрана подключён файлом, а не по глобальному имени класса:
## глобальные имена собирает редактор, а проект часто запускается из
## командной строки, где нового имени ещё нет в кэше.
const UnderdarkBg := preload("res://scenes/ui/underdark_bg.gd")

var _mode: String = GameSetup.MODE_STANDARD
var _count: int = GameScreen.MIN_PLAYERS
## На сколько человек искать стол (FIND GAME) — отдельно от своей комнаты.
var _match_count: int = GameScreen.MIN_PLAYERS
var _page := PAGE_MAIN
## Содержимое карточки меню — пересобирается при смене страницы.
var _col: VBoxContainer
## Строка-подсказка внизу страницы (текст кнопки под мышью).
var _hint: Label
var _hint_default := ""
## Надписи и фишки, которые меняются вместе с выбором режима и игроков.
var _mode_note: Label
var _dots: HBoxContainer


## page — с какой страницы открыть меню (возврат из обучения, лобби и т. п.).
func _init(page: String = PAGE_MAIN) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PixelTheme.theme()

	# Живой задник во всю силу: меню — единственное место, где фону не мешают
	# ни доска, ни карты.
	add_child(UnderdarkBg.make())

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", GameScreen.zone_style(8))
	centre.add_child(card)

	_col = VBoxContainer.new()
	# Ширина постоянная: иначе окно (оно по центру) раздувалось бы и прыгало,
	# когда под мышью меняется строка-подсказка или описание режима.
	_col.custom_minimum_size.x = MENU_WIDTH
	_col.add_theme_constant_override("separation", 4)
	card.add_child(_col)

	show_page(page)


func current_page() -> String:
	return _page


func show_page(page: String) -> void:
	_page = page
	for child in _col.get_children():
		_col.remove_child(child)
		child.queue_free()
	_mode_note = null
	_dots = null
	match page:
		PAGE_PLAY:
			_build_play()
		PAGE_HOTSEAT:
			_build_hotseat()
		PAGE_ONLINE:
			_build_online()
		PAGE_MATCHMAKING:
			_build_matchmaking()
		PAGE_LOBBY:
			_build_lobby()
		PAGE_LIBRARY:
			_build_library()
		_:
			_page = PAGE_MAIN
			_build_main()


## Esc и BACK: на страницу выше.
func go_back() -> void:
	if PAGE_PARENTS.has(_page):
		show_page(PAGE_PARENTS[_page])


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE \
			and PAGE_PARENTS.has(_page):
		go_back()
		get_viewport().set_input_as_handled()


# --- страницы ---------------------------------------------------------------

func _build_main() -> void:
	_add_title("TYRANTS OF THE UNDERDARK")
	_col.add_child(_profile_row())
	_col.add_child(HSeparator.new())

	# Незаконченная онлайн-партия (игру закрыли или она упала) — вернуться в неё.
	if not NetSession.saved_game().is_empty():
		_col.add_child(_big_button("RETURN TO GAME", "Your online game is not over yet: go back to your seat.",
			func(): online_requested.emit("resume", 0, "")))
	_col.add_child(_big_button("PLAY", "Start a game: online or at this computer.",
		func(): show_page(PAGE_PLAY)))
	_col.add_child(_big_button("LIBRARY", "How to play and every card of the game.",
		func(): show_page(PAGE_LIBRARY)))
	# Фон по кругу: CLASSIC -> BLACK -> ORANGE IS NEW BLACK -> WINDOWS XP.
	var bg := _big_button(UnderdarkBg.button_text(),
		"Change the background (menu and game). Click again for the next one.", func(): pass) as Button
	bg.pressed.connect(func():
		UnderdarkBg.set_style(UnderdarkBg.next_style())
		bg.text = UnderdarkBg.button_text())
	_col.add_child(bg)
	_col.add_child(_big_button("QUIT", "Close the game.",
		func(): get_tree().quit()))

	_add_hint(PAGE_HINTS[_page])


func _build_play() -> void:
	_add_title("PLAY")
	_col.add_child(HSeparator.new())
	_col.add_child(_big_button("ONLINE", "Play over the internet or a home network.",
		func(): show_page(PAGE_ONLINE)))
	_col.add_child(_big_button("HOTSEAT", "2-4 players take turns at this computer.",
		func(): show_page(PAGE_HOTSEAT)))
	_col.add_child(HSeparator.new())
	_col.add_child(_back_button())
	_add_hint(PAGE_HINTS[_page])


func _build_hotseat() -> void:
	_add_title("HOTSEAT")
	_add_dim("Players take turns at this computer.")
	_col.add_child(HSeparator.new())
	_add_game_options()
	_col.add_child(HSeparator.new())

	_col.add_child(_big_button("START GAME", "Deal the cards and begin.",
		func(): started.emit(GameScreen.player_ids_for(_count), _mode)))
	_col.add_child(_back_button())
	_add_hint(PAGE_HINTS[_page])


func _build_online() -> void:
	_add_title("ONLINE")
	_col.add_child(HSeparator.new())
	_col.add_child(_big_button("MATCHMAKING", "Play with random people who are looking for a game too.",
		func(): show_page(PAGE_MATCHMAKING)))
	_col.add_child(_big_button("LOBBY", "Create a room for friends or join theirs.",
		func(): show_page(PAGE_LOBBY)))
	_col.add_child(HSeparator.new())
	_col.add_child(_back_button())
	_add_hint(PAGE_HINTS[_page])


## Поиск игры: случайные соперники, режим всегда RANDOM 4 — выбрать можно
## только, на сколько человек стол.
func _build_matchmaking() -> void:
	_add_title("MATCHMAKING")
	_add_dim("Random opponents. Market: %s." % MODE_TITLES[NetSession.MATCH_MODE])
	_col.add_child(HSeparator.new())
	var counts: Array = []
	var group := ButtonGroup.new()
	for count in range(GameScreen.MIN_PLAYERS, GameScreen.MAX_PLAYERS + 1):
		var b := _toggle(str(count), group, count == _match_count, 24)
		b.pressed.connect(func(): _match_count = count)
		b.mouse_entered.connect(func(): _set_hint("Look for a table of %d players." % count))
		b.mouse_exited.connect(func(): _set_hint(_hint_default))
		counts.append(b)
	_col.add_child(_heading("PLAYERS"))
	_col.add_child(_row(counts))
	_col.add_child(HSeparator.new())
	_col.add_child(_big_button("FIND GAME", "Wait in line until enough players are found.",
		func(): online_requested.emit("find", _match_count, NetSession.MATCH_MODE)))
	_col.add_child(_back_button())
	_add_hint(PAGE_HINTS[_page])


## Игра с друзьями: своя комната или вход в чужую.
func _build_lobby() -> void:
	_add_title("LOBBY")
	_col.add_child(HSeparator.new())
	_col.add_child(_heading("NEW GAME WITH FRIENDS", PixelTheme.GOLD))
	_add_game_options()
	_col.add_child(_pair(
		_button("CREATE ROOM", "Get a room code on our server and send it to friends.",
			func(): online_requested.emit("create", _count, _mode)),
		_button("HOST BY IP", "Home network or Radmin VPN: friends join by your IP.",
			func(): online_requested.emit("host", _count, _mode))))

	_col.add_child(HSeparator.new())
	_col.add_child(_heading("JOIN A FRIEND'S GAME", PixelTheme.GOLD))
	_col.add_child(_pair(
		_button("JOIN BY CODE", "Type the room code your friend got.",
			func(): online_requested.emit("join_code", 0, _mode)),
		_button("JOIN BY IP", "Type the IP of the friend who pressed HOST BY IP.",
			func(): online_requested.emit("join_ip", 0, _mode))))

	_col.add_child(HSeparator.new())
	_col.add_child(_back_button())
	_add_hint(PAGE_HINTS[_page])


func _build_library() -> void:
	_add_title("LIBRARY")
	_col.add_child(HSeparator.new())
	_col.add_child(_big_button("HOW TO PLAY", "Rules for beginners, page by page.",
		func(): how_to_play_requested.emit()))
	_col.add_child(_big_button("CARDS", "Every card of the game, half-deck by half-deck.",
		func(): cards_requested.emit()))
	_col.add_child(HSeparator.new())
	_col.add_child(_back_button())
	_add_hint(PAGE_HINTS[_page])


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


## Своя фишка с гербом, имя (щелчок — профиль) и камень звания. Звание,
## рейтинг и рубашка карт — внутри профиля (решение владельца, 2026-09-28).
func _profile_row() -> Control:
	var local := PlayerProfile.load_local()
	var colour := String(local["colour"])
	var icon := ProfileScreen.token_icon(colour if colour != "" else "red", String(local["emblem"]))
	var name_button := Button.new()
	name_button.text = String(local["name"]) if String(local["name"]) != "" else "No name yet"
	name_button.flat = true
	name_button.focus_mode = Control.FOCUS_NONE
	name_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	name_button.add_theme_color_override("font_color", PixelTheme.TEXT)
	name_button.add_theme_color_override("font_hover_color", PixelTheme.GOLD)
	name_button.add_theme_color_override("font_pressed_color", PixelTheme.GOLD)
	name_button.pressed.connect(func(): profile_requested.emit())
	name_button.mouse_entered.connect(func(): _set_hint("Your profile: name, emblem, card back, rank and last games."))
	name_button.mouse_exited.connect(func(): _set_hint(_hint_default))
	var parts: Array[Control] = [icon, name_button]
	# Звание онлайн-партий — каким его сервер сообщил в последний раз.
	var rating := PlayerProfile.cached_rating()
	if rating >= 0:
		parts.append(ProfileScreen.rank_badge(rating))
	var row := _row(parts)
	row.add_theme_constant_override("separation", 6)
	return row


# --- мелкие детали вёрстки ---------------------------------------------------

func _add_title(text: String) -> void:
	# Заголовок — тот же шрифт ровно вдвое крупнее (пиксель остаётся квадратным).
	var title := Label.new()
	title.text = text
	title.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
	title.add_theme_color_override("font_color", PixelTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(title)


func _add_dim(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(label)
	return label


func _heading(text: String, colour: Color = PixelTheme.TEXT_DIM) -> Label:
	var label := GameScreen.section_label(text)
	label.add_theme_color_override("font_color", colour)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _add_hint(default_text: String) -> void:
	_col.add_child(HSeparator.new())
	_hint_default = default_text
	_hint = _add_dim(default_text)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _set_hint(text: String) -> void:
	if _hint != null and is_instance_valid(_hint):
		_hint.text = text


func _big_button(text: String, hint: String, action: Callable) -> Control:
	var b := _button(text, hint, action)
	b.custom_minimum_size = BIG_BUTTON
	return b


func _back_button() -> Control:
	var b := _button("BACK", "One step back (Esc).", go_back)
	b.custom_minimum_size = Vector2(70, 16)
	return b


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
