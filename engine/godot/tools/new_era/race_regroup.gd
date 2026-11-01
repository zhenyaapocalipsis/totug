extends SceneTree

# Race regroup (NE-36): moves creatures between New Era cards by
# tools/new_era/race_regroup.tsv (dest <- src) and writes the "race" field of
# every New Era card from tools/new_era/races.tsv. A creature moves with its
# name, art window (pixel_cards SINGLE_ART), mini face (mini_faces.json) and
# HS animation (hs_play RECIPES, hs_unity tables); the effect stays on the card.
# Run once: the map is not idempotent. "-- races" writes only the race field.

const GODOT := "C:/tyrants of the underdark godot/engine/godot/"
const UNITY := "C:/tyrants of the underdark godot/hs_unity/"
const CARDS := GODOT + "data/cards/cards.json"
const FACES := GODOT + "data/cards/mini_faces.json"
const PIXEL := GODOT + "tools/pixel_cards.gd"
const HS := GODOT + "scenes/ui/hs_fx/hs_play.gd"
const DEFAULT_FACE := [56, 12]
const NO_RACE_TYPES := ["SIEGE", "MERCENARY"]

var dest_src := {}  # "49009" -> "49709"
var src_dest := {}


func _init() -> void:
	var races_only := OS.get_cmdline_user_args().has("races")
	if not races_only:
		_load_map()
		_move_names()
		_move_art()
		_move_faces()
		_move_hs()
		for f in [UNITY + "data/hs_assign.tsv", UNITY + "render/port_queue.tsv"]:
			_remap_tsv(f)
		_remap_card_map(UNITY + "CARD_MAP.md")
	_write_races()
	print("race_regroup: done")
	quit()


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _rows(path: String) -> Array:
	var out := []
	for line in _read(path).split("\n"):
		if line.strip_edges() == "" or line.begins_with("#"):
			continue
		out.append(line.split("\t"))
	return out


func _load_map() -> void:
	for r: PackedStringArray in _rows(GODOT + "tools/new_era/race_regroup.tsv"):
		dest_src[r[0].strip_edges()] = r[1].strip_edges()
	for d: String in dest_src:
		src_dest[dest_src[d]] = d
	var a := dest_src.keys()
	var b := src_dest.keys()
	a.sort()
	b.sort()
	assert(a == b and a.size() == dest_src.size(), "race_regroup.tsv must be a permutation")
	print("moves: ", dest_src.size())


## card_id -> name, from the current cards.json.
func _names() -> Dictionary:
	var out := {}
	for c: Dictionary in JSON.parse_string(_read(CARDS)):
		out[str(int(c["card_id"]))] = String(c["name"])
	return out


func _move_names() -> void:
	var names := _names()
	var text := _read(CARDS)
	for d: String in dest_src:
		var re := RegEx.create_from_string("\"card_id\": " + d + ",\\s*\\n\\s*\"name\": \"([^\"]*)\"")
		var m := re.search(text)
		assert(m != null, "no card " + d)
		text = text.substr(0, m.get_start(1)) + names[dest_src[d]] + text.substr(m.get_end(1))
	_write(CARDS, text)


## SINGLE_ART lines "\t<id>: [\"deck/file\", Rect2i(...)],".
func _move_art() -> void:
	var text := _read(PIXEL)
	var re := RegEx.create_from_string("(?m)^\\t(\\d{5}): (\\[\"[^\"]+\", Rect2i\\([^)]*\\)\\])")
	var orig := {}
	for m in re.search_all(text):
		orig[m.get_string(1)] = m.get_string(2)
	var out := ""
	var last := 0
	for m in re.search_all(text):
		var id := m.get_string(1)
		if dest_src.has(id):
			assert(orig.has(dest_src[id]), "no art for " + dest_src[id])
			out += text.substr(last, m.get_start(2) - last) + orig[dest_src[id]]
			last = m.get_end(2)
	_write(PIXEL, out + text.substr(last))


## Mini faces: mini_faces.json wins over MINI_FACE in pixel_cards.gd, so every
## moved card gets its creature's face there (from the json, the const or default).
func _move_faces() -> void:
	var faces: Dictionary = JSON.parse_string(_read(FACES))
	var consts := {}
	var re := RegEx.create_from_string("(\\d{5}): Vector2i\\((\\d+), (\\d+)\\)")
	for m in re.search_all(_read(PIXEL)):
		consts[m.get_string(1)] = [int(m.get_string(2)), int(m.get_string(3))]
	var fixed := {}
	for k: String in faces:
		fixed[k] = [int(faces[k][0]), int(faces[k][1])]
	for d: String in dest_src:
		var s: String = dest_src[d]
		fixed[d] = [int(faces[s][0]), int(faces[s][1])] if faces.has(s) else consts.get(s, DEFAULT_FACE)
	_write(FACES, JSON.stringify(fixed, "\t") + "\n")


func _move_hs() -> void:
	var text := _read(HS)
	var re := RegEx.create_from_string("const RECIPES := (\\{[^\\n]*\\})")
	var m := re.search(text)
	var old: Dictionary = JSON.parse_string(m.get_string(1))
	var keys: Array = old.keys()
	for d: String in dest_src:
		if old.has(dest_src[d]) and not keys.has(d):
			keys.append(d)
	var parts := []
	for k: String in keys:
		var v = old.get(dest_src[k]) if dest_src.has(k) else old[k]
		if v != null:
			parts.append("\"%s\": \"%s\"" % [k, v])
	text = text.substr(0, m.get_start(1)) + "{" + ", ".join(parts) + "}" + text.substr(m.get_end(1))
	_write(HS, text)


## First column is a card id: src -> dest (one pass, so swaps do not chain).
func _remap_tsv(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var lines := _read(path).split("\n")
	for i in lines.size():
		var tab := lines[i].find("\t")
		if tab > 0 and src_dest.has(lines[i].substr(0, tab)):
			lines[i] = src_dest[lines[i].substr(0, tab)] + lines[i].substr(tab)
	_write(path, "\n".join(lines))


## Rows "| Name (id) | ...": the id follows its creature.
func _remap_card_map(path: String) -> void:
	var text := _read(path)
	var re := RegEx.create_from_string("\\((\\d{5})\\)")
	var out := ""
	var last := 0
	for m in re.search_all(text):
		var id := m.get_string(1)
		if src_dest.has(id):
			out += text.substr(last, m.get_start(1) - last) + src_dest[id]
			last = m.get_end(1)
	_write(path, out + text.substr(last))


## "race" goes right after "type" of every New Era card (49000-50199) except
## the fan half-decks SIEGE and MERCENARY.
func _write_races() -> void:
	var race_of := {}
	for r: PackedStringArray in _rows(GODOT + "tools/new_era/races.tsv"):
		race_of[r[0]] = r[1].strip_edges()
	var text := _read(CARDS)
	var missing := []
	for c: Dictionary in JSON.parse_string(text):
		var id := int(c["card_id"])
		if id < 49000 or id >= 50200 or NO_RACE_TYPES.has(String(c["type"])):
			continue
		if not race_of.has(String(c["name"])):
			missing.append(c["name"])
			continue
		var at := text.find("\"card_id\": %d," % id)
		var type_at := text.find("\"type\": ", at)
		var eol := text.find("\n", type_at)
		var line := "\n    \"race\": \"%s\"," % race_of[c["name"]]
		if c.has("race"):
			var r_at := text.find("\n    \"race\": ", eol)
			text = text.substr(0, r_at) + line + text.substr(text.find("\n", r_at + 1))
		else:
			text = text.substr(0, eol) + line + text.substr(eol)
	assert(missing.is_empty(), "no race for " + str(missing))
	_write(CARDS, text)
