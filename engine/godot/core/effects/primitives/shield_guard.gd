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

const CARD := "49021"

var victim: String
var hit: CardEffect
var what: String
## resume() вызывает эффект от имени того, кто отвечал (жертвы), поэтому
## атакующего запоминаем при первом вызове.
var attacker: String = ""


func _init(victim_id: String, hit_effect: CardEffect, description: String = "") -> void:
	victim = victim_id
	hit = hit_effect
	what = description


## Защищён ли юнит владельца owner от действия игрока attacker.
static func can_react(state: GameState, attacker: String, owner: String) -> bool:
	if owner == "" or owner == attacker or owner == GameState.WHITE:
		return false
	if not state.players.has(owner):
		return false
	return (state.players[owner] as PlayerState).deck.hand.has(CARD)


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if is_answered():
		if bool(answer()) and can_react(state, attacker, victim):
			var p: PlayerState = state.players[victim]
			p.deck.hand.erase(CARD)
			p.deck.discard_pile.append(CARD)
			resolver.log_event("shield_guardian", {"player_id": victim, "attacker": attacker, "what": what})
			resolver.push(SequenceEffect.new([DeployTroop.new(4), DrawCards.new(1)]), victim)
			return
		resolver.push(hit, attacker)
		return
	attacker = player_id
	if not can_react(state, attacker, victim):
		resolver.push(hit, attacker)
		return
	var pd := PendingDecision.new()
	pd.player_id = victim
	pd.prompt = "Discard Shield Guardian to stop %s? (deploy 4 troops, draw a card)" % (what if what != "" else "it")
	pd.choice_type = "confirm"
	pd.legal_options = [true, false]
	pd.source_card = CARD
	pd.target_effect = self
	resolver.request_decision(pd)
