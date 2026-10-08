extends PanelContainer

## Просмотр реплея (этап Replay-2): полоса управления поверх верха доски и
## сама партия реплея. Экран партии (GameScreen в режиме реплея) только
## показывает — партию двигает эта полоса (ReplayBook.step / seek).
##
##   |<  <<  <  PLAY  >  >>  >|   TURN 12/48   x1 x2 x4   AUTO ■ ■ ■ ■   STATS EXIT
##   [=====шкала: отрезок на ход, цветом ходившего; щелчок/тяга — перемотка===]
##
## <, > — один ход реплея (действие или ответ на вопрос карты); <<, >> — к
## началу хода игрока; |<, >| — к раздаче и к концу. AUTO — смотреть глазами
## того, кто сейчас действует (видна его рука), цветной квадрат — глазами
## одного игрока. Клавиши: пробел — пауза, стрелки — шаг, с Shift — ход.
##
## Перемотка собирает партию заново с раздачи (ReplayBook.seek): назад
## движок не отматывается. Сводку ходов слева экран собирает заново из
## событий последних RECAP_TURNS ходов.

signal exit_requested
## STATS — экран статистики партии (Replay-3); воспроизведение встаёт на паузу.
signal stats_requested

const SPEEDS: Array[float] = [1.0, 2.0, 4.0]
## Секунд на один ход реплея при x1.
const STEP_SECONDS := 1.0
const RECAP_TURNS := 4
const BUTTON_H := 14.0
const TIMELINE_H := 7.0

var replay: Dictionary
var server: GameServer
## Сколько ходов реплея уже применено (0 — раздача, total() — конец).
var cursor := 0
var playing := false
var speed := 1.0
## Глазами того, кто действует (true), или одного игрока (watched).
var follow := true
var watched := ""
## Экран партии (GameScreen): show_replay(), replay_busy().
var screen: Control

var _starts: Array[int] = []
var _wait := 0.0
var _play: Button
var _turn_label: Label
var _speed_buttons: Array[Button] = []
var _eye_buttons: Dictionary = {}  # "auto" / цвет -> Button
var _timeline: Control
var _dragging := false
var _drag_to := 0


func _init(replay_data: Dictionary) -> void:
	replay = replay_data
	server = ReplayBook.start(replay)
	_starts = ReplayBook.turn_starts(replay)
	var seat := String((replay["header"] as Dictionary).get("seat", ""))
	if seat != "":
		watched = seat
	else:
		watched = String(ids()[0]) if not ids().is_empty() else ""
	add_theme_stylebox_override("panel", GameScreen.zone_style(2))
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 900

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	col.add_child(row)
	row.add_child(_button("|<", func(): seek(0)))
	row.add_child(_button("<<", func(): seek(_turn_before(cursor))))
	row.add_child(_button("<", func(): seek(cursor - 1)))
	_play = _button("PLAY", toggle_play, 34)
	row.add_child(_play)
	row.add_child(_button(">", func(): step_forward(true)))
	row.add_child(_button(">>", func(): seek(_turn_after(cursor))))
	row.add_child(_button(">|", func(): seek(total())))
	_turn_label = Label.new()
	_turn_label.custom_minimum_size.x = 62
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_turn_label)
	var speeds := ButtonGroup.new()
	for s in SPEEDS:
		var b := _button("x%d" % int(s), func(): speed = s, 18)
		b.toggle_mode = true
		b.button_group = speeds
		b.button_pressed = s == speed
		_speed_buttons.append(b)
		row.add_child(b)
	row.add_child(VSeparator.new())
	var eyes := ButtonGroup.new()
	var auto := _button("AUTO", func(): set_eye(""), 30)
	auto.toggle_mode = true
	auto.button_group = eyes
	_eye_buttons["auto"] = auto
	row.add_child(auto)
	for pid in ids():
		var b := _eye_button(String(pid))
		b.button_group = eyes
		_eye_buttons[String(pid)] = b
		row.add_child(b)
	row.add_child(VSeparator.new())
	row.add_child(_button("STATS", func():
		playing = false
		_sync()
		stats_requested.emit(), 34))
	row.add_child(_button("EXIT", func(): exit_requested.emit(), 30))

	_timeline = Control.new()
	_timeline.custom_minimum_size = Vector2(0, TIMELINE_H)
	_timeline.mouse_filter = Control.MOUSE_FILTER_STOP
	_timeline.draw.connect(_draw_timeline)
	_timeline.gui_input.connect(_on_timeline_input)
	col.add_child(_timeline)
	_eye_buttons["auto"].button_pressed = follow
	_sync()


func ids() -> Array:
	return (replay["header"] as Dictionary).get("ids", [])


func total() -> int:
	return (replay["intents"] as Array).size()


## Чьими глазами сейчас смотрим.
func viewer() -> String:
	if not follow or server.state.game_over:
		return watched
	if server.resolver.is_waiting():
		return server.resolver.pending.player_id
	return server.state.current_player()


## Номер хода игрока на позиции p: 0 — раздача (муллиган и стартовые
## локации), дальше 1..
func turn_at(p: int) -> int:
	var n := 0
	for i in range(1, _starts.size() - 1):
		if _starts[i] <= p:
			n = i
	return n


func turn_count() -> int:
	return _starts.size() - 2


func _turn_before(p: int) -> int:
	var best := 0
	for s in _starts:
		if s < p:
			best = s
	return best


func _turn_after(p: int) -> int:
	for s in _starts:
		if s > p:
			return s
	return total()


func toggle_play() -> void:
	if cursor >= total():
		seek(0)
	playing = not playing
	_wait = 0.0
	_sync()


## pid "" — AUTO (глазами действующего).
func set_eye(pid: String) -> void:
	follow = pid == ""
	if pid != "":
		watched = pid
	_show([], false)


## Один ход реплея вперёд, с анимацией (animate) или без.
func step_forward(animate: bool) -> void:
	if cursor >= total():
		playing = false
		_sync()
		return
	var result := ReplayBook.step(server, replay, cursor)
	cursor += 1
	_show(result["events"], animate)


## Перемотать на позицию p: партия заново с раздачи, сводка — из событий
## последних RECAP_TURNS ходов.
func seek(p: int) -> void:
	p = clampi(p, 0, total())
	var from := _starts[maxi(0, _starts.find(_turn_before(p + 1)) - RECAP_TURNS + 1)]
	server = ReplayBook.start(replay)
	var recap: Array = []
	for i in p:
		var result := ReplayBook.step(server, replay, i)
		if i >= from:
			recap.append_array(result["events"])
	cursor = p
	if cursor >= total():
		playing = false
	if screen != null:
		screen.replay_seeked(recap)
	_sync()


func _show(events: Array, animate: bool) -> void:
	if screen != null:
		screen.show_replay(events, animate)
	_sync()


func _process(delta: float) -> void:
	if not playing:
		return
	if screen != null and screen.replay_busy():
		return
	var real := delta / Engine.time_scale if Engine.time_scale > 0.0 else 0.0
	_wait -= real * speed
	if _wait > 0.0:
		return
	_wait = STEP_SECONDS
	step_forward(true)


## Клавиши реплея (их отдаёт экран партии). true — клавиша наша.
func handle_key(key: InputEventKey) -> bool:
	if not key.pressed:
		return key.keycode in [KEY_SPACE, KEY_LEFT, KEY_RIGHT]
	match key.keycode:
		KEY_SPACE:
			if not key.echo:
				toggle_play()
			return true
		KEY_LEFT:
			seek(_turn_before(cursor) if key.shift_pressed else cursor - 1)
			return true
		KEY_RIGHT:
			if key.shift_pressed:
				seek(_turn_after(cursor))
			else:
				step_forward(true)
			return true
	return false


func _sync() -> void:
	if _play == null:
		return
	_play.text = "PAUSE" if playing else "PLAY"
	var at := _shown_cursor()
	_turn_label.text = "SETUP" if turn_at(at) == 0 and at < total() \
		else "TURN %d/%d" % [turn_at(at), turn_count()]
	if at >= total():
		_turn_label.text = "END %d/%d" % [turn_count(), turn_count()]
	_timeline.queue_redraw()


# --- шкала ------------------------------------------------------------------

## Отрезок на каждый ход игрока цветом ходившего (раздача — серая), сыгранное
## ярче, позиция — светлая черта.
func _draw_timeline() -> void:
	var w := _timeline.size.x
	var h := _timeline.size.y
	var n := maxi(1, total())
	_timeline.draw_rect(Rect2(0, 0, w, h), PixelTheme.PANEL_LO)
	var intents: Array = replay["intents"]
	for i in range(_starts.size() - 1):
		var a := _starts[i]
		var b := _starts[i + 1]
		if b <= a:
			continue
		var x0 := floorf(w * a / n)
		var x1 := floorf(w * b / n)
		var colour := PixelTheme.TEXT_OFF
		if i > 0:
			var pid := String((intents[a] as Dictionary).get("player_id", ""))
			colour = BoardPanel.PLAYER_COLORS.get(pid, PixelTheme.TEXT_OFF)
		if a >= _shown_cursor():
			colour = colour.darkened(0.55)
		# Между ходами — щель в пиксель, чтобы ходы читались по отдельности.
		_timeline.draw_rect(Rect2(x0, 1, maxf(1.0, x1 - x0 - 1.0), h - 2), colour)
	var px := floorf(w * _shown_cursor() / n)
	_timeline.draw_rect(Rect2(clampf(px - 1.0, 0.0, w - 2.0), 0, 2, h), PixelTheme.TEXT)


## Щелчок или тяга по шкале: пока кнопка зажата, движется только черта (и
## надпись хода), партия пересобирается, когда кнопку отпустили — сборка
## длинной партии занимает доли секунды, на каждое движение мыши её не хватит.
func _on_timeline_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		_dragging = button.pressed
		_drag_to = _cursor_at(button.position.x)
		if not button.pressed and _drag_to != cursor:
			seek(_drag_to)
		_sync()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		_drag_to = _cursor_at(motion.position.x)
		_sync()


func _cursor_at(x: float) -> int:
	return roundi(clampf(x / maxf(1.0, _timeline.size.x), 0.0, 1.0) * total())


## Куда показывать черту шкалы: при тяге — куда тянут.
func _shown_cursor() -> int:
	return _drag_to if _dragging else cursor


# --- кнопки -----------------------------------------------------------------

func _button(text: String, action: Callable, width: float = 18.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, BUTTON_H)
	b.focus_mode = Control.FOCUS_NONE
	SetupScreen._style_button(b)
	b.pressed.connect(action)
	return b


## Квадрат цвета игрока: смотреть его глазами. Выбранный — с золотой рамкой.
func _eye_button(pid: String) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(BUTTON_H, BUTTON_H)
	var colour: Color = BoardPanel.PLAYER_COLORS.get(pid, Color.GRAY)
	b.add_theme_stylebox_override("normal", PixelTheme.button_box(colour.darkened(0.3), PixelTheme.BORDER))
	b.add_theme_stylebox_override("hover", PixelTheme.button_box(colour, PixelTheme.GOLD))
	b.add_theme_stylebox_override("pressed", PixelTheme.button_box(colour, PixelTheme.GOLD, 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.button_pressed = not follow and watched == pid
	b.pressed.connect(func(): set_eye(pid))
	return b
