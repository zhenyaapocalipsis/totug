extends SceneTree
const PC := preload("res://tools/pixel_cards.gd")
const L10n := preload("res://scenes/localization.gd")
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		printerr("FAIL: ", message)
func _initialize() -> void:
	for mode in ["standard", "double", "random3", "random4", "random6", "newera"]:
		var halves: Array[String] = ["shadow", "celestial"]
		if mode == "double": halves = ["shadow", "shadow"]
		if mode == "random3": halves.append("drow")
		if mode == "random4": halves.append_array(["drow", "dragons"] as Array[String])
		if mode == "random6": halves.append_array(["drow", "dragons", "demons", "undead"] as Array[String])
		var state := GameSetup.new_game(["red", "blue"] as Array[String], 11, halves, false, false, false, mode)
		var deck: Deck = state.players.red.deck
		deck.hand.clear()
		var initial := state.supplies.remaining("49124")
		check(initial == 4, mode + ": four familiars in supply")
		for i in range(5):
			deck.hand.append("49118")
			TurnEngine.play_card(state, "red", "49118", EffectResolver.new())
		check(deck.discard_pile.count("49124") == 4, mode + ": Strahd gains a familiar until exhausted")
		check(state.supplies.remaining("49124") == 0, mode + ": finite supply")
	var god_state := GameSetup.new_game(["red", "blue"] as Array[String], 11, ["drow", "dragons"] as Array[String], false, false, false)
	check(not god_state.supplies.counts.has("49124"), "no Ravenloft: no familiar supply")
	GodMode.give_card(god_state, "red", "49118", 1, "hand")
	TurnEngine.play_card(god_state, "red", "49118", EffectResolver.new())
	check(god_state.players.red.deck.discard_pile.has("49124"), "God Mode Strahd gains familiar without Ravenloft")
	check(god_state.supplies.remaining("49124") == 3, "God Mode creates exactly four tokens")
	god_state.supplies.counts["49124"] = 0
	GodMode.give_card(god_state, "red", "49118", 1, "hand")
	check(god_state.supplies.remaining("49124") == 0, "giving Strahd again does not refill exhausted supply")
	var state := GameSetup.new_game(["red", "blue"] as Array[String], 11, [], false, false, false)
	state.market.display[0] = "49010"
	state.players.red.deck.hand = ["50100", "48613"] as Array[String]
	var r := EffectResolver.new()
	TurnEngine.play_card(state, "red", "50100", r)
	r.resume(state, 1)
	r.resume(state, 0)
	check(state.played_aspects_this_turn.has("CONQUEST"), "copied Planetar supports later Conquest Focus")
	r.resume(state, 2)  # Planetar: draw per House Guard (zero here).
	check(not r.is_waiting(), "copied Planetar finishes")
	TurnEngine.play_card(state, "red", "48613", r)
	check(r.is_waiting(), "Cultist asks for a white troop")
	if r.is_waiting(): r.resume(state, r.pending.legal_options[0])
	check(r.is_waiting() and r.pending.choice_type == "target_slot", "Cultist Focus asks to deploy troops")

	state.turn_flags.clear()
	state.stock("red").trophy_hall_count = 0
	check(CardLive.entry(state, "red", "50107").notes[0].text == "(0/4)", "Kraken starts at 0/4")
	state.turn_flags = {"trophy_start": 0, "deploys": 3, "spy_done": true, "promoted": true}
	state.stock("red").trophy_hall_count = 1
	check(CardLive.entry(state, "red", "50107").notes[0].text == "(4/4)", "Kraken reaches 4/4")
	for locale in ["en", "ru"]:
		L10n.set_locale(locale)
		var img := Image.load_from_file("res://assets/cards_mini/50002.png")
		CardLiveFace._draw_mini_header(img, "50002", 10)
		if OS.get_cmdline_user_args().has("screenshots"):
			img.save_png("res://bug-frog-" + locale + ".png")
		check(PC.mini_side_x("10") + 2 + PC.text_width("10", 1) <= PC.MINI_W - 1, "price 10 fits")
		var box := CardLiveFace.layout_for_card("50107", CardLive.entry(state, "red", "50107").notes, 160, 285)
		check(str(box.words).contains("4/4"), "Kraken counter visible in " + locale)
	print("bug fixes: failed ", failed)
	quit(1 if failed else 0)
