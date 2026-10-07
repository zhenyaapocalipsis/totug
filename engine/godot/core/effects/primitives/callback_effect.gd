class_name CallbackEffect
extends CardEffect

## Шаг эффекта, заданный функцией func(state, player_id, resolver). Нужен,
## чтобы примитив мог отложить "собственно действие" и "продолжение" за
## вопросом другого игрока (реакция ShieldGuard) и продолжить с того же места.

var fn: Callable


func _init(f: Callable) -> void:
	fn = f


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	fn.call(state, player_id, resolver)
