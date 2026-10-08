class_name GiveInsaneOutcast
extends CardEffect

## "<X> recruits an Insane Outcast" — кладёт Insane Outcast (card_id 48341,
## единственный экземпляр-джокер, не привязан к аспекту/типу) в сброс
## указанного игрока, как обычный Recruit (без оплаты).
##
## mode:
##   "self"            — сам разыгравший карту игрок
##   "each_opponent"   — все противники
##   "choose_opponent"          — активный игрок выбирает, кто из противников
##   "choose_opponent_adjacent" — УПРОЩЕНО (см. ниже): по правилам должен быть
##       противник с войском, смежным хотя бы с одним из только что
##       развёрнутых слотов (Gibbering Mouther); в этой реализации сужение по
##       смежности не проверяется — выбор идёт из ВСЕХ противников. Пометка
##       для владельца игры: если хочет строгую проверку смежности, отдельно
##       уточнить набор "только что развёрнутых слотов" в интерфейсе эффекта.

const INSANE_OUTCAST_ID := Supplies.INSANE_OUTCAST

var mode: String
var count: int


func _init(m: String, n: int = 1) -> void:
	mode = m
	count = n


## Стопка Insane Outcast конечна — 30 штук (рулбук стр. 13): "If the supply of
## ... Insane Outcasts runs out, the game continues, but you'll no longer be
## able to recruit one of those cards". Если на всех не хватило, выдаём
## сколько есть и молча останавливаемся — это не ошибка.
func _give(state: GameState, target_id: String, resolver: EffectResolver) -> void:
	var p: PlayerState = state.players[target_id]
	# New Era, Bone Naga в руке получателя: он может взять Outcast в руку.
	if p.deck.hand.has(ShadowCards.BONE_NAGA) and state.supplies.is_available(INSANE_OUTCAST_ID):
		resolver.push(ShadowCards.NagaReaction.new(target_id, count), target_id)
		return
	var given := 0
	for i in range(count):
		if not state.supplies.take(INSANE_OUTCAST_ID):
			break
		p.deck.discard_pile.append(INSANE_OUTCAST_ID)
		given += 1
	if given > 0:
		resolver.log_event("give_insane_outcast", {"player_id": target_id, "count": given})


## Порядок раздачи важен ровно тогда, когда стопки на всех не хватает:
## "If multiple Insane Outcasts are recruited and would run out, they are
## recruited in clockwise order starting with the player whose turn it is"
## (рулбук стр. 13) — то есть обход turn_order начинается с текущего игрока,
## а не с начала списка.
func _clockwise_from_current(state: GameState) -> Array[String]:
	var order: Array[String] = []
	var n: int = state.turn_order.size()
	for i in range(n):
		order.append(state.turn_order[(state.current_player_index + i) % n])
	return order


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	match mode:
		"self":
			_give(state, player_id, resolver)
			return
		"each_opponent":
			for pid: String in _clockwise_from_current(state):
				if pid != player_id:
					_give(state, pid, resolver)
			return

	# choose_opponent / choose_opponent_adjacent
	if is_answered():
		var target = answer()
		if target != null and target != "":
			_give(state, String(target), resolver)
		return
	var options: Array = []
	for pid: String in state.turn_order:
		if pid != player_id:
			options.append(pid)
	if options.is_empty():
		return
	var pd := PendingDecision.new()
	pd.player_id = player_id
	pd.prompt = "Choose an opponent"
	pd.choice_type = "target_player"
	pd.legal_options = options
	pd.target_effect = self
	resolver.request_decision(pd)
