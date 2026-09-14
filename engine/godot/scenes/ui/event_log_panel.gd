class_name EventLogPanel
extends PanelContainer

## Журнал хода: человеко-читаемые строки из events, которые вернул сервер.
## Перевод типов событий в текст живёт здесь, а не в движке: движок пишет
## машинные события ({"type": "assassinate", ...}), интерфейс их переводит.

const MAX_LINES := 200

var _text: RichTextLabel
var _lines: Array[String] = []


func _init() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.09, 0.12)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	add_child(col)

	var title := Label.new()
	title.text = "Журнал"
	title.add_theme_font_size_override("font_size", 13)
	title.modulate = Color(0.8, 0.8, 0.85)
	col.add_child(title)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = false
	_text.scroll_following = true
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size = Vector2(0, 120)
	_text.add_theme_font_size_override("normal_font_size", 12)
	col.add_child(_text)


func add_events(events: Array) -> void:
	for e in events:
		_lines.append(describe(e as Dictionary))
	if _lines.size() > MAX_LINES:
		_lines = _lines.slice(_lines.size() - MAX_LINES)
	_text.text = "\n".join(_lines)


func add_note(text: String) -> void:
	_lines.append(text)
	_text.text = "\n".join(_lines)


static func card_name(card_id: String) -> String:
	var data: Dictionary = CardLibrary.card_data(card_id)
	return String(data.get("name", card_id)) if not data.is_empty() else card_id


static func describe(e: Dictionary) -> String:
	var who := String(e.get("player_id", ""))
	var amount := int(e.get("amount", 0))
	match String(e.get("type", "")):
		"gain_power":
			return "%s: +%d Power" % [who, amount]
		"gain_influence":
			return "%s: +%d Influence" % [who, amount]
		"vp_income":
			var parts: Array[String] = []
			if int(e.get("markers", 0)) > 0:
				var marked: Array = e.get("marker_sites", [])
				parts.append("%d за маркеры контроля (%s)" % [
					int(e["markers"]), ", ".join(PackedStringArray(marked))])
			if int(e.get("cluster_bonus", 0)) > 0:
				parts.append("%d за бонус гекса A2" % int(e.get("cluster_bonus", 0)))
			if parts.is_empty():
				parts.append("источник неизвестен")
			return "%s: конец хода, +%d VP (%s), всего %d" % [
				who, int(e.get("granted", 0)), ", ".join(parts), int(e.get("total_vp", 0))]
		"gain_vp":
			return "%s: +%d VP" % [who, amount]
		"gain_per_n":
			return "%s: +%d %s (за количество)" % [who, amount, e.get("resource", "")]
		"draw_cards":
			return "%s: добор %d карт" % [who, amount]
		"discard":
			return "%s: сброшена карта %s" % [who, card_name(String(e.get("card_id", "")))]
		"force_discard":
			return "%s вынужден сбросить %s" % [who, card_name(String(e.get("card_id", "")))]
		"deploy_troop":
			return "%s: войско развёрнуто в %s (эффект карты)" % [who, e.get("slot_id", "?")]
		"place_spy":
			return "%s: шпион поставлен на %s" % [who, e.get("site_id", "?")]
		"move_troop":
			return "%s: войско перемещено %s -> %s" % [who, e.get("from", "?"), e.get("to", "?")]
		"supplant":
			return "%s: supplant в %s (войско игрока %s заменено)" % [who, e.get("slot_id", "?"), e.get("owner", "?")]
		"return_troop":
			return "%s: войско возвращено в барак владельца из %s" % [who, e.get("slot_id", "?")]
		"return_own_spy":
			return "%s: свой шпион возвращён с %s" % [who, e.get("site_id", "?")]
		"removed_to_supply":
			return "%s: карта %s ушла из игры" % [who, card_name(String(e.get("card_id", "")))]
		"queued_end_of_turn":
			return "%s: эффект отложен до конца хода" % who
		"ghost_recruit":
			return "%s: рекрут из стопки сожранных — %s" % [who, card_name(String(e.get("card_id", "")))]
		"put_deck_into_discard":
			return "%s: колода добора сброшена целиком" % who
		"assassinate":
			return "%s: убийство войска в %s" % [who, e.get("slot_id", "?")]
		"deploy":
			return "%s: войско развёрнуто в %s" % [who, e.get("slot_id", "?")]
		"recruit":
			return "%s: рекрут из маркета (слот %s)" % [who, e.get("market_index", "?")]
		"recruit_supply":
			return "%s: рекрут из стопки — %s" % [who, card_name(String(e.get("card_id", "")))]
		"recruit_free":
			return "%s: рекрут без оплаты — %s" % [who, card_name(String(e.get("card_id", "")))]
		"return_spy":
			return "%s: шпион игрока %s возвращён с %s" % [who, e.get("spy_owner", "?"), e.get("site_id", "?")]
		"turn_income":
			var parts: Array[String] = []
			if int(e.get("a2_power", 0)) + int(e.get("a2_influence", 0)) > 0:
				parts.append("бонус гекса A2: +%d Power, +%d Influence" % [int(e.get("a2_power", 0)), int(e.get("a2_influence", 0))])
			if int(e.get("marker_influence", 0)) > 0:
				parts.append("маркеры: +%d Influence" % int(e.get("marker_influence", 0)))
			return "%s: начало хода — %s" % [who, "; ".join(parts)]
		"turn_ended":
			return "%s: ход завершён%s" % [who, "  — ПАРТИЯ ОКОНЧЕНА" if bool(e.get("game_over", false)) else ""]
		"promote":
			return "%s: во Внутренний круг — %s" % [who, card_name(String(e.get("card_id", "")))]
		"devour":
			return "%s: сожрана карта %s" % [who, card_name(String(e.get("card_id", "")))]
		"give_insane_outcast":
			return "%s получает Insane Outcast ×%s" % [who, e.get("count", 1)]
		_:
			return "%s: %s" % [who, e.get("type", "?")]
