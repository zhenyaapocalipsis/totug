extends SceneTree

const L10n := preload("res://scenes/localization.gd")
const Settings := preload("res://scenes/game_settings.gd")
var failed := 0

func _initialize() -> void:
	Settings.path_override = "res://.godot/localization_menu.cfg"
	Settings._cfg = null
	_run.call_deferred()

func check(ok: bool) -> void:
	if not ok:
		failed += 1

func _run() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(960, 540))
	L10n.set_locale("en")
	var menu := SetupScreen.new(SetupScreen.PAGE_LOBBY)
	root.add_child(menu)
	for i in 12:
		await process_frame
	menu._lobby_join = true
	menu._join_by_ip = false
	menu.show_page(SetupScreen.PAGE_LOBBY)
	for i in 3:
		await process_frame
	var edit: LineEdit = menu._col.find_children("*", "LineEdit", true, false)[0]
	edit.text = "Q7RW"
	var id := edit.get_instance_id()
	var mode := menu._chosen_mode()
	L10n.set_locale("ru")
	check(TranslationServer.get_or_add_domain(&"ui_captions").translate("JOIN") == "ВОЙТИ")
	check(TranslationServer.get_or_add_domain(&"ui_captions").translate("HOTSEAT") == "НА ОДНОМ ПК")
	check(edit.text == "Q7RW" and edit.get_instance_id() == id)
	check(menu._chosen_mode() == mode and TranslationServer.translate("START") == "START")
	check(menu._action.text == "JOIN" and menu._action.tr(menu._action.text) == "ВОЙТИ")
	var received: Array = []
	menu.online_requested.connect(func(kind, _count, _mode, address): received.assign([kind, address]))
	menu._action.pressed.emit()
	check(received == ["join_code", "Q7RW"])
	if DisplayServer.get_name() != "headless":
		for i in 18:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/localization_menu_ru.png")
	L10n.set_locale("en")
	check(menu._action.tr(menu._action.text) == "JOIN" and edit.text == "Q7RW")
	menu.free()
	print("menu translation: 7 checks, failed %d" % failed)
	quit(1 if failed else 0)
