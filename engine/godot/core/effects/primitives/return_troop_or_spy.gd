class_name ReturnTroopOrSpy
extends CardEffect

## "Return another player's troop or spy" / "Return up to two troops or
## spies" / "Return an enemy spy" — снимает вражескую фигуру (не белую: белые
## войска никому не принадлежат, их не "возвращают") с доски в барак
## владельца. troop_only/spy_only сужают выбор для карт вроде "Return an
## enemy spy" (spy_only=true, оставлено также как основа для Actions-подобных
## карточных эффектов без платы).
##
## Цель обязана быть в зоне Присутствия ИГРОКА, применяющего эффект (как у
## базового действия Actions.return_enemy_spy, рулбук стр. 13) — эффект карты
## не отличается от базового действия в этом смысле, только не стоит Power.
## Без этой проверки можно было вернуть фигуру где угодно на доске, даже там,
## где у игрока нет ни одного своего войска или шпиона поблизости.

var remaining: int
var up_to: bool
var troop_only: bool
var spy_only: bool


func _init(count: int = 1, allow_fewer: bool = false, only_troops: bool = false, only_spies: bool = false) -> void:
	remaining = count
	up_to = allow_fewer
	troop_only = only_troops
	spy_only = only_spies


## Опции кодируются строками "troop|<slot_id>" / "spy|<site_id>|<owner_id>",
## чтобы одним choice_type покрыть оба типа целей.
##
## Разделитель именно "|", а не ":" — здесь был баг, найденный автопрогоном на
## настоящей доске. Id слота собранной доски САМ содержит двоеточие
## ("c_s1:C4_0_1", префикс — место гекса в раскладке), поэтому строка
## "troop:c_s1:C4_0_1" при split(":") давала parts[1] = "c_s1": войско
## "снималось" с несуществующего слота, настоящее оставалось на доске, а в
## барак владельцу ничего не возвращалось. На синтетических досках юнит-тестов
## двоеточий в id нет, поэтому тесты этого не видели.
const SEP := "|"


func _legal_targets(state: GameState, player_id: String) -> Array:
	var result: Array = []
	if not spy_only:
		for slot_id: String in state.graph.slots.keys():
			var owner: String = state.troops.get(slot_id, "")
			if owner != "" and owner != player_id and owner != "white":
				if state.presence.has_presence_at_slot(player_id, slot_id, state.troops, state.spies):
					result.append("troop%s%s" % [SEP, slot_id])
	if not troop_only:
		for site_id: String in state.spies.keys():
			if not state.presence.has_presence_at_site(player_id, site_id, state.troops, state.spies):
				continue
			for owner: String in state.spies[site_id]:
				if owner != player_id:
					result.append("spy%s%s%s%s" % [SEP, site_id, SEP, owner])
	return result


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if is_answered():
		var choice = answer()
		_answered = false
		_answer = null
		if choice != null and choice != "":
			_resolve_choice(state, String(choice), resolver)
			remaining -= 1
		else:
			remaining = 0
		_continue(state, player_id, resolver)
		return
	_continue(state, player_id, resolver)


func _resolve_choice(state: GameState, choice: String, resolver: EffectResolver) -> void:
	var parts: PackedStringArray = choice.split(SEP)
	if parts.size() < 2:
		return
	if parts[0] == "troop":
		var slot_id: String = parts[1]
		var owner: String = state.troops.get(slot_id, "")
		state.troops[slot_id] = ""
		if state.players.has(owner):
			state.players[owner].troops_in_barracks += 1
		resolver.log_event("return_troop", {"slot_id": slot_id, "owner": owner})
	else:
		var site_id: String = parts[1]
		var owner: String = parts[2]
		var site_spies: Array = state.spies.get(site_id, [])
		var idx: int = site_spies.find(owner)
		if idx != -1:
			site_spies.remove_at(idx)
			state.spies[site_id] = site_spies
		if state.players.has(owner):
			state.players[owner].spies_in_barracks += 1
		resolver.log_event("return_spy", {"site_id": site_id, "owner": owner})


func _continue(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if remaining <= 0:
		return
	var legal: Array = _legal_targets(state, player_id)
	if legal.is_empty():
		return
	var pd := PendingDecision.new()
	pd.player_id = player_id
	pd.prompt = "Return a troop or spy"
	pd.choice_type = "target_return"
	pd.legal_options = legal
	if up_to:
		pd.legal_options.append("")
	pd.target_effect = self
	resolver.request_decision(pd)
