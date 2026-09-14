class_name SiteControl
extends RefCounted

## Контроль сайтов и итоговый подсчёт (рулбук, стр. 11 и 14).
##
##   Контроль:        у тебя больше войск на сайте, чем у любого другого цвета.
##                    При равенстве контроль теряется и маркер возвращается на карту.
##   Тотальный:       ВСЕ троп-слоты сайта заняты только твоими войсками
##                    И на сайте нет вражеских шпионов.
##
## Белые войска считаются отдельным "цветом" — они мешают контролю так же,
## как войска других игроков ("Enemy. Cards and rules that refer to enemy troops
## include both white troops and other players' troops").

const WHITE := "white"

var _graph: MapGraph


func _init(graph: MapGraph) -> void:
	_graph = graph


## Кто контролирует сайт: id игрока, либо "" если никто (пусто или ничья).
func controller_of(site_id: String, troops: Dictionary) -> String:
	var counts: Dictionary = {}
	for slot_id in _graph.slots_of_site(site_id):
		var owner: String = troops.get(slot_id, "")
		if owner == "":
			continue
		counts[owner] = int(counts.get(owner, 0)) + 1

	if counts.is_empty():
		return ""

	var best := ""
	var best_count := 0
	var tied := false
	for owner: String in counts.keys():
		var c: int = counts[owner]
		if c > best_count:
			best = owner
			best_count = c
			tied = false
		elif c == best_count:
			tied = true

	if tied:
		return ""
	# белые войска могут "лидировать" по числу, но белые никого не контролируют
	if best == WHITE:
		return ""
	return best


func has_total_control(player: String, site_id: String, troops: Dictionary, spies: Dictionary) -> bool:
	var site_slots := _graph.slots_of_site(site_id)
	if site_slots.is_empty():
		return false
	for slot_id in site_slots:
		if troops.get(slot_id, "") != player:
			return false
	for spy_owner: String in spies.get(site_id, []):
		if spy_owner != player:
			return false
	return true


## Итоговые VP за карту (без учёта колоды, внутреннего круга, трофеев и токенов):
##   • VP сайта за каждый контролируемый сайт
##   • +2 VP за каждый сайт под тотальным контролем
func map_score(player: String, troops: Dictionary, spies: Dictionary) -> int:
	var total := 0
	for site_id: String in _graph.sites.keys():
		if controller_of(site_id, troops) != player:
			continue
		total += int(_graph.sites[site_id]["vp"])
		if has_total_control(player, site_id, troops, spies):
			total += 2
	return total
