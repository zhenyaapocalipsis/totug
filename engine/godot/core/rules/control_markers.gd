class_name ControlMarkers
extends RefCounted

## Маркеры контроля на именованных локациях (гексы A1, A3, B1-B6).
##
## Правило подтверждено владельцем игры 2026-09-14 по физической игре:
##   • контроль локации с маркером       -> +1 Influence в ход;
##   • ТОТАЛЬНЫЙ контроль такой локации  -> те же +1 Influence и сверх того VP,
##     своё число у каждой локации (Great Web 3, Lolth Shrine 2, остальные 1).
##
## Influence НЕ складывается: тотальный контроль не даёт +2 Influence, он лучше
## обычного только за счёт VP. (Так же, как ярусы бонуса гекса A2 — см.
## claude/progress.md. Если владелец игры прочтёт иначе, менять здесь.)
##
## ВАЖНО про то, чего это правило ЗАМЕНИЛО. Раньше движок каждый ход начислял
## VP за контроль ЛЮБОЙ локации (SiteControl.map_score). Это было неверно:
## VP обычных локаций считаются ТОЛЬКО в финальном подсчёте (core/rules/
## scoring.gd, рулбук стр. 14). По ходу партии VP приносят лишь маркеры
## контроля и региональный бонус гекса A2.
##
## Сроки начисления — как у бонуса A2 и по той же причине: Influence выдаётся
## в НАЧАЛЕ хода (иначе игрок не успеет его потратить: неизрасходованные
## ресурсы сгорают в конце хода, рулбук стр. 7), а VP — в конце хода.

const DATA_PATH := "res://data/board/control_markers.json"

static var _markers: Array = []


class Reward:
	var influence: int = 0
	var vp: int = 0
	## Названия локаций с маркером, которые игрок контролирует (для интерфейса).
	var sites: Array[String] = []
	## Из них — под тотальным контролем.
	var total_control_sites: Array[String] = []
	## Те же локации тотального контроля, но id — ленте ходов, чтобы
	## подсвечивать их на доске.
	var total_control_ids: Array[String] = []


static func _load() -> Array:
	if not _markers.is_empty():
		return _markers
	var text := FileAccess.get_file_as_string(DATA_PATH)
	if text.is_empty():
		push_error("не читается " + DATA_PATH)
		return []
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("повреждён " + DATA_PATH)
		return []
	_markers = (parsed as Dictionary).get("markers", [])
	return _markers


## Есть ли на этой локации маркер контроля. site_id — id СОБРАННОЙ доски
## ("b1:B1_site0"), поэтому сверяем по гексу и названию локации.
static func marker_for(state: GameState, site_id: String) -> Dictionary:
	if not state.graph.sites.has(site_id):
		return {}
	var site: Dictionary = state.graph.sites[site_id]
	var hex_id := String(site.get("hex", ""))
	var site_name := String(site.get("name", ""))
	for marker in _load():
		var m: Dictionary = marker
		if String(m["hex"]) == hex_id and String(m["site_name"]) == site_name:
			return m
	return {}


static func evaluate(state: GameState, player_id: String) -> Reward:
	var reward := Reward.new()
	for site_id: String in state.graph.sites.keys():
		var marker := marker_for(state, site_id)
		if marker.is_empty():
			continue
		if state.control.controller_of(site_id, state.troops) != player_id:
			continue
		var site_name := String(state.graph.sites[site_id]["name"])
		reward.influence += int(marker.get("control_influence", 0))
		reward.sites.append(site_name)
		if state.control.has_total_control(player_id, site_id, state.troops, state.spies):
			reward.vp += int(marker.get("total_control_vp", 0))
			reward.total_control_sites.append(site_name)
			reward.total_control_ids.append(site_id)
	return reward


## Есть ли маркер у локации site_name на плитке tile ("B1") — для раскладки
## схемы, которая видит граф, но не состояние партии.
static func is_marked(tile: String, site_name: String) -> bool:
	for marker in _load():
		if String(marker["hex"]) == tile and String(marker["site_name"]) == site_name:
			return true
	return false


## Все локации с маркерами на собранной доске — интерфейсу, чтобы их отмечать.
static func marked_sites(state: GameState) -> Array[String]:
	var result: Array[String] = []
	for site_id: String in state.graph.sites.keys():
		if not marker_for(state, site_id).is_empty():
			result.append(site_id)
	return result
