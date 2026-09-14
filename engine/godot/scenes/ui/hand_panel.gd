class_name HandPanel
extends PanelContainer

## Рука игрока-зрителя. Карта кликается, только если сервер назвал её в
## legal["play_card"] — то есть в свой ход и когда не ждём чьё-то решение.

signal card_clicked(card_id: String)

var _row: HBoxContainer
var _title: Label


func _init() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.14)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	add_child(col)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 13)
	_title.modulate = Color(0.8, 0.8, 0.85)
	col.add_child(_title)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 166)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 8)
	scroll.add_child(_row)


func update_from_view(view: Dictionary, viewer_id: String) -> void:
	for child in _row.get_children():
		child.queue_free()

	var p: Dictionary = (view["players"] as Dictionary)[viewer_id]
	var hand: Array = p.get("hand", [])
	var playable: Array = (view.get("legal", {}) as Dictionary).get("play_card", [])
	_title.text = "%s's hand — %d card%s%s" % [EventLogPanel.player_name(viewer_id), hand.size(),
		"" if hand.size() == 1 else "s", "  (click a bright card to play it)" if not playable.is_empty() else ""]

	for cid: String in hand:
		var card := CardView.new(cid, 146, 160, 6)
		card.set_clickable(playable.has(cid))
		card.pressed.connect(func(clicked: String): card_clicked.emit(clicked))
		_row.add_child(card)
