class_name ForceDiscard
extends CardEffect

## "X must discard a card" — заставляет противника(ов) сбросить карту.
##
## УПРОЩЕНИЕ (пометка для владельца игры, поправить при необходимости):
## по рулбуку сбрасываемую карту выбирает сам сбрасывающий игрок; здесь для
## простоты сетевого протокола сбрасывается детерминированно последняя карта
## руки (без отдельного pending_decision у пострадавшего игрока). Ничего не
## меняется по сути правила "сброс на 1 карту меньше" — спорна только "какая
## именно карта", это никогда не влияет на публичный счёт.
##
## mode:
##   "choose_opponent" — АКТИВНЫЙ игрок выбирает, какой оппонент (из тех, кто
##                       удовлетворяет min_cards) сбрасывает.
##   "each_opponent"   — сбрасывают ВСЕ оппоненты, удовлетворяющие min_cards.
##
## min_cards — порог "more than N cards" (Cranium Rats/Gauth/Nothic/Chuul:
## порог считается по ВСЕМ картам игрока — cards_outside_inner_circle() плюс
## рука, см. Deck — используем hand+draw+discard+played, что и есть полный
## пул карт игрока вне Внутреннего круга).

var mode: String
var min_cards: int


func _init(m: String, threshold: int = 0) -> void:
	mode = m
	min_cards = threshold


func _total_cards(p: PlayerState) -> int:
	return p.deck.cards_outside_inner_circle().size()


func _eligible_opponents(state: GameState, player_id: String) -> Array:
	var result: Array = []
	for pid: String in state.turn_order:
		if pid == player_id:
			continue
		if _total_cards(state.players[pid]) > min_cards:
			result.append(pid)
	return result


func _discard_one(state: GameState, victim_id: String, resolver: EffectResolver) -> void:
	var vp: PlayerState = state.players[victim_id]
	if vp.deck.hand.is_empty():
		return
	var card_id: String = vp.deck.hand.pop_back()
	vp.deck.discard_pile.append(card_id)
	resolver.log_event("force_discard", {"player_id": victim_id, "card_id": card_id})


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if mode == "each_opponent":
		for pid: String in _eligible_opponents(state, player_id):
			_discard_one(state, pid, resolver)
		return

	# choose_opponent
	if is_answered():
		var victim = answer()
		if victim != null and victim != "":
			_discard_one(state, String(victim), resolver)
		return
	var options: Array = _eligible_opponents(state, player_id)
	if options.is_empty():
		return
	var pd := PendingDecision.new()
	pd.player_id = player_id
	pd.prompt = "Choose an opponent to discard a card"
	pd.choice_type = "target_player"
	pd.legal_options = options
	pd.target_effect = self
	resolver.request_decision(pd)
