extends SceneTree

var failed := 0

func check(value: bool, message: String) -> void:
	if not value:
		failed += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	var ids: Array[String] = ["red", "blue", "green", "purple"]
	var screen := GameScreen.new(1793884280, [], ids, GameSetup.MODE_STANDARD,
		{}, ["blue", "green", "purple"])
	var before := screen._bug_extra()
	for pid: String in ids:
		check(before["setup"]["initial"][pid]["soldier"] == 3, "initial Soldier count " + pid)
		check(before["setup"]["initial"][pid]["n"] == 10, "initial deck size " + pid)
		var deck: Deck = screen.server.state.players[pid].deck
		# Model an unrecorded mutation without changing the replay or data files.
		while deck.hand.has("48344"):
			deck.hand.erase("48344")
		while deck.draw_pile.has("48344"):
			deck.draw_pile.erase("48344")
	var extra := screen._bug_extra()
	for pid: String in ids:
		check(extra["setup"]["initial"][pid]["soldier"] == 3, "evidence is frozen " + pid)
		check(extra["current"][pid]["soldier"] == 0, "mutation is visible " + pid)
		check(extra["current"][pid]["n"] == 7, "short deck is visible " + pid)
	check(extra["setup"]["cached"]["copies"]["48344"] == 3, "cached starting data")
	check(extra["setup"]["disk"]["copies"]["48344"] == 3, "on-disk starting data")
	check(String(extra["setup"]["data_sha"]).length() == 64, "data hash")
	check(String(extra["setup"]["setup_sha"]).length() == 64, "code hash")
	var copies: Dictionary = GameSetup._load_half_decks()["starting_deck"]["copies"]
	var saved: Variant = copies["48344"]
	copies["48344"] = 0
	var changed := BugReport.starting_evidence(screen.server.state)
	copies["48344"] = saved
	check(changed["cached"]["copies"]["48344"] == 0, "changed cache is recorded")
	check(changed["disk"]["copies"]["48344"] == 3, "cache differs from the package")
	check(extra["setup"]["cached"]["copies"]["48344"] == 3, "initial inputs are frozen")

	var clean := BugReport.clean({"id": "starter_evidence", "extra": extra})
	var received: Variant = JSON.parse_string(clean["extra"])
	check(received is Dictionary, "evidence survives the report size limit")
	check(received == JSON.parse_string(JSON.stringify(extra)), "all evidence survives sanitization")
	check(JSON.stringify(extra).length() <= BugReport.TEXT_MAX, "four-player evidence fits")
	check(screen._replay_log.is_empty(), "no intents needed to expose the mutation")
	screen.free()
	print("starter evidence: failed ", failed)
	quit(0 if failed == 0 else 1)
