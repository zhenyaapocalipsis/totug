class_name MapGraph
extends RefCounted

## Логический граф игровой карты.
##
## Узлы двух видов:
##   - SITE      — сайт (локация с именем и VP)
##   - SLOT      — троп-слот; либо принадлежит сайту, либо лежит на маршруте
##
## Рёбра — смежность между троп-слотами. Принадлежность слота сайту хранится отдельно.
##
## Граф не знает ничего о фишках, игроках и отрисовке — только топология.
## Кто где стоит, живёт в GameState; запросы Presence — в core/rules/presence.gd.

enum NodeKind { SITE, SLOT }

## site_id -> { name, vp, hex, slots: PackedStringArray }
var sites: Dictionary = {}

## slot_id -> { site: String ("" если маршрутный), hex: String, pos: Vector2 }
var slots: Dictionary = {}

## slot_id -> PackedStringArray смежных slot_id
var _adjacency: Dictionary = {}

## site_id -> PackedStringArray слотов, СМЕЖНЫХ с сайтом, но не входящих в него
var _site_adjacent_slots: Dictionary = {}

## site_id -> PackedStringArray сайтов, соединённых с ним НАПРЯМУЮ.
##
## На части тайлов две локации соединены туннелем, на котором не нарисовано ни
## одного троп-слота (C3: Red Forest - Xal Veldrin - Iron Wastes; A3: спицы Web
## и Great Web через центральный контур). Владелец игры подтвердил, что такие
## локации считаются соседними. Для Присутствия это значит: войско в одной даёт
## Присутствие в другой.
var _site_adjacency: Dictionary = {}


func add_site(site_id: String, site_name: String, vp: int, hex: String) -> void:
	sites[site_id] = {
		"name": site_name,
		"vp": vp,
		"hex": hex,
		"slots": PackedStringArray(),
	}


func add_slot(slot_id: String, hex: String, pos: Vector2, site_id: String = "") -> void:
	slots[slot_id] = {"site": site_id, "hex": hex, "pos": pos}
	_adjacency[slot_id] = PackedStringArray()
	if site_id != "":
		assert(sites.has(site_id), "слот ссылается на несуществующий сайт: " + site_id)
		var arr: PackedStringArray = sites[site_id]["slots"]
		arr.append(slot_id)
		sites[site_id]["slots"] = arr


func connect_slots(a: String, b: String) -> void:
	if a == b:
		return
	assert(slots.has(a) and slots.has(b), "связь между несуществующими слотами: %s - %s" % [a, b])
	var adj_a: PackedStringArray = _adjacency[a]
	if adj_a.has(b):
		return
	adj_a.append(b)
	_adjacency[a] = adj_a
	var adj_b: PackedStringArray = _adjacency[b]
	adj_b.append(a)
	_adjacency[b] = adj_b


## Прямая связь двух локаций: туннель между ними без троп-слотов.
func connect_sites(a: String, b: String) -> void:
	if a == b:
		return
	assert(sites.has(a) and sites.has(b), "связь несуществующих сайтов: %s - %s" % [a, b])
	for pair in [[a, b], [b, a]]:
		var list: PackedStringArray = _site_adjacency.get(pair[0], PackedStringArray())
		if not list.has(pair[1]):
			list.append(pair[1])
		_site_adjacency[pair[0]] = list


func adjacent_sites(site_id: String) -> PackedStringArray:
	return _site_adjacency.get(site_id, PackedStringArray())


func adjacent_slots(slot_id: String) -> PackedStringArray:
	return _adjacency.get(slot_id, PackedStringArray())


func site_of_slot(slot_id: String) -> String:
	if not slots.has(slot_id):
		return ""
	return slots[slot_id]["site"]


func is_route_slot(slot_id: String) -> bool:
	return site_of_slot(slot_id) == ""


func slots_of_site(site_id: String) -> PackedStringArray:
	if not sites.has(site_id):
		return PackedStringArray()
	return sites[site_id]["slots"]


## Слоты, смежные с сайтом извне (не входящие в сам сайт). Кэшируется после finalize().
func slots_adjacent_to_site(site_id: String) -> PackedStringArray:
	return _site_adjacent_slots.get(site_id, PackedStringArray())


## Сайты, с которыми смежен данный слот: его собственный сайт и любой сайт,
## один из слотов которого смежен с этим слотом.
func sites_adjacent_to_slot(slot_id: String) -> PackedStringArray:
	var result := PackedStringArray()
	var own := site_of_slot(slot_id)
	if own != "":
		result.append(own)
	for neighbour in adjacent_slots(slot_id):
		var s := site_of_slot(neighbour)
		if s != "" and not result.has(s):
			result.append(s)
	return result


## Убирает тупики: кольца туннелей, которые ведут не дальше одного соседа
## (локация считается одним соседом, сколько бы её мест ни касалось кольца).
## Такие кольца стоят на туннелях, упирающихся в край доски. Решение владельца
## (2026-09-22): тупиков в игре нет — они занимали треть колец и место на
## экране. Удаляется цепочкой: без последнего кольца предпоследнее тоже
## становится тупиком. Места в локациях не трогаются никогда.
## Возвращает id удалённых слотов.
func prune_dead_ends() -> PackedStringArray:
	var removed := PackedStringArray()
	var changed := true
	while changed:
		changed = false
		for slot_id: String in slots.keys():
			if not is_route_slot(slot_id):
				continue
			var neighbours := {}
			for other in adjacent_slots(slot_id):
				var site := site_of_slot(other)
				neighbours[site if site != "" else other] = true
			if neighbours.size() <= 1:
				_remove_slot(slot_id)
				removed.append(slot_id)
				changed = true
	return removed


func _remove_slot(slot_id: String) -> void:
	for other in adjacent_slots(slot_id):
		var list: PackedStringArray = _adjacency[other]
		list.remove_at(list.find(slot_id))
		_adjacency[other] = list
	_adjacency.erase(slot_id)
	slots.erase(slot_id)


## Должен вызываться после того, как все узлы и рёбра добавлены.
func finalize() -> void:
	_site_adjacent_slots.clear()
	for site_id: String in sites.keys():
		var outside := PackedStringArray()
		var own_slots: PackedStringArray = sites[site_id]["slots"]
		for slot_id in own_slots:
			for neighbour in adjacent_slots(slot_id):
				if site_of_slot(neighbour) == site_id:
					continue
				if not outside.has(neighbour):
					outside.append(neighbour)
		_site_adjacent_slots[site_id] = outside


func slot_count() -> int:
	return slots.size()


func site_count() -> int:
	return sites.size()


## Все слоты, достижимые из данного: по смежности слотов И через прямые связи
## локаций. Прямую связь локаций надо учитывать — между ними нет промежуточного
## места под войска, но пройти из одной в другую можно.
func reachable_slots(slot_id: String) -> PackedStringArray:
	var seen := {slot_id: true}
	var queue: Array[String] = [slot_id]
	while not queue.is_empty():
		var current: String = queue.pop_back()
		for neighbour in adjacent_slots(current):
			if not seen.has(neighbour):
				seen[neighbour] = true
				queue.append(neighbour)
		var site := site_of_slot(current)
		if site == "":
			continue
		for other_site in adjacent_sites(site):
			for other_slot in slots_of_site(other_site):
				if not seen.has(other_slot):
					seen[other_slot] = true
					queue.append(other_slot)
	var result := PackedStringArray()
	for key: String in seen.keys():
		result.append(key)
	return result


## Диагностика: слоты, из которых никуда не попасть.
##
## Это НЕ всегда дефект: на X1 и X2 есть локации, которых не касается ни один
## туннель (The Barrens, Indifference). По правилам шпиона можно поставить на
## любую локацию без Присутствия, а шпион уже даёт Присутствие — через него
## такие локации и разыгрываются.
func isolated_slots() -> PackedStringArray:
	var result := PackedStringArray()
	for slot_id: String in slots.keys():
		if reachable_slots(slot_id).size() <= slots_of_site(site_of_slot(slot_id)).size() \
				and adjacent_slots(slot_id).is_empty() \
				and adjacent_sites(site_of_slot(slot_id)).is_empty():
			result.append(slot_id)
	return result


## Количество связных компонент доски, с учётом прямых связей локаций.
##
## Единица здесь НЕ обязательна: локации, к которым не подходит ни один туннель
## (The Barrens на X1, Indifference на X2), образуют собственные компоненты по
## замыслу — попасть туда можно только шпионом. Проверять надо не «ровно одна
## компонента», а «все компоненты кроме главной — это заведомо изолированные
## локации».
func connected_component_count() -> int:
	var seen := {}
	var components := 0
	for start: String in slots.keys():
		if seen.has(start):
			continue
		components += 1
		for slot_id in reachable_slots(start):
			seen[slot_id] = true
	return components
