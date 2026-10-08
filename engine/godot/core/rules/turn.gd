class_name TurnEngine
extends RefCounted

## Ход игрока (рулбук, стр. 8), строго по порядку:
##   [начало хода] Начислить Power/Influence региональных бонусов гекса A2
##                 (claude/rules/cluster_bonus.gd) — см. пояснение по срокам
##                 начисления там. Также сбросить played_aspects_this_turn
##                 (этап 5, FocusEffect).
##   ... шаг 1 (розыгрыш карт / базовые действия) — вне TurnEngine, это
##       core/rules/actions.gd (базовые действия) и TurnEngine.play_card()
##       (розыгрыш карты, этап 5), вызывается вызывающим кодом сколько
##       угодно раз.
##   [конец хода]
##   0. Прогнать отложенные "At end of turn, ..." эффекты сыгранных карт
##      (этап 5, PlayerState.pending_end_of_turn) — ДО обычных четырёх шагов.
##   1. Promote карт во Внутренний круг, если разыгранные карты велели.
##   2. Начислить VP за маркеры контроля локаций (обычный + региональный
##      бонус гекса A2).
##   3. Сбросить разыгранные карты и всё, что осталось в руке.
##   4. Добрать до размера руки 5 (с перетасовкой сброса, если колода кончилась).
## Ресурсы (Power/Influence) сгорают отдельным шагом — рулбук относит это к
## самому пулу (стр. 7), а не к перечисленным четырём шагам, но по смыслу это
## тоже происходит на границе хода.

const HAND_SIZE := 5


## Вызывается ПЕРЕД тем, как игрок начнёт шаг 1 своего хода (до первого
## Actions.*/play_card). Начисляет ресурсы регионального бонуса A2 — их нужно
## успеть потратить до конца этого же хода, иначе они сгорят как обычные
## неизрасходованные Power/Influence (рулбук стр. 7). Также сбрасывает
## played_aspects_this_turn нового хода.
static func start_turn(state: GameState, player_id: String, resolver: EffectResolver = null) -> void:
	state.played_aspects_this_turn.clear()
	state.ghost_market_player = ""
	state.turn_discounts.clear()
	state.turn_flags.clear()
	var p: PlayerState = state.players[player_id]
	if p.start_of_turn_influence > 0:
		p.influence += p.start_of_turn_influence
		if resolver != null:
			resolver.log_event("start_of_turn_influence", {"player_id": player_id, "amount": p.start_of_turn_influence})
		p.start_of_turn_influence = 0
	# Маркеры контроля (A1, A3, B1-B6): +1 Influence за каждую контролируемую
	# локацию с маркером; бонус A2 — Power/Influence своего яруса. Тоже в начале
	# хода — иначе сгорит, не успев пригодиться.
	state.marker_influence_paid.clear()
	state.a2_paid = {"power": 0, "influence": 0}
	_grant_income(state, player_id, resolver, true)


## Правило владельца игры (2026-09-24): Influence за локацию с маркером
## выдаётся СРАЗУ, как только игрок взял её под контроль посреди хода, а не
## только в начале следующего. Не чаще раза за ход на локацию
## (state.marker_influence_paid). То же для Power/Influence бонуса A2
## (2026-09-28): ярус достигнут или вырос посреди хода — доплачивается
## разница с уже выданным в этом ходу (state.a2_paid); ярус упал — ничего не
## отнимается. Зовётся после каждого действия игрока.
static func grant_control_income(state: GameState, player_id: String, resolver: EffectResolver = null) -> void:
	_grant_income(state, player_id, resolver, false)


static func _grant_income(state: GameState, player_id: String, resolver: EffectResolver, turn_start: bool) -> void:
	var a2: Array[int] = _pay_a2(state, player_id)
	var marker_sites: Array[String] = []
	var marker_influence: int = _pay_marker_influence(state, player_id, marker_sites)
	if resolver != null and (a2[0] + a2[1] + marker_influence) > 0:
		resolver.log_event("turn_income", {
			"player_id": player_id,
			"turn_start": turn_start,
			"a2_power": a2[0],
			"a2_influence": a2[1],
			"marker_influence": marker_influence,
			"marker_site_ids": marker_sites,
		})


## Доплата бонуса A2 до уровня текущего яруса: [Power, Influence].
static func _pay_a2(state: GameState, player_id: String) -> Array[int]:
	var bonus: ClusterBonus.Reward = ClusterBonus.evaluate(state, player_id)
	var power := maxi(0, bonus.power - int(state.a2_paid["power"]))
	var influence := maxi(0, bonus.influence - int(state.a2_paid["influence"]))
	state.a2_paid["power"] = int(state.a2_paid["power"]) + power
	state.a2_paid["influence"] = int(state.a2_paid["influence"]) + influence
	var p: PlayerState = state.players[player_id]
	p.power += power
	p.influence += influence
	return [power, influence]


## paid_sites — сюда дописываются локации, за которые заплачено сейчас.
static func _pay_marker_influence(state: GameState, player_id: String, paid_sites: Array[String] = []) -> int:
	var gained := 0
	for site_id: String in ControlMarkers.marked_sites(state):
		if state.marker_influence_paid.has(site_id):
			continue
		if state.control.controller_of(site_id, state.troops) != player_id:
			continue
		state.marker_influence_paid.append(site_id)
		paid_sites.append(site_id)
		gained += int(ControlMarkers.marker_for(state, site_id).get("control_influence", 0))
	state.players[player_id].influence += gained
	return gained


## Розыгрыш карты (этап 5). Переносит карту из руки в played_pile, регистрирует
## её аспект (для Focus) и запускает её эффект через resolver. Если эффект
## останавливается на решении игрока, resolver.pending будет не null — вызывающий
## код должен показать decision и в дальнейшем вызвать resume_card().
## Возвращает false, если карты нет в руке (эффект в этом случае не трогается).
static func play_card(state: GameState, player_id: String, card_id: String, resolver: EffectResolver) -> bool:
	var p: PlayerState = state.players[player_id]
	if not p.deck.play_from_hand(card_id):
		return false
	var aspect: String = CardLibrary.card_aspect(card_id)
	if aspect != "":
		state.played_aspects_this_turn.append(aspect)
	var effect: CardEffect = ShadowCards.on_play(state, player_id, card_id, CardLibrary.get_effect(card_id))
	resolver.apply(effect, player_id, state)
	return true


## Продолжение розыгрыша карты (или отложенного end-of-turn эффекта) после
## того, как игрок ответил на resolver.pending.
static func resume_card(state: GameState, answer, resolver: EffectResolver) -> void:
	resolver.resume(state, answer)


## end_turn поддерживает необязательный resolver: если карты этого хода не
## оставили pending end-of-turn эффектов, работает точно как раньше (этапы
## 1-4 звали end_turn(state, player_id) без резолвера). Если resolver не
## передан, для внутреннего использования создаётся временный — реальные
## decision-эффекты в pending_end_of_turn в этом случае не должны появляться
## (вызывающий код этапа 6/7 обязан передавать общий resolver партии).
static func end_turn(state: GameState, player_id: String, resolver: EffectResolver = null) -> void:
	var r: EffectResolver = resolver if resolver != null else EffectResolver.new()
	if run_deferred_end_of_turn(state, player_id, r):
		return
	finish_end_of_turn(state, player_id, r)


## 0. отложенные "at end of turn" эффекты сыгранных в этот ход карт.
## Берём по одному из очереди: если эффект запросил решение, остальные
## остаются в p.pending_end_of_turn (раньше очередь очищалась целиком, и
## второй promote — Black Earth Cultist + Earth Elemental Myrmidon — терялся).
## Возвращает true, если ждём решения: вызывающий код после resume_card()
## зовёт эту функцию снова, а когда она вернёт false — finish_end_of_turn().
static func run_deferred_end_of_turn(state: GameState, player_id: String, resolver: EffectResolver) -> bool:
	var p: PlayerState = state.players[player_id]
	while not p.pending_end_of_turn.is_empty():
		var effect: CardEffect = p.pending_end_of_turn.pop_front()
		resolver.apply(effect, player_id, state)
		if resolver.is_waiting():
			return true
	return false


## Хвост end_turn (шаги 1-4 + сгорание ресурсов), вынесенный отдельно, чтобы
## его можно было позвать и сразу (end_turn без отложенных эффектов), и после
## того как resume_card() разрешил все отложенные decision'ы.
## resolver нужен только чтобы записать в журнал, за что начислены VP: игрок
## видел, как счёт растёт, и не понимал причину (вопрос владельца игры
## "за что у красного 18 VP?"). Правила от него не зависят.
static func finish_end_of_turn(state: GameState, player_id: String, resolver: EffectResolver = null) -> void:
	var p: PlayerState = state.players[player_id]

	# 1. promote
	for card_id: String in p.pending_promotions.duplicate():
		p.deck.promote(card_id)
	p.pending_promotions.clear()

	# 2. VP по ходу партии приносят ТОЛЬКО две вещи:
	#      • тотальный контроль локации с маркером (A1, A3, B1-B6);
	#      • региональный бонус гекса A2.
	# VP обычных локаций в течение партии НЕ начисляются — они считаются один
	# раз в финальном подсчёте (core/rules/scoring.gd, рулбук стр. 14).
	# Исправлено 2026-09-14 по прямому указанию владельца игры: до этого
	# движок каждый ход выдавал VP за контроль любой локации, и счёт рос
	# в разы быстрее, чем должен.
	var marker_reward: ControlMarkers.Reward = ControlMarkers.evaluate(state, player_id)
	var bonus_vp: int = ClusterBonus.evaluate(state, player_id).vp
	var granted: int = state.vp_bank.grant(marker_reward.vp + bonus_vp)
	p.vp_tokens += granted
	if resolver != null and granted > 0:
		resolver.log_event("vp_income", {
			"player_id": player_id,
			"markers": marker_reward.vp,
			"marker_sites": marker_reward.total_control_sites,
			"marker_site_ids": marker_reward.total_control_ids,
			"cluster_bonus": bonus_vp,
			"granted": granted,
			"total_vp": p.vp_tokens,
		})

	# 3. сброс
	p.deck.end_of_turn_discard()

	# 4. добор
	p.deck.draw_up_to(HAND_SIZE, state.rng)

	# неистраченные ресурсы сгорают (рулбук стр. 7)
	p.reset_resources_for_new_turn()
