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
##   sites   — контроль: [{id, name, vp, turns: {цвет: сколько ходов держал},
##             held: [цвет владельца после каждого хода, "" — ничей]}],
##             по убыванию VP сайта;
##   best    — самый сильный ход: {turn, player, gain} (рост VP за свой ход);
##   leads   — ходы, после которых сменился лидер по VP;
##   leaders — лидер по VP после каждого хода (leaders()).

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
	var site_held := {}
	for sid in site_ids:
		site_turns[sid] = {}
		site_held[sid] = []

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
			(site_held[sid] as Array).append(owner if counts.has(owner) else "")
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
			"turns": site_turns[sid], "held": site_held[sid]})
	sites.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return int(x["vp"]) > int(y["vp"]) or (int(x["vp"]) == int(y["vp"]) and String(x["name"]) < String(y["name"])))

	return {"ids": ids, "turns": turns, "parts": parts, "buys": buys, "counts": counts, "sites": sites,
		"best": best_turn(turns), "leads": lead_changes(turns, ids), "leaders": leaders(turns, ids)}


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
	var who := leaders(turns, ids)
	for t in range(1, who.size()):
		if who[t - 1] != "" and who[t] != who[t - 1]:
			changes.append(t)
	return changes


## Лидер по VP после каждого хода; ничья оставляет прежнего ("" — пока
## никто не вырвался вперёд).
static func leaders(turns: Array, ids: Array[String]) -> Array[String]:
	var who: Array[String] = []
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
		if not tied:
			leader = top
		who.append(leader)
	return who


# --- сводка по многим партиям (Replay-4) ---------------------------------------

## Короткая выжимка партии глазами игрока seat — то, что нужно сводке по
## многим партиям (ReplayStats.aggregate). Хранится в строке истории
## (PlayerProfile.set_history_summary), чтобы не пересчитывать реплеи.
##   won, place, players — итог; vp — свои VP в конце;
##   buys    — купленные карты (id, с повторами);
##   counts  — свои действия за партию (ACTIONS);
##   power, influence — в среднем за свой ход;
##   curve   — свои VP в конце каждого раунда; rival — VP лучшего соперника там же.
static func summary_for(stats: Dictionary, header: Dictionary) -> Dictionary:
	var seat := String(header.get("seat", ""))
	var ids: Array = stats.get("ids", [])
	if not ids.has(seat):
		return {}
	var turns: Array = stats["turns"]
	var parts: Dictionary = stats["parts"]
	var mine := int(parts[seat]["total"])
	var place := 1
	var winners: Array = header.get("winners", [])
	for pid in ids:
		if pid != seat and (winners.has(pid) or int(parts[pid]["total"]) > mine) and not winners.has(seat):
			place += 1
	var buys: Array = []
	for b in stats["buys"][seat]:
		buys.append(String(b["card"]))
	var power := 0.0
	var influence := 0.0
	var own := 0
	var curve: Array = []
	var rival: Array = []
	for t in range(1, turns.size()):
		var turn: Dictionary = turns[t]
		if String(turn["player"]) == seat:
			power += float(turn["power"])
			influence += float(turn["influence"])
			own += 1
		var last := t == turns.size() - 1 or int(turns[t + 1]["round"]) != int(turn["round"])
		if last:
			curve.append(int(turn["vp"][seat]))
			var best := 0
			for pid in ids:
				if pid != seat:
					best = maxi(best, int(turn["vp"][pid]))
			rival.append(best)
	return {"won": winners.has(seat), "place": place, "players": ids.size(), "vp": mine, "buys": buys,
		"counts": (stats["counts"][seat] as Dictionary).duplicate(),
		"power": power / maxf(1.0, own), "influence": influence / maxf(1.0, own),
		"curve": curve, "rival": rival}


## Выжимки всех партий истории (PlayerProfile.history), новые первыми.
## Строке без выжимки она считается по её реплею (если он той же версии
## правил) и запоминается — следующий раз пересчитывать не придётся.
## Партии без реплея (до Replay-1, другой версии) в сводку не попадают.
static func history_summaries(dir: String = ReplayBook.DIR) -> Array:
	var out: Array = []
	var fresh := {}
	for game: Dictionary in PlayerProfile.history():
		var summary: Dictionary = game.get("summary", {})
		var file := String(game.get("replay", ""))
		if summary.is_empty() and file != "":
			var replay := ReplayBook.load_replay(file, dir)
			if not replay.is_empty() and ReplayBook.same_version(replay):
				summary = summary_for(collect(replay), replay["header"])
				if not summary.is_empty():
					fresh[file] = summary
		if not summary.is_empty():
			out.append(summary)
	PlayerProfile.set_history_summaries(fresh)
	return out


## Сводка по выжимкам многих партий (summary_for):
##   games, wins;
##   cards  — id -> {games: в скольких партиях купил, wins, copies};
##   groups — "all"/"wins"/"losses" -> {games, vp, power, influence,
##            counts: действие -> сумма} (средние = сумма / games);
##   curve  — "wins"/"losses"/"rival" -> средние VP в конце каждого раунда
##            (по партиям, дошедшим до этого раунда).
static func aggregate(summaries: Array) -> Dictionary:
	var cards := {}
	var groups := {}
	for g in ["all", "wins", "losses"]:
		var counts := {}
		for action in ACTION_ORDER:
			counts[action] = 0
		groups[g] = {"games": 0, "vp": 0, "power": 0.0, "influence": 0.0, "counts": counts}
	var sums := {"wins": [], "losses": [], "rival": []}
	var seen := {"wins": [], "losses": [], "rival": []}
	var wins := 0
	for s: Dictionary in summaries:
		var won := bool(s.get("won", false))
		if won:
			wins += 1
		for g in ["all", "wins" if won else "losses"]:
			var group: Dictionary = groups[g]
			group["games"] = int(group["games"]) + 1
			group["vp"] = int(group["vp"]) + int(s.get("vp", 0))
			group["power"] = float(group["power"]) + float(s.get("power", 0.0))
			group["influence"] = float(group["influence"]) + float(s.get("influence", 0.0))
			for action in ACTION_ORDER:
				group["counts"][action] = int(group["counts"][action]) + int((s.get("counts", {}) as Dictionary).get(action, 0))
		var copies := {}
		for cid in s.get("buys", []):
			copies[String(cid)] = int(copies.get(String(cid), 0)) + 1
		for cid: String in copies:
			if not cards.has(cid):
				cards[cid] = {"games": 0, "wins": 0, "copies": 0}
			cards[cid]["games"] = int(cards[cid]["games"]) + 1
			cards[cid]["wins"] = int(cards[cid]["wins"]) + (1 if won else 0)
			cards[cid]["copies"] = int(cards[cid]["copies"]) + int(copies[cid])
		for key in [["wins" if won else "losses", "curve"], ["rival", "rival"]]:
			var points: Array = s.get(key[1], [])
			for r in points.size():
				while (sums[key[0]] as Array).size() <= r:
					(sums[key[0]] as Array).append(0.0)
					(seen[key[0]] as Array).append(0)
				sums[key[0]][r] = float(sums[key[0]][r]) + float(points[r])
				seen[key[0]][r] = int(seen[key[0]][r]) + 1
	var curve := {}
	for key: String in sums:
		var avg: Array[float] = []
		for r in (sums[key] as Array).size():
			avg.append(float(sums[key][r]) / int(seen[key][r]))
		curve[key] = avg
	return {"games": summaries.size(), "wins": wins, "cards": cards, "groups": groups, "curve": curve}
