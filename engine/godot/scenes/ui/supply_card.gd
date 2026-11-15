extends CardView

## Compact supply face; inherits purchasing, refusal feedback and full preview.
var remaining := 0
var _caption: Label

func _init(cid: String) -> void:
	super(cid, 58, 44)
	hover_full = true
	var face := Control.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(face)
	_caption = Label.new()
	_caption.position = Vector2(2, 1)
	_caption.size = Vector2(54, 22)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.max_lines_visible = 2
	_caption.clip_text = true
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(_caption)
	_caption.text = CardText.field(card_id, "name").to_upper()

func _language_changed() -> void:
	super._language_changed()
	if _caption != null:
		_caption.text = CardText.field(card_id, "name").to_upper()

func _draw() -> void:
	draw_set_transform(_shake_offset())
	var border := PixelTheme.GOLD if clickable else PixelTheme.BORDER
	draw_rect(Rect2(Vector2.ZERO, size), PixelTheme.PANEL_LO)
	draw_rect(Rect2(Vector2.ZERO, size), border, false)
	var price := CardLibrary.card_cost(card_id)
	if live:
		price = int(live_data.get(card_id, {}).get("cost", price))
	if cost_now >= 0:
		price = cost_now
	var font := get_theme_default_font()
	draw_string(font, Vector2(2, 32), "%d INF" % price, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelTheme.SIZE, COST_COLOR)
	draw_string(font, Vector2(2, 42), "x%d" % remaining, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelTheme.SIZE, PixelTheme.TEXT if remaining > 0 else PixelTheme.DANGER)
	if is_shaking():
		draw_rect(Rect2(Vector2.ZERO, size), Color(PixelTheme.DANGER, 0.3))
