class_name ChooseEffect
extends CardEffect

## "Choose one:" — игрок выбирает один из N вариантов, выбранный вариант
## выполняется. labels — то, что видит игрок (для UI/тестов), options — сами
## эффекты в том же порядке.

var options: Array[CardEffect] = []
var labels: Array[String] = []
var prompt: String = "Choose one:"
## Карта, которой принадлежит выбор (её арт рисуется на вариантах); пусто —
## выбор создан не при сборке карты, интерфейс покажет список строк.
var source_card: String = CardLibrary.building_card


func _init(opts: Array[CardEffect], lbls: Array[String], p: String = "Choose one:") -> void:
	options = opts
	labels = lbls
	prompt = p


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if is_answered():
		var idx: int = int(answer())
		resolver.push(options[idx], player_id)
		return

	var pd := PendingDecision.new()
	pd.player_id = player_id
	pd.prompt = prompt
	pd.choice_type = "choose_option"
	# В legal_options — номера вариантов, потому что именно номер ждёт обратно
	# apply() выше; подписи идут отдельным полем (см. pending_decision.gd).
	# Вариант не предлагается, если сам эффект говорит, что он сейчас ничего
	# не даст (см. CardEffect.is_available — например, "Return one of your
	# spies", когда шпионов на доске нет).
	var indices: Array = []
	var shown_labels: Array[String] = []
	for i in range(options.size()):
		if not options[i].is_available(state, player_id):
			continue
		indices.append(i)
		shown_labels.append(labels[i] if i < labels.size() else "")
	pd.legal_options = indices
	pd.option_labels = shown_labels
	pd.source_card = source_card
	pd.target_effect = self
	resolver.request_decision(pd)
