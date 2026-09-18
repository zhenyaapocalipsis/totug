class_name PlayerPanel
extends PanelContainer

## Зона информации игрока-зрителя: ресурсы хода, VP, бараки, трофеи, колода.
## Узкая колонка — ряд «подпись … число». Откуда придут VP и Influence —
## во всплывающей подсказке зоны.
##
## Панель ничего не решает сама: всё берёт из среза состояния (view).

const POWER_COLOR := Color(0.95, 0.45, 0.35)
const INFLUENCE_COLOR := Color(0.45, 0.75, 0.98)
const VP_COLOR := Color(0.98, 0.82, 0.35)

var _title: Label
var _values: Dictionary = {}  # key -> Label
var _style: StyleBoxFlat


## Колонка узкая (112 px), поэтому строк мало и подписи короткие: парные
## величины стоят в одной строке через косую черту.
func _init() -> void:
	_style = GameScreen.zone_style(2)
	_style.border_width_top = 2
	add_theme_stylebox_override("panel", _style)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	head.add_child(_title)
	var vp_value := Label.new()
	vp_value.add_theme_color_override("font_color", VP_COLOR)
	head.add_child(vp_value)
	_values["vp"] = vp_value

	_add_row(col, "power", "Power", POWER_COLOR)
	_add_row(col, "influence", "Influence", INFLUENCE_COLOR)
	_add_row(col, "troops", "Troops/spies")
	_add_row(col, "deck", "Deck/disc")
	_add_row(col, "trophies", "Troph/circle")


func _add_row(parent: Control, key: String, caption: String,
		colour: Color = Color("f0e6d2")) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var name_label := Label.new()
	name_label.text = caption
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	row.add_child(name_label)
	var value := Label.new()
	value.add_theme_color_override("font_color", colour)
	row.add_child(value)
	_values[key] = value


func update_from_view(view: Dictionary, viewer_id: String) -> void:
	var p: Dictionary = (view["players"] as Dictionary)[viewer_id]
	_style.border_color = BoardPanel.PLAYER_COLORS.get(viewer_id, Color(0.6, 0.6, 0.6))
	_title.text = EventLogPanel.player_name(viewer_id).to_upper()
	_title.add_theme_color_override("font_color", EventLogPanel.player_color(viewer_id))

	(_values["power"] as Label).text = str(int(p["power"]))
	(_values["influence"] as Label).text = str(int(p["influence"]))
	(_values["vp"] as Label).text = "%d VP" % int(p["vp_tokens"])
	(_values["troops"] as Label).text = "%d/%d" % [
		int(p["troops_in_barracks"]), int(p["spies_in_barracks"])]
	(_values["deck"] as Label).text = "%d/%d" % [int(p["deck_size"]), int(p["discard_size"])]
	(_values["trophies"] as Label).text = "%d/%d" % [
		int(p["trophy_hall_count"]), (p.get("inner_circle", []) as Array).size()]

	tooltip_text = _describe_income(view.get("vp_income", {}))


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
	return "\n".join(PackedStringArray(lines))


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
	# Экран маленький, поэтому строка подсказки — телеграфная: действие,
	# цена и сколько целей. Подробности игрок видит на самой доске.
	if cards > 0:
		parts.append("play hand (%d)" % cards)
	if deploys > 0:
		parts.append("Deploy 1P: green rings (%d)" % deploys)
	if kills > 0:
		parts.append("Assassinate 3P: orange rings (%d)" % kills)
	if spies > 0:
		parts.append("return spy 3P (%d)" % spies)
	if market > 0 or supply > 0:
		parts.append("recruit (%d)" % (market + supply))
	if bool(legal.get("deploy_for_vp", false)):
		parts.append("Deploy for 1 VP")
	if parts.is_empty():
		var note := "Nothing else to do — end your turn."
		if not p.is_empty() and (int(p.get("power", 0)) > 0 or int(p.get("influence", 0)) > 0):
			note = "Nothing affordable — end your turn (Power and Influence are lost)."
		return note
	return " · ".join(parts)
