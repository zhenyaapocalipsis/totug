class_name CardLive
extends RefCounted

## Живой текст карт (владелец, 2026-10-11): числа и условия в тексте карты —
## по нынешнему положению игрока. Считает сервер (StateView кладёт их в срез
## игрока, view["live"]), рисует клиент (CardLiveFace): после фразы текста
## встаёт пометка — сколько сейчас ("(3)", "(+2)") или прогресс условия ("(2/4)"),
## зелёная, если условие выполнено / число не ноль, красная — если нет. Цена
## карты со скидкой (Cursed Affinity, House Guard дешевле) — новой цифрой.
##
## entry(): {"notes": [{phrase, text, ok}], "cost": цена сейчас} — "cost" только
## если она не равна напечатанной; пустой словарь — у карты ничего живого.

## Фраза текста (заглавными, без конечной точки) -> что после неё показать:
##   ["per", источник, N]   — "+(счёт / N)": VP / Power за каждые N;
##   ["count", источник]    — "(счёт)": за каждый, сколько их сейчас;
##   ["need", источник, N]  — "(счёт/N)": условие "N или больше";
##   ["have", источник]     — "(YES)"/"(NO)".
## Источники — GainVpPerN._count_source и свои (_count).
const RULES := {
	"48711": [["FOR EACH SITE YOU CONTROL", "count", "sites_controlled"]],  # Quaggoth
	"48705": [["FOR EACH SPY YOU HAVE ON THE BOARD", "count", "spies_on_board"]],  # Aboleth
	"48715": [["FOR EVERY 3 TROOPS IN YOUR TROPHY HALL", "per", "trophy_hall", 3]],  # Beholder
	"48433": [["FOR EVERY 2 SITES YOU CONTROL", "per", "sites_controlled", 2]],  # White Dragon
	"48419": [["SITE CONTROL MARKER YOU HAVE", "per", "control_markers", 1]],  # Green Dragon
	"48400": [["WHITE TROOPS IN YOUR TROPHY HALL", "per", "white_trophy", 3]],  # Black Dragon
	"48403": [["CARDS IN YOUR INNER CIRCLE", "per", "inner_circle", 3]],  # Blue Dragon
	"48426": [["SITE UNDER YOUR TOTAL CONTROL", "per", "sites_controlled_total", 1]],  # Red Dragon
	"48721": [["PLAYER TROOPS IN YOUR TROPHY HALL", "per", "player_trophy", 5]],  # Death Knight
	"48728": [["CARDS IN YOUR INNER CIRCLE", "per", "inner_circle", 3]],  # Vampire
	"48320": [["4 OR MORE CARDS IN YOUR INNER CIRCLE", "need", "inner_circle", 4]],  # Drow Negotiator
	"48415": [["5 OR MORE PLAYER TROOPS IN YOUR TROPHY HALL", "need", "player_trophy", 5]],  # Dragonclaw
	"48738": [["8 OR MORE TROOPS IN YOUR TROPHY HALL", "need", "trophy_hall", 8]],  # Revenant
	"49001": [["6 OR MORE CARDS IN YOUR INNER CIRCLE", "need", "inner_circle", 6]],  # Priest
	"49015": [["LEFT YOUR BARRACKS", "need", "troops_left", 10]],  # Solar
	"49102": [["PUT AN INSANE OUTCAST INTO YOUR HAND", "have", "outcast_supply"]],  # Death Dog
	"49112": [["INSANE OUTCASTS FROM YOUR DISCARD PILE", "count", "discard_outcasts"]],  # Spirit Naga
	"49019": [["GIANT EAGLE IN YOUR DISCARD PILE", "have", "eagle_discard"],  # Scout
		["IN YOUR DECK", "have", "eagle_deck"]],
	"49008": [["PER HOUSE GUARD PLAYED THIS TURN", "per", "guards_played", 1]],  # Pegasus
	"49010": [["PER HOUSE GUARD PLAYED THIS TURN", "per", "guards_played", 1]],  # Planetar
	"49013": [["PER SPY YOU HAVE ON THE BOARD", "per", "spies_on_board", 1]],  # Unicorn
	"49120": [["COSTS 1 LESS PER INSANE OUTCAST YOU PLAYED THIS TURN", "less", "outcasts_played"],  # Drider
		["PER SPY YOU HAVE ON THE BOARD", "per", "spies_on_board", 1]],
	"49123": [["PER SPY YOU HAVE ON THE BOARD", "per", "spies_on_board", 1]],  # Phase Spider
	"49100": [["PER INSANE OUTCAST YOU PLAYED THIS TURN", "per", "outcasts_played", 1]],  # Specter
	"49105": [["PER INSANE OUTCAST YOU PLAYED THIS TURN", "per", "outcasts_played", 1]],  # Grick
	"49108": [["PER INSANE OUTCAST YOU PLAYED THIS TURN", "per", "outcasts_played", 1]],  # Gargoyle
	"49107": [["PER INSANE OUTCAST PLAYED THIS TURN", "count", "outcasts_played"]],  # Sea Hag
	"49110": [["PER INSANE OUTCAST PLAYED THIS TURN", "count", "outcasts_played"]],  # Lemure
	"49115": [["PER INSANE OUTCAST IN YOUR DISCARD PILE", "per", "discard_outcasts_x3", 1]],  # Chain Devil
	"49113": [["COSTS 1 LESS PER INSANE OUTCAST YOU PLAYED THIS TURN", "less", "outcasts_played"],  # Rakshasa
		["CARDS IN YOUR INNER CIRCLE", "per", "inner_circle", 3]],
	"49114": [["COSTS 1 LESS PER INSANE OUTCAST YOU PLAYED THIS TURN", "less", "outcasts_played"],  # Nightmare
		["PER 2 SITES YOU CONTROL", "per", "sites_controlled", 2]],
	"49118": [["PER SITE UNDER YOUR TOTAL CONTROL", "per", "sites_controlled_total", 1]],  # Treant
	"49119": [["COSTS 1 LESS PER INSANE OUTCAST YOU PLAYED THIS TURN", "less", "outcasts_played"],  # Bone Devil
		["PER 3 TROOPS IN YOUR TROPHY HALL", "per", "trophy_hall", 3]],
}


## Живое у всех карт из ids (повторы не мешают) глазами игрока pid.
static func for_view(state: GameState, pid: String, ids: Array) -> Dictionary:
	var out := {}
	for cid in ids:
		var key := String(cid)
		if key == "" or out.has(key):
			continue
		var e := entry(state, pid, key)
		if not e.is_empty():
			out[key] = e
	return out


static func entry(state: GameState, pid: String, cid: String) -> Dictionary:
	if not state.players.has(pid):
		return {}
	var out := {}
	var notes: Array = []
	for rule: Array in RULES.get(cid, []):
		var n := _count(state, pid, String(rule[2]))
		var note := {"phrase": String(rule[0])}
		match String(rule[1]):
			"per":
				var gain := n / int(rule[3])
				note["text"] = "(+%d)" % gain
				note["ok"] = gain > 0
			"count":
				note["text"] = "(%d)" % n
				note["ok"] = n > 0
			"need":
				note["text"] = "(%d/%d)" % [n, int(rule[3])]
				note["ok"] = n >= int(rule[3])
			"have":
				note["text"] = "(YES)" if n > 0 else "(NO)"
				note["ok"] = n > 0
			"less":
				note["text"] = "(-%d)" % n
				note["ok"] = n > 0
		notes.append(note)
	if not notes.is_empty():
		out["notes"] = notes
	var printed := CardLibrary.card_cost(cid)
	if printed >= 0:
		var now := printed
		if Supplies.PURCHASABLE.has(cid):
			now = Actions.supply_cost(state, cid)
		else:
			now = maxi(0, printed - ShadowCards.affinity_discount(state, cid))
		if now != printed:
			out["cost"] = now
	return out


static func _count(state: GameState, pid: String, source: String) -> int:
	var p: PlayerState = state.players[pid]
	match source:
		"troops_left":
			return state.troops_out(pid)
		"outcast_supply":
			return state.supplies.remaining(Supplies.INSANE_OUTCAST)
		"discard_outcasts":
			return p.deck.discard_pile.count(Supplies.INSANE_OUTCAST)
		"discard_outcasts_x3":
			return 3 * p.deck.discard_pile.count(Supplies.INSANE_OUTCAST)
		"eagle_discard":
			return p.deck.discard_pile.count(CelestialCards.GIANT_EAGLE)
		"eagle_deck":
			return p.deck.draw_pile.count(CelestialCards.GIANT_EAGLE)
		"guards_played":
			return p.deck.played_pile.count(Supplies.HOUSE_GUARD)
		"outcasts_played":
			return ShadowCards.outcasts_played(state)
	return GainVpPerN.new("vp", source, 1, 1)._count_source(state, pid)
