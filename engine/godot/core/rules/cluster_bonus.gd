class_name ClusterBonus
extends RefCounted

## Региональный бонус гекса A2 (дополнение Demonweb, лист v2.2).
##
## Текст на самом тайле A2 (сверен по PDF-арту, не по данным Lua-мода —
## владелец игры подтвердил 2026-09-12, что это настоящее правило, см.
## claude/progress.md):
##
##   TROOPS IN ALL 3        — 1 Influence / ход
##   CONTROL ALL 3          — 1 Influence, 1 Power, 1 VP / ход
##   TOTAL CONTROL OF ALL 3 — 2 Influence, 2 Power, 4 VP / ход
##
## "Все 3" — сайты Fogtown, Gallenghast, Darkflame (сами по себе они внутри
## гекса A2, у каждого печатное VP=4 и 3 троп-слота — это НЕ входит в данный
## бонус, а считается как обычно через SiteControl.map_score).
##
## Ярусы НЕ складываются между собой для control/total control: Lua-мод прямо
## говорит "+4 VP instead of the +1", т.е. тотальный контроль ПОЛНОСТЬЮ
## заменяет ярус простого контроля, а не добавляется к нему. По той же логике
## (арт даёт для каждого яруса абсолютную сумму, а не прирост) здесь взят один
## и тот же принцип и для нижнего яруса: игрок получает бонус ТОЛЬКО того
## яруса, до которого дотянулся, а не сумму всех пройденных.
##
## Но "troops in all 3" — это ДРУГОЕ по природе условие: оно не эксклюзивно.
## Контролировать все три сайта разом может только один игрок (или никто), а
## вот просто держать войско на каждом из трёх могут сразу несколько игроков
## одновременно (один сайт — войска нескольких цветов сразу, контроль решает
## большинство). Поэтому:
##   - ярус "troops in all 3" проверяется и начисляется НЕЗАВИСИМО каждому
##     игроку, у кого войска есть на всех трёх сайтах, даже если сайты
##     контролирует кто-то другой;
##   - ярусы control/total control проверяются для игрока, который
##     ЭКСКЛЮЗИВНО контролирует (или тотально контролирует) все три сайта
##     сразу — и заменяют для него ярус "troops in all 3" целиком (см. выше).
##
## Ресурсы (Power/Influence) начисляются в НАЧАЛЕ хода игрока (TurnEngine.
## start_turn), а не в конце: неизрасходованные Power/Influence сгорают в
## конце хода (рулбук стр. 7), так что начисление их на этом же шаге end_turn
## было бы бессмысленным — игрок никогда не успел бы их потратить. VP,
## наоборот, начисляется в конце хода вместе с обычным site-control VP
## (TurnEngine.end_turn) — с ними проблемы сгорания нет, это токены.

const SITE_NAMES: PackedStringArray = ["Fogtown", "Gallenghast", "Darkflame"]


class Reward:
	var power: int = 0
	var influence: int = 0
	var vp: int = 0


## Site id всех трёх сайтов бонуса на данной карте. Ищем по ИМЕНИ, а не по
## фиксированному id: гекс A2 не гарантированно попадает на стол в модульной
## сборке Demonweb (как и в самом Lua-моде — demonwebCheckA2Bonus тоже ищет
## по имени). Пусто, если гекса A2 нет в этой партии.
static func find_site_ids(graph: MapGraph) -> PackedStringArray:
	var found: PackedStringArray = []
	for site_id: String in graph.sites.keys():
		var site: Dictionary = graph.sites[site_id]
		if SITE_NAMES.has(String(site["name"])):
			found.append(site_id)
	if found.size() != SITE_NAMES.size():
		return PackedStringArray()
	return found


static func _player_has_troop_at(state: GameState, player_id: String, site_id: String) -> bool:
	for slot_id in state.graph.slots_of_site(site_id):
		if state.troops.get(slot_id, "") == player_id:
			return true
	return false


## Бонус, заработанный игроком player_id прямо сейчас (текущее состояние
## доски). Пустой Reward, если гекса A2 нет на столе либо ни один ярус не
## выполнен.
static func evaluate(state: GameState, player_id: String) -> Reward:
	var reward := Reward.new()
	var site_ids := find_site_ids(state.graph)
	if site_ids.is_empty():
		return reward

	var has_troops_everywhere := true
	for site_id: String in site_ids:
		if not _player_has_troop_at(state, player_id, site_id):
			has_troops_everywhere = false
			break

	var controls_all := true
	var totally_controls_all := true
	for site_id: String in site_ids:
		if state.control.controller_of(site_id, state.troops) != player_id:
			controls_all = false
			totally_controls_all = false
			break
		if not state.control.has_total_control(player_id, site_id, state.troops, state.spies):
			totally_controls_all = false

	if totally_controls_all:
		reward.influence = 2
		reward.power = 2
		reward.vp = 4
	elif controls_all:
		reward.influence = 1
		reward.power = 1
		reward.vp = 1
	elif has_troops_everywhere:
		reward.influence = 1
	return reward
