class_name Deck
extends RefCounted

## Личная колода игрока: колода добора, рука, сброс, разыгранные в этот ход
## карты и Внутренний круг (рулбук, стр. 8-9, 12-14).
##
## Карты — это просто id (String). Данные карты (стоимость, deck-VP,
## inner-circle-VP, эффект) сюда не входят: этап 2 их не знает и не считает
## (см. claude/stage2-start-here.md — "Карты в этап 2 не входят"; тексты и
## значения 177 уникальных карт появятся на этапе 4). Всё, что здесь есть,
## работает с ЛЮБЫМ набором id, который ему передали, включая синтетические
## тестовые id.

var draw_pile: Array[String] = []
var hand: Array[String] = []
var discard_pile: Array[String] = []
var played_pile: Array[String] = []
var inner_circle: Array[String] = []


func _init(starting_cards: Array[String] = []) -> void:
	draw_pile = starting_cards.duplicate()


## Тасует произвольный Array детерминированным RNG (Fisher-Yates). Общий
## помощник — им пользуется и Market при сборке колоды маркета.
static func shuffle_array(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func shuffle_draw_pile(rng: RandomNumberGenerator) -> void:
	shuffle_array(draw_pile, rng)


## Добор одной карты. Если колода добора пуста, сначала перетасовывает в неё
## сброс (рулбук, стр. 12). Возвращает false, если добирать было совсем
## нечего (колода и сброс оба пусты).
func draw_one(rng: RandomNumberGenerator) -> bool:
	if draw_pile.is_empty():
		if discard_pile.is_empty():
			return false
		draw_pile = discard_pile.duplicate()
		discard_pile.clear()
		shuffle_draw_pile(rng)
	var card: String = draw_pile.pop_back()
	hand.append(card)
	return true


## Добор до размера руки hand_size. Возвращает число реально добранных карт
## (меньше запрошенного, если карт всего не хватает).
func draw_up_to(hand_size: int, rng: RandomNumberGenerator) -> int:
	var drawn := 0
	while hand.size() < hand_size:
		if not draw_one(rng):
			break
		drawn += 1
	return drawn


## Разыграть карту из руки. Этап 2 не применяет эффект карты (см. заголовок
## файла) — просто переносит её в played_pile, чтобы конец хода мог её
## сбросить. Возвращает false, если карты нет в руке.
func play_from_hand(card_id: String) -> bool:
	var idx := hand.find(card_id)
	if idx == -1:
		return false
	hand.remove_at(idx)
	played_pile.append(card_id)
	return true


## Promote: переносит карту из played_pile (разыгранную В ЭТОТ ход, рулбук
## стр. 13) во Внутренний круг. Промутированные карты выходят из колоды
## насовсем — в перетасовку сброса больше не попадают.
func promote(card_id: String) -> bool:
	var idx := played_pile.find(card_id)
	if idx == -1:
		return false
	played_pile.remove_at(idx)
	inner_circle.append(card_id)
	return true


## Конец хода (рулбук стр. 8, шаг 3): разыгранные карты и всё, что осталось
## в руке, идут в сброс.
func end_of_turn_discard() -> void:
	discard_pile.append_array(played_pile)
	discard_pile.append_array(hand)
	played_pile.clear()
	hand.clear()


## Карты, которые считаются по deck-VP в финальном подсчёте: колода + рука +
## сброс + played_pile (рулбук стр. 14: "deck, hand, and discard pile" — на
## случай, если подсчёт идёт до финального сброса хода, played_pile тоже
## учтена). Внутренний круг считается отдельно (inner_circle).
func cards_outside_inner_circle() -> Array[String]:
	var result: Array[String] = []
	result.append_array(draw_pile)
	result.append_array(hand)
	result.append_array(discard_pile)
	result.append_array(played_pile)
	return result
