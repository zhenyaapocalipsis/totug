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
	var p: PlayerState = state.players[player_id]
	var bonus: ClusterBonus.Reward = ClusterBonus.evaluate(state, player_id)
	p.power += bonus.power
	p.influence += bonus.influence
	# Маркеры контроля (A1, A3, B1-B6): +1 Influence за каждую контролируемую
	# локацию с маркером. Тоже в начале хода — иначе сгорит, не успев пригодиться.
	var markers: ControlMarkers.Reward = ControlMarkers.evaluate(state, player_id)
	p.influence += markers.influence
	if resolver != null and (bonus.power + bonus.influence + markers.influence) > 0:
		resolver.log_event("turn_income", {
			"player_id": player_id,
			"a2_power": bonus.power,
			"a2_influence": bonus.influence,
			"marker_influence": markers.influence,
		})


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
	var effect: CardEffect = CardLibrary.get_effect(card_id)
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
	var p: PlayerState = state.players[player_id]

	# 0. отложенные "at end of turn" эффекты сыгранных в этот ход карт.
	var deferred: Array[CardEffect] = p.pending_end_of_turn.duplicate()
	p.pending_end_of_turn.clear()
	for effect in deferred:
		r.apply(effect, player_id, state)
		# Если один из отложенных эффектов запросил решение, дальнейшие шаги
		# конца хода приостанавливаются вместе с ним — вызывающий код должен
		# вызвать resume_card(), а затем finish_end_of_turn() сам.
		if r.is_waiting():
			return

	finish_end_of_turn(state, player_id, r)


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
