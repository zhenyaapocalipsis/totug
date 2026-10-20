class_name GodMode
extends RefCounted

## Режим бога в хотсите (владелец, 2026-10-20): проверять карты, не играя
## партию до нужного места. Выдать любую карту в любом числе, поставить или
## убрать войска и шпионов, добавить Power/Influence/VP, добрать карты,
## передать ход любому игроку. Правила тут не проверяются — состояние
## правится напрямую. Действие — словарь {"op": ..., ...}; применяет его
## GameServer.apply_god (только хотсит: по сети такие действия не ходят).
##
## Войска и шпионы берутся из бараков владельца, пока там есть, и
## возвращаются туда же, когда их убирают; пустые бараки не мешают ставить
## дальше и не заканчивают партию.

## Куда кладётся выданная карта: рука, верх колоды добора, сброс, Внутренний круг.
const ZONES: Array[String] = ["hand", "deck", "discard", "inner"]
## Больше копий за раз не выдаётся.
const MAX_COUNT := 20


static func apply(state: GameState, action: Dictionary, resolver: EffectResolver = null) -> bool:
	var pid := String(action.get("player_id", ""))
	match String(action.get("op", "")):
		"give":
			return give_card(state, pid, String(action.get("card_id", "")),
				int(action.get("count", 1)), String(action.get("zone", "hand")))
		"troop":
			return set_troop(state, String(action.get("slot_id", "")), String(action.get("owner", "")))
		"spy":
			return toggle_spy(state, String(action.get("site_id", "")), String(action.get("owner", "")))
		"clear_site":
			return clear_site(state, String(action.get("site_id", "")))
		"resources":
			return add_resources(state, pid, int(action.get("power", 0)),
				int(action.get("influence", 0)), int(action.get("vp", 0)))
		"draw":
			return draw(state, pid, int(action.get("count", 1)))
		"discard_hand":
			return discard_hand(state, pid)
		"set_turn":
			return set_turn(state, pid, resolver)
	return false


## count копий карты card_id игроку pid в зону zone (ZONES).
static func give_card(state: GameState, pid: String, card_id: String, count: int, zone: String) -> bool:
	if not state.players.has(pid) or CardLibrary.card_data(card_id).is_empty() or not ZONES.has(zone):
		return false
	var deck: Deck = (state.players[pid] as PlayerState).deck
	var pile: Array[String]
	match zone:
		"hand": pile = deck.hand
		# Верх колоды добора — конец массива (Deck.draw_one берёт pop_back).
		"deck": pile = deck.draw_pile
		"discard": pile = deck.discard_pile
		"inner": pile = state.stock(pid).deck.inner_circle
	for i in range(clampi(count, 1, MAX_COUNT)):
		pile.append(card_id)
	return true


## Поставить на место slot_id войско owner (id игрока или "white"); "" — убрать.
## Прежнее войско игрока возвращается в его бараки.
static func set_troop(state: GameState, slot_id: String, owner: String) -> bool:
	if not state.graph.slots.has(slot_id):
		return false
	if owner != "" and owner != GameState.WHITE and not state.players.has(owner):
		return false
	var old := String(state.troops.get(slot_id, ""))
	if old == owner:
		return old != ""
	if state.players.has(old):
		var holder := state.stock(old)
		holder.troops_in_barracks = mini(holder.troops_in_barracks + 1,
			state.starting_troops * state.stock_share(old))
	if owner == "":
		state.troops.erase(slot_id)
		return true
	if state.players.has(owner):
		var stock := state.stock(owner)
		stock.troops_in_barracks = maxi(0, stock.troops_in_barracks - 1)
	state.troops[slot_id] = owner
	return true


## Шпион owner на локации site_id: нет — поставить, есть — убрать.
static func toggle_spy(state: GameState, site_id: String, owner: String) -> bool:
	if not state.graph.sites.has(site_id) or not state.players.has(owner):
		return false
	var here: Array = state.spies.get(site_id, [])
	var stock := state.stock(owner)
	if here.has(owner):
		here.erase(owner)
		stock.spies_in_barracks = mini(stock.spies_in_barracks + 1,
			PlayerState.STARTING_SPIES * state.stock_share(owner))
	else:
		here.append(owner)
		stock.spies_in_barracks = maxi(0, stock.spies_in_barracks - 1)
	if here.is_empty():
		state.spies.erase(site_id)
	else:
		state.spies[site_id] = here
	return true


## Убрать с локации site_id все войска и всех шпионов.
static func clear_site(state: GameState, site_id: String) -> bool:
	if not state.graph.sites.has(site_id):
		return false
	for slot_id: String in state.graph.slots_of_site(site_id):
		if state.troops.has(slot_id):
			set_troop(state, slot_id, "")
	for owner in (state.spies.get(site_id, []) as Array).duplicate():
		toggle_spy(state, site_id, String(owner))
	return true


## Добавить (или отнять — отрицательные числа) Power, Influence и VP.
## Ниже нуля не уходит.
static func add_resources(state: GameState, pid: String, power: int, influence: int, vp: int) -> bool:
	if not state.players.has(pid):
		return false
	var p: PlayerState = state.players[pid]
	p.power = maxi(0, p.power + power)
	p.influence = maxi(0, p.influence + influence)
	if vp > 0:
		p.vp_tokens += state.vp_bank.grant(vp)
	else:
		p.vp_tokens = maxi(0, p.vp_tokens + vp)
	return true


## Добрать count карт из колоды (пустая — сброс перетасовывается, как обычно).
static func draw(state: GameState, pid: String, count: int) -> bool:
	if not state.players.has(pid):
		return false
	var deck: Deck = (state.players[pid] as PlayerState).deck
	for i in range(clampi(count, 1, MAX_COUNT)):
		deck.draw_one(state.rng)
	return true


## Вся рука — в сброс.
static func discard_hand(state: GameState, pid: String) -> bool:
	if not state.players.has(pid):
		return false
	var deck: Deck = (state.players[pid] as PlayerState).deck
	deck.discard_pile.append_array(deck.hand)
	deck.hand.clear()
	return true


## Ход переходит к pid сразу: начинается его ход (доход начала хода, сброс
## счётчиков хода), но ничьи карты не сбрасываются и не добираются — рука
## прежнего ходящего остаётся у него, сыгранные им карты уйдут в сброс в
## конце его следующего хода.
static func set_turn(state: GameState, pid: String, resolver: EffectResolver = null) -> bool:
	var index := state.turn_order.find(pid)
	if index < 0:
		return false
	state.current_player_index = index
	state.in_extra_turn = false
	TurnEngine.start_turn(state, pid, resolver)
	return true
