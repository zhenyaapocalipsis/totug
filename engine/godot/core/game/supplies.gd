class_name Supplies
extends RefCounted

## Общие стопки карт рядом с маркетом (рулбук, стр. 4 шаги 3-4 и стр. 13).
##
## Это НЕ маркет: карты лежат открытыми стопками в своих отмеченных местах на
## поле, не занимают слотов дисплея и не пополняются из колоды маркета.
##   • House Guard (15 шт, стоимость 3) и Priestess of Lolth (15 шт, стоимость 2)
##     — их можно рекрутить за Influence в любой момент шага 1 своего хода
##     наравне с картой из маркета ("...to recruit a House Guard, a Priestess
##     of Lolth, or a card from the market").
##   • Insane Outcast (30 шт) — выкладывается ТОЛЬКО если в игре полуколода
##     Demons (шаг 4 сетапа); раздаётся эффектами карт, не покупается.
##
## "If the supply of House Guards, Priestesses of Lolth, or Insane Outcasts
## runs out, the game continues, but you'll no longer be able to recruit one of
## those cards" — то есть исчерпание стопки НЕ заканчивает партию (в отличие от
## пустой колоды маркета) и не является ошибкой, просто источник иссяк.

const HOUSE_GUARD := "48340"
const PRIESTESS_OF_LOLTH := "48343"
const INSANE_OUTCAST := "48341"

## Карты, которые игрок может купить за Influence из общей стопки.
const PURCHASABLE := [HOUSE_GUARD, PRIESTESS_OF_LOLTH]

var counts: Dictionary = {}  # card_id -> сколько осталось


func _init(initial: Dictionary = {}) -> void:
	for card_id: String in initial.keys():
		counts[card_id] = int(initial[card_id])


## Стандартный набор по рулбуку. with_insane_outcasts — шаг 4 сетапа: стопка
## Insane Outcast выкладывается, только если играем с полуколодой Demons.
static func standard(with_insane_outcasts: bool = true) -> Supplies:
	var s := Supplies.new({
		HOUSE_GUARD: 15,
		PRIESTESS_OF_LOLTH: 15,
	})
	if with_insane_outcasts:
		s.counts[INSANE_OUTCAST] = 30
	return s


func remaining(card_id: String) -> int:
	return int(counts.get(card_id, 0))


func is_available(card_id: String) -> bool:
	return remaining(card_id) > 0


## Снять одну карту со стопки. false, если стопка пуста или её нет в игре.
func take(card_id: String) -> bool:
	if remaining(card_id) <= 0:
		return false
	counts[card_id] = counts[card_id] - 1
	return true


## Что сейчас можно купить за Influence (для UI и валидации намерений).
func purchasable_available() -> Array[String]:
	var result: Array[String] = []
	for card_id: String in PURCHASABLE:
		if is_available(card_id):
			result.append(card_id)
	return result
