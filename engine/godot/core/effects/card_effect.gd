class_name CardEffect
extends RefCounted

## Базовый класс эффекта карты (этап 5).
##
## apply() — единственный метод, который переопределяют примитивы и обёртки.
## Либо эффект применяется полностью синхронно (меняет state и возвращается),
## либо вызывает resolver.request_decision(pd) с pd.target_effect = self и
## останавливается — тогда apply() будет вызван ЕЩЁ РАЗ (после resolver.resume),
## и на этот раз is_answered() уже вернёт true, а answer() — ответ игрока.
##
## ВАЖНО (double-push bug, см. progress.md): если apply() собирается вызвать
## request_decision(pd) с pd.target_effect = self, эффект НЕЛЬЗЯ до этого
## самостоятельно пушить в resolver — resolver сам восстановит его в стеке
## внутри resume(). Пушить в стек можно только ДОЧЕРНИЕ эффекты (например,
## выбранный вариант ChooseEffect) — не самого себя.

var _answered: bool = false
var _answer = null


func is_answered() -> bool:
	return _answered


func answer():
	return _answer


func set_answer(value) -> void:
	_answer = value
	_answered = true


## Переопределяется в наследниках. player_id — тот, чьей картой применяется
## эффект (может отличаться от "текущего игрока хода" — см. Elder Brain/
## Ulitharid, где карта разыгрывается "как будто из руки").
func apply(_state: GameState, _player_id: String, _resolver: EffectResolver) -> void:
	push_error("CardEffect.apply() не переопределён в %s" % get_script().resource_path)


## Переопределяется, когда вариант эффекта в этом состоянии гарантированно
## ничего не даст (например, "Return one of your spies" — если шпионов на
## доске нет вообще). ChooseEffect использует это, чтобы не предлагать такой
## вариант игроку кнопкой (рулбук не рассматривает выбор заведомо пустого
## варианта). true по умолчанию — большинство эффектов доступны всегда.
func is_available(_state: GameState, _player_id: String) -> bool:
	return true
