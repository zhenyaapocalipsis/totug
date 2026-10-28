class_name PauseMenu
extends Control

## Меню по Esc во время партии: настройки, вернуться в главное меню или выйти
## из игры. Повторный Esc (или RESUME) закрывает, из настроек Esc — назад к
## кнопкам. Пока меню открыто, щелчки до игры под ним не доходят, а таймер
## хода стоит (GameScreen._process).

signal main_menu_requested

const BUTTON_SIZE := Vector2(110, 16)
const SettingsPanel := preload("res://scenes/ui/settings_panel.gd")

var _col: VBoxContainer
## Настройки (SettingsPanel) с заголовком и BACK — на месте кнопок меню.
var _settings: VBoxContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Над всем экраном партии, включая меню по Tab (z_index 1000).
	z_index = 1100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	var dim := ColorRect.new()
	dim.color = PixelTheme.DIM
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", GameScreen.zone_style(6))
	centre.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)

	var title := Label.new()
	title.text = "MENU"
	title.add_theme_color_override("font_color", PixelTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	col.add_child(_button("RESUME", func(): visible = false))
	# Все настройки — та же панель, что во вкладке SETTINGS главного меню
	# (владелец, 2026-10-06); громкость теперь там.
	col.add_child(_button("SETTINGS", func(): show_settings(true)))
	col.add_child(_button("MAIN MENU", func(): main_menu_requested.emit()))
	col.add_child(_button("QUIT GAME", func(): get_tree().quit()))
	_col = col

	_settings = VBoxContainer.new()
	_settings.add_theme_constant_override("separation", 4)
	_settings.visible = false
	card.add_child(_settings)
	var head := Label.new()
	head.text = "SETTINGS"
	head.add_theme_color_override("font_color", PixelTheme.GOLD)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings.add_child(head)
	_settings.add_child(SettingsPanel.new())
	_settings.add_child(HSeparator.new())
	var back := _button("BACK", func(): show_settings(false))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_settings.add_child(back)

	# Пока меню открыто, музыка звучит приглушённо, «за стеной». Закрыли —
	# в следующий раз оно открывается с кнопок, не с настроек.
	visibility_changed.connect(func():
		Music.set_muffled(is_visible_in_tree())
		if not visible:
			show_settings(false))


## Настройки вместо кнопок меню (и обратно).
func show_settings(on: bool) -> void:
	_settings.visible = on
	_col.visible = not on


func settings_open() -> bool:
	return _settings.visible


## Ещё одна кнопка — сразу под RESUME (сетевая партия: PAUSE FOR ALL).
func add_button(text: String, action: Callable) -> void:
	var button := _button(text, action)
	_col.add_child(button)
	_col.move_child(button, 2)


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	SetupScreen._style_button(button)
	button.pressed.connect(action)
	return button
