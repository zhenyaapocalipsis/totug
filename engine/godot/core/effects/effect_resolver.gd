class_name EffectResolver
extends RefCounted

## Явный стек LIFO для применения эффектов карт (этап 5).
##
## Почему явный стек, а не рекурсия: розыгрыш карты может остановиться
## посреди эффекта, чтобы спросить игрока (choose one / цель / "you may").
## GameServer (этап 6) должен уметь сохранить это состояние между сетевыми
## сообщениями — явный стек сериализуется (как список кадров), обычный
## вызов стека GDScript — нет.
##
## Кадр стека — Dictionary {"effect": CardEffect, "player_id": String}.

var _stack: Array = []
var pending: PendingDecision = null
var events: Array[Dictionary] = []


func push(effect: CardEffect, player_id: String) -> void:
	_stack.append({"effect": effect, "player_id": player_id})


## Точка входа: положить эффект на стек и прогнать резолвер до конца или до
## первого запроса решения.
func apply(effect: CardEffect, player_id: String, state: GameState) -> void:
	push(effect, player_id)
	_run(state)


func _run(state: GameState) -> void:
	while not _stack.is_empty() and pending == null:
		var frame: Dictionary = _stack.pop_back()
		var effect: CardEffect = frame["effect"]
		var player_id: String = frame["player_id"]
		effect.apply(state, player_id, self)


## Вызывается изнутри CardEffect.apply(), когда нужен ответ игрока. Сохраняет
## остаток стека (то, что должно выполниться ПОСЛЕ ответа) внутрь pd.stack и
## останавливает резолвер. pd.target_effect должен быть эффектом, который сам
## же вызвал request_decision (см. предупреждение про double-push в
## card_effect.gd) — ЕГО САМОГО в стек класть не нужно, resume() сделает это.
func request_decision(pd: PendingDecision) -> void:
	pd.stack = _stack.duplicate()
	_stack.clear()
	pending = pd


## Игрок ответил на pending-решение. answer — сырое значение, специфичное для
## choice_type (int-индекс для choose_option, bool для confirm, String id
## слота/сайта/карты для target_*, Array[String] для *_multi).
func resume(state: GameState, answer) -> void:
	var pd: PendingDecision = pending
	pending = null
	_stack = pd.stack.duplicate()
	pd.target_effect.set_answer(answer)
	push(pd.target_effect, pd.player_id)
	_run(state)


func log_event(kind: String, data: Dictionary = {}) -> void:
	var evt: Dictionary = {"type": kind}
	evt.merge(data)
	events.append(evt)


func is_waiting() -> bool:
	return pending != null
