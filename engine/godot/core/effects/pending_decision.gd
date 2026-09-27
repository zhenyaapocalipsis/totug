class_name PendingDecision
extends RefCounted

## Ожидающее решение игрока внутри применения эффекта карты (этап 5).
##
## Когда какой-то CardEffect не может продолжить синтетически (нужен выбор
## игрока — вариант choose one, цель assassinate/deploy/move/place spy/devour/
## promote, подтверждение "you may..."), он строит PendingDecision и передаёт
## его в EffectResolver.request_decision(). EffectResolver сохраняет остаток
## своего стека внутрь pd.stack и останавливается. Клиент (или тест) должен
## прочитать prompt/choice_type/legal_options, узнать у игрока ответ и вызвать
## EffectResolver.resume(state, answer).
##
## Паттерн target_effect (важно, см. claude/progress.md, этап 5):
## resolver.request_decision(pd) НЕЛЬЗЯ вызывать после того, как pd.target_effect
## уже запушен в стек резолвера — иначе эффект применится дважды при resume
## (double-push bug). pd.target_effect получает ответ через set_answer() и
## пушится в стек ЗАНОВО только внутри resume().

var player_id: String = ""
var prompt: String = ""
var choice_type: String = ""      # "choose_option" | "confirm" | "target_slot" |
                                   # "target_site" | "target_card" | "target_player" |
                                   # "target_card_multi" | "target_slot_multi"
var legal_options: Array = []

## Человеко-читаемые подписи вариантов, параллельно legal_options (пусто, если
## подписи не нужны — id слота или название карты интерфейс подпишет сам).
##
## Зачем отдельное поле: в legal_options лежит РОВНО ТО, что клиент должен
## прислать обратно в ответе. Раньше ChooseEffect клал туда подписи ("+2
## Influence"), а ждал обратно номер варианта — клиент, честно вернувший
## присланное значение, всегда попадал бы в первый вариант, и молча, без
## ошибки. Подписи и значения ответа с тех пор разведены.
var option_labels: Array[String] = []
## Карта, задавшая вопрос "Choose one" (см. ChooseEffect.source_card).
var source_card: String = ""
var stack: Array = []             # снимок стека резолвера на момент запроса
var target_effect: CardEffect = null
var data: Dictionary = {}         # произвольный контекст, специфичный для эффекта

## Метка вида решения для интерфейса: пусто у обычных вопросов карт,
## "starting_site" — стартовая расстановка. Экран показывает её не плашкой над
## доской, а на месте зоны сыгранных карт (решение владельца, 2026-09-20).
## "hand" — карту выбирают прямо в руке внизу экрана, без окна и затемнения,
## чтобы при выборе были видны доска и рынок (решение владельца, 2026-09-27).
var tag: String = ""
