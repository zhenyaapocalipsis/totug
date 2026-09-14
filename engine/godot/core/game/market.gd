class_name Market
extends RefCounted

## Маркет: 6 карт лицом вверх + колода маркета (рулбук, стр. 4 и 12).
##
## Сборка (рулбук стр. 4, шаг 2): взять 2 из 4 полуколод по 40 карт и
## перетасовать их ВМЕСТЕ в одну колоду маркета на 80 карт — не сложить
## стопками, а именно смешать. Затем открыть верхние 6 (шаг 5).
##
## Как и Deck, работает с любыми id карт — реальный набор из 177 уникальных
## карт появится на этапе 4.

const DISPLAY_SIZE := 6

var deck: Array[String] = []
var display: Array[String] = []  # ровно DISPLAY_SIZE слотов; "" — слот пуст (колода маркета исчерпана)


static func build(half_a: Array[String], half_b: Array[String], rng: RandomNumberGenerator) -> Market:
	var market := Market.new()
	var combined: Array[String] = []
	combined.append_array(half_a)
	combined.append_array(half_b)
	Deck.shuffle_array(combined, rng)
	market.deck = combined
	market._fill_display()
	return market


func _fill_display() -> void:
	while display.size() < DISPLAY_SIZE:
		display.append(_draw_top())


func _draw_top() -> String:
	if deck.is_empty():
		return ""
	return deck.pop_back()


## Recruit по индексу дисплея (рулбук стр. 13): убрать карту с доски и вернуть
## её id (вызывающий код кладёт её в сброс игрока), заполнить освободившийся
## слот верхней картой колоды маркета — либо "", если колода уже пуста.
## Возвращает "" при неверном индексе или уже пустом слоте.
func recruit_at(index: int) -> String:
	if index < 0 or index >= display.size():
		return ""
	var card_id: String = display[index]
	if card_id == "":
		return ""
	display[index] = _draw_top()
	return card_id


func is_deck_empty() -> bool:
	return deck.is_empty()


## Этап 6: сколько карт осталось в закрытой колоде маркета (открытая
## информация — на столе виден размер стопки, хоть и не содержимое).
func deck_size() -> int:
	return deck.size()


## Этап 6: список реально доступных для найма карт дисплея (без пустых
## слотов) — то, что StateView отдаёт клиентам как публичную информацию.
func available_cards() -> Array[String]:
	var result: Array[String] = []
	for card_id: String in display:
		if card_id != "":
			result.append(card_id)
	return result


## Этап 6: стоимость карты в слоте дисплея (обёртка над CardLibrary, чтобы
## сетевой слой не тянул зависимость на core/cards напрямую из intent'ов).
## -1 при неверном индексе или пустом слоте.
func card_cost(index: int) -> int:
	if index < 0 or index >= display.size():
		return -1
	var card_id: String = display[index]
	if card_id == "":
		return -1
	return CardLibrary.card_cost(card_id)


## Этап 6: синоним recruit_at для сетевого слоя (Actions.recruit уже
## использует recruit_at напрямую — remove_card существует для симметрии
## API, которым пользуется GameServer/тесты этапа 6).
func remove_card(index: int) -> String:
	return recruit_at(index)
