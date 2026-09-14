class_name PlayerPanel
extends PanelContainer

## Планшет игрока: ресурсы текущего хода, бараки, трофи-холл, VP и кнопки
## действий, которые не привязаны к клику по доске или карте.
##
## Панель ничего не решает сама: какие кнопки доступны, ей сообщает срез
## состояния (view["legal"]), который посчитал сервер.

signal action_requested(kind: String)

var _title: Label
var _resources: Label
var _forces: Label
var _end_turn_button: Button
var _deploy_vp_button: Button
var _hint: Label
var _income: Label


func _init() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	add_child(col)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 15)
	col.add_child(_title)

	_resources = Label.new()
	_resources.add_theme_font_size_override("font_size", 14)
	col.add_child(_resources)

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
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.modulate = Color(0.75, 0.72, 0.6)
	col.add_child(_hint)

	var buttons := HBoxContainer.new()
	col.add_child(buttons)

	_deploy_vp_button = Button.new()
	_deploy_vp_button.text = "Deploy за 1 VP"
	_deploy_vp_button.tooltip_text = "Барак пуст: действие Deploy даёт 1 VP вместо войска (рулбук, стр. 12)"
	_deploy_vp_button.pressed.connect(func(): action_requested.emit("deploy_for_vp"))
	buttons.add_child(_deploy_vp_button)

	_end_turn_button = Button.new()
	_end_turn_button.text = "Завершить ход"
	_end_turn_button.pressed.connect(func(): action_requested.emit("end_turn"))
	buttons.add_child(_end_turn_button)


func update_from_view(view: Dictionary, viewer_id: String) -> void:
	var p: Dictionary = (view["players"] as Dictionary)[viewer_id]
	var is_my_turn: bool = String(view["current_player"]) == viewer_id
	var legal: Dictionary = view.get("legal", {})

	_title.text = "%s%s" % [viewer_id, "  — ваш ход" if is_my_turn else ""]
	_resources.text = "Power %d    Influence %d    VP %d" % [
		int(p["power"]), int(p["influence"]), int(p["vp_tokens"])]
	_forces.text = "войск в бараке %d · шпионов %d · трофи-холл %d · рука %d · колода %d · сброс %d" % [
		int(p["troops_in_barracks"]), int(p["spies_in_barracks"]), int(p["trophy_hall_count"]),
		int(p["hand_size"]), int(p["deck_size"]), int(p["discard_size"])]

	# Откуда возьмутся VP в конце хода — иначе счёт растёт "сам собой".
	var income: Dictionary = view.get("vp_income", {})
	if income.is_empty():
		_income.text = ""
	else:
		# VP по ходу партии дают только маркеры контроля и бонус гекса A2.
		# Контроль обычных локаций пойдёт в зачёт лишь в конце игры.
		var lines: Array[String] = []
		var per_turn: Array[String] = []
		if int(income.get("markers", 0)) > 0:
			var marked: Array = income.get("marker_total_control_sites", [])
			per_turn.append("+%d VP за маркеры контроля (%s)" % [
				int(income["markers"]), ", ".join(PackedStringArray(marked))])
		if int(income.get("cluster_bonus", 0)) > 0:
			per_turn.append("+%d VP за бонус гекса A2" % int(income["cluster_bonus"]))
		if per_turn.is_empty():
			lines.append("В конце хода VP не начислится.")
		else:
			lines.append("В конце хода: " + ", ".join(PackedStringArray(per_turn)) + ".")
		if int(income.get("marker_influence", 0)) > 0:
			var ctrl: Array = income.get("marker_sites", [])
			lines.append("В начале хода: +%d Influence за маркеры (%s)." % [
				int(income["marker_influence"]), ", ".join(PackedStringArray(ctrl))])
		if int(income.get("cluster_power", 0)) + int(income.get("cluster_influence", 0)) > 0:
			lines.append("В начале хода: +%d Power, +%d Influence за бонус гекса A2." % [
				int(income.get("cluster_power", 0)), int(income.get("cluster_influence", 0))])
		var controlled: Array = income.get("controlled", [])
		lines.append("Локаций под контролем: %d, в конце игры они дадут %d VP." % [
			controlled.size(), int(income.get("final_sites", 0))])
		_income.text = "\n".join(PackedStringArray(lines))

	_deploy_vp_button.disabled = not bool(legal.get("deploy_for_vp", false))
	_end_turn_button.disabled = not bool(legal.get("end_turn", false))

	if bool(view.get("game_over", false)):
		_hint.text = "Партия окончена."
	elif not is_my_turn:
		_hint.text = "Ход игрока %s." % view["current_player"]
	else:
		_hint.text = _describe_options(legal)


func _describe_options(legal: Dictionary) -> String:
	if legal.is_empty():
		return ""
	var parts: Array[String] = []
	var deploys: int = (legal.get("deploy_slots", []) as Array).size()
	var kills: int = (legal.get("assassinate_slots", []) as Array).size()
	var market: int = (legal.get("recruit_market", []) as Array).size()
	var supply: int = (legal.get("recruit_supply", []) as Array).size()
	var spies: int = (legal.get("return_spy", []) as Array).size()
	if deploys > 0:
		parts.append("Deploy: %d слотов (1 Power)" % deploys)
	if kills > 0:
		parts.append("Assassinate: %d целей (3 Power)" % kills)
	if spies > 0:
		parts.append("вернуть шпиона: %d (3 Power)" % spies)
	if market > 0 or supply > 0:
		parts.append("по карману карт: %d" % (market + supply))
	if parts.is_empty():
		return "Доступных действий нет — разыграйте карту или завершите ход."
	return "Доступно: " + "; ".join(parts)
