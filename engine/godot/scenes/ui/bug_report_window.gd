class_name BugReportWindow
extends Control

## Окно BUG REPORT (этап Bug-1): что случилось, снимок экрана, SEND. Отчёт
## (BugReport) сперва ложится в исходящие, потом уходит на сервер — сразу,
## если связь есть, иначе при возврате в главное меню.

const L10n := preload("res://scenes/localization.gd")

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
	L10n.bind(title, "bug.title")
	title.add_theme_color_override("font_color", PixelTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var ask := Label.new()
	L10n.bind(ask, "bug.question")
	col.add_child(ask)
	_text = TextEdit.new()
	_text.custom_minimum_size = TEXT_SIZE
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	L10n.bind(_text, "bug.example", {}, "placeholder_text")
	_text.text_changed.connect(func():
		if _text.text.length() > BugReport.TEXT_MAX:
			_text.text = _text.text.left(BugReport.TEXT_MAX)
			_text.set_caret_column(_text.get_line(_text.get_caret_line()).length()))
	col.add_child(_text)
	_attach = CheckBox.new()
	L10n.bind(_attach, "bug.attach")
	_attach.button_pressed = true
	col.add_child(_attach)
	var note := Label.new()
	L10n.bind(note, "bug.note")
	note.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	col.add_child(note)
	_status = Label.new()
	_status.custom_minimum_size.x = TEXT_SIZE.x
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.visible = false
	col.add_child(_status)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	_send = _button("bug.send", _on_send)
	row.add_child(_send)
	row.add_child(_button("bug.cancel", queue_free))


func _button(key: String, action: Callable) -> Button:
	var button := Button.new()
	L10n.bind(button, key)
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
	if key != null and key.keycode == KEY_ESCAPE and key.pressed and not key.echo:
		queue_free()
		get_viewport().set_input_as_handled()


## Пустой текст не шлём — без него отчёт почти бесполезен.
func _on_send() -> void:
	if _text.text.strip_edges() == "":
		_show_status("bug.describe", PixelTheme.TEXT_DIM)
		return
	var report := BugReport.make(_text.text, where, _shot if _attach.button_pressed else null, record, extra)
	var outbox := net.bug_outbox if net != null else BugReport.OUTBOX
	if not BugReport.queue(report, outbox):
		_show_status("bug.save_error", PixelTheme.TEXT_DIM)
		return
	_send.disabled = true
	_text.editable = false
	if net != null and net.is_connected_to_server():
		_sent_id = String(report["id"])
		net.bug_report_sent.connect(_on_sent)
		net.send_bug_reports()
		_show_status("bug.sending", PixelTheme.TEXT)
	else:
		_show_status("bug.queued", PixelTheme.GOLD)
		_close_soon(THANKS_SECONDS * 2)


func _on_sent(id: String, saved: bool) -> void:
	if id != _sent_id:
		return
	if saved:
		_show_status("bug.sent", PixelTheme.GOLD)
	else:
		_show_status("bug.limited", PixelTheme.TEXT_DIM)
	_close_soon(THANKS_SECONDS)


func _show_status(key: String, colour: Color) -> void:
	L10n.bind(_status, key)
	_status.add_theme_color_override("font_color", colour)
	_status.visible = true


func _close_soon(seconds: float) -> void:
	get_tree().create_timer(seconds).timeout.connect(queue_free)
