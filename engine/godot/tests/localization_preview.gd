extends SceneTree

const L10n := preload("res://scenes/localization.gd")
const Settings := preload("res://scenes/game_settings.gd")
var failures := 0


func _initialize() -> void:
	Settings.path_override = "res://.godot/localization_preview.cfg"
	Settings._cfg = null
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path_override))
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(960, 540))
	L10n.set_locale("en")
	var menu := SetupScreen.new(SetupScreen.PAGE_SETTINGS)
	root.add_child(menu)
	for i in 12:
		await process_frame
	var menu_settings: Control = menu._tabs[SetupScreen.PAGE_SETTINGS].find_child("LanguageButton", true, false)
	_click(menu_settings)
	for i in 3:
		await process_frame
	_check(L10n.locale() == "ru", "mouse click in main menu")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/localization_ru_menu.png")
	print("menu bounds: ", menu._window.get_global_rect())
	menu.free()
	var base := Control.new()
	base.theme = PixelTheme.theme()
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(base)
	var pause := PauseMenu.new()
	base.add_child(pause)
	pause.visible = true
	pause.show_settings(true)
	for i in 6:
		await process_frame
	var pause_language: Control = pause.find_child("LanguageButton", true, false)
	_click(pause_language)
	for i in 3:
		await process_frame
	_check(L10n.locale() == "en", "mouse click in pause settings")
	_click(pause_language)
	for i in 3:
		await process_frame
	_check(L10n.locale() == "ru" and pause.settings_open(), "mouse return to Russian preserves panel")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/localization_ru_pause.png")
	base.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path_override))
	print("language mouse checks: 3, failed: %d" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", description)


func _click(control: Control) -> void:
	var point: Vector2 = root.get_screen_transform() * control.get_global_rect().get_center()
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		event.position = point
		event.global_position = point
		Input.parse_input_event(event)
	Input.flush_buffered_events()
