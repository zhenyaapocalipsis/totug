class_name StateCopy
extends RefCounted

## Глубокая копия состояния партии (этап Bot-2): бот "проигрывает ходы в
## уме" на копии, не трогая настоящую партию.
##
## Поля копируются по списку переменных скрипта, а не перечислением руками:
## новое поле в GameState / PlayerState / Deck / Market / Supplies / VPBank
## попадёт в копию само (и в fingerprint, которым тесты сверяют копию).
##
## Общие с оригиналом (не меняются за партию): graph, presence, control.
## Массивы и словари копируются глубоко, но объекты внутри них — нет. Такой
## объект в состоянии один: PlayerState.pending_end_of_turn (эффекты карт
## "At end of turn"). Поэтому копию снимают, только когда этот список пуст у
## всех (GameServer.is_quiet); иначе GameServer.clone повторяет ходы от
## последней такой точки.

const SHARED := ["graph", "presence", "control"]

## script -> PackedStringArray имён переменных скрипта (список не меняется).
static var _fields: Dictionary = {}


static func copy_state(state: GameState) -> GameState:
	var copy := GameState.new(state.graph)
	_copy_fields(state, copy)
	return copy


static func _copy_fields(src: Object, dst: Object) -> void:
	for field: String in _field_names(src):
		if SHARED.has(field):
			dst.set(field, src.get(field))
		elif field == "players":  # id -> PlayerState
			var players := {}
			var src_players: Dictionary = src.get(field)
			for pid in src_players.keys():
				players[pid] = _copy_object(src_players[pid])
			dst.set(field, players)
		else:
			dst.set(field, _copy_value(src.get(field)))


static func _copy_value(v: Variant) -> Variant:
	match typeof(v):
		TYPE_ARRAY:
			return (v as Array).duplicate(true)
		TYPE_DICTIONARY:
			return (v as Dictionary).duplicate(true)
		TYPE_OBJECT:
			return _copy_object(v)
	return v


static func _copy_object(obj: Object) -> Object:
	if obj == null:
		return null
	if obj is RandomNumberGenerator:
		var rng := RandomNumberGenerator.new()
		rng.seed = (obj as RandomNumberGenerator).seed
		rng.state = (obj as RandomNumberGenerator).state
		return rng
	var dst: Object
	if obj is PlayerState:
		dst = PlayerState.new((obj as PlayerState).id)
	elif obj is Deck or obj is Market or obj is Supplies or obj is VPBank:
		dst = obj.get_script().new()
	else:
		return obj  # неизменяемые помощники и эффекты карт — общие
	_copy_fields(obj, dst)
	return dst


static func _field_names(obj: Object) -> PackedStringArray:
	var script: Script = obj.get_script()
	if _fields.has(script):
		return _fields[script]
	var names := PackedStringArray()
	for prop: Dictionary in obj.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			names.append(String(prop["name"]))
	_fields[script] = names
	return names


## Всё состояние строкой — для тестов: копия обязана совпасть с оригиналом,
## а оригинал — не измениться от ходов в копии.
static func fingerprint(state: GameState) -> String:
	return var_to_str(_plain(state))


static func _plain(v: Variant) -> Variant:
	match typeof(v):
		TYPE_ARRAY:
			return (v as Array).map(_plain)
		TYPE_DICTIONARY:
			var out := {}
			for key in (v as Dictionary).keys():
				out[key] = _plain(v[key])
			return out
		TYPE_OBJECT:
			if v == null:
				return null
			if v is RandomNumberGenerator:
				return [v.seed, v.state]
			if v is GameState or v is PlayerState or v is Deck or v is Market or v is Supplies or v is VPBank:
				var out := {}
				for field: String in _field_names(v):
					if not SHARED.has(field):
						out[field] = _plain(v.get(field))
				return out
			return (v as Object).get_script().resource_path if v.get_script() != null else str(v)
	return v
