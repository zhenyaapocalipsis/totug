class_name ChatPanel
extends PanelContainer

## Зона чата: две вкладки — Chat и Log (журнал событий).
##
## Сети пока нет, поэтому сообщение просто появляется в своей же истории.
## Для сетевой игры экран подпишется на message_sent и будет пересылать
## текст, а входящие сообщения добавлять через add_message().

signal message_sent(text: String)

var log_panel: EventLogPanel

var _tabs: TabContainer
var _history: RichTextLabel
var _input: LineEdit


func _init() -> void:
	add_theme_stylebox_override("panel", GameScreen.zone_style(1))

	_tabs = TabContainer.new()
	var empty := StyleBoxEmpty.new()
	_tabs.add_theme_stylebox_override("panel", empty)
	add_child(_tabs)

	var chat := VBoxContainer.new()
	chat.name = "Chat"
	chat.add_theme_constant_override("separation", 2)
	_tabs.add_child(chat)

	_history = RichTextLabel.new()
	_history.bbcode_enabled = true
	_history.scroll_following = true
	_history.selection_enabled = true
	_history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_history.text = "[color=#77748a][i]Local until online play arrives.[/i][/color]"
	chat.add_child(_history)

	_input = LineEdit.new()
	_input.placeholder_text = "Message, Enter to send"
	_input.text_submitted.connect(_on_submitted)
	chat.add_child(_input)

	log_panel = EventLogPanel.new()
	log_panel.name = "Log"
	_tabs.add_child(log_panel)
	_tabs.current_tab = 1  # в локальной партии журнал полезнее


func _on_submitted(text: String) -> void:
	var clean := text.strip_edges()
	_input.clear()
	if clean == "":
		return
	message_sent.emit(clean)


## Сетевая партия: чат настоящий, открываем его вкладку первой.
func set_online() -> void:
	_history.text = "[color=#77748a][i]Chat with the other players. Enter to send.[/i][/color]"
	_tabs.current_tab = 0


func add_message(player_id: String, text: String) -> void:
	_history.append_text("\n[b][color=%s]%s:[/color][/b] %s" % [
		EventLogPanel.player_color(player_id).to_html(false),
		EventLogPanel.player_name(player_id), EventLogPanel._escape(text)])
