extends SceneTree

const L10n := preload("res://scenes/localization.gd")
const Settings := preload("res://scenes/game_settings.gd")

class FakeNet extends NetSession:
	var actions: Array = []
	func friends_action(action: String, args: Array = []) -> void:
		actions.append([action, args])

class FakeUpdater extends Updater:
	var requests: Array[String] = []
	var installed := ""
	func _ready() -> void:
		_label = Label.new()
		_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		theme = PixelTheme.theme()
		add_child(_label)
		L10n.bind(_label, "update.checking")
	func _pack_path() -> String:
		return "res://.godot/localization_update.pck"
	func _request(relative: String) -> void:
		requests.append(relative)
	func _restart_with(fresh: String) -> bool:
		installed = fresh
		return true

var passed := 0
var failed := 0

func _initialize() -> void:
	Settings.path_override = "res://.godot/localization_profile_settings.cfg"
	Settings._cfg = null
	PlayerProfile.path_override = "res://.godot/localization_profile.cfg"
	_run.call_deferred()

func check(ok: bool, why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: ", why)

func texts(node: Node) -> String:
	var out := ""
	if node is Label or node is Button:
		out += node.tr(node.text) + "\n"
	for child in node.get_children():
		out += texts(child)
	return out

func shot(file: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/" + file)

func _run() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(960, 540))
	var bg := ColorRect.new()
	bg.color = PixelTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	L10n.set_locale("en")
	PlayerProfile.save_local({"name": "START", "emblem": ""})
	PlayerProfile.cache_stats({"rating": 1160, "games": 10, "wins": 4})
	PlayerProfile.save_phrases(["Keep my phrase", "", "Oops!", "Йога"])
	var entry := {"time": 1793923200, "place": 1, "seat": "red", "rating": 1160, "delta": 12, "vp": 42, "won": true,
		"players": [{"seat": "red", "name": "START", "vp": 42, "won": true}, {"seat": "blue", "name": "Друг", "vp": 35}],
		"breakdown": {"sites": 8, "total_control": 4, "trophies": 5, "deck": 10, "inner_circle": 12, "tokens": 3}}
	PlayerProfile.add_history(entry)
	PlayerProfile.add_totals(entry)
	var cfg_before := FileAccess.get_file_as_string(PlayerProfile.path())
	var profile := ProfileScreen.new()
	profile.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(profile)
	profile._edit_name(true)
	profile._name_edit.text = "ЙНовый ник"
	var name_id := profile._name_edit.get_instance_id()
	var emblem := profile.emblem()
	L10n.set_locale("ru")
	check(profile._name_edit.visible and profile._name_edit.text == "ЙНовый ник" and profile._name_edit.get_instance_id() == name_id, "rename draft preserved")
	check(texts(profile).contains("МАТРОНА") and texts(profile).contains("ДАЛЕЕ: ТИРАН ПРИ 1250"), "rank and next threshold translated")
	check(profile._stats_name.text == "START", "nickname literal")
	check(profile.emblem() == emblem, "emblem preserved")
	check(profile._counter.text.contains("Можно закрасить пикселей"), "pixel counter translated")
	check(texts(profile).contains("ПОСЛЕДНИЕ ИГРЫ ПО СЕТИ: 1") and texts(profile).contains("1-Е") and texts(profile).contains("ПО ЗА ИГРУ"), "history table translated")
	profile._show_tab("CHAT")
	profile._phrase_edits[0].text = "Новый черновик Й"
	var edit_id := profile._phrase_edits[0].get_instance_id()
	L10n.set_locale("en")
	L10n.set_locale("ru")
	check(profile._page == "CHAT" and profile._chat.visible and profile._phrase_edits[0].text == "Новый черновик Й" and profile._phrase_edits[0].get_instance_id() == edit_id, "chat draft and tab preserved")
	check(profile._phrase_edits[1].placeholder_text == "Думаю..." and profile._phrase_edits[2].text == "Oops!", "default hint translated, saved phrase literal")
	L10n.bind(profile._saved_note, "profile.saved")
	profile._changed()
	L10n.set_locale("en")
	check(profile._saved_note.text == "", "cleared save message stays cleared")
	check(FileAccess.get_file_as_string(PlayerProfile.path()) == cfg_before, "language switch writes no profile data")
	profile._save()
	check(PlayerProfile.load_phrase_overrides()[1] == "" and PlayerProfile.load_phrase_overrides()[2] == "Oops!" and PlayerProfile.load_phrases()[1] == "Thinking...", "save preserves default marker and explicit English phrase")
	profile._show_tab("STATS")
	L10n.set_locale("ru")
	await shot("localization_profile_ru.png")
	profile._show_tab("EMBLEM")
	await shot("localization_emblem_ru.png")
	profile._show_tab("CHAT")
	await shot("localization_phrases_ru.png")
	profile.free()
	var card := ProfileCard.new("blue", {"name": "START", "rating": 1160, "games": 10, "wins": 4})
	root.add_child(card)
	card._place(Vector2(950, 530))
	check(texts(card).contains("START") and texts(card).contains("МАТРОНА") and texts(card).contains("ДОЛЯ ПОБЕД 40%"), "player card translated")
	var net := FakeNet.new()
	card._add_friend_button(net, "START")
	var add: Button = card._col.get_child(card._col.get_child_count() - 1)
	check(add.text == "ДОБАВИТЬ В ДРУЗЬЯ", "friend action translated")
	add.pressed.emit()
	check(net.actions == [["list", []], ["add", ["START"]]] and add.disabled, "friend request keeps original recipient")
	L10n.set_locale("en")
	check(add.text == "REQUEST SENT" and add.disabled, "pending friend request preserved")
	L10n.set_locale("ru")
	await process_frame
	check(card._panel.position.x >= 0 and card._panel.position.y >= 0 and card._panel.get_global_rect().end.x <= 960, "translated card stays in viewport")
	card.free()
	net.free()
	var other := PlayerProfilePanel.new(null, "START")
	root.add_child(other)
	other.show_data({"missing": true})
	check(other._status.text == "Игрок START не найден.", "missing profile translated")
	other._waiting = ["sample.replay", "blue"]
	L10n.set_locale("en")
	check(other._waiting == ["sample.replay", "blue"] and other._status.text == "No player named START.", "pending replay unchanged")
	other.free()
	var history := ProfileScreen.history_players({"seat": "red", "players": [{"seat": "red", "name": "START", "vp": 42, "won": true}]})
	root.add_child(history)
	L10n.set_locale("ru")
	check(history.get_child(0).tooltip_text == "START (вы): 42 ПО, победитель", "history tooltip translated")
	history.free()
	var updater := FakeUpdater.new()
	updater.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(updater)
	check(updater._label.text == "ПРОВЕРКА ОБНОВЛЕНИЙ...", "updater starts in saved language")
	updater._stage = Updater.Stage.PATCH
	updater._show_progress(1048576, 4194304, 2.5)
	check(updater._label.text.contains("ИСПРАВЛЕНИЕ  25%") and updater._label.text.contains("1.0 / 4.0 МиБ"), "Russian progress")
	L10n.set_locale("en")
	check(updater._label.text == "DOWNLOADING PATCH  25%\n1.0 / 4.0 MiB  |  2.5 MiB/s" and updater.requests.is_empty() and updater._stage == Updater.Stage.PATCH, "progress switch sends no request")
	updater._start_full()
	L10n.set_locale("ru")
	check(updater._label.text == "ЗАГРУЗКА ОБНОВЛЕНИЯ..." and updater.requests == ["game.pck"], "fallback state preserved")
	updater._show_progress(2097152, 4194304, 1.5)
	await shot("localization_update_ru.png")
	updater._install()
	L10n.set_locale("en")
	check(updater._label.text == "RESTARTING..." and updater.installed.ends_with(".pck.new"), "restart stage localized without real installation")
	updater.free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayerProfile.path()))
	print("profile/update localization: passed %d, failed %d" % [passed, failed])
	quit(1 if failed else 0)
