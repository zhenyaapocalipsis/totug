class_name StateView
extends RefCounted

## Персональный срез GameState для одного игрока (этап 6).
##
## Скрытая информация (рулбук нигде это не описывает как сетевой протокол —
## решение по умолчанию для цифровой версии, задокументировано в
## claude/progress.md, этап 6):
##   - Рука противника скрыта (только hand_size).
##   - Сброс противника скрыт (только discard_size).
##   - Колода добора скрыта у ВСЕХ, включая владельца (только deck_size) —
##     порядок карт в ней неизвестен и самому игроку после перетасовки.
##   - Войска/шпионы на доске, маркет, Внутренний круг, played_pile,
##     devoured_pile, played_aspects_this_turn — открытая информация всем.
##   - PendingDecision.legal_options видны только игроку, который решает;
##     остальным — пустой список (сам факт "кто-то принимает решение" и
##     prompt видны всем, чтобы UI мог показать "Ждём хода игрока X").
##
## Результат — только встроенные типы Godot (Dictionary/Array/String/int/
## bool), пригоден для JSON.stringify() без дополнительной обработки.


static func for_player(state: GameState, viewer_id: String) -> Dictionary:
	var view: Dictionary = {
		"current_player": state.current_player(),
		"turn_order": state.turn_order.duplicate(),
		"game_over": state.game_over,
		"game_end_triggered": state.game_end_triggered,
		"game_end_reason": state.game_end_reason,
		"troops": state.troops.duplicate(),
		"site_control": _site_control(state),
		"spies": _duplicate_spies(state.spies),
		"played_aspects_this_turn": state.played_aspects_this_turn.duplicate(),
		"devoured_pile": state.devoured_pile.duplicate(),
		"ghost_market_card": Actions.ghost_market_card(state, state.current_player()),
		"vp_bank": {
			"ones": state.vp_bank.ones,
			"fives": state.vp_bank.fives,
			"total_remaining": state.vp_bank.total_remaining(),
		},
		"market": {
			"display": state.market.display.duplicate(),
			"deck_size": state.market.deck_size(),
		},
		"supplies": state.supplies.counts.duplicate(),
		"players": {},
		"pending_decision": _pending_decision_view(state, viewer_id),
	}
	for pid: String in state.players.keys():
		view["players"][pid] = _player_view(state.players[pid], pid == viewer_id)
	view["legal"] = _legal_actions(state, viewer_id)
	# Партия окончена — итоговый счёт по статьям и победители (ничья — все
	# с лучшим счётом). Колоды здесь уже не тайна: подсчёт открытый.
	if state.game_over:
		var scores := {}
		var decks := {}
		for pid: String in state.turn_order:
			scores[pid] = Scoring.breakdown(state, pid)
			var d: Deck = state.players[pid].deck
			decks[pid] = {"deck": Array(d.cards_outside_inner_circle()), "inner": Array(d.inner_circle)}
		view["final_scores"] = scores
		view["final_decks"] = decks
		var vp := Scoring.library_card_vp(state)
		view["winners"] = Array(Scoring.winners(state, vp[0], vp[1]))
	# Сколько VP игрок получит в конце хода и за что. Игрок видел растущий
	# счёт и не понимал причину — вопрос владельца игры "за что 18 VP?".
	# ВАЖНО: VP за контроль ОБЫЧНЫХ локаций начисляются только в финальном
	# подсчёте. По ходу партии VP дают лишь маркеры контроля (гексы A1, A3,
	# B1-B6) и региональный бонус гекса A2.
	if state.players.has(viewer_id):
		var marker_reward: ControlMarkers.Reward = ControlMarkers.evaluate(state, viewer_id)
		var bonus: ClusterBonus.Reward = ClusterBonus.evaluate(state, viewer_id)
		var bonus_vp: int = bonus.vp
		var final_sites_vp: int = state.control.map_score(viewer_id, state.troops, state.spies)
		var names: Array[String] = []
		for site_id: String in state.graph.sites.keys():
			if state.control.controller_of(site_id, state.troops) == viewer_id:
				names.append(String(state.graph.sites[site_id]["name"]))
		names.sort()
		var marker_sites: Array[String] = marker_reward.sites.duplicate()
		marker_sites.sort()
		var total_sites: Array[String] = marker_reward.total_control_sites.duplicate()
		total_sites.sort()
		view["vp_income"] = {
			"markers": marker_reward.vp,
			"marker_influence": marker_reward.influence,
			"marker_sites": marker_sites,
			"marker_total_control_sites": total_sites,
			"cluster_bonus": bonus_vp,
			"cluster_power": bonus.power,
			"cluster_influence": bonus.influence,
			"total": marker_reward.vp + bonus_vp,
			"final_sites": final_sites_vp,
			"controlled": names,
		}
	return view


## Что зритель может сделать прямо сейчас. Считает СЕРВЕР, а не клиент:
## иначе интерфейсу пришлось бы завести свою копию правил Присутствия и цен —
## ровно то, что запрещает архитектура ("UI — тупой рендерер").
## Пустой словарь, если сейчас не ход зрителя или ждём чьё-то решение.
static func _legal_actions(state: GameState, viewer_id: String) -> Dictionary:
	if state.game_over or state.current_player() != viewer_id:
		return {}
	if not state.players.has(viewer_id):
		return {}
	var p: PlayerState = state.players[viewer_id]

	var deploy_slots: Array[String] = []
	if p.power >= Actions.COST_DEPLOY and p.troops_in_barracks > 0:
		for slot_id in state.presence.deployable_slots(viewer_id, state.troops, state.spies):
			deploy_slots.append(slot_id)

	var kill_slots: Array[String] = []
	if p.power >= Actions.COST_ASSASSINATE:
		for slot_id in state.presence.assassinatable_slots(viewer_id, state.troops, state.spies):
			kill_slots.append(slot_id)

	# Вражеские шпионы там, где у зрителя есть Присутствие (3 Power).
	var spy_targets: Array = []
	if p.power >= Actions.COST_RETURN_SPY:
		for site_id in state.presence.sites_with_presence(viewer_id, state.troops, state.spies):
			for owner in (state.spies.get(site_id, []) as Array):
				if owner != viewer_id:
					spy_targets.append({"site_id": site_id, "spy_owner": owner})

	# Карты маркета, на которые хватает Influence.
	var market_indices: Array[int] = []
	for i in range(state.market.display.size()):
		var cost: int = state.market.card_cost(i)
		if cost >= 0 and cost <= p.influence:
			market_indices.append(i)
	var ghost_card := Actions.ghost_market_card(state, viewer_id)
	if ghost_card != "" and CardLibrary.card_cost(ghost_card) <= p.influence:
		market_indices.append(Market.DEVOURED_TOP_INDEX)

	var supply_cards: Array[String] = []
	for card_id: String in state.supplies.purchasable_available():
		var scost: int = CardLibrary.card_cost(card_id)
		if scost >= 0 and scost <= p.influence:
			supply_cards.append(card_id)

	# Слоты, где у зрителя ЕСТЬ Присутствие, независимо от ресурсов. Нужны
	# интерфейсу, чтобы объяснить отказ: "нет Присутствия" и "не хватает
	# Power" — разные причины, а игрок видел одинаковое "сюда нельзя".
	var presence_slots: Array[String] = []
	for slot_id in state.presence.deployable_slots(viewer_id, state.troops, state.spies):
		presence_slots.append(slot_id)

	return {
		"play_card": p.deck.hand.duplicate(),
		"presence_slots": presence_slots,
		"deploy_slots": deploy_slots,
		"assassinate_slots": kill_slots,
		"return_spy": spy_targets,
		"recruit_market": market_indices,
		"recruit_supply": supply_cards,
		# Deploy с пустым бараком — законное действие, дающее 1 VP вместо
		# войска (рулбук стр. 12), поэтому оно отдельно от deploy_slots.
		"deploy_for_vp": p.power >= Actions.COST_DEPLOY and p.troops_in_barracks <= 0,
		"end_turn": true,
	}


## Статическое описание собранной доски: геометрия и названия не меняются за
## партию, поэтому клиенту достаточно получить это один раз при входе в игру
## (в локальном режиме — при старте сцены).
static func board_snapshot(state: GameState) -> Dictionary:
	var sites: Dictionary = {}
	for site_id: String in state.graph.sites.keys():
		var s: Dictionary = state.graph.sites[site_id]
		sites[site_id] = {
			"name": s["name"],
			"vp": s["vp"],
			"hex": s.get("hex", ""),
			"slots": Array(state.graph.slots_of_site(site_id)),
		}

	# Координаты берём из BoardGeometry: в самом графе у слота записано
	# положение ВНУТРИ гекса, и если рисовать по нему, все гексы лягут друг на
	# друга (так и было — доска выглядела кашей).
	var geometry: Dictionary = BoardGeometry.build(state)
	var slots: Dictionary = geometry.get("slots", {})
	if slots.is_empty():
		# синтетические доски тестов: геометрии нет, отдаём то, что есть
		for slot_id: String in state.graph.slots.keys():
			var sl: Dictionary = state.graph.slots[slot_id]
			var pos: Vector2 = sl["pos"]
			slots[slot_id] = {"x": pos.x, "y": pos.y, "site_id": sl.get("site", ""), "hex": sl.get("hex", "")}

	return {
		"sites": sites,
		"slots": slots,
		"tiles": geometry.get("tiles", []),
		"hex_radius_px": geometry.get("hex_radius_px", 1.0),
		# pixel-art schematic view of the same board (empty for synthetic test boards)
		"schematic": BoardSchematic.build(state),
		# какие полуколоды собраны в маркет: по ним экран красит фон
		"half_decks": state.half_decks.duplicate(),
	}


## Кто сейчас контролирует какую локацию: site_id -> player_id, и только те
## локации, у которых контролёр есть. Открытая информация — войска на доске
## видны всем, — но считать её должен движок: правила контроля живут в
## core/rules/site_control.gd, а интерфейс правил не знает.
static func _site_control(state: GameState) -> Dictionary:
	var out: Dictionary = {}
	for site_id: String in state.graph.sites.keys():
		var owner := state.control.controller_of(site_id, state.troops)
		if owner != "":
			out[site_id] = owner
	return out


static func _duplicate_spies(spies: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for site_id: String in spies.keys():
		result[site_id] = (spies[site_id] as Array).duplicate()
	return result


static func _player_view(p: PlayerState, is_owner: bool) -> Dictionary:
	var view: Dictionary = {
		"id": p.id,
		"power": p.power,
		"influence": p.influence,
		"troops_in_barracks": p.troops_in_barracks,
		"spies_in_barracks": p.spies_in_barracks,
		"trophy_hall_count": p.trophy_hall_count,
		"white_trophy_count": p.white_trophy_count,
		"trophies": p.trophies.duplicate(),
		"vp_tokens": p.vp_tokens,
		"inner_circle": p.deck.inner_circle.duplicate(),
		"played_pile": p.deck.played_pile.duplicate(),
		"hand_size": p.deck.hand.size(),
		"discard_size": p.deck.discard_pile.size(),
		"deck_size": p.deck.draw_pile.size(),
	}
	if is_owner:
		view["hand"] = p.deck.hand.duplicate()
		view["discard_pile"] = p.deck.discard_pile.duplicate()
		view["pending_promotions"] = p.pending_promotions.duplicate()
	return view


static func _pending_decision_view(state: GameState, viewer_id: String) -> Dictionary:
	# GameServer держит EffectResolver отдельно от GameState (стек резолвера
	# не сериализуется в само состояние партии) — поэтому pending передаётся
	# сюда явно самим GameServer'ом через for_player_with_pending(), а этот
	# путь используется, только когда StateView зовут напрямую (тесты) без
	# активного resolver'а.
	return {}


## Вариант for_player(), которым в реальности пользуется GameServer: pending
## живёт в EffectResolver, а не в GameState, поэтому его передают отдельно.
static func for_player_with_pending(state: GameState, viewer_id: String, pending: PendingDecision) -> Dictionary:
	var view: Dictionary = for_player(state, viewer_id)
	view["pending_decision"] = _decision_dict(pending, viewer_id)
	# Пока ждём ответа на вопрос карты, сервер отклонит любое другое действие,
	# поэтому и интерфейс не должен предлагать ни карты, ни кнопки.
	if pending != null:
		view["legal"] = {}
	return view


static func _decision_dict(pending: PendingDecision, viewer_id: String) -> Dictionary:
	if pending == null:
		return {}
	var mine: bool = pending.player_id == viewer_id
	return {
		"player_id": pending.player_id,
		"prompt": pending.prompt,
		"choice_type": pending.choice_type,
		"tag": pending.tag,
		"legal_options": pending.legal_options.duplicate() if mine else [],
		"option_labels": pending.option_labels.duplicate() if mine else [],
		"source_card": pending.source_card,
	}
