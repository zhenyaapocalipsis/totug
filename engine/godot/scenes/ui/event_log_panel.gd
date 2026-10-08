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

## Строки появляются по одной, а не пачкой: сыгранная карта часто порождает
## сразу несколько событий, и вывалившись разом они читаются как один мазок.
## Свежая строка короткое время подсвечена — видно, что именно добавилось.
const STAGGER := 0.09        # пауза между строками
const FRESH_TIME := 1.1      # сколько держится подсветка свежей строки
## Если событий привалило больше, чем влезет в разумное ожидание, лишние
## выводятся сразу: заставлять ждать конца длинной цепочки нельзя.
const QUEUE_LIMIT := 10
const FRESH_BG := "#2a1e4d"

## Статический снимок доски (StateView.board_snapshot) — для названий локаций.
var board: Dictionary = {}

var _text: RichTextLabel
var _lines: Array[String] = []
var _queue: Array[String] = []   # строки, ждущие своей очереди
var _next_in := 0.0
var _fresh_left := 0.0
var _fresh_index := -1


## Журнал живёт вкладкой в зоне чата (chat_panel.gd), поэтому своей рамки и
## заголовка у него нет.
func _init() -> void:
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_following = true
	_text.selection_enabled = true
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_text)
	set_process(false)


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
		_queue.append(line)
		if String(evt.get("type", "")) == "turn_ended" and not bool(evt.get("game_over", false)):
			# Только дефисы: рамочных символов (─) в пиксельном шрифте нет,
			# вместо них рисовались пустые квадратики.
			_queue.append("[color=#8a8a95]------------[/color]")
	_start_queue()


func add_note(text: String) -> void:
	_queue.append("[i][color=#c8b98a]%s[/color][/i]" % _escape(text))
	_start_queue()


## Очередь длиннее разумного выводится сразу до остатка в QUEUE_LIMIT строк.
func _start_queue() -> void:
	while _queue.size() > QUEUE_LIMIT:
		_lines.append(_queue.pop_front())
	if not _queue.is_empty():
		set_process(true)
		if _next_in <= 0.0:
			_release_line()
	_trim_and_show()


func _release_line() -> void:
	_lines.append(_queue.pop_front())
	_fresh_index = _lines.size() - 1
	_fresh_left = FRESH_TIME
	_next_in = STAGGER


func _process(delta: float) -> void:
	var changed := false
	_next_in = maxf(_next_in - delta, 0.0)
	if _next_in <= 0.0 and not _queue.is_empty():
		_release_line()
		changed = true
	if _fresh_left > 0.0:
		_fresh_left = maxf(_fresh_left - delta, 0.0)
		if _fresh_left <= 0.0:
			_fresh_index = -1
			changed = true
	if changed:
		_trim_and_show()
	if _queue.is_empty() and _fresh_left <= 0.0:
		set_process(false)


func _trim_and_show() -> void:
	if _lines.size() > MAX_LINES:
		var cut := _lines.size() - MAX_LINES
		_lines = _lines.slice(cut)
		if _fresh_index >= 0:
			_fresh_index -= cut
	var shown := _lines.duplicate()
	if _fresh_index >= 0 and _fresh_index < shown.size():
		shown[_fresh_index] = "[bgcolor=%s]%s[/bgcolor]" % [FRESH_BG, shown[_fresh_index]]
	_text.text = "\n".join(shown)


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")


static func player_name(player_id: String) -> String:
	if player_id == GameState.WHITE:
		return "White"
	var own := PlayerProfile.name_of(player_id)
	return own if own != "" else player_id.capitalize()


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
			var owner := String(e.get("owner", ""))
			if owner == "":
				return "%s returns a troop from %s to its owner's barracks" % [who, slot]
			return "%s returns %s's troop from %s" % [who, player_name(owner), slot]
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
			# Чей зал — главное, о чём спрашивали игроки: "у кого взяли войско".
			var hall := String(e.get("hall", ""))
			var colour := String(e.get("color", "?")).capitalize()
			if hall == "":
				return "%s takes a %s troop from a trophy hall" % [who, colour]
			return "%s takes a %s troop from %s's trophy hall" % [who, colour, player_name(hall)]
		"choose_starting_site":
			return "%s starts at %s" % [who, site]
		"market_mulligan":
			var new_card := String(e.get("new_card_id", ""))
			return "%s replaces %s in the market with %s" % [who, card,
				card_name(new_card) if new_card != "" else "nothing"]
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
		"game_abandoned":
			return "%s did not come back — GAME OVER, rating does not change" % who
		"give_insane_outcast":
			return "%s receives Insane Outcast ×%s" % [who, e.get("count", 1)]
		_:
			return "%s: %s" % [who, e.get("type", "?")]
