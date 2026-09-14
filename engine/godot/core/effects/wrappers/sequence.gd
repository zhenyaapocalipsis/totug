class_name SequenceEffect
extends CardEffect

## Цепочка эффектов, выполняемых по порядку. Каждый может остановиться на
## решении — стек резолвера гарантирует, что оставшиеся эффекты цепочки
## выполнятся ПОСЛЕ ответа, в правильном порядке (кладём их в стек в обратном
## порядке одним синхронным проходом; сама SequenceEffect не переприменяется).

var effects: Array[CardEffect] = []


func _init(effs: Array[CardEffect] = []) -> void:
	effects = effs


func apply(_state: GameState, player_id: String, resolver: EffectResolver) -> void:
	for i in range(effects.size() - 1, -1, -1):
		resolver.push(effects[i], player_id)
