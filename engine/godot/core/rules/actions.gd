class_name Actions
extends RefCounted

## Четыре базовых действия (рулбук, стр. 8, 11-13). В шаге 1 своего хода
## игрок может брать их сколько угодно раз в любом порядке, пока хватает
## ресурсов из пула — пул не проверяется здесь предварительно одним счётчиком
## "действий за ход", вызывающий код зовёт эти функции столько раз, сколько
## хочет игрок.
##
## Розыгрыш карты (шаг "Play a card") сюда не входит — это Deck.play_from_hand,
## без применения эффекта (этап 5).

const COST_ASSASSINATE := 3
const COST_DEPLOY := 1
const COST_RETURN_SPY := 3
const WHITE := "white"


## Assassinate a troop (рулбук стр. 11): 3 Power, цель — вражеское войско
## (чужой игрок ИЛИ белое) в зоне Присутствия. Убитое войско уходит в
## трофи-холл ассасина (стр. 14: трофи-холл считает ЛЮБОЕ войско).
static func assassinate(state: GameState, player_id: String, slot_id: String) -> bool:
	var p: PlayerState = state.players[player_id]
	if p.power < COST_ASSASSINATE:
		return false
	var legal: PackedStringArray = state.presence.assassinatable_slots(player_id, state.troops, state.spies)
	if not legal.has(slot_id):
		return false
	p.power -= COST_ASSASSINATE
	var victim: String = state.troops.get(slot_id, "")
	state.troops[slot_id] = ""
	p.add_trophy(victim)
	return true


## Deploy a troop (рулбук стр. 12): 1 Power. Если в бараке войск больше нет,
## действие вместо развёртывания даёт 1 VP ("Each time you take this action
## while you have no troops remaining in your barracks, gain 1 VP instead").
## Развёртывание последнего войска запускает конец игры (стр. 14).
static func deploy(state: GameState, player_id: String, slot_id: String) -> bool:
	var p: PlayerState = state.players[player_id]
	if p.power < COST_DEPLOY:
		return false

	if p.troops_in_barracks <= 0:
		p.power -= COST_DEPLOY
		p.vp_tokens += state.vp_bank.grant(1)
		return true

	var legal: PackedStringArray = state.presence.deployable_slots(player_id, state.troops, state.spies)
	if not legal.has(slot_id):
		return false

	p.power -= COST_DEPLOY
	state.troops[slot_id] = player_id
	p.troops_in_barracks -= 1
	if p.troops_in_barracks == 0:
		GameEnd.trigger(state, "last_troop")
	return true


## Recruit a card (рулбук стр. 13): Influence, равный стоимости карты.
## card_cost передаётся снаружи — этап 2 не знает реальных стоимостей карт
## (claude/architecture.md, раздел 1: у карт мода нет разобранного поля cost).
static func recruit(state: GameState, player_id: String, market_index: int, card_cost: int) -> bool:
	var p: PlayerState = state.players[player_id]
	if p.influence < card_cost:
		return false
	if market_index == Market.DEVOURED_TOP_INDEX:
		var ghost_card := ghost_market_card(state, player_id)
		if ghost_card == "":
			return false
		state.devoured_pile.pop_back()
		p.influence -= card_cost
		p.deck.discard_pile.append(ghost_card)
		return true
	if market_index < 0 or market_index >= state.market.display.size():
		return false
	if state.market.display[market_index] == "":
		return false
	var card_id: String = state.market.recruit_at(market_index)
	if card_id == "":
		return false
	p.influence -= card_cost
	p.deck.discard_pile.append(card_id)
	if state.market.is_deck_empty():
		GameEnd.trigger(state, "market_empty")
	return true


## Ghost: "for the rest of your turn treat the top card of the devoured deck as
## if it was in the market". Возвращает эту карту, если эффект действует для
## player_id и её можно купить (у стартовых карт нет стоимости), иначе "".
static func ghost_market_card(state: GameState, player_id: String) -> String:
	if state.ghost_market_player == "" or state.ghost_market_player != player_id:
		return ""
	if state.devoured_pile.is_empty():
		return ""
	var top: String = state.devoured_pile[state.devoured_pile.size() - 1]
	return top if CardLibrary.card_cost(top) >= 0 else ""


## Recruit из общей стопки — House Guard или Priestess of Lolth (рулбук стр. 13:
## "you may expend Influence from your resource pool to recruit a House Guard,
## a Priestess of Lolth, or a card from the market"). Это отдельный источник:
## карты лежат своими открытыми стопками рядом с маркетом, слотов дисплея не
## занимают и из колоды маркета не пополняются, поэтому исчерпание такой стопки
## конец партии НЕ запускает (в отличие от опустевшей колоды маркета).
##
## Стоимость берётся из CardLibrary, а не передаётся снаружи: в отличие от
## Actions.recruit (написан на этапе 2, когда реальных карт ещё не было),
## этот метод появился уже после этапа 4 и знает настоящие цены.
static func recruit_from_supply(state: GameState, player_id: String, card_id: String) -> bool:
	if not Supplies.PURCHASABLE.has(card_id):
		return false
	if not state.supplies.is_available(card_id):
		return false
	var cost: int = CardLibrary.card_cost(card_id)
	if cost < 0:
		return false
	var p: PlayerState = state.players[player_id]
	if p.influence < cost:
		return false
	if not state.supplies.take(card_id):
		return false
	p.influence -= cost
	p.deck.discard_pile.append(card_id)
	return true


## Return an enemy spy (рулбук стр. 13): 3 Power, цель — вражеский шпион в
## зоне Присутствия (белых шпионов не бывает). Шпион возвращается в барак
## владельца — не в трофи-холл, это не войско.
static func return_enemy_spy(state: GameState, player_id: String, site_id: String, spy_owner: String) -> bool:
	var p: PlayerState = state.players[player_id]
	if p.power < COST_RETURN_SPY:
		return false
	if spy_owner == player_id or spy_owner == WHITE:
		return false
	if not state.presence.has_presence_at_site(player_id, site_id, state.troops, state.spies):
		return false
	var site_spies: Array = state.spies.get(site_id, [])
	var idx: int = site_spies.find(spy_owner)
	if idx == -1:
		return false
	p.power -= COST_RETURN_SPY
	site_spies.remove_at(idx)
	state.spies[site_id] = site_spies
	if state.players.has(spy_owner):
		state.players[spy_owner].spies_in_barracks += 1
	return true
