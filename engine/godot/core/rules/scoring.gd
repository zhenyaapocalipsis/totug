class_name Scoring
extends RefCounted

## Финальный подсчёт (рулбук, стр. 14):
##   • VP сайта за каждый контролируемый сайт
##   • +2 VP за каждый сайт под тотальным контролем     — оба уже считает
##     SiteControl.map_score (этап 1), здесь просто переиспользуются
##   • 1 VP за каждое войско в трофи-холле
##   • deck-VP каждой карты в колоде, руке и сбросе
##   • inner-circle-VP каждой карты Внутреннего круга
##   • VP-токены, набранные по ходу игры
##
## card_deck_vp / card_inner_circle_vp — Dictionary card_id -> int, передаются
## снаружи: этап 2 не знает реальных VP-значений карт (это данные этапа 4).
## Для несуществующего в словаре id используется 0 — так синтетические
## тестовые id, не заведённые явно, безопасны по умолчанию.

static func final_score(
	state: GameState,
	player_id: String,
	card_deck_vp: Dictionary = {},
	card_inner_circle_vp: Dictionary = {}
) -> int:
	var p: PlayerState = state.players[player_id]
	var total: int = state.control.map_score(player_id, state.troops, state.spies)
	total += p.trophy_hall_count

	for card_id: String in p.deck.cards_outside_inner_circle():
		total += int(card_deck_vp.get(card_id, 0))
	for card_id: String in p.deck.inner_circle:
		total += int(card_inner_circle_vp.get(card_id, 0))

	total += p.vp_tokens
	var extra := card_bonus_vp(state, player_id)
	total += int(extra["deck"]) + int(extra["inner"])
	return total


## Итоговый счёт по статьям — для экрана конца партии. VP карт берутся из
## CardLibrary (у карт без VP там null → 0). Сумма статей = final_score с теми
## же VP карт (проверяет тест).
static func breakdown(state: GameState, player_id: String) -> Dictionary:
	var p: PlayerState = state.players[player_id]
	var sites := 0
	var total_control := 0
	for site_id: String in state.graph.sites.keys():
		if state.control.controller_of(site_id, state.troops) != player_id:
			continue
		sites += int(state.graph.sites[site_id]["vp"])
		if state.control.has_total_control(player_id, site_id, state.troops, state.spies):
			total_control += 2
	var deck := 0
	for card_id: String in p.deck.cards_outside_inner_circle():
		deck += _card_vp(card_id, "deck_vp")
	var inner := 0
	for card_id: String in p.deck.inner_circle:
		inner += _card_vp(card_id, "inner_circle_vp")
	var extra := card_bonus_vp(state, player_id)
	deck += int(extra["deck"])
	inner += int(extra["inner"])
	var result := {
		"sites": sites,
		"total_control": total_control,
		"trophies": p.trophy_hall_count,
		"deck": deck,
		"inner_circle": inner,
		"tokens": p.vp_tokens,
	}
	result["total"] = sites + total_control + p.trophy_hall_count + deck + inner + p.vp_tokens
	return result


static func _card_vp(card_id: String, key: String) -> int:
	var v = CardLibrary.card_data(card_id).get(key)
	return int(v) if v != null else 0


## VP карт из CardLibrary в виде словарей для final_score / winners.
static func library_card_vp(state: GameState) -> Array[Dictionary]:
	var deck_vp := {}
	var inner_vp := {}
	for pid: String in state.players.keys():
		var d: Deck = state.players[pid].deck
		for card_id: String in d.cards_outside_inner_circle() + d.inner_circle:
			deck_vp[card_id] = _card_vp(card_id, "deck_vp")
			inner_vp[card_id] = _card_vp(card_id, "inner_circle_vp")
	return [deck_vp, inner_vp]


## Игроки с максимальным итоговым счётом (может быть несколько — ничья,
## рулбук стр. 14: "If there's a tie for most, the tied players each win").
static func winners(
	state: GameState,
	card_deck_vp: Dictionary = {},
	card_inner_circle_vp: Dictionary = {}
) -> Array[String]:
	var scores: Dictionary = {}
	var best: int = -1
	for player_id: String in state.turn_order:
		var score: int = final_score(state, player_id, card_deck_vp, card_inner_circle_vp)
		scores[player_id] = score
		if score > best:
			best = score
	var result: Array[String] = []
	for player_id: String in state.turn_order:
		if int(scores[player_id]) == best:
			result.append(player_id)
	return result


## New Era (Celestial Order): VP карт, которые зависят от партии, а не напечатаны.
##   Couatl (49006): в колоде — 1 VP за каждого своего шпиона на доске, во
##     Внутреннем круге — столько же плюс напечатанные 2.
##   Druid (49009): за каждую копию (колода или Внутренний круг) — 5 VP, если у
##     игрока больше всех карт в колоде (вне Внутреннего круга), 2 VP — если
##     вторая по размеру; вдвоём — 3 и 1 (половина с округлением вверх).
##     Ничья делит место: все равные получают бонус этого места.
const COUATL := "49006"
const DRUID := "49009"


static func card_bonus_vp(state: GameState, player_id: String) -> Dictionary:
	var p: PlayerState = state.players[player_id]
	var deck_extra := 0
	var inner_extra := 0
	var spies := 0
	for owners: Array in state.spies.values():
		spies += owners.count(player_id)
	var outside := p.deck.cards_outside_inner_circle()
	deck_extra += outside.count(COUATL) * spies
	inner_extra += p.deck.inner_circle.count(COUATL) * spies

	var druids := outside.count(DRUID) + p.deck.inner_circle.count(DRUID)
	if druids > 0:
		var place := _deck_size_place(state, player_id)
		var two := state.players.size() <= 2
		var bonus := 0
		if place == 1:
			bonus = 3 if two else 5
		elif place == 2:
			bonus = 1 if two else 2
		deck_extra += bonus * outside.count(DRUID)
		inner_extra += bonus * p.deck.inner_circle.count(DRUID)

	# Devourer / Sword Wraith Commander в колоде: Insane Outcast там стоят 0 VP
	# вместо -1.
	if ShadowCards.OUTCASTS_WORTHLESS.any(func(c): return outside.has(c)):
		deck_extra += outside.count(ShadowCards.OUTCAST)
	return {"deck": deck_extra, "inner": inner_extra}


## Место игрока по размеру колоды: 1 — больше всех (с ничьей), 2 — следующий
## размер, 0 — дальше.
static func _deck_size_place(state: GameState, player_id: String) -> int:
	var sizes: Array[int] = []
	for pid: String in state.players.keys():
		var n: int = (state.players[pid] as PlayerState).deck.cards_outside_inner_circle().size()
		if not sizes.has(n):
			sizes.append(n)
	sizes.sort()
	sizes.reverse()
	var mine: int = (state.players[player_id] as PlayerState).deck.cards_outside_inner_circle().size()
	var idx := sizes.find(mine)
	return idx + 1 if idx <= 1 else 0
