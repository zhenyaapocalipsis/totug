class_name VPBank
extends RefCounted

## Общий запас VP-токенов (рулбук, стр. 2 и 8): 40 номиналом 1 и 16 номиналом 5.
##
## "Whenever you're told to gain VP, take unclaimed VP markers equaling that
## amount" — то есть токены физически кончаются. grant() отдаёт максимум,
## какой можно составить из того, что осталось: сначала пятёрками, остаток —
## единицами. Если единиц не хватает на остаток, игрок получает МЕНЬШЕ VP,
## чем должен был бы — правило не описывает размен пятёрки, поэтому этот
## случай (практически недостижимый за партию: суммарно в банке 120 VP)
## сознательно не пытается размениваться сложнее.

var ones: int
var fives: int


func _init(initial_ones: int = 40, initial_fives: int = 16) -> void:
	ones = initial_ones
	fives = initial_fives


## Возвращает реально выданное количество VP (может быть меньше amount).
func grant(amount: int) -> int:
	if amount <= 0:
		return 0
	var use_fives: int = mini(amount / 5, fives)
	var remaining: int = amount - use_fives * 5
	var use_ones: int = mini(remaining, ones)
	fives -= use_fives
	ones -= use_ones
	return use_fives * 5 + use_ones


func total_remaining() -> int:
	return ones + fives * 5
