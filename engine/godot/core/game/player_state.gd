class_name PlayerState
extends RefCounted

## Состояние одного игрока.
##
## power/influence — пул ресурсов текущего хода, сгорает в конце хода
## (рулбук, стр. 7). troops_in_barracks/spies_in_barracks — то, что ещё не
## выставлено на доску (40 войск и 5 шпионов на игрока, компоненты стр. 2).
## trophy_hall_count — сколько войск игрок убил ассасинациями (рулбук стр. 14:
## считаются ЛЮБЫЕ войска в трофи-холле, не только вражеские). vp_tokens —
## физические VP-токены, выданные VPBank.
##
## pending_promotions — заготовка под этап 5: карты, разыгранные в этот ход,
## которые сказали "promote" в конце хода. Этап 2 в неё ничего не кладёт.

const STARTING_TROOPS := 40
const STARTING_SPIES := 5

var id: String
var power: int = 0
var influence: int = 0
var troops_in_barracks: int = STARTING_TROOPS
var spies_in_barracks: int = STARTING_SPIES
var deck: Deck
var trophy_hall_count: int = 0
var white_trophy_count: int = 0
## Цвета войск в трофейном зале: "white" или id игрока -> количество. Нужны
## картам, которые берут войска из зала и выставляют их СВОИМ цветом
## (Mummy Lord, Orcus, Lich — решение владельца игры 2026-09-15).
var trophies: Dictionary = {}
var vp_tokens: int = 0
var pending_promotions: Array[String] = []

## Этап 5: эффекты вида "At end of turn, ..." сыгранных в этот ход карт,
## сложены сюда AtEndOfTurn.apply() и прогоняются TurnEngine.end_turn() перед
## обычными шагами конца хода.
var pending_end_of_turn: Array[CardEffect] = []


func _init(player_id: String, starting_deck_cards: Array[String] = []) -> void:
	id = player_id
	deck = Deck.new(starting_deck_cards)


## Стартовая колода по рулбуку (стр. 4): 7 Noble + 3 Soldier. Конкретные id
## передаёт вызывающий код (этап 2 не знает реальных карт) — этот помощник
## просто повторяет id нужное число раз, детерминированно.
static func make_starting_deck(noble_id: String, soldier_id: String) -> Array[String]:
	var cards: Array[String] = []
	for i in range(7):
		cards.append(noble_id)
	for i in range(3):
		cards.append(soldier_id)
	return cards


## Убитое войско цвета color попадает в трофейный зал.
func add_trophy(color: String) -> void:
	trophies[color] = int(trophies.get(color, 0)) + 1
	trophy_hall_count += 1
	if color == "white":
		white_trophy_count += 1


## Забрать одно войско цвета color из зала. false — такого нет.
func take_trophy(color: String) -> bool:
	if int(trophies.get(color, 0)) <= 0:
		return false
	trophies[color] = int(trophies[color]) - 1
	if trophies[color] == 0:
		trophies.erase(color)
	trophy_hall_count = maxi(0, trophy_hall_count - 1)
	if color == "white":
		white_trophy_count = maxi(0, white_trophy_count - 1)
	return true


## "Player troops in your trophy hall" — без белых.
func player_trophy_count() -> int:
	return trophy_hall_count - white_trophy_count


func reset_resources_for_new_turn() -> void:
	# рулбук стр. 7: неистраченные Power/Influence сгорают в конце хода
	power = 0
	influence = 0
