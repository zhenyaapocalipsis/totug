extends RefCounted

## Display names only. EventLog and game/network IDs retain their original values.
const L10n := preload("res://scenes/localization.gd")

static func player_message(pid: String) -> Dictionary:
	if pid == GameState.WHITE:
		return {"l10n_key": "game.player_white"}
	var own := PlayerProfile.name_of(pid)
	if own != "":
		return {"l10n_key": "lobby.raw", "parameters": {"value": own}}
	var team := String(BoardPanel.team_of.get(pid, ""))
	if team != "":
		return {"l10n_key": "game.team_player", "parameters": {"team": colour_message(team), "number": 1 if team == pid else 2}}
	return colour_message(pid)

static func colour_message(pid: String) -> Dictionary:
	var key := "game.player_" + pid
	return {"l10n_key": key} if L10n.catalog("en").has(key) else {"l10n_key": "lobby.raw", "parameters": {"value": pid.capitalize()}}

static func team_message(pid: String) -> Dictionary:
	var key := "game.team_" + pid
	return {"l10n_key": key} if L10n.catalog("en").has(key) else {"l10n_key": "lobby.raw", "parameters": {"value": pid.to_upper() + " TEAM"}}

static func player_name(pid: String) -> String:
	var message := player_message(pid)
	return L10n.text(message.l10n_key, message.get("parameters", {}))

static func trophies_text(trophies: Dictionary, order: Array) -> String:
	var parts: Array[String] = []
	for colour in ["white"] + order:
		var count := int(trophies.get(String(colour), 0))
		if count > 0:
			parts.append("%s %d" % [L10n.text("game.neutral") if colour == "white" else player_name(String(colour)), count])
	return L10n.text("game.trophies", {"parts": ", ".join(parts) if not parts.is_empty() else L10n.text("game.none")})
