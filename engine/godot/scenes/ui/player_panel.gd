class_name PlayerPanel
extends PanelContainer

## Планшет игрока: ресурсы текущего хода, бараки, трофи-холл, VP и кнопки
## действий, которые не привязаны к клику по доске или карте.
##
## Панель ничего не решает сама: какие кнопки доступны, ей сообщает срез
## состояния (view["legal"]), который посчитал сервер.
##
## Этап 3: Power / Influence / VP — крупными цветными числами, подсказка
## "что можно сделать" перечисляет действия и их цену, рамка панели в цвете
## игрока.

signal action_requested(kind: String)

const POWER_COLOR := Color(0.95, 0.45, 0.35)
const INFLUENCE_COLOR := Color(0.45, 0.75, 0.98)
const VP_COLOR := Color(0.98, 0.82, 0.35)

var _title: Label
var _resources: RichTextLabel
var _forces: Label
var _end_turn_button: Button
var _deploy_vp_button: Button
var _hint: Label
var _income: Label
var _style: StyleBoxFlat


func _init() -> void:
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.12, 0.12, 0.16)
	_style.set_corner_radius_all(6)
	_style.set_content_margin_all(8)
	_style.border_width_left = 5
	add_theme_stylebox_override("panel", _style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	col.add_child(top)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 18)
	top.add_child(_title)

	_resources = RichTextLabel.new()
	_resources.bbcode_enabled = true
	_resources.fit_content = true
	_resources.autowrap_mode = TextServer.AUTOWRAP_OFF
	_resources.scroll_active = false
	_resources.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resources.add_theme_font_size_override("normal_font_size", 18)
	_resources.add_theme_font_size_override("bold_font_size", 20)
	top.add_child(_resources)

	_forces = Label.new()
	_forces.add_theme_font_size_override("font_size", 12)
	_forces.modulate = Color(0.8, 0.8, 0.85)
	col.add_child(_forces)

	_income = Label.new()
	_income.add_theme_font_size_override("font_size", 12)
	_income.modulate = Color(0.62, 0.82, 0.66)
	_income.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_income)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.modulate = Color(0.95, 0.88, 0.62)
	col.add_child(_hint)

	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 6)
	row.add_child(buttons)

	_end_turn_button = Button.new()
	_end_turn_button.text = "End turn"
	_end_turn_button.custom_minimum_size = Vector2(170, 44)
	_end_turn_button.add_theme_font_size_override("font_size", 17)
	_end_turn_button.pressed.connect(func(): action_requested.emit("end_turn"))
	buttons.add_child(_end_turn_button)

	_deploy_vp_button = Button.new()
	_deploy_vp_button.text = "Deploy for 1 VP"
	_deploy_vp_button.tooltip_text = "Your barracks are empty: the Deploy action gives 1 VP instead of a troop"
	_deploy_vp_button.custom_minimum_size = Vector2(170, 30)
	_deploy_vp_button.pressed.connect(func(): action_requested.emit("deploy_for_vp"))
	buttons.add_child(_deploy_vp_button)


func update_from_view(view: Dictionary, viewer_id: String) -> void:
	var p: Dictionary = (view["players"] as Dictionary)[viewer_id]
	var is_my_turn: bool = String(view["current_player"]) == viewer_id
	var legal: Dictionary = view.get("legal", {})
	var colour: Color = BoardPanel.PLAYER_COLORS.get(viewer_id, Color(0.6, 0.6, 0.6))

	_style.border_color = colour
	_title.text = EventLogPanel.player_name(viewer_id)
	_title.modulate = EventLogPanel.player_color(viewer_id)
	_resources.text = "Power [b][color=%s]%d[/color][/b]     Influence [b][color=%s]%d[/color][/b]     VP [b][color=%s]%d[/color][/b]" % [
		POWER_COLOR.to_html(false), int(p["power"]),
		INFLUENCE_COLOR.to_html(false), int(p["influence"]),
		VP_COLOR.to_html(false), int(p["vp_tokens"])]
	_forces.text = "Troops in barracks %d · Spies %d · Trophy hall %d · Hand %d · Deck %d · Discard %d · Inner Circle %d" % [
		int(p["troops_in_barracks"]), int(p["spies_in_barracks"]), int(p["trophy_hall_count"]),
		int(p["hand_size"]), int(p["deck_size"]), int(p["discard_size"]),
		(p.get("inner_circle", []) as Array).size()]

	_income.text = _describe_income(view.get("vp_income", {}))

	_deploy_vp_button.visible = bool(legal.get("deploy_for_vp", false))
	_end_turn_button.disabled = not bool(legal.get("end_turn", false))

	var pending: Dictionary = view.get("pending_decision", {})
	if bool(view.get("game_over", false)):
		_hint.text = "The game is over."
	elif not pending.is_empty():
		var decider := String(pending.get("player_id", ""))
		_hint.text = "Answer the card's question first." if decider == viewer_id \
			else "Waiting for %s to decide." % EventLogPanel.player_name(decider)
	elif not is_my_turn:
		_hint.text = "%s's turn." % EventLogPanel.player_name(String(view["current_player"]))
	else:
		_hint.text = describe_options(legal, p)


## Откуда возьмутся VP — иначе счёт растёт "сам собой".
static func _describe_income(income: Dictionary) -> String:
	if income.is_empty():
		return ""
	# VP по ходу партии дают только маркеры контроля и бонус гекса A2.
	# Контроль обычных локаций пойдёт в зачёт лишь в конце игры.
	var lines: Array[String] = []
	var per_turn: Array[String] = []
	if int(income.get("markers", 0)) > 0:
		var marked: Array = income.get("marker_total_control_sites", [])
		per_turn.append("+%d VP for control markers (%s)" % [
			int(income["markers"]), ", ".join(PackedStringArray(marked))])
	if int(income.get("cluster_bonus", 0)) > 0:
		per_turn.append("+%d VP for the A2 hex bonus" % int(income["cluster_bonus"]))
	var start: Array[String] = []
	if int(income.get("marker_influence", 0)) > 0:
		var ctrl: Array = income.get("marker_sites", [])
		start.append("+%d Influence for control markers (%s)" % [
			int(income["marker_influence"]), ", ".join(PackedStringArray(ctrl))])
	if int(income.get("cluster_power", 0)) + int(income.get("cluster_influence", 0)) > 0:
		start.append("+%d Power, +%d Influence for the A2 hex bonus" % [
			int(income.get("cluster_power", 0)), int(income.get("cluster_influence", 0))])
	var controlled: Array = income.get("controlled", [])
	lines.append("Sites controlled: %d (worth %d VP at game end)." % [
		controlled.size(), int(income.get("final_sites", 0))])
	if not per_turn.is_empty():
		lines.append("End of turn: " + ", ".join(PackedStringArray(per_turn)) + ".")
	if not start.is_empty():
		lines.append("Start of turn: " + ", ".join(PackedStringArray(start)) + ".")
	return "   ".join(PackedStringArray(lines))


## Что можно сделать прямо сейчас и сколько это стоит. Публичная — для тестов.
static func describe_options(legal: Dictionary, p: Dictionary = {}) -> String:
	if legal.is_empty():
		return ""
	var parts: Array[String] = []
	var cards: int = (legal.get("play_card", []) as Array).size()
	var deploys: int = (legal.get("deploy_slots", []) as Array).size()
	var kills: int = (legal.get("assassinate_slots", []) as Array).size()
	var market: int = (legal.get("recruit_market", []) as Array).size()
	var supply: int = (legal.get("recruit_supply", []) as Array).size()
	var spies: int = (legal.get("return_spy", []) as Array).size()
	if cards > 0:
		parts.append("play cards from your hand (%d)" % cards)
	if deploys > 0:
		parts.append("Deploy a troop, 1 Power (green rings: %d)" % deploys)
	if kills > 0:
		parts.append("Assassinate, 3 Power (orange rings: %d)" % kills)
	if spies > 0:
		parts.append("return an enemy spy, 3 Power (orange diamonds: %d)" % spies)
	if market > 0 or supply > 0:
		parts.append("recruit a bright card from the market (%d)" % (market + supply))
	if bool(legal.get("deploy_for_vp", false)):
		parts.append("Deploy for 1 VP (barracks empty)")
	if parts.is_empty():
		var note := "Nothing else to do — end your turn."
		if not p.is_empty() and (int(p.get("power", 0)) > 0 or int(p.get("influence", 0)) > 0):
			note = "Nothing affordable — end your turn (unspent Power and Influence are lost)."
		return note
	return "You can: " + "; ".join(parts) + "."
