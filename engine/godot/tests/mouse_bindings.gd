extends SceneTree

const Settings := preload("res://scenes/game_settings.gd")
const SettingsPanel := preload("res://scenes/ui/settings_panel.gd")
var passed := 0
var failed := 0

func check(value: bool, label: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
	print("%s %s" % ["ok" if value else "FAIL", label])

func _initialize() -> void:
	Settings.path_override = "user://mouse_bindings_test.cfg"
	Settings._cfg = null
	Settings.reset_keys()
	call_deferred("run")

func run() -> void:
	var panel := SettingsPanel.new()
	root.add_child(panel)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_XBUTTON1
	panel._wait_key("zoom")
	mouse.pressed = false
	panel._input(mouse)
	check(panel.waiting_for_key(), "release does not assign a button")
	mouse.pressed = true
	panel._input(mouse)
	check(not panel.waiting_for_key() and Settings.is_key(mouse, "zoom"), "panel assigns mouse button")
	check(panel._key_buttons["zoom"].text == "MOUSE 8", "panel displays mouse binding")
	panel._wait_key("ping")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	panel._input(escape)
	check(not panel.waiting_for_key() and Settings.key("ping") == KEY_TAB, "Escape cancels assignment")
	Settings._cfg = null
	check(Settings.is_key(mouse, "zoom"), "mouse binding persists after reload")
	Settings.set_key("ping", Settings.key("zoom"))
	check(Settings.key("zoom") == KEY_TAB and Settings.is_key(mouse, "ping"), "mouse and keyboard bindings swap")
	Settings.reset_keys()
	check(Settings.key("zoom") == KEY_ALT and Settings.key("ping") == KEY_TAB, "reset restores keyboard defaults")
	Settings.set_key("zoom", -MOUSE_BUTTON_XBUTTON1)
	panel.queue_free()
	var screen := GameScreen.new(7)
	root.add_child(screen)
	var preview := CardPreview.active
	preview._input(mouse)
	check(preview.alt_held(), "mouse press enables card preview")
	mouse.pressed = false
	preview._input(mouse)
	check(not preview.alt_held(), "mouse release disables card preview")
	Settings.set_key("end_turn", -MOUSE_BUTTON_RIGHT)
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = true
	screen._input(mouse)
	check(screen._space_held, "mouse press starts end turn hold")
	mouse.pressed = false
	screen._input(mouse)
	check(not screen._space_held, "mouse release cancels end turn hold")
	Settings.set_key("ping", -MOUSE_BUTTON_MIDDLE)
	mouse.button_index = MOUSE_BUTTON_MIDDLE
	mouse.pressed = true
	screen._input(mouse)
	check(screen._tab_down, "mouse press starts ping wheel")
	mouse.pressed = false
	screen._input(mouse)
	check(not screen._tab_down, "mouse release ends ping wheel")
	mouse.button_index = MOUSE_BUTTON_LEFT
	screen._input(mouse)
	check(true, "unbound mouse button passes without errors")
	Settings.set_key("fullscreen", -MOUSE_BUTTON_XBUTTON2)
	mouse.button_index = MOUSE_BUTTON_XBUTTON2
	mouse.pressed = true
	root.get_node("WindowKeys")._input(mouse)
	check(Settings.value("window_mode") == "full", "mouse button toggles fullscreen")
	Settings.reset_keys()
	screen.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path()))
	print("mouse bindings: passed %d, failed %d" % [passed, failed])
	quit(1 if failed else 0)
