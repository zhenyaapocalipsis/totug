class_name BotPlayer
extends RefCounted

## Бот (этап Bot-1): жадный игрок на оценочной функции.
##
## Играет через тот же GameServer, что и люди: смотрит на партию и отдаёт
## одно Intent за раз (next_intent). Скрытое не подглядывает: из чужого знает
## только открытое (доска, маркет, сыгранные карты, число карт), из своего —
## руку. Порядок колод не использует вовсе.
##
## Как он выбирает:
##   1. разыгрывает все карты руки (карты с Focus — в конце, Insane Outcast —
##      первым, пока в руке есть что сбросить);
##   2. тратит Power: для каждого возможного действия (Deploy, Assassinate,
##      возврат шпиона) на минуту меняет доску, оценивает позицию и
##      возвращает доску обратно; берёт лучшее по приросту оценки на 1 Power;
##   3. тратит Influence на карту с лучшей ценностью (сила карты в начале
##      партии, VP карты в конце);
##   4. заканчивает ход.
## Вопросы карт решает так же: цели на доске — пробной расстановкой и
## оценкой, карты — по ценности, "Choose one" — по словам варианта.
##
## Оценка позиции (eval): VP, которые игрок получит, если партия кончится
## сейчас (локации, тотальный контроль, трофеи, жетоны, VP карт), плюс доход
## маркеров контроля и бонуса A2, умноженный на оставшиеся ходы, плюс немного
## за войска на доске и (только для себя) за ширину Присутствия. Итог —
## своя оценка минус смесь лучшего соперника и среднего соперника.

const W_TROOP := 0.25          # войско на доске (сила и шаг к концу партии)
const W_PRESENCE := 0.06       # каждый слот, куда можно развернуться
const W_RESOURCE := 0.4        # 1 Power/Influence дохода за ход ~ 0.4 VP
const W_LEADER := 0.6          # в оценке соперников: доля лучшего, остальное — среднее
const MIN_BUY_VALUE := 0.2     # дешевле этого карту не покупаем
const OUTCAST := "48341"


## Кто сейчас должен действовать: тот, кому адресован вопрос, иначе ходящий.
## Пусто, если партия окончена.
static func acting_player(server: GameServer) -> String:
	if server.state.game_over:
		return ""
	if server.resolver.is_waiting():
		return server.resolver.pending.player_id
	return server.state.current_player()


## Следующее намерение бота за игрока pid; null, если сейчас действует не он.
static func next_intent(server: GameServer, pid: String) -> Intent:
	if acting_player(server) != pid:
		return null
	if server.resolver.is_waiting():
		return Intent.make_decision(pid, answer(server.state, server.resolver.pending, pid))
	return _main_action(server.state, pid)


## Запасной ход, если сервер отклонил выбор бота: первый допустимый ответ на
## вопрос или конец хода. Без него бот мог бы бесконечно слать одно и то же.
static func fallback_intent(server: GameServer, pid: String) -> Intent:
	if server.resolver.is_waiting():
		var pd: PendingDecision = server.resolver.pending
		var ans = null
		if pd.choice_type == "confirm":
			ans = false
		elif not pd.legal_options.is_empty():
			ans = pd.legal_options[0]
		return Intent.make_decision(pid, ans)
	return Intent.end_turn(pid)


## Доиграть партию ботами за всех (тесты и прогоны баланса). Возвращает
## {intents, rejected, finished}: finished=false — упёрлись в лимит намерений.
static func play_out(server: GameServer, max_intents: int = 20000) -> Dictionary:
	var intents := 0
	var rejected := 0
	var rejected_in_row := 0
	while not server.state.game_over and intents < max_intents:
		var pid := acting_player(server)
		var intent: Intent = next_intent(server, pid) if rejected_in_row == 0 else fallback_intent(server, pid)
		var res: Dictionary = server.apply_intent(intent)
		intents += 1
		if int(res["error"]) != GameServer.Error.OK:
			rejected += 1
			rejected_in_row += 1
			if rejected_in_row > 2:
				# и запасной ход не прошёл — заканчиваем ход силой
				server.apply_intent(Intent.end_turn(server.state.current_player()))
				rejected_in_row = 0
		else:
			rejected_in_row = 0
	return {"intents": intents, "rejected": rejected, "finished": server.state.game_over}


# --- основной ход ---------------------------------------------------------

static func _main_action(state: GameState, pid: String) -> Intent:
	var p: PlayerState = state.players[pid]
	if not p.deck.hand.is_empty():
		return Intent.play_card(pid, _card_to_play(p.deck.hand))
	var ctx := _context(state, pid)
	var power_act := _best_power_action(state, pid, ctx)
	if power_act != null:
		return power_act
	var buy := _best_buy(state, pid, ctx)
	if buy != null:
		return buy
	return Intent.end_turn(pid)


static func _card_to_play(hand: Array[String]) -> String:
	if hand.has(OUTCAST) and hand.size() > 1:
		return OUTCAST
	for cid: String in hand:
		if not _is_focus(cid) and cid != OUTCAST:
			return cid
	return hand[0]


static func _is_focus(cid: String) -> bool:
	return String(CardLibrary.card_data(cid).get("ability_text", "")).contains("Focus")


static func _best_power_action(state: GameState, pid: String, ctx: Dictionary) -> Intent:
	var p: PlayerState = state.players[pid]
	if p.power <= 0:
		return null
	var base := evaluate(state, ctx)
	var best: Intent = null
	var best_ratio := -0.01  # действие хоть чуть-чуть в минус не берём

	if p.power >= Actions.COST_DEPLOY:
		if p.troops_in_barracks <= 0:
			best = Intent.deploy(pid, "")
			best_ratio = 1.0
		else:
			for slot: String in state.presence.deployable_slots(pid, state.troops, state.spies):
				var gain := _troops_eval(state, ctx, {slot: pid}) - base
				if p.troops_in_barracks == 1:
					gain += _end_trigger_bonus(state, ctx)
				var ratio := gain / float(Actions.COST_DEPLOY)
				if ratio > best_ratio:
					best_ratio = ratio
					best = Intent.deploy(pid, slot)

	var kill_cost := Actions.assassinate_cost(state)
	if p.power >= kill_cost:
		for slot: String in state.presence.assassinatable_slots(pid, state.troops, state.spies):
			var gain := _troops_eval(state, ctx, {slot: ""}, {pid: 1.0}) - base
			var ratio := gain / maxf(0.5, float(kill_cost))
			if ratio > best_ratio:
				best_ratio = ratio
				best = Intent.assassinate(pid, slot)

	var spy_cost := Actions.return_spy_cost(state)
	if p.power >= spy_cost:
		for site: String in state.presence.sites_with_presence(pid, state.troops, state.spies):
			for owner: String in (state.spies.get(site, []) as Array):
				if owner == pid:
					continue
				var gain := _spy_eval(state, ctx, site, owner, false) - base
				var ratio := gain / maxf(0.5, float(spy_cost))
				if ratio > best_ratio:
					best_ratio = ratio
					best = Intent.return_spy(pid, site, owner)
	return best


## Развернуть последнее войско = запустить конец партии: хорошо лидеру,
## плохо отстающему.
static func _end_trigger_bonus(state: GameState, ctx: Dictionary) -> float:
	return 2.0 if _is_leader(state, ctx) else -5.0


static func _is_leader(state: GameState, ctx: Dictionary) -> bool:
	var me: String = ctx["me"]
	var mine := final_vp(state, me)
	for pid: String in state.turn_order:
		if pid != me and final_vp(state, pid) >= mine:
			return false
	return true


## VP игрока, если бы партия кончилась сейчас.
static func final_vp(state: GameState, pid: String) -> int:
	return int(Scoring.breakdown(state, pid)["total"])


static func _best_buy(state: GameState, pid: String, ctx: Dictionary) -> Intent:
	var p: PlayerState = state.players[pid]
	if p.influence <= 0:
		return null
	var best: Intent = null
	var best_value := MIN_BUY_VALUE
	for i in range(state.market.display.size()):
		var cost := Actions.market_cost(state, i)
		if cost < 0 or cost > p.influence:
			continue
		var v := card_value(String(state.market.display[i]), state, pid, ctx)
		if v > best_value:
			best_value = v
			best = Intent.recruit(pid, i)
	var ghost := Actions.ghost_market_card(state, pid)
	if ghost != "" and CardLibrary.card_cost(ghost) <= p.influence:
		var gv := card_value(ghost, state, pid, ctx)
		if gv > best_value:
			best_value = gv
			best = Intent.recruit(pid, Market.DEVOURED_TOP_INDEX)
	for cid: String in state.supplies.purchasable_available():
		var scost := Actions.supply_cost(state, cid)
		if scost < 0 or scost > p.influence:
			continue
		var sv := card_value(cid, state, pid, ctx)
		if sv > best_value:
			best_value = sv
			best = Intent.recruit_supply(pid, cid)
	return best


## Ценность карты в колоде: в начале партии важна сила (цену считаем мерой
## силы), к концу — VP карты. Плюс немного за аспект, которого в колоде уже
## много (Focus). Стартовые карты стоят около нуля, Insane Outcast — минус.
static func card_value(cid: String, state: GameState, pid: String, ctx: Dictionary) -> float:
	var d := CardLibrary.card_data(cid)
	var cost := float(d.get("cost")) if d.get("cost") != null else 0.0
	var dvp := float(d.get("deck_vp")) if d.get("deck_vp") != null else 0.0
	var ivp := float(d.get("inner_circle_vp")) if d.get("inner_circle_vp") != null else 0.0
	var strength_w := clampf(float(ctx["h"]) / 6.0, 0.2, 1.0)
	var v := cost * strength_w + dvp + ivp * 0.25
	var aspect = d.get("aspect")
	if aspect != null and cost > 0.0:
		var same := 0
		for own: String in state.players[pid].deck.cards_outside_inner_circle():
			if CardLibrary.card_aspect(own) == String(aspect) and CardLibrary.card_cost(own) > 0:
				same += 1
		v += minf(0.1 * same, 0.8)
	return v


## Насколько выгодно отправить карту во Внутренний круг: её VP там минус то,
## что колода теряет без неё.
static func _promote_value(cid: String, state: GameState, pid: String, ctx: Dictionary) -> float:
	var d := CardLibrary.card_data(cid)
	var ivp := float(d.get("inner_circle_vp")) if d.get("inner_circle_vp") != null else 0.0
	var dvp := float(d.get("deck_vp")) if d.get("deck_vp") != null else 0.0
	return ivp - dvp - 0.5 * maxf(0.0, card_value(cid, state, pid, ctx) - dvp)


# --- ответы на вопросы карт ---------------------------------------------

## Ответ бота на вопрос pd (MAKE_DECISION). Всегда одно из legal_options,
## кроме confirm (true/false) и пустых списков (null — пропустить).
static func answer(state: GameState, pd: PendingDecision, pid: String):
	var opts: Array = pd.legal_options
	var ctx := _context(state, pid)
	var prompt := pd.prompt.to_lower()
	match pd.choice_type:
		"confirm":
			return true
		"choose_option":
			return _best_by(opts, func(o): return _label_value(_label_of(pd, o)))
		"target_player":
			return _best_by(opts, func(o): return _rival_value(state, ctx, String(o)))
		"target_card":
			return _answer_card(state, pd, pid, ctx, prompt)
		"target_market_index":
			return _answer_market(state, pid, ctx, prompt, opts)
		"target_slot":
			return _answer_slot(state, pd, pid, ctx, prompt)
		"target_site":
			return _answer_site(state, pid, ctx, prompt, opts)
		"target_return":
			return _best_by(opts, func(o): return _return_value(state, ctx, String(o)))
	return opts[0] if not opts.is_empty() else null


static func _label_of(pd: PendingDecision, option) -> String:
	var i := pd.legal_options.find(option)
	return pd.option_labels[i] if i >= 0 and i < pd.option_labels.size() else ""


## Грубая цена варианта "Choose one" по его словам.
static func _label_value(label: String) -> float:
	var l := label.to_lower()
	var n := 1.0
	var rx := RegEx.create_from_string("(\\d+)")
	var m := rx.search(l)
	if m != null:
		n = float(m.get_string(1))
	var v := 0.5
	if l.contains("vp"):
		v = maxf(v, n * 1.3)
	if l.contains("influence") or l.contains("power"):
		v = maxf(v, n * 0.85)
	if l.contains("supplant"):
		v = maxf(v, 3.0)
	elif l.contains("assassinate"):
		v = maxf(v, 2.5)
	if l.contains("deploy"):
		v = maxf(v, n * 0.9)
	if l.contains("spy") and l.contains("place"):
		v = maxf(v, 1.8)
	if l.contains("promote"):
		v = maxf(v, 1.8)
	if l.contains("draw"):
		v = maxf(v, n * 1.0)
	if l.contains("return"):
		v = maxf(v, 1.2)
	if l.contains("move"):
		v = maxf(v, 1.0)
	if l.contains("devour"):
		v = maxf(v, 0.8)
	return v


static func _answer_card(state: GameState, pd: PendingDecision, pid: String, ctx: Dictionary, prompt: String):
	var opts: Array = pd.legal_options
	var cards: Array = opts.filter(func(o): return String(o) != "")
	var can_skip := opts.size() != cards.size()
	if cards.is_empty():
		return "" if can_skip else null
	if prompt.contains("promote"):
		return _best_by(cards, func(o): return _promote_value(String(o), state, pid, ctx))
	if prompt.contains("discard") or prompt.contains("devour"):
		var worst = _best_by(cards, func(o): return -card_value(String(o), state, pid, ctx))
		# Необязательный сброс/пожирание: хорошую карту не отдаём.
		if can_skip and card_value(String(worst), state, pid, ctx) > 0.6:
			return ""
		return worst
	if prompt.contains("face-up pile"):
		return "" if can_skip else cards[0]
	return _best_by(cards, func(o): return card_value(String(o), state, pid, ctx))


static func _answer_market(state: GameState, pid: String, ctx: Dictionary, prompt: String, opts: Array):
	var idxs: Array = opts.filter(func(o): return int(o) >= 0 or int(o) == Market.DEVOURED_TOP_INDEX)
	var can_skip := idxs.size() != opts.size()
	if prompt.contains("replace"):
		return -1 if can_skip else opts[0]
	if idxs.is_empty():
		return opts[0] if not opts.is_empty() else null
	var value := func(o) -> float:
		var cid := Actions.ghost_market_card(state, pid) if int(o) == Market.DEVOURED_TOP_INDEX \
			else String(state.market.display[int(o)])
		return card_value(cid, state, pid, ctx)
	# Пожрать карту с маркета — убрать ту, что сильнее всего пригодилась бы
	# соперникам; взять даром — лучшую себе. Оценка одна и та же.
	return _best_by(idxs, value)


static func _answer_slot(state: GameState, pd: PendingDecision, pid: String, ctx: Dictionary, prompt: String):
	var opts: Array = pd.legal_options
	var slots: Array = opts.filter(func(o): return String(o) != "")
	var can_skip := opts.size() != slots.size()
	if slots.is_empty():
		return "" if can_skip else null
	var base := evaluate(state, ctx)
	var value: Callable
	if prompt.begins_with("move troop to"):
		var source := String(pd.target_effect.get("_picked_source")) if pd.target_effect != null else ""
		var owner := String(state.troops.get(source, ""))
		value = func(o): return _troops_eval(state, ctx, {source: "", String(o): owner})
	elif prompt.contains("supplant"):
		value = func(o): return _troops_eval(state, ctx, {String(o): pid}, {pid: 1.0})
	elif prompt.contains("assassinate"):
		value = func(o): return _troops_eval(state, ctx, {String(o): ""}, {pid: 1.0})
	elif prompt.contains("deploy"):
		value = func(o): return _troops_eval(state, ctx, {String(o): pid})
	else:
		# Вернуть/сдвинуть войско: оцениваем, что будет без него на этом месте.
		value = func(o): return _troops_eval(state, ctx, {String(o): ""})
	var best = _best_by(slots, value)
	# "Up to": отказываемся, если любой выбор хуже, чем ничего.
	if can_skip and float(value.call(best)) < base - 0.01:
		return ""
	return best


static func _answer_site(state: GameState, pid: String, ctx: Dictionary, prompt: String, opts: Array):
	var sites: Array = opts.filter(func(o): return String(o) != "")
	if sites.is_empty():
		return opts[0] if not opts.is_empty() else null
	if prompt.contains("starting site"):
		return _best_by(sites, func(o): return _starting_site_value(state, ctx, String(o)))
	if prompt.contains("return"):
		return _best_by(sites, func(o): return _spy_eval(state, ctx, String(o), pid, false))
	return _best_by(sites, func(o): return _spy_eval(state, ctx, String(o), pid, true))


static func _starting_site_value(state: GameState, ctx: Dictionary, site: String) -> float:
	for slot: String in state.graph.slots_of_site(site):
		if state.troops.get(slot, "") == "":
			return _troops_eval(state, ctx, {slot: String(ctx["me"])})
	return -1000.0


static func _return_value(state: GameState, ctx: Dictionary, option: String) -> float:
	if option == "":
		return evaluate(state, ctx) - 0.01
	var parts := option.split(ReturnTroopOrSpy.SEP)
	if parts[0] == "troop":
		return _troops_eval(state, ctx, {parts[1]: ""})
	return _spy_eval(state, ctx, parts[1], parts[2], false)


## Насколько соперник опасен (для вредных карт "выбери соперника").
static func _rival_value(state: GameState, ctx: Dictionary, pid: String) -> float:
	if pid == String(ctx["me"]):
		return -1000.0
	return _player_value(state, pid, float(ctx["h"]), _troop_counts(state), ctx)


static func _best_by(options: Array, score: Callable):
	var best = null
	var best_score := -INF
	for o in options:
		var s := float(score.call(o))
		if best == null or s > best_score:
			best = o
			best_score = s
	return best


# --- оценка позиции -------------------------------------------------------

## Общие для одного решения величины: кто "я", сколько примерно ходов
## осталось (h) и VP карт каждого игрока (за ход не меняются от действий на
## доске, поэтому считаются один раз).
static func _context(state: GameState, me: String) -> Dictionary:
	var card_vp := {}
	for pid: String in state.turn_order:
		var b := Scoring.breakdown(state, pid)
		card_vp[pid] = float(b["deck"]) + float(b["inner_circle"])
	return {"me": me, "h": horizon(state), "card_vp": card_vp}


## Сколько примерно кругов осталось до конца партии: конец наступает, когда у
## кого-то кончатся войска или опустеет колода маркета.
static func horizon(state: GameState) -> float:
	if state.game_end_triggered:
		return 0.5
	var n := state.turn_order.size()
	var min_barracks := PlayerState.STARTING_TROOPS
	for pid: String in state.turn_order:
		min_barracks = mini(min_barracks, state.players[pid].troops_in_barracks)
	var by_troops := float(min_barracks) / 3.0
	var by_market := float(state.market.deck_size()) / (1.5 * float(maxi(1, n)))
	return clampf(minf(by_troops, by_market), 0.5, 8.0)


## Оценка позиции глазами ctx.me (больше — лучше). extra_trophies: pid ->
## сколько трофеев добавить (пробное убийство ещё не положило войско в зал).
static func evaluate(state: GameState, ctx: Dictionary, extra_trophies: Dictionary = {}) -> float:
	var me: String = ctx["me"]
	var h: float = ctx["h"]
	var counts := _troop_counts(state)
	var mine := _player_value(state, me, h, counts, ctx) + float(extra_trophies.get(me, 0.0))
	mine += W_PRESENCE * state.presence.deployable_slots(me, state.troops, state.spies).size()
	var best_opp := -INF
	var sum_opp := 0.0
	var n_opp := 0
	for pid: String in state.turn_order:
		if pid == me:
			continue
		var v := _player_value(state, pid, h, counts, ctx) + float(extra_trophies.get(pid, 0.0))
		best_opp = maxf(best_opp, v)
		sum_opp += v
		n_opp += 1
	if n_opp == 0:
		return mine
	return mine - (W_LEADER * best_opp + (1.0 - W_LEADER) * sum_opp / n_opp)


static func _player_value(state: GameState, pid: String, h: float, counts: Dictionary, ctx: Dictionary) -> float:
	var p: PlayerState = state.players[pid]
	var v := float(state.control.map_score(pid, state.troops, state.spies))
	v += p.trophy_hall_count + p.vp_tokens
	v += float((ctx["card_vp"] as Dictionary).get(pid, 0.0))
	var m := ControlMarkers.evaluate(state, pid)
	var c := ClusterBonus.evaluate(state, pid)
	v += h * (m.vp + c.vp + W_RESOURCE * (m.influence + c.influence + c.power))
	v += W_TROOP * int(counts.get(pid, 0))
	return v


static func _troop_counts(state: GameState) -> Dictionary:
	var counts := {}
	for owner: String in state.troops.values():
		if owner != "":
			counts[owner] = int(counts.get(owner, 0)) + 1
	return counts


## Оценка после пробной перестановки войск (slot -> новый владелец, "" —
## пусто). Доска возвращается в прежний вид до выхода из функции.
static func _troops_eval(state: GameState, ctx: Dictionary, changes: Dictionary, extra_trophies: Dictionary = {}) -> float:
	var old := {}
	for slot: String in changes.keys():
		old[slot] = state.troops[slot] if state.troops.has(slot) else null
		state.troops[slot] = changes[slot]
	var v := evaluate(state, ctx, extra_trophies)
	for slot: String in old.keys():
		if old[slot] == null:
			state.troops.erase(slot)
		else:
			state.troops[slot] = old[slot]
	return v


## Оценка после пробно поставленного (add) или снятого шпиона owner на site.
static func _spy_eval(state: GameState, ctx: Dictionary, site: String, owner: String, add: bool) -> float:
	var had := state.spies.has(site)
	var before: Array = (state.spies.get(site, []) as Array).duplicate()
	var after := before.duplicate()
	if add:
		after.append(owner)
	else:
		after.erase(owner)
	state.spies[site] = after
	var v := evaluate(state, ctx)
	if had:
		state.spies[site] = before
	else:
		state.spies.erase(site)
	return v
