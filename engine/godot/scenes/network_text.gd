extends RefCounted

## Legacy English network strings are recognized only at the display edge.
const EXACT := {
  "Could not connect": "network.connect",
  "The connection to the game was lost": "network.lost",
  "The server is full, try again later": "network.full_server",
  "This game has already started": "network.started",
  "This game is full": "network.full_game",
  "Too many wrong room codes. Wait a few minutes and try again": "network.codes",
  "Too many new players from your network today. Try again tomorrow": "network.accounts",
  "Your router has no public internet address (provider NAT).": "network.nat",
  "Router did not answer (UPnP is off or unsupported).": "network.no_router"
}
const PATTERNS := [
	["^There is no room (.+)$", "network.room", ["code"]],
	["^Different game version \\(yours ([0-9]+), server ([0-9]+)\\): update the game$", "network.version", ["client", "server"]],
	["^The name (.+) is taken by another player. Go BACK and click your name to change it$", "network.name", ["name"]],
	["^Your provider gives no public address \\((.+)\\)\\.$", "network.private", ["address"]],
	["^Router refused to open port ([0-9]+)\\.$", "network.refused", ["port"]],
	["^Port ([0-9]+) is open on your router\\.$", "network.opened", ["port"]]]

static func message(source: String) -> Dictionary:
	if EXACT.has(source):
		return {"l10n_key": EXACT[source]}
	for pattern: Array in PATTERNS:
		var match_ := RegEx.create_from_string(pattern[0]).search(source)
		if match_ != null:
			var parameters := {}
			for i in pattern[2].size():
				parameters[pattern[2][i]] = match_.get_string(i + 1)
			return {"l10n_key": pattern[1], "parameters": parameters}
	return {"l10n_key": "network.unknown", "parameters": {"source": source}}
