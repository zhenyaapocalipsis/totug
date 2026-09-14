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
	return total


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
