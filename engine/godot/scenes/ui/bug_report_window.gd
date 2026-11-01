class_name BugReportWindow
extends Control

## Окно BUG REPORT (этап Bug-1): что случилось, снимок экрана, SEND. Отчёт
## (BugReport) сперва ложится в исходящие, потом уходит на сервер — сразу,
## если связь есть, иначе при возврате в главное меню.

const TEXT_SIZE := Vector2(300, 84)
const BUTTON_SIZE := Vector2(70, 16)
## Сколько показывать «спасибо» перед тем, как окно закроется само.
const THANKS_SECONDS := 1.5

var where := "menu"
var record: Dictionary = {}
var extra: Dictionary = {}
var net: NetSession
var _shot: Image
var _text: TextEdit
var _attach: CheckBox
var _status: Label
var _send: Button
var _sent_id := ""


## Снимок экрана — до окна (cover — что спрятать на кадр снимка, например меню
## по Esc), потом окно поверх parent.
static func open(parent: Node, session: NetSession, place: String, game_record: Dictionary = {},
		info: Dictionary = {}, cover: CanvasItem = null) -> BugReportWindow:
	var window := BugReportWindow.new()
	window.net = session
	window.where = place
	window.record = game_record
	window.extra = info
	window._capture_then_show(parent, cover)
	return window


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PixelTheme.theme()
	z_index = 1200
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var dim := ColorRect.new()
	dim.color = PixelTheme.DIM
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", GameScreen.zone_style(6))
	centre.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)

	var title := Label.new()
	title.text = "BUG REPORT"
	title.add_theme_color_override("font_color", PixelTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var ask := Label.new()
	ask.text = "What went wrong? What did you do just before it?"
	col.add_child(ask)
	_text = TextEdit.new()
	_text.custom_minimum_size = TEXT_SIZE
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.placeholder_text = "e.g. I played Drow Negotiator and could not pick a troop"
	_text.text_changed.connect(func():
		if _text.text.length() > BugReport.TEXT_MAX:
			_text.text = _text.text.left(BugReport.TEXT_MAX)
			_text.set_caret_column(_text.get_line(_text.get_caret_line()).length()))
	col.add_child(_text)
	_attach = CheckBox.new()
	_attach.text = "Attach screenshot"
	_attach.button_pressed = true
	col.add_child(_attach)
	var note := Label.new()
	note.text = "The game log and the game record are attached too."
	note.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	col.add_child(note)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.visible = false
	col.add_child(_status)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	_send = _button("SEND", _on_send)
	row.add_child(_send)
	row.add_child(_button("CANCEL", queue_free))


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	SetupScreen._style_button(button)
	button.pressed.connect(action)
	return button


func _capture_then_show(parent: Node, cover: CanvasItem) -> void:
	var was_visible := cover != null and cover.visible
	if was_visible:
		cover.visible = false
		await RenderingServer.frame_post_draw
	_shot = parent.get_viewport().get_texture().get_image()
	if was_visible and is_instance_valid(cover):
		cover.visible = true
	if is_instance_valid(parent):
		parent.add_child(self)
		_text.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key.keycode == KEY_ESCAPE and key.pressed and not key.echo:
		queue_free()
		get_viewport().set_input_as_handled()


## Пустой текст не шлём — без него отчёт почти бесполезен.
func _on_send() -> void:
	if _text.text.strip_edges() == "":
		_show_status("Please describe the problem first.", PixelTheme.TEXT_DIM)
		return
	var report := BugReport.make(_text.text, where, _shot if _attach.button_pressed else null, record, extra)
	var outbox := net.bug_outbox if net != null else BugReport.OUTBOX
	if not BugReport.queue(report, outbox):
		_show_status("Could not save the report.", PixelTheme.TEXT_DIM)
		return
	_send.disabled = true
	_text.editable = false
	if net != null and net.is_connected_to_server():
		_sent_id = String(report["id"])
		net.bug_report_sent.connect(_on_sent)
		net.send_bug_reports()
		_show_status("Sending...", PixelTheme.TEXT)
	else:
		_show_status("Saved. It will be sent when you are back in the main menu.", PixelTheme.GOLD)
		_close_soon(THANKS_SECONDS * 2)


func _on_sent(id: String, saved: bool) -> void:
	if id != _sent_id:
		return
	if saved:
		_show_status("Report sent. Thank you!", PixelTheme.GOLD)
	else:
		_show_status("Too many reports. Try again later.", PixelTheme.TEXT_DIM)
	_close_soon(THANKS_SECONDS)


func _show_status(text: String, colour: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", colour)
	_status.visible = true


func _close_soon(seconds: float) -> void:
	get_tree().create_timer(seconds).timeout.connect(func():
		if is_instance_valid(self):
			queue_free())
