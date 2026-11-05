extends SceneTree

const L10n := preload("res://scenes/localization.gd")
const Settings := preload("res://scenes/game_settings.gd")
const OUTBOX := "res://.godot/localization_bug_outbox/"

class FakeNet extends NetSession:
	var online := true
	var sends := 0
	func is_connected_to_server() -> bool:
		return online
	func send_bug_reports() -> void:
		sends += 1

var passed := 0
var failed := 0

func _initialize() -> void:
	Settings.path_override = "res://.godot/localization_bug_settings.cfg"
	Settings._cfg = null
	PlayerProfile.path_override = "res://.godot/localization_bug_profile.cfg"
	_run.call_deferred()

func check(ok: bool, why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: ", why)

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
	var log_path: Variant = ProjectSettings.get_setting("debug/file_logging/log_path")
	ProjectSettings.set_setting("debug/file_logging/log_path", "res://.godot/nonexistent_bug_fixture.log")
	var bg := ColorRect.new()
	bg.color = PixelTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	PlayerProfile.save_local({"name": "Test Й", "emblem": ""})
	var net := FakeNet.new()
	net.bug_outbox = OUTBOX
	L10n.set_locale("en")
	var window := BugReportWindow.new()
	window.net = net
	window.where = "online"
	window.record = {"header": {"seed": 42}, "intents": []}
	window.extra = {"card_id": "48306", "seat": "red"}
	root.add_child(window)
	var pending_before := BugReport.pending(OUTBOX).size()
	window._on_send()
	check(window._status.text == "Please describe the problem first." and not window._send.disabled, "empty description rejected")
	check(BugReport.pending(OUTBOX).size() == pending_before and net.sends == 0, "empty report not queued or sent")
	window._text.text = "Черновик Й: [b]не выбирается войско[/b]\nПосле карты 48306."
	window._text.select(0, 0, 0, 8)
	var selected := window._text.get_selected_text()
	var text_id := window._text.get_instance_id()
	window._attach.button_pressed = false
	window._shot = Image.create(8, 8, false, Image.FORMAT_RGB8)
	window._shot.fill(Color.RED)
	var shot_id := window._shot.get_instance_id()
	L10n.set_locale("ru")
	check(window._text.get_instance_id() == text_id and window._text.text.begins_with("Черновик Й") and window._text.get_selected_text() == selected, "draft, selection and input preserved")
	check(not window._attach.button_pressed and window._shot.get_instance_id() == shot_id, "attachment choice and original screenshot preserved")
	check(window._send.text == "ОТПРАВИТЬ" and window._status.text == "Сначала опишите проблему.", "form and validation message update")
	check(window._sent_id == "" and net.sends == 0, "language switch sends nothing")
	window._status.hide()
	await shot("localization_bug_ru.png")
	window._on_send()
	var id := window._sent_id
	var reports := BugReport.pending(OUTBOX).filter(func(r): return r.id == id)
	check(reports.size() == 1 and reports[0].text == window._text.text and reports[0].name == "Test Й", "user report text and name remain literal")
	check(reports[0].shot.is_empty() and reports[0].where == "online" and reports[0].extra.card_id == "48306" and reports[0].record.header.seed == 42, "attachment exclusion and stable evidence preserved")
	check(window._send.disabled and not window._text.editable and net.sends == 1 and window._status.text == "Отправка...", "sending state")
	L10n.set_locale("en")
	check(window._status.text == "Sending..." and window._send.disabled and not window._text.editable and net.sends == 1 and window._sent_id == id, "pending send survives language switch")
	net.bug_report_sent.emit("another-report", true)
	check(window._status.text == "Sending...", "unrelated acknowledgement ignored")
	L10n.set_locale("ru")
	net.bug_report_sent.emit(id, true)
	check(window._status.text == "Отчёт отправлен. Спасибо!", "acknowledgement translated")
	await shot("localization_bug_sent_ru.png")
	window.free()
	BugReport.done(id, OUTBOX)
	var offline := BugReportWindow.new()
	net.online = false
	offline.net = net
	root.add_child(offline)
	offline._text.text = "Offline fixture Й"
	offline._shot = Image.create(8, 8, false, Image.FORMAT_RGB8)
	offline._shot.fill(Color.BLUE)
	offline._on_send()
	var queued := BugReport.pending(OUTBOX).filter(func(r): return r.text == "Offline fixture Й")
	check(queued.size() == 1 and not queued[0].shot.is_empty() and net.sends == 1, "offline report with screenshot queued locally")
	await shot("localization_bug_queued_ru.png")
	L10n.set_locale("en")
	check(offline._status.text == "Saved. It will be sent when you are back in the main menu." and offline._send.disabled, "offline status switches language")
	offline.free()
	for r in queued:
		BugReport.done(r.id, OUTBOX)
	var limited := BugReportWindow.new()
	root.add_child(limited)
	limited._sent_id = "fixture-limit"
	limited._on_sent("fixture-limit", false)
	L10n.set_locale("ru")
	check(limited._status.text == "Слишком много отчётов. Повторите попытку позже.", "rate limit status updates")
	limited._show_status("bug.save_error", PixelTheme.TEXT_DIM)
	L10n.set_locale("en")
	check(limited._status.text == "Could not save the report.", "save failure status switches back")
	limited._unhandled_key_input(InputEventMouseMotion.new())
	limited.free()
	# Auto-close timers must safely outlive a manually closed window.
	await create_timer(BugReportWindow.THANKS_SECONDS * 2 + 0.1).timeout
	check(BugReport.pending(OUTBOX).size() == pending_before, "test reports cleaned without touching other outboxes")
	net.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayerProfile.path()))
	ProjectSettings.set_setting("debug/file_logging/log_path", log_path)
	print("bug report localization: passed %d, failed %d" % [passed, failed])
	quit(1 if failed else 0)
