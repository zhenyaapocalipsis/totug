class_name GainVpPerN
extends CardEffect

## "Gain X <resource> for every N <source>" — общий примитив для всех карт с
## бонусом, пропорциональным какому-то счётчику на доске (сайты, войска,
## шпионы, трофи-холл, внутренний круг). resource по умолчанию "vp", но тот же
## примитив используют и карты вида "Gain 1 Power for every 3 troops in your
## trophy hall" (Beholder) — resource="power".
##
## source:
##   "troops_on_board"      — свои войска физически на доске (любые слоты)
##   "spies_on_board"       — свои шпионы физически на доске
##   "inner_circle"         — карт во Внутреннем круге
##   "sites_controlled"     — сайтов под обычным контролем (= "site control markers")
##   "sites_controlled_total" — сайтов под тотальным контролем
##   "white_trophy"         — белых войск в трофи-холле игрока
##   "trophy_hall"          — ЛЮБЫХ войск в трофи-холле игрока (рулбук стр. 14)

var resource: String
var source: String
var per: int
var amount: int


func _init(res: String, src: String, per_n: int, amt: int) -> void:
	resource = res
	source = src
	per = maxi(per_n, 1)
	amount = amt


func _count_source(state: GameState, player_id: String) -> int:
	var p: PlayerState = state.players[player_id]
	match source:
		"troops_on_board":
			var n := 0
			for owner: String in state.troops.values():
				if owner == player_id:
					n += 1
			return n
		"spies_on_board":
			var n := 0
			for owners: Array in state.spies.values():
				n += owners.count(player_id)
			return n
		"inner_circle":
			return p.deck.inner_circle.size()
		"sites_controlled":
			var n := 0
			for site_id: String in state.graph.sites.keys():
				if state.control.controller_of(site_id, state.troops) == player_id:
					n += 1
			return n
		"sites_controlled_total":
			var n := 0
			for site_id: String in state.graph.sites.keys():
				if state.control.has_total_control(player_id, site_id, state.troops, state.spies):
					n += 1
			return n
		"control_markers":
			var n := 0
			for site_id: String in ControlMarkers.marked_sites(state):
				if state.control.controller_of(site_id, state.troops) == player_id:
					n += 1
			return n
		"player_trophy":
			return p.player_trophy_count()
		"white_trophy":
			return p.white_trophy_count
		"trophy_hall":
			return p.trophy_hall_count
	push_error("GainVpPerN: неизвестный source '%s'" % source)
	return 0


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	var count: int = _count_source(state, player_id)
	var gained: int = (count / per) * amount
	if gained <= 0:
		return
	var p: PlayerState = state.players[player_id]
	match resource:
		"power":
			p.power += gained
		"influence":
			p.influence += gained
		"vp":
			p.vp_tokens += state.vp_bank.grant(gained)
		_:
			push_error("GainVpPerN: неизвестный resource '%s'" % resource)
	resolver.log_event("gain_per_n", {"player_id": player_id, "resource": resource, "amount": gained})
