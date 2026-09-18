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

const BUTTON_SIZE := Vector2(190, 52)
const DOT := 18.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.052, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", GameScreen.zone_style(28))
	centre.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)

	var title := Label.new()
	title.text = "TYRANTS OF THE UNDERDARK"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.93, 0.86, 0.62))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Hotseat: everyone plays at this screen, one after another"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.72, 0.7, 0.8))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(subtitle)

	col.add_child(HSeparator.new())
	col.add_child(GameScreen.section_label("HOW MANY PLAYERS?"))

	for count in range(GameScreen.MIN_PLAYERS, GameScreen.MAX_PLAYERS + 1):
		col.add_child(_count_row(count))

	col.add_child(HSeparator.new())
	var note := Label.new()
	note.text = "Two random half-decks each game; the first player is drawn at random."
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(0.6, 0.58, 0.68))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(note)


## Строка выбора: кнопка с числом и цветные фишки тех, кто сядет за стол.
func _count_row(count: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var ids := GameScreen.player_ids_for(count)
	var button := Button.new()
	button.text = "%d PLAYERS" % count
	button.custom_minimum_size = BUTTON_SIZE
	button.add_theme_font_size_override("font_size", 18)
	_style_button(button)
	button.pressed.connect(func(): started.emit(ids))
	row.add_child(button)

	# Фишки лежат в блоке постоянной ширины (место под все четыре), иначе
	# строки разной длины и кнопки стоят лесенкой.
	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 8)
	dots.custom_minimum_size = Vector2(
		DOT * GameScreen.MAX_PLAYERS + 8.0 * (GameScreen.MAX_PLAYERS - 1), 0)
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
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.15, 0.21)
	normal.border_color = Color(0.36, 0.34, 0.44)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.24, 0.21, 0.3)
	hover.border_color = Color(0.92, 0.75, 0.35)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(0.1, 0.09, 0.14)
	pressed.border_color = Color(0.8, 0.62, 0.3)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(0.9, 0.88, 0.95))
	button.add_theme_color_override("font_hover_color", Color(1, 0.97, 0.88))
