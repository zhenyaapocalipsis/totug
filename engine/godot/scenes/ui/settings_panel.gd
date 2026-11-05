extends HBoxContainer

## Настройки игры — одна панель на два места: вкладка SETTINGS главного меню
## и SETTINGS в меню по Esc (владелец, 2026-10-06). Слева звук и экран, справа
## клавиши и игровые мелочи. Всё сохраняется сразу, кнопки APPLY нет.
##
## Переназначить клавишу: щелчок по ней, потом нужная клавиша (Esc — передумать).
## Занятая клавиша меняется местами с прежней.

const GameSettings := preload("res://scenes/game_settings.gd")

const L10n := preload("res://scenes/localization.gd")

const LABEL_W := 116
const VALUE_BUTTON := Vector2(80, 16)
const SLIDER_W := 80

## Кнопки клавиш по действиям и действие, которое ждёт новую клавишу.
var _key_buttons: Dictionary = {}
var _waiting := ""
var _screen_button: Button
var _language_button: Button
var _captions: Array[Dictionary] = []
var _cycle_values: Array[Dictionary] = []
var _slider_values: Array[Dictionary] = []


func _init() -> void:
	add_theme_constant_override("separation", 8)
	var left := _column()
	add_child(left)
	add_child(VSeparator.new())
	var right := _column()
	add_child(right)

	_language_button = _value_button(L10n.language_name(), func(_b: Button):
		GameSettings.set_value("language", "ru" if L10n.locale() == "en" else "en"))
	_language_button.name = "LanguageButton"
	left.add_child(_row("settings.language", _language_button))
	left.add_child(_heading("settings.sound"))
	left.add_child(_slider_row("settings.master", float(GameSettings.value("master_volume")),
		func(v: float): GameSettings.set_value("master_volume", v)))
	left.add_child(_slider_row("settings.effects", Sfx.volume, func(v: float): Sfx.set_volume(v)))
	left.add_child(_slider_row("settings.music", Music.volume, func(v: float): Music.set_volume(v)))

	left.add_child(_heading("settings.screen"))
	_screen_button = _value_button(L10n.text("settings.mode_" + GameSettings.window_mode_now()), func(b: Button):
		var i := GameSettings.WINDOW_MODES.find(GameSettings.window_mode_now())
		var next: String = GameSettings.WINDOW_MODES[(i + 1) % GameSettings.WINDOW_MODES.size()]
		GameSettings.set_value("window_mode", next)
		b.text = L10n.text("settings.mode_" + next))
	left.add_child(_row("settings.mode", _screen_button))
	# F11 и Alt+Enter переключают экран и мимо этой кнопки.
	visibility_changed.connect(func():
		_screen_button.text = L10n.text("settings.mode_" + GameSettings.window_mode_now()))
	left.add_child(_cycle_row("settings.vsync", "vsync", [true, false], _on_off))
	left.add_child(_cycle_row("settings.fps_limit", "max_fps", GameSettings.FPS_LIMITS, _fps_label))
	left.add_child(_cycle_row("settings.show_fps", "show_fps", [false, true], _on_off))

	right.add_child(_heading("settings.keys"))
	for action: String in GameSettings.ACTIONS:
		if action == "ally_hand" and not SetupScreen.TEAMS_ENABLED:
			continue  # клавиша T нужна только в 2v2 (спрятан)
		var b := _value_button(GameSettings.key_name(action), func(_b: Button): _wait_key(action))
		_key_buttons[action] = b
		right.add_child(_row("settings.key." + action, b))
	right.add_child(_row("settings.pause_menu", _fixed("ESC")))
	var reset := _value_button(L10n.text("settings.reset_keys"), func(_b: Button):
		GameSettings.reset_keys()
		_wait_key(""))
	_caption(reset, "settings.reset_keys")
	reset.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_child(reset)

	right.add_child(_heading("settings.game"))
	right.add_child(_cycle_row("settings.hold", "hold_seconds", GameSettings.HOLD_STEPS,
		_seconds_label))
	right.add_child(_cycle_row("settings.animations", "anim_speed", GameSettings.SPEED_STEPS,
		GameSettings.speed_label))
	right.add_child(_cycle_row("settings.move_hints", "move_hints", [true, false], _on_off))
	L10n.events.changed.connect(_refresh_language)


## Ждать клавишу для action ("" — не ждать). Подписи всех клавиш — заново.
func _wait_key(action: String) -> void:
	_waiting = action
	for a: String in _key_buttons:
		(_key_buttons[a] as Button).text = L10n.text("settings.press_key") if a == action else GameSettings.key_name(a)


func waiting_for_key() -> bool:
	return _waiting != ""


## Новая клавиша для ждущего действия. Esc — передумать; ушли с панели —
## тоже. Событие дальше не идёт: ни в партию, ни в меню по Esc.
func _input(event: InputEvent) -> void:
	if _waiting == "":
		return
	if not is_visible_in_tree():
		_wait_key("")
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	if key.keycode != KEY_ESCAPE:
		GameSettings.set_key(_waiting, key.keycode if key.keycode != KEY_NONE else key.physical_keycode)
	_wait_key("")


# --- строки ----------------------------------------------------------------------

func _column() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	return col


func _heading(text: String) -> Label:
	var label := GameScreen.section_label("")
	_caption(label, text)
	label.add_theme_color_override("font_color", PixelTheme.GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## Подпись слева, настройка справа.
func _row(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var label := Label.new()
	_caption(label, text)
	label.custom_minimum_size.x = LABEL_W
	label.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	row.add_child(control)
	return row


## Ползунок 0–100% с числом справа; меняет громкость сразу.
func _slider_row(text: String, start: float, apply: Callable) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = roundf(start * 100.0)
	slider.custom_minimum_size = Vector2(SLIDER_W, 16)
	slider.focus_mode = Control.FOCUS_NONE
	box.add_child(slider)
	var number := Label.new()
	number.custom_minimum_size.x = 30
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.text = _percent(slider.value)
	box.add_child(number)
	_slider_values.append({"number": number, "slider": slider})
	slider.value_changed.connect(func(v: float):
		number.text = _percent(v)
		apply.call(v / 100.0))
	return _row(text, box)


static func _percent(v: float) -> String:
	return L10n.text("settings.off") if v <= 0.0 else "%d%%" % roundi(v)


## Кнопка-значение: щелчок — следующее из steps (по кругу), сразу в файл.
func _cycle_row(text: String, setting: String, steps: Array, label: Callable) -> HBoxContainer:
	var b := _value_button(label.call(GameSettings.value(setting)), func(button: Button):
		button.text = label.call(GameSettings.cycle(setting, steps)))
	_cycle_values.append({"button": b, "setting": setting, "format": label})
	return _row(text, b)


func _value_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = VALUE_BUTTON
	b.focus_mode = Control.FOCUS_NONE
	SetupScreen._style_button(b)
	b.pressed.connect(func(): action.call(b))
	return b


## Неизменяемое значение (Esc): та же рамка, но без нажатия.
func _fixed(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = VALUE_BUTTON
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", PixelTheme.TEXT_OFF)
	return label


func _caption(control: Control, key: String) -> void:
	control.set("text", L10n.text(key))
	_captions.append({"control": control, "key": key})


func _refresh_language() -> void:
	for entry: Dictionary in _captions:
		entry.control.set("text", L10n.text(entry.key))
	_language_button.text = L10n.language_name()
	_screen_button.text = L10n.text("settings.mode_" + GameSettings.window_mode_now())
	for entry: Dictionary in _cycle_values:
		entry.button.text = entry.format.call(GameSettings.value(entry.setting))
	for entry: Dictionary in _slider_values:
		entry.number.text = _percent(entry.slider.value)
	_wait_key(_waiting)


static func _on_off(value: bool) -> String:
	return L10n.text("settings.on" if value else "settings.off")


static func _fps_label(value: int) -> String:
	return L10n.text("settings.no_limit") if value <= 0 else str(value)


static func _seconds_label(value: float) -> String:
	return L10n.text("settings.seconds", {"value": str(int(value)) if value == floorf(value) else str(value)})
