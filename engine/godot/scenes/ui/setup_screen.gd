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

signal started(player_ids: Array[String])

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
	subtitle.text = "Hotseat: everyone plays at this screen, one by one"
	subtitle.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(subtitle)

	col.add_child(HSeparator.new())
	col.add_child(GameScreen.section_label("HOW MANY PLAYERS?"))

	for count in range(GameScreen.MIN_PLAYERS, GameScreen.MAX_PLAYERS + 1):
		col.add_child(_count_row(count))

	col.add_child(HSeparator.new())
	var note := Label.new()
	note.text = "Two random half-decks; the first player is drawn at random."
	note.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(note)


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
	button.pressed.connect(func(): started.emit(ids))
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
		PixelTheme.box(PixelTheme.PANEL_HI, PixelTheme.BORDER, 1, 4, 2))
	button.add_theme_stylebox_override("hover",
		PixelTheme.box(PixelTheme.BORDER, PixelTheme.GOLD, 1, 4, 2))
	button.add_theme_stylebox_override("pressed",
		PixelTheme.box(PixelTheme.GOLD, PixelTheme.GOLD, 1, 4, 2))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", PixelTheme.TEXT)
	button.add_theme_color_override("font_hover_color", PixelTheme.GOLD)
	button.add_theme_color_override("font_pressed_color", PixelTheme.BG)
