extends SceneTree

const L10n := preload("res://scenes/localization.gd")
const Settings := preload("res://scenes/game_settings.gd")
const SettingsPanel := preload("res://scenes/ui/settings_panel.gd")
const TEST_PATH := "res://.godot/localization_test.cfg"
var passed := 0
var failed := 0
var startup_only := false


func _initialize() -> void:
	Settings.path_override = TEST_PATH
	Settings._cfg = null
	startup_only = OS.get_cmdline_user_args().has("--verify-saved")
	if not startup_only:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	_run.call_deferred()


func check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: ", description)


func _run() -> void:
	if startup_only:
		var restored := SettingsPanel.new()
		check(L10n.locale() == "ru" and restored._language_button.text == "Русский", "fresh process restores Russian before constructing UI")
		restored.free()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
		print("запуск: пройдено %d, провалено %d" % [passed, failed])
		quit(1 if failed else 0)
		return
	var en := L10n.catalog("en")
	var ru := L10n.catalog("ru")
	check(en.size() == ru.size() and en.keys().all(func(k): return ru.has(k)), "catalog coverage")
	var placeholders := RegEx.new()
	placeholders.compile("\\{[^}]+\\}")
	for key: String in en:
		var english: String = en[key]
		var russian: String = ru.get(key, "")
		check(not russian.is_empty(), "nonempty: " + key)
		check(placeholders.search_all(english).map(func(m): return m.get_string()) ==
			placeholders.search_all(russian).map(func(m): return m.get_string()), "parameters: " + key)
		for ch: String in placeholders.sub(russian, "", true).replace("\n", ""):
			check(PixelTheme.theme().default_font.has_char(ch.unicode_at(0)), "glyph: " + ch)
	check(L10n.locale() == "en", "default is English")
	var first := SettingsPanel.new()
	root.add_child(first)
	var pause := PauseMenu.new()
	root.add_child(pause)
	pause.visible = true
	pause.show_settings(true)
	var second: Control = pause._settings.get_child(1)
	var menu := SetupScreen.new(SetupScreen.PAGE_SETTINGS)
	# The menu remains unparented: no deferred layout tour rebuilding its tabs.
	var first_id := first.get_instance_id()
	var second_id := second.get_instance_id()
	var old_hold := Settings.hold_seconds()
	first._wait_key("ping")
	first._language_button.pressed.emit()
	check(L10n.locale() == "ru", "language button switches to Russian")
	check(second._language_button.text == "Русский", "other settings panel updates immediately")
	check(first._waiting == "ping" and first._key_buttons.ping.text == "НАЖМИТЕ КЛАВИШУ", "key capture preserved")
	check(pause.settings_open() and _button(pause, "НАЗАД") != null, "open pause settings preserved")
	check(menu.current_page() == SetupScreen.PAGE_SETTINGS and _button(menu, "НАСТРОЙКИ") != null, "menu tab preserved")
	check(first.get_instance_id() == first_id and second.get_instance_id() == second_id, "panels not recreated")
	check(Settings.hold_seconds() == old_hold, "other settings unchanged")
	var config := ConfigFile.new()
	check(config.load(TEST_PATH) == OK and config.get_value("interface", "language", "") == "ru", "saved Russian")
	# Recreate configuration cache, as in another launch; check the disk value.
	Settings._cfg = null
	L10n.set_locale("en")
	Settings._apply("language")
	check(L10n.locale() == "ru", "saved language loads before next screen")
	check(L10n.text("settings.seconds", {"value": 3}) == "3 С", "parameter formatting")
	ru.erase("settings.sound")
	check(L10n.text("settings.sound") == "SOUND", "missing Russian entry falls back to English")
	ru["settings.sound"] = "ЗВУК"
	check(L10n.text("unknown.key") == "unknown.key", "unknown key stays visible")
	second._language_button.pressed.emit()
	check(L10n.locale() == "en" and _button(pause, "BACK") != null, "switch back from in-game settings")
	check(first._waiting == "ping" and first._key_buttons.ping.text == "PRESS A KEY", "capture survives return to English")
	check(_button(menu, "SETTINGS") != null, "menu updates back to English")
	var listener_count := L10n.events.changed.get_connections().size()
	first.free()
	pause.free()
	menu.free()
	check(L10n.events.changed.get_connections().size() < listener_count, "freed panels disconnect")
	Settings.set_value("language", "unsupported")
	config.load(TEST_PATH)
	check(L10n.locale() == "en" and config.get_value("interface", "language", "") == "en", "invalid language uses English")
	# The second invocation verifies real startup, then removes this test file.
	Settings.set_value("language", "ru")
	print("локализация: пройдено %d, провалено %d" % [passed, failed])
	quit(1 if failed else 0)


func _button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption:
		return node
	for child in node.get_children():
		var found := _button(child, caption)
		if found != null:
			return found
	return null
