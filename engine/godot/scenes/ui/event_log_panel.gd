class_name EventLogPanel
extends PanelContainer

## Журнал хода: человеко-читаемые строки из events, которые вернул сервер.
## Перевод типов событий в текст живёт здесь, а не в движке: движок пишет
## машинные события ({"type": "assassinate", ...}), интерфейс их переводит.
##
## Этап 3: строки на английском, имя игрока окрашено в его цвет, вместо id
## слотов ("c_n1:C4_3_1") — названия локаций, начало каждого хода отделено
## заметной строкой.

const MAX_LINES := 300

## Статический снимок доски (StateView.board_snapshot) — для названий локаций.
var board: Dictionary = {}

var _text: RichTextLabel
var _lines: Array[String] = []


## Журнал живёт вкладкой в зоне чата (chat_panel.gd), поэтому своей рамки и
## заголовка у него нет.
func _init() -> void:
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_following = true
	_text.selection_enabled = true
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 12)
	_text.add_theme_font_size_override("bold_font_size", 12)
	_text.add_theme_font_size_override("italics_font_size", 12)
	add_child(_text)


func add_events(events: Array) -> void:
	for e in events:
		var evt: Dictionary = e
		var who := String(evt.get("player_id", ""))
		var line := describe(evt, board)
		# Имя игрока в начале строки красим в его цвет — так видно, чьё это
		# действие, не вчитываясь.
		var pname := player_name(who)
		if who != "" and line.begins_with(pname):
			line = "[b][color=%s]%s[/color][/b]%s" % [
				player_color(who).to_html(false), pname, _escape(line.substr(pname.length()))]
		else:
			line = _escape(line)
		_lines.append(line)
		if String(evt.get("type", "")) == "turn_ended" and not bool(evt.get("game_over", false)):
			_lines.append("[color=#8a8a95]────────────[/color]")
	_trim_and_show()


func add_note(text: String) -> void:
	_lines.append("[i][color=#c8b98a]%s[/color][/i]" % _escape(text))
	_trim_and_show()


func _trim_and_show() -> void:
	if _lines.size() > MAX_LINES:
		_lines = _lines.slice(_lines.size() - MAX_LINES)
	_text.text = "\n".join(_lines)


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")


static func player_name(player_id: String) -> String:
	if player_id == GameState.WHITE:
		return "White"
	return player_id.capitalize()


static func player_color(player_id: String) -> Color:
	return BoardPanel.PLAYER_COLORS.get(player_id, Color(0.75, 0.75, 0.78)).lightened(0.25)


static func card_name(card_id: String) -> String:
	var data: Dictionary = CardLibrary.card_data(card_id)
	return String(data.get("name", card_id)) if not data.is_empty() else card_id


## Название локации по id: "Caer Sidi". Без снимка доски — сам id.
static func site_name(site_id: String, board: Dictionary) -> String:
	var sites: Dictionary = board.get("sites", {})
	if sites.has(site_id):
		return String((sites[site_id] as Dictionary)["name"])
	return site_id


## Где стоит слот: название локации или "a tunnel".
static func slot_place(slot_id: String, board: Dictionary) -> String:
	var slots: Dictionary = board.get("slots", {})
	if not slots.has(slot_id):
		return slot_id
	var site_id := String((slots[slot_id] as Dictionary).get("site_id", ""))
	if site_id == "":
		return "a tunnel"
	return site_name(site_id, board)


static func describe(e: Dictionary, board: Dictionary = {}) -> String:
	var who := player_name(String(e.get("player_id", "")))
	var amount := int(e.get("amount", 0))
	var card := card_name(String(e.get("card_id", "")))
	var slot := slot_place(String(e.get("slot_id", "?")), board)
	var site := site_name(String(e.get("site_id", "?")), board)
	match String(e.get("type", "")):
		"play_card":
			return "%s plays %s" % [who, card]
		"gain_power":
			return "%s gains %d Power" % [who, amount]
		"gain_influence":
			return "%s gains %d Influence" % [who, amount]
		"vp_income":
			var parts: Array[String] = []
			if int(e.get("markers", 0)) > 0:
				var marked: Array = e.get("marker_sites", [])
				parts.append("%d for control markers (%s)" % [
					int(e["markers"]), ", ".join(PackedStringArray(marked))])
			if int(e.get("cluster_bonus", 0)) > 0:
				parts.append("%d for the A2 hex bonus" % int(e.get("cluster_bonus", 0)))
			if parts.is_empty():
				parts.append("unknown source")
			return "%s: end of turn, +%d VP (%s), total %d" % [
				who, int(e.get("granted", 0)), ", ".join(parts), int(e.get("total_vp", 0))]
		"gain_vp":
			return "%s gains %d VP" % [who, amount]
		"gain_per_n":
			return "%s gains %d %s" % [who, amount, e.get("resource", "")]
		"draw_cards":
			return "%s draws %d card%s" % [who, amount, "" if amount == 1 else "s"]
		"discard":
			return "%s discards %s" % [who, card]
		"force_discard":
			return "%s is forced to discard %s" % [who, card]
		"deploy_troop":
			return "%s deploys a troop to %s (card effect)" % [who, slot]
		"place_spy":
			return "%s places a spy at %s" % [who, site]
		"move_troop":
			return "%s moves a troop from %s to %s" % [who,
				slot_place(String(e.get("from", "?")), board), slot_place(String(e.get("to", "?")), board)]
		"supplant":
			return "%s supplants %s's troop at %s" % [who, player_name(String(e.get("victim", "?"))), slot]
		"return_troop":
			return "%s returns a troop from %s to its owner's barracks" % [who, slot]
		"return_own_spy":
			return "%s returns own spy from %s" % [who, site]
		"removed_to_supply":
			return "%s: %s leaves the game" % [who, card]
		"queued_end_of_turn":
			return "%s: effect will resolve at end of turn" % who
		"ghost_recruit":
			return "%s recruits %s from the devoured pile" % [who, card]
		"ghost_market":
			return "%s: top devoured card joins the market this turn" % who
		"put_deck_into_discard":
			return "%s puts their whole deck into the discard pile" % who
		"assassinate":
			var victim := String(e.get("victim", ""))
			if victim == "":
				return "%s assassinates a troop at %s" % [who, slot]
			return "%s assassinates %s's troop at %s" % [who, player_name(victim), slot]
		"deploy":
			return "%s deploys a troop to %s" % [who, slot]
		"recruit":
			if e.has("card_id"):
				return "%s recruits %s" % [who, card]
			return "%s recruits from market slot %s" % [who, e.get("market_index", "?")]
		"recruit_supply":
			return "%s recruits %s" % [who, card]
		"recruit_free":
			return "%s recruits %s for free" % [who, card]
		"return_spy":
			return "%s returns %s's spy from %s" % [who, player_name(String(e.get("spy_owner", "?"))), site]
		"take_trophy":
			return "%s takes a %s troop from a trophy hall" % [who, player_name(String(e.get("color", "?")))]
		"choose_starting_site":
			return "%s starts at %s" % [who, site]
		"turn_income":
			var parts: Array[String] = []
			if int(e.get("a2_power", 0)) + int(e.get("a2_influence", 0)) > 0:
				parts.append("A2 hex bonus: +%d Power, +%d Influence" % [int(e.get("a2_power", 0)), int(e.get("a2_influence", 0))])
			if int(e.get("marker_influence", 0)) > 0:
				parts.append("control markers: +%d Influence" % int(e.get("marker_influence", 0)))
			return "%s: start of turn — %s" % [who, "; ".join(parts)]
		"turn_ended":
			return "%s ends the turn%s" % [who, "  — GAME OVER" if bool(e.get("game_over", false)) else ""]
		"promote":
			return "%s promotes %s to the Inner Circle" % [who, card]
		"devour":
			return "%s devours %s" % [who, card]
		"give_insane_outcast":
			return "%s receives Insane Outcast ×%s" % [who, e.get("count", 1)]
		_:
			return "%s: %s" % [who, e.get("type", "?")]
