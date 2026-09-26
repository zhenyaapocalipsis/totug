extends Control

## Вопрос сразу после создания профиля: пройти обучение (HOW TO PLAY) или
## сразу в главное меню. Тексты кнопок — решение владельца (2026-09-26).
##
## Без class_name: экран подключается файлом (preload), так его видно и без
## кэша редактора. Вёрстка кодом, как у остальных экранов меню.

## true — игрок новичок и хочет обучение.
signal answered(wants_tutorial: bool)

const YES_TEXT := "YES, I'M NEWBY"
const NO_TEXT := "NO, I'M ALREADY KIKORIKI"
const UnderdarkBg := preload("res://scenes/ui/underdark_bg.gd")


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PixelTheme.theme()
	add_child(UnderdarkBg.make())

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", GameScreen.zone_style(12))
	centre.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	var name_text := String(PlayerProfile.load_local()["name"])
	var title := Label.new()
	title.text = "WELCOME, %s!" % name_text.to_upper() if name_text != "" else "WELCOME!"
	title.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
	title.add_theme_color_override("font_color", PixelTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var question := Label.new()
	question.text = "Is this your first time in the Underdark?\nThe tutorial explains the rules page by page."
	question.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(question)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	row.add_child(_button(YES_TEXT, true))
	row.add_child(_button(NO_TEXT, false))


func _button(text: String, wants: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(160, 22)
	SetupScreen._style_button(b)
	b.pressed.connect(func(): answered.emit(wants))
	return b
