extends SceneTree

const L10n := preload("res://scenes/localization.gd")
const Settings := preload("res://scenes/game_settings.gd")

class FakeNet extends NetSession:
	var sent: Array[String] = []
	func ban_card(card: String) -> void:
		sent.append(card)

var passed := 0
var failed := 0

func _initialize() -> void:
	Settings.path_override = "res://.godot/localization_bans.cfg"
	Settings._cfg = null
	_run.call_deferred()

func check(ok: bool, why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: ", why)

func _run() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(960, 540))
	L10n.set_locale("en")
	var net := FakeNet.new()
	net.seat = "red"
	var panel := BanPanel.new(net)
	root.add_child(panel)
	panel.set_process(false)
	var view := {"decks": ["drow", "dragons", "demons", "undead"], "turn": "red", "left": 38.5,
		"locked": ["dragons"], "order": ["blue", "red", "green", "purple", "purple", "green", "red", "blue"],
		"bans": [{"seat": "blue", "card": ""}], "each": 2}
	panel.show_view(view)
	panel.select("48306")
	panel._chat_edit.text = "Набранное [b]сообщение[/b]"
	var input_id := panel._chat_edit.get_instance_id()
	var grid_id := (panel._decks.drow.grid as Control).get_instance_id()
	panel._on_chat("green", "Keep [b]this[/b] text Й")
	panel._on_chat("blue", BanPanel.SUGGEST_PREFIX + "48306")
	check(panel.chat_text().contains("suggests banning ADVOCATE"), "English suggestion")
	check(panel._ban.text == "BAN ADVOCATE", "English selected button")
	L10n.set_locale("ru")
	check(panel._ban.text == "ЗАПРЕТИТЬ ЗАЩИТНИК", "Russian selected button")
	check(panel._status.text.contains("ВАШ ЗАПРЕТ") and panel._status.text.contains("ДРОУ"), "Russian selected status")
	check(panel._selected == "48306" and panel._left == 38.5 and panel.deck_shown("drow"), "selection, timer and deck preserved")
	check((panel._decks.drow.grid as Control).get_instance_id() == grid_id, "card grid preserved")
	check(panel._chat_edit.get_instance_id() == input_id and panel._chat_edit.text == "Набранное [b]сообщение[/b]", "draft and input preserved")
	check(panel.chat_text().contains("Keep [b]this[/b] text Й"), "user message literal")
	check(panel.chat_text().contains("предлагает запретить ЗАЩИТНИК (ДРОУ)"), "existing suggestion translated")
	check((panel._decks.dragons.tab as Button).text == "x ДРАКОНЫ", "locked tab localized")
	check(not panel.can_ban(GameSetup.half_deck_copies("dragons").keys()[0]), "locked deck stays locked")
	check(net.sent.is_empty(), "language switch sends no action")
	panel._send(panel._selected)
	check(net.sent == ["48306"], "stable card ID submitted")
	L10n.set_locale("en")
	check(panel._ban.disabled and panel._skip.disabled, "pending action stays disabled")
	check(panel._ban.text == "BAN ADVOCATE" and panel.chat_text().contains("suggests banning ADVOCATE"), "English restored")
	var starting := view.duplicate(true)
	starting.turn = ""
	starting.starting = true
	starting.left = 9.2
	panel.show_view(starting)
	L10n.set_locale("ru")
	check(panel._left == 9.2 and panel._clock.text == "0:10" and panel._status.text.contains("через 10"), "starting countdown preserved and translated")
	# Return to selected-card state for a visual check without contacting a server.
	panel.show_view(view)
	panel.select("48306")
	if DisplayServer.get_name() != "headless":
		for i in 18:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/localization_bans_ru.png")
	var long_decks := view.duplicate(true)
	long_decks.decks = ["freljord", "celestial", "mercenaries", "aberrations"]
	long_decks.locked = []
	panel.show_view(long_decks)
	L10n.set_locale("en")
	L10n.set_locale("ru")
	await process_frame
	check(panel.chat_text().contains("предлагает запретить ЗАЩИТНИК (ДРОУ)"), "old suggestion keeps original deck")
	var long_tab: Button = panel._decks.freljord.tab
	check(long_tab.tooltip_text.contains("ДОЛИНА ЛЕДЯНОГО ВЕТРА") and long_tab.tooltip_text.contains("ICEWIND DALE"), "full and original deck names available")
	check(long_tab.size.x < 100 and panel._decks.celestial.tab.clip_text, "long titles keep tab row width")
	panel._on_chat("red", "close before deferred scroll")
	var listeners := L10n.events.changed.get_connections().size()
	panel.free()
	await process_frame
	check(L10n.events.changed.get_connections().size() < listeners, "subscriptions released")
	net.free()
	L10n.set_locale("en")
	print("bans localization: passed %d, failed %d" % [passed, failed])
	quit(1 if failed else 0)
