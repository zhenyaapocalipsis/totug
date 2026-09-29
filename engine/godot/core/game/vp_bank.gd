class_name VPBank
extends RefCounted

## Общий запас VP-токенов (рулбук, стр. 2 и 8): 40 номиналом 1 и 16 номиналом 5.
##
## grant() ВСЕГДА выдаёт запрошенное. Раньше он отдавал «сколько можно
## составить из оставшихся токенов» и пятёрки не разменивал: к середине
## партии на четверых 40 единиц кончались, и любой доход меньше 5 VP
## (тотальный контроль маркера, Deploy при пустом бараке) молча давал 0 —
## жалоба владельца игры 2026-09-30. Теперь:
##   • сначала пятёрками, остаток единицами;
##   • единиц не хватает — пятёрка разменивается на пять единиц;
##   • банк пуст — VP всё равно выдаются (как если бы игроки считали на
##     бумаге), выданное сверх банка копится в extra.

var ones: int
var fives: int
## VP, выданные сверх физического запаса токенов.
var extra: int = 0


func _init(initial_ones: int = 40, initial_fives: int = 16) -> void:
	ones = initial_ones
	fives = initial_fives


## Возвращает выданное количество VP — всегда amount (0 для amount <= 0).
func grant(amount: int) -> int:
	if amount <= 0:
		return 0
	var use_fives: int = mini(amount / 5, fives)
	fives -= use_fives
	var remaining: int = amount - use_fives * 5
	while remaining > ones and fives > 0:
		fives -= 1
		ones += 5
	var use_ones: int = mini(remaining, ones)
	ones -= use_ones
	extra += remaining - use_ones
	return amount


func total_remaining() -> int:
	return ones + fives * 5
