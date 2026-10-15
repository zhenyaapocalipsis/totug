class_name ShieldGuard
extends CardEffect

## Реакция Shield Guardian (Celestial Order, Galio из Runeterra Reforged):
## "If one of your units would be Assassinated, Supplanted, moved, or returned,
## you may discard this card to negate that effect and deploy 4 troops and draw
## a card." Решение владельца (2026-10-07): честная реакция в чужой ход.
##
## Атакующий эффект (карта или базовое действие) не делает удар сам, а
## оборачивает его: ShieldGuard.new(victim, удар). Если у жертвы в руке
## Shield Guardian, ей задаётся вопрос (pd.player_id = жертва):
##   да  — Shield Guardian из руки в сброс, удар отменён, жертва ставит
##         4 войска и берёт карту (решения — её);
##   нет — удар выполняется.
## Отменяется один удар; остальные удары того же эффекта идут как обычно
## (второй Shield Guardian в руке защитит и от следующего).
##
## Ankheg (Calimshan, Rammus из Runeterra Reforged) — та же реакция, но только
## на убийство и вытеснение войска (kill = true): "If one of your troops would be
## Assassinated or Supplanted by a player, you may discard this card to negate
## that effect and Supplant one of their troops instead". Если в руке обе карты,
## сначала спрашивается Shield Guardian, при отказе — Ankheg.

const CARD := "49021"
const ANKHEG := "49718"

var victim: String
var hit: CardEffect
var what: String
var kill: bool
## resume() вызывает эффект от имени того, кто отвечал (жертвы), поэтому
## атакующего запоминаем при первом вызове.
var attacker: String = ""
var _asking: String = ""


func _init(victim_id: String, hit_effect: CardEffect, description: String = "", is_kill: bool = false) -> void:
	victim = victim_id
	hit = hit_effect
	what = description
	kill = is_kill


## Защищён ли юнит владельца owner от действия игрока attacker (kill — убийство
## или вытеснение войска: на них отвечает ещё и Ankheg).
static func can_react(state: GameState, attacker: String, owner: String, is_kill: bool = false) -> bool:
	return _guards(state, attacker, owner, is_kill).size() > 0


static func _guards(state: GameState, attacker: String, owner: String, is_kill: bool) -> Array[String]:
	var out: Array[String] = []
	if owner == "" or owner == attacker or owner == GameState.WHITE:
		return out
	if not state.players.has(owner):
		return out
	var hand: Array = (state.players[owner] as PlayerState).deck.hand
	if hand.has(CARD):
		out.append(CARD)
	if is_kill and hand.has(ANKHEG):
		out.append(ANKHEG)
	return out


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if is_answered():
		var yes := bool(answer())
		_answered = false
		_answer = null
		var guards := _guards(state, attacker, victim, kill)
		if yes and guards.has(_asking):
			var p: PlayerState = state.players[victim]
			p.deck.hand.erase(_asking)
			p.deck.discard_pile.append(_asking)
			if _asking == CARD:
				resolver.log_event("shield_guardian", {"player_id": victim, "attacker": attacker, "what": what})
				resolver.push(SequenceEffect.new([DeployTroop.new(4), DrawCards.new(1)]), victim)
			else:
				resolver.log_event("ankheg_block", {"player_id": victim, "attacker": attacker, "what": what})
				var strike := SupplantTroop.new(1, false, true)
				strike.only_owner = attacker
				resolver.push(strike, victim)
			return
		var next := guards.find(_asking) + 1
		if _asking == CARD and next < guards.size():
			_ask(guards[next], resolver)
			return
		resolver.push(hit, attacker)
		return
	attacker = player_id
	var guards := _guards(state, attacker, victim, kill)
	if guards.is_empty():
		resolver.push(hit, attacker)
		return
	_ask(guards[0], resolver)


func _ask(card: String, resolver: EffectResolver) -> void:
	_asking = card
	var pd := PendingDecision.new()
	pd.player_id = victim
	if card == CARD:
		pd.prompt = "Discard Shield Guardian to stop %s? (deploy 4 troops, draw a card)" % (what if what != "" else "it")
	else:
		pd.prompt = "Discard Ankheg to stop %s? (supplant one of their troops)" % (what if what != "" else "it")
	pd.choice_type = "confirm"
	pd.legal_options = [true, false]
	pd.source_card = card
	pd.target_effect = self
	resolver.request_decision(pd)
