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
##   "choose_opponent_deployed" — решение владельца (2026-10-12, Gibbering
##       Mouther): только противники, в чьё Присутствие встало хотя бы одно
##       войско, развёрнутое этой картой (слоты — общий список slots, его
##       заполняет DeployTroop.deployed). Никого нет — Outcast не выдаётся.

const INSANE_OUTCAST_ID := Supplies.INSANE_OUTCAST

var mode: String
var count: int
## Для "choose_opponent_deployed": слоты, куда карта поставила войска.
var slots: Array = []


func _init(m: String, n: int = 1) -> void:
	mode = m
	count = n


## Стопка Insane Outcast конечна — 30 штук (рулбук стр. 13): "If the supply of
## ... Insane Outcasts runs out, the game continues, but you'll no longer be
## able to recruit one of those cards". Если на всех не хватило, выдаём
## сколько есть и молча останавливаемся — это не ошибка.
func _give(state: GameState, target_id: String, resolver: EffectResolver) -> void:
	var p: PlayerState = state.players[target_id]
	# New Era, Swarm of Crawling Claws в руке получателя: он может взять Outcast в руку.
	if p.deck.hand.has(ShadowCards.CRAWLING_CLAWS) and state.supplies.is_available(INSANE_OUTCAST_ID):
		resolver.push(ShadowCards.ClawsReaction.new(target_id, count), target_id)
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
				if state.is_opponent(player_id, pid):
					_give(state, pid, resolver)
			return

	# choose_opponent / choose_opponent_deployed
	if is_answered():
		var target = answer()
		if target != null and target != "":
			_give(state, String(target), resolver)
		return
	var options: Array = []
	for pid: String in state.turn_order:
		if state.is_opponent(player_id, pid) and (mode != "choose_opponent_deployed" or _deployed_into(state, pid)):
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


func _deployed_into(state: GameState, pid: String) -> bool:
	for slot_id: String in slots:
		if state.presence.has_presence_at_slot(pid, slot_id, state.troops, state.spies):
			return true
	return false
