class_name ReplayStats
extends RefCounted

## Статистика партии по реплею (этап Replay-3) — для экрана STATS просмотрщика.
## Партия проигрывается с раздачи (ReplayBook.step), после каждого хода
## игрока снимается срез. Всё считается по движку, а не по записанному итогу:
## новую статистику можно добавить и для старых реплеев той же версии.
##
## collect() возвращает:
##   ids     — цвета по порядку раздачи;
##   turns   — ход за ходом, [0] — после раздачи (муллиган и стартовые локации):
##             {player, start, round, vp: {цвет: VP, будь партия окончена сейчас},
##              power, influence — сколько ходивший получил за этот ход};
##   parts   — разбивка VP в конце (Scoring.breakdown): цвет -> статья -> VP;
##   buys    — покупки: цвет -> [{turn, card}];
##   counts  — действия за партию: цвет -> ACTIONS -> сколько;
##   sites   — контроль: [{id, name, vp, turns: {цвет: сколько ходов держал}}],
##             по убыванию VP сайта;
##   best    — самый сильный ход: {turn, player, gain} (рост VP за свой ход);
##   leads   — ходы, после которых сменился лидер по VP.

## Действия в сводке и события движка, которые их считают.
const ACTIONS := {
	"played": ["play_card"],
	"bought": ["recruit", "recruit_supply", "recruit_free"],
	"deployed": ["deploy", "deploy_troop"],
	"kills": ["assassinate", "supplant"],
	"spies": ["place_spy"],
	"returns": ["return_troop", "return_spy"],
	"devoured": ["devour"],
	"promoted": ["promote"],
}
const ACTION_ORDER: Array[String] = ["played", "bought", "deployed", "kills", "spies", "returns",
	"devoured", "promoted"]


static func collect(replay: Dictionary) -> Dictionary:
	var server := ReplayBook.start(replay)
	var state := server.state
	var intents: Array = replay["intents"]
	var starts := ReplayBook.turn_starts(replay)
	var ids: Array[String] = []
	for pid in (replay["header"] as Dictionary).get("ids", []):
		ids.append(String(pid))

	var event_action := {}
	for action: String in ACTIONS:
		for type: String in ACTIONS[action]:
			event_action[type] = action
	var buys := {}
	var counts := {}
	for pid in ids:
		buys[pid] = []
		counts[pid] = {}
		for action in ACTION_ORDER:
			counts[pid][action] = 0
	var site_ids: Array = state.graph.sites.keys()
	var site_turns := {}
	for sid in site_ids:
		site_turns[sid] = {}

	var turns: Array = []
	for t in range(starts.size() - 1):
		var a := starts[t]
		var b := starts[t + 1]
		var player := state.current_player()
		var me: PlayerState = state.players[player]
		# Ресурсы хода: что было на руках к началу (доход начала хода) плюс
		# всё, что прибавлялось по ходу.
		var power := me.power
		var influence := me.influence
		# После END_TURN ресурсы сгорают — это не трата, считать перестаём;
		# события вопросов конца хода (promote) считаем дальше.
		var ended := false
		for i in range(a, b):
			var p_before := me.power
			var i_before := me.influence
			var result := ReplayBook.step(server, replay, i)
			if not ended:
				power += maxi(0, me.power - p_before)
				influence += maxi(0, me.influence - i_before)
			ended = ended or int((intents[i] as Dictionary).get("type", -1)) == Intent.Type.END_TURN
			for e in result["events"]:
				var evt: Dictionary = e
				var type := String(evt.get("type", ""))
				var pid := String(evt.get("player_id", ""))
				if not counts.has(pid) or not event_action.has(type):
					continue
				var action: String = event_action[type]
				counts[pid][action] = int(counts[pid][action]) + 1
				if action == "bought":
					(buys[pid] as Array).append({"turn": t, "card": String(evt.get("card_id", ""))})
		var vp := {}
		for pid in ids:
			vp[pid] = int(Scoring.breakdown(state, pid)["total"])
		for sid in site_ids:
			var owner := state.control.controller_of(String(sid), state.troops)
			if counts.has(owner):
				site_turns[sid][owner] = int(site_turns[sid].get(owner, 0)) + 1
		turns.append({"player": player if t > 0 else "", "start": a,
			"round": 0 if t == 0 else (t - 1) / ids.size() + 1,
			"vp": vp, "power": power if t > 0 else 0, "influence": influence if t > 0 else 0})
	# Брошенная партия: её конец (abandon) — после последнего хода.
	var gone := String((replay["header"] as Dictionary).get("abandoned_by", ""))
	if gone != "" and not state.game_over:
		server.abandon(gone)

	var parts := {}
	for pid in ids:
		parts[pid] = Scoring.breakdown(state, pid)

	var sites: Array = []
	for sid in site_ids:
		var info: Dictionary = state.graph.sites[sid]
		sites.append({"id": String(sid), "name": String(info.get("name", sid)), "vp": int(info.get("vp", 0)),
			"turns": site_turns[sid]})
	sites.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return int(x["vp"]) > int(y["vp"]) or (int(x["vp"]) == int(y["vp"]) and String(x["name"]) < String(y["name"])))

	return {"ids": ids, "turns": turns, "parts": parts, "buys": buys, "counts": counts, "sites": sites,
		"best": best_turn(turns), "leads": lead_changes(turns, ids)}


## Ход, за который ходивший прибавил больше всего VP.
static func best_turn(turns: Array) -> Dictionary:
	var best := {"turn": 0, "player": "", "gain": 0}
	for t in range(1, turns.size()):
		var pid := String(turns[t]["player"])
		var gain := int(turns[t]["vp"].get(pid, 0)) - int(turns[t - 1]["vp"].get(pid, 0))
		if gain > int(best["gain"]):
			best = {"turn": t, "player": pid, "gain": gain}
	return best


## Номера ходов, после которых лидер по VP стал другим (ничья лидера не меняет).
static func lead_changes(turns: Array, ids: Array[String]) -> Array[int]:
	var changes: Array[int] = []
	var leader := ""
	for t in turns.size():
		var vp: Dictionary = turns[t]["vp"]
		var top := ""
		var top_vp := -1
		var tied := false
		for pid in ids:
			if int(vp[pid]) > top_vp:
				top = pid
				top_vp = int(vp[pid])
				tied = false
			elif int(vp[pid]) == top_vp:
				tied = true
		if tied or top == leader:
			continue
		if leader != "":
			changes.append(t)
		leader = top
	return changes
