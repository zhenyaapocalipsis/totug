class_name StateSerializer
extends RefCounted

## JSON round-trip персонального среза состояния — для реконнекта (этап 6).
##
## Сам стек эффектов (EffectResolver) живёт только в памяти сервера и не
## сериализуется: при реконнекте клиент получает свежий StateView (включая
## pending_decision, если резолвер сейчас чего-то ждёт) и продолжает работу
## с того же места — ему не нужно восстанавливать промежуточные состояния
## GDScript-объектов, только текущий публичный/персональный срез.


## Персональный снимок как Dictionary (то же самое, что StateView.for_player,
## плюс pending, если сервер его передал).
static func snapshot_for(state: GameState, viewer_id: String, pending: PendingDecision = null) -> Dictionary:
	if pending != null:
		return StateView.for_player_with_pending(state, viewer_id, pending)
	return StateView.for_player(state, viewer_id)


## Тот же снимок, сериализованный в JSON-строку (то, что реально уходит по
## сети / сохраняется для реконнекта).
static func to_json(state: GameState, viewer_id: String, pending: PendingDecision = null) -> String:
	return JSON.stringify(snapshot_for(state, viewer_id, pending))


## Разбор JSON-строки обратно в Dictionary. Возвращает {} при некорректном
## JSON вместо падения — вызывающий код (клиент) должен сам решить, что
## делать с пустым/повреждённым снимком (например, запросить снимок заново).
## Использует JSON.new().parse() вместо JSON.parse_string(), чтобы битый
## JSON не печатал ошибку движка в лог — ошибка тут ожидаемый, обработанный
## случай (реконнект с повреждённым/чужим снимком), а не баг.
static func from_json(json_text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(json_text) != OK:
		return {}
	var parsed = json.get_data()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
