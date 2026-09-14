class_name Presence
extends RefCounted

## Правило "Присутствия" (Presence) из рулбука, стр. 10.
##
##   Ты имеешь Присутствие:
##     • на любом сайте, где у тебя есть шпион, войско,
##       или войско в слоте, смежном с этим сайтом;
##     • в любом троп-слоте на маршруте, если этот слот смежен с сайтом
##       или слотом, где у тебя есть войско.
##
## Почти каждое действие на карте (deploy, assassinate, supplant, move, return)
## упирается в эту проверку, поэтому она вынесена отдельно и покрыта тестами.
##
## Занятость слотов и шпионов приходит из GameState через лёгкий интерфейс:
##   troops: slot_id -> owner_id  (owner_id "" = пусто, "white" = белое войско)
##   spies:  site_id -> Array[owner_id]

const WHITE := "white"

var _graph: MapGraph


func _init(graph: MapGraph) -> void:
	_graph = graph


func has_presence_at_site(player: String, site_id: String, troops: Dictionary, spies: Dictionary) -> bool:
	if not _graph.sites.has(site_id):
		return false

	# шпион на сайте
	var site_spies: Array = spies.get(site_id, [])
	if site_spies.has(player):
		return true

	# собственное войско в одном из слотов сайта
	for slot_id in _graph.slots_of_site(site_id):
		if troops.get(slot_id, "") == player:
			return true

	# войско в слоте, смежном с сайтом
	for slot_id in _graph.slots_adjacent_to_site(site_id):
		if troops.get(slot_id, "") == player:
			return true

	# войско в локации, соединённой с этой НАПРЯМУЮ (туннель без троп-слотов).
	# Между такими локациями нет промежуточного места под войска, поэтому войско
	# в соседней локации стоит «в слоте, смежном с этим сайтом».
	for neighbour_site in _graph.adjacent_sites(site_id):
		for slot_id in _graph.slots_of_site(neighbour_site):
			if troops.get(slot_id, "") == player:
				return true

	return false


func has_presence_at_slot(player: String, slot_id: String, troops: Dictionary, spies: Dictionary) -> bool:
	if not _graph.slots.has(slot_id):
		return false

	# слот внутри сайта — Присутствие определяется самим сайтом
	var site_id := _graph.site_of_slot(slot_id)
	if site_id != "":
		return has_presence_at_site(player, site_id, troops, spies)

	# маршрутный слот: смежен с сайтом, где есть своё войско...
	for adjacent_site in _graph.sites_adjacent_to_slot(slot_id):
		for site_slot in _graph.slots_of_site(adjacent_site):
			if troops.get(site_slot, "") == player:
				return true

	# ...или со слотом, где есть своё войско
	for neighbour in _graph.adjacent_slots(slot_id):
		if troops.get(neighbour, "") == player:
			return true

	return false


## Все слоты, куда игрок может развернуть войско (deploy): пустые и с Присутствием.
## Исключение из рулбука: если у игрока нет войск на карте вообще,
## разворачиваться можно в любой пустой слот.
func deployable_slots(player: String, troops: Dictionary, spies: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	var has_any_troop := false
	for slot_id: String in _graph.slots.keys():
		if troops.get(slot_id, "") == player:
			has_any_troop = true
			break

	for slot_id: String in _graph.slots.keys():
		if troops.get(slot_id, "") != "":
			continue
		if not has_any_troop or has_presence_at_slot(player, slot_id, troops, spies):
			result.append(slot_id)
	return result


## Все войска, которые игрок может убить (assassinate): вражеские (чужие ИЛИ белые),
## в слотах, где у игрока есть Присутствие.
func assassinatable_slots(player: String, troops: Dictionary, spies: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	for slot_id: String in _graph.slots.keys():
		var owner: String = troops.get(slot_id, "")
		if owner == "" or owner == player:
			continue
		if has_presence_at_slot(player, slot_id, troops, spies):
			result.append(slot_id)
	return result


## Все сайты, где у игрока есть Присутствие.
func sites_with_presence(player: String, troops: Dictionary, spies: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	for site_id: String in _graph.sites.keys():
		if has_presence_at_site(player, site_id, troops, spies):
			result.append(site_id)
	return result
