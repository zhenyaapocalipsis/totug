extends SceneTree
const L10n := preload("res://scenes/localization.gd")
const Text := preload("res://scenes/decision_text.gd")
const Settings := preload("res://scenes/game_settings.gd")
var passed := 0
var failed := 0
func _initialize() -> void:
	Settings.path_override = "res://.godot/localization_decisions.cfg"
	Settings._cfg = null
	PlayerProfile.path_override = "res://.godot/localization_decisions_profile.cfg"
	_run.call_deferred()
func check(ok: bool, why: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		printerr("FAIL: ", why)
func ids(node: Node) -> Array:
	var result := []
	for child in node.get_children():
		if child is Button or child is CardView or child is OptionCard:
			result.append(child.get_instance_id())
		result.append_array(ids(child))
	return result
func _run() -> void:
	L10n.set_locale("en")
	var screen := GameScreen.new(7, ["drow", "dragons"], ["red", "blue"])
	root.add_child(screen)
	screen.set_process(false)
	screen._decision_dialog.visible = false
	screen._piles_window.visible = false
	var dialog := DecisionDialog.new()
	screen.add_child(dialog)
	var view := {"current_player":"red", "pending_decision":{"player_id":"red", "choice_type":"confirm", "prompt":"Devour this card?", "legal_options":[true,false], "source_card":"48320"}}
	dialog.update_from_view(view,"red")
	var answers := []
	dialog.option_chosen.connect(func(a): answers.append(a))
	for i in 3: await process_frame
	var original := JSON.stringify(view)
	var nodes := ids(dialog)
	var blink := dialog._blink_time
	L10n.set_locale("ru")
	for i in 3: await process_frame
	check(dialog._prompt.text == "Поглотить эту карту?", "prompt translated")
	check(ids(dialog) == nodes and JSON.stringify(view) == original, "same choices and unmodified server view")
	check(dialog._blink_time == blink and answers.is_empty(), "language does not answer or reset animation")
	var button := dialog._options_box.get_child(0).get_child(0) as Button
	check(button.text == "Да", "confirm caption")
	button.pressed.emit()
	check(answers == [true], "original bool response")
	L10n.set_locale("en")
	check(dialog._prompt.text == "Devour this card?" and button.text == "Yes", "English restored")
	view.pending_decision = {"player_id":"red", "choice_type":"choose_option", "prompt":"Choose one:", "legal_options":[0,1],"source_card":"48320", "option_labels":["Place a spy", "+2 Influence"]}
	dialog.update_from_view(view,"red")
	dialog.toggle_cards()
	var key := dialog._cards_key
	L10n.set_locale("ru")
	for i in 3: await process_frame
	check(dialog._cards_hidden and dialog._cards_key == key, "hidden option cards stay hidden")
	dialog.update_from_view(view,"red")
	check(dialog._cards_hidden, "same prompt refresh preserves hidden choice")
	L10n.set_locale("en")
	view.pending_decision = {"player_id":"red", "choice_type":"choose_option", "prompt":"Choose one:", "legal_options":[0,1,2], "option_labels":["Choose a player: they place three 1 VP tokens for you", "Set aside a card that costs 5 or less: it is played at the start of each of your turns", "Give a played card to an opponent"]}
	dialog.update_from_view(view,"red")
	for i in 3: await process_frame
	nodes = ids(dialog)
	button = dialog._options_box.get_child(0).get_child(0) as Button
	button.grab_focus()
	L10n.set_locale("ru")
	for i in 4: await process_frame
	check(ids(dialog) == nodes and button.has_focus(), "long translated choices reflow without replacing buttons or focus")
	button.pressed.emit()
	check(answers == [true,0], "reflow preserves option index: " + str(answers))
	var piles := PilesWindow.new()
	screen._board_area.add_child(piles)
	piles.set_strip_bottom(screen._decision_dialog.strip_bottom)
	var pd := {"tag":"explore","player_id":"red","prompt":"Explore", "source_card":"48320", "data":{"cards":["48320","48306","48340"],"takeable":["48320","48306"],"take_left":1,"take_label":"HAND","what":"a card that costs 3 or less"}}
	piles.show_decision(pd,"red")
	piles._set_where(1,"take")
	piles._swap(0,2)
	var plan := piles.plan()
	nodes = ids(piles)
	var data := JSON.stringify(pd)
	L10n.set_locale("en")
	for i in 3: await process_frame
	L10n.set_locale("ru")
	for i in 3: await process_frame
	check(piles.plan() == plan and ids(piles) == nodes and JSON.stringify(pd) == data, "Explore order, routing and cards preserved")
	check(piles._title.text == "Исследуйте 3 верхних карт:" and not piles._hint.text.contains("TOP"), "Explore title and rules translated")
	check(piles._hint.text.contains("карта стоимостью не выше 3"), "nested Explore filter translated")
	piles.show_decision(pd,"red")
	check(piles.plan() == plan, "same server decision keeps edited plan")
	pd = {"tag":"lamia","player_id":"red","prompt":"Lamia", "data":{"step":"split","rival":"blue","face_up":["48320","48306"],"face_down":["48340"]}}
	piles.show_decision(pd,"red")
	piles._move_card("48320",true)
	var up := piles._up.duplicate()
	var down := piles._down.duplicate()
	nodes = ids(piles)
	L10n.set_locale("en")
	L10n.set_locale("ru")
	for i in 3: await process_frame
	check(piles._up == up and piles._down == down and ids(piles) == nodes, "Lamia edited split preserved")
	check(piles._title.text.begins_with("Разделите"), "Lamia title translated")
	check(Text.text("Assassinate a troop (2 left)") == "Уничтожьте отряд (осталось: 2)", "count suffix translated")
	check(Text.text("Return one of your troops (1/3)") == "Верните свой отряд (1/3)", "progress counts retained")
	check(Text.text("Unknown old replay prompt") == "Unknown old replay prompt", "unknown legacy text retained")
	PlayerProfile.seats = {"red":{"name":"Yes"}}
	check(Text.text("Waiting for Yes.") == "Ожидание: Yes." and Text.text("Yes") == "Да", "nickname protected without blocking button captions")
	PlayerProfile.seats = {}
	for source: String in Text._data.exact:
		check(Text.text(source) != source, "catalog exact: " + source)
	for entry: Dictionary in Text._data.patterns:
		var source := String(entry.source).replace("%s", "SAMPLE").replace("%d", "2")
		var translated := Text.text(source)
		check(translated == String(entry.target).format({"v0": "SAMPLE" if String(entry.source).begins_with("%s") else "2", "v1": "2", "v2": "2"}) or (not translated.contains("{v") and translated != source), "catalog pattern: " + source)
	dialog.visible = false
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/localization_decisions_ru.png")
	print("localized decisions: ", passed, " checks, failed ", failed)
	quit(1 if failed else 0)
