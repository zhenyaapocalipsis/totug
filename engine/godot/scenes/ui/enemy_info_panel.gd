class_name EnemyInfoPanel
extends PanelContainer

## Зона информации о противниках: по строке на каждого игрока, кроме зрителя.
## Только открытые сведения — VP, ресурсы хода, войска, размер руки и колоды.

var _text: RichTextLabel


func _init() -> void:
	add_theme_stylebox_override("panel", GameScreen.zone_style())
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", 11)
	_text.add_theme_font_size_override("bold_font_size", 14)
	add_child(_text)


func update_from_view(view: Dictionary, viewer_id: String) -> void:
	var current := String(view["current_player"])
	var blocks: Array[String] = []
	for pid in (view.get("turn_order", []) as Array):
		if String(pid) == viewer_id:
			continue
		var p: Dictionary = (view["players"] as Dictionary).get(pid, {})
		if p.is_empty():
			continue
		var dim := "#9c99aa"
		var head := "[b][color=%s]%s[/color][/b]   [color=%s]%d VP[/color]" % [
			EventLogPanel.player_color(String(pid)).to_html(false),
			EventLogPanel.player_name(String(pid)).to_upper(),
			PlayerPanel.VP_COLOR.to_html(false), int(p["vp_tokens"])]
		if String(pid) == current:
			head += "   [color=#e8d9a0]◆ turn[/color]"
		var line1 := "[color=%s]Power[/color] [color=%s]%d[/color]   [color=%s]Influence[/color] [color=%s]%d[/color]   [color=%s]Hand[/color] %d" % [
			dim, PlayerPanel.POWER_COLOR.to_html(false), int(p["power"]),
			dim, PlayerPanel.INFLUENCE_COLOR.to_html(false), int(p["influence"]),
			dim, int(p["hand_size"])]
		var line2 := "[color=%s]Troops %d · Spies %d · Trophies %d · Deck %d/%d · IC %d[/color]" % [
			dim, int(p["troops_in_barracks"]), int(p["spies_in_barracks"]), int(p["trophy_hall_count"]),
			int(p["deck_size"]), int(p["discard_size"]), (p.get("inner_circle", []) as Array).size()]
		blocks.append("%s\n%s\n%s" % [head, line1, line2])
	_text.text = "\n".join(PackedStringArray(blocks)) if not blocks.is_empty() else "[color=#77748a]No opponents[/color]"
