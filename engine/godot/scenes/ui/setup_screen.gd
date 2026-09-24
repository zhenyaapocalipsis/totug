class_name SetupScreen
extends Control

## Экран перед партией: сколько человек садится за один экран (хотсит).
##
## Правила и доска умеют 2, 3 и 4 игроков (GameSetup.pick_hexes — раскладки
## с B2/B3 и с пятью угловыми гексами), но экран партии всегда собирал игру
## ровно на двоих. Выбор количества живёт здесь, а GameScreen получает уже
## готовый список цветов — так экран партии ничего не знает про меню.
##
## Вёрстка кодом по той же причине, что и в game_screen.gd: .tscn в этом
## проекте правится вслепую, без редактора.

signal started(player_ids: Array[String], mode: String)
## Сетевая игра. kind: "create" / "join_code" — через сервер с кодами комнат,
## "host" / "join_ip" — напрямую по IP (локальная сеть, Radmin VPN).
signal online_requested(kind: String, player_count: int, mode: String)
## Открыть профиль игрока (имя и герб, ProfileScreen).
signal profile_requested
## Открыть обучение для новичков (how_to_play_screen.gd).
signal how_to_play_requested

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

var _mode: String = GameSetup.MODE_STANDARD
var _mode_note: Label

const BUTTON_SIZE := Vector2(90, 16)
const DOT := 7.0
## Задник экрана подключён файлом, а не по глобальному имени класса:
## глобальные имена собирает редактор, а проект часто запускается из
## командной строки, где нового имени ещё нет в кэше.
const UnderdarkBg := preload("res://scenes/ui/underdark_bg.gd")


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PixelTheme.theme()

	# Живой задник во всю силу: меню — единственное место, где фону не мешают
	# ни доска, ни карты.
	add_child(UnderdarkBg.make())

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", GameScreen.zone_style(6))
	centre.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	card.add_child(col)

	# Заголовок — тот же шрифт ровно вдвое крупнее (пиксель остаётся квадратным).
	var title := Label.new()
	title.text = "TYRANTS OF THE UNDERDARK"
	title.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
	title.add_theme_color_override("font_color", PixelTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Play at one screen (hotseat) or online"
	subtitle.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(subtitle)

	col.add_child(_profile_row())

	var learn_row := HBoxContainer.new()
	learn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(learn_row)
	var learn := Button.new()
	learn.text = "HOW TO PLAY"
	learn.tooltip_text = "Rules for beginners, page by page"
	learn.custom_minimum_size = BUTTON_SIZE
	_style_button(learn)
	learn.pressed.connect(func(): how_to_play_requested.emit())
	learn_row.add_child(learn)

	col.add_child(HSeparator.new())
	col.add_child(GameScreen.section_label("GAME MODE"))
	col.add_child(_mode_row())
	_mode_note = Label.new()
	_mode_note.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	_mode_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_mode_note)
	_select_mode(GameSetup.MODE_STANDARD)

	col.add_child(HSeparator.new())
	col.add_child(GameScreen.section_label("HOW MANY PLAYERS?"))

	for count in range(GameScreen.MIN_PLAYERS, GameScreen.MAX_PLAYERS + 1):
		col.add_child(_count_row(count))

	col.add_child(HSeparator.new())
	col.add_child(GameScreen.section_label("ONLINE: ROOM CODE (same game mode)"))
	col.add_child(_online_row("create", "CREATE", "join_code", "JOIN CODE",
		"Create a room on the server for %d players; friends join by its code"))
	col.add_child(GameScreen.section_label("DIRECT: HOME NETWORK OR RADMIN VPN"))
	col.add_child(_online_row("host", "HOST", "join_ip", "JOIN IP",
		"Open a game for %d players; the others join by your IP"))

	col.add_child(HSeparator.new())
	var note := Label.new()
	note.text = "The first player is drawn at random."
	note.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(note)

	var quit_row := HBoxContainer.new()
	quit_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(quit_row)
	var quit := Button.new()
	quit.text = "QUIT GAME"
	quit.custom_minimum_size = BUTTON_SIZE
	_style_button(quit)
	quit.pressed.connect(func(): get_tree().quit())
	quit_row.add_child(quit)


## Своя фишка с гербом, имя и кнопка PROFILE.
func _profile_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var local := PlayerProfile.load_local()
	row.add_child(ProfileScreen.token_icon("red", String(local["emblem"])))
	var name_label := Label.new()
	name_label.text = String(local["name"]) if String(local["name"]) != "" else "No name yet"
	name_label.add_theme_color_override("font_color", PixelTheme.TEXT)
	row.add_child(name_label)
	var button := Button.new()
	button.text = "PROFILE"
	button.tooltip_text = "Your name and emblem (drawn on your troops)"
	button.custom_minimum_size = Vector2(60, 16)
	_style_button(button)
	button.pressed.connect(func(): profile_requested.emit())
	row.add_child(button)
	return row


## Четыре кнопки режима; нажатая остаётся подсвеченной (ButtonGroup).
func _mode_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var group := ButtonGroup.new()
	for mode: String in GameSetup.MODES:
		var button := Button.new()
		button.text = MODE_TITLES[mode]
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = mode == GameSetup.MODE_STANDARD
		button.custom_minimum_size = Vector2(60, 16)
		_style_button(button)
		button.pressed.connect(func(): _select_mode(mode))
		row.add_child(button)
	return row


func _select_mode(mode: String) -> void:
	_mode = mode
	_mode_note.text = MODE_NOTES[mode]


## Строка сетевой игры: открыть партию на 2/3/4 места или войти в чужую.
func _online_row(open_kind: String, open_text: String, join_kind: String, join_text: String,
		open_tip: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for count in range(GameScreen.MIN_PLAYERS, GameScreen.MAX_PLAYERS + 1):
		var open := Button.new()
		open.text = "%s %d" % [open_text, count]
		open.tooltip_text = open_tip % count
		open.custom_minimum_size = Vector2(56, 16)
		_style_button(open)
		open.pressed.connect(func(): online_requested.emit(open_kind, count, _mode))
		row.add_child(open)
	var join := Button.new()
	join.text = join_text
	join.tooltip_text = "Join a game someone else has opened"
	join.custom_minimum_size = Vector2(62, 16)
	_style_button(join)
	join.pressed.connect(func(): online_requested.emit(join_kind, 0, _mode))
	row.add_child(join)
	return row


## Строка выбора: кнопка с числом и цветные фишки тех, кто сядет за стол.
func _count_row(count: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var ids := GameScreen.player_ids_for(count)
	var button := Button.new()
	button.text = "%d PLAYERS" % count
	button.custom_minimum_size = BUTTON_SIZE
	_style_button(button)
	button.pressed.connect(func(): started.emit(ids, _mode))
	row.add_child(button)

	# Фишки лежат в блоке постоянной ширины (место под все четыре), иначе
	# строки разной длины и кнопки стоят лесенкой.
	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 3)
	dots.custom_minimum_size = Vector2(
		DOT * GameScreen.MAX_PLAYERS + 3.0 * (GameScreen.MAX_PLAYERS - 1), 0)
	row.add_child(dots)
	for pid: String in ids:
		var dot := ColorRect.new()
		dot.color = BoardPanel.PLAYER_COLORS.get(pid, Color.GRAY)
		dot.custom_minimum_size = Vector2(DOT, DOT)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.tooltip_text = EventLogPanel.player_name(pid)
		dots.add_child(dot)

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
