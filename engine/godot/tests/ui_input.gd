extends SceneTree

## Проверка, что по интерфейсу можно КЛИКАТЬ мышью.
##
## Зачем отдельно: все остальные проверки дёргают сервер напрямую
## (`server.apply_intent(...)`) и потому не видят, доходит ли щелчок мыши до
## карты вообще. Ровно на этом и обожглись: в собранной игре нажатия по картам
## руки молча ничего не делали, хотя 394 теста и автопрогон партий проходили —
## сигнал от карты просто никто не слушал.
##
##   xvfb-run -a godot47 --path . --rendering-driver opengl3 \
##     --script res://tests/ui_input.gd
##
## Нужен экран: в headless событие мыши до GUI не доходит (проверено).
##
## Две ловушки, на которые тест сам наступил и о которых стоит помнить:
##   1. Координаты. Картинка масштабируется под окно (stretch keep), поэтому
##      координаты узла и координаты мыши — РАЗНЫЕ системы. Событие надо
##      подавать через root.get_screen_transform(), иначе клик уходит мимо.
##   2. Кадры. После перерисовки новые узлы получают размер и положение только
##      на СЛЕДУЮЩЕМ кадре: если мерить сразу, у карты нулевой rect и попасть
##      в неё нельзя. Поэтому тест идёт шагами с паузой в несколько кадров.

const SETTLE := 3  # кадров ожидания между шагами

var _passed := 0
var _failed := 0
var _screen: GameScreen
var _frame := 0
var _step := 0
var _next_step_at := SETTLE

# состояние, переносимое между шагами
var _hand_before := 0
var _resources_before := 0
var _discard_before := 0
var _turn_owner := ""


func _initialize() -> void:
	print("\n=== клики по интерфейсу ===\n")
	_screen = GameScreen.new(7)
	root.add_child(_screen)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < _next_step_at:
		return false
	_next_step_at = _frame + SETTLE
	_step += 1
	match _step:
		1: _step_click_hand_card()
		2: _step_check_hand_card()
		3: _step_prepare_market()
		4: _step_click_market_card()
		5: _step_click_end_turn()
		6: _step_check_end_turn()
		_:
			print("\n=== пройдено: %d, провалено: %d ===\n" % [_passed, _failed])
			quit(1 if _failed > 0 else 0)
			return true
	return false


# --- шаги --------------------------------------------------------------------

func _step_click_hand_card() -> void:
	var player := _current_player()
	var card: CardView = null
	for c: CardView in _all_cards():
		if c.clickable and player.deck.hand.has(c.card_id):
			card = c
			break
	check(card != null, "в руке есть карта, помеченная как кликабельная")
	if card == null:
		return
	check(_fully_visible(card), "карта руки видна целиком, по ней можно попасть мышью")
	_hand_before = player.deck.hand.size()
	_resources_before = player.power + player.influence
	_click(card)


func _step_check_hand_card() -> void:
	var player := _current_player()
	check(player.deck.hand.size() == _hand_before - 1,
		"после щелчка карта ушла из руки (было %d, стало %d)" % [_hand_before, player.deck.hand.size()])
	check(player.power + player.influence > _resources_before,
		"эффект карты применился: ресурсов стало больше (%d -> %d)"
			% [_resources_before, player.power + player.influence])


func _step_prepare_market() -> void:
	var player := _current_player()
	player.influence = 99
	_screen.refresh(StateView.for_player_with_pending(
		_screen.server.state, _screen.viewer_id, _screen.server.resolver.pending))
	_discard_before = player.deck.discard_pile.size()


func _step_click_market_card() -> void:
	var player := _current_player()
	var market: Array = _screen.server.state.market.display
	var card: CardView = null
	for c: CardView in _all_cards():
		if c.clickable and market.has(c.card_id) and not player.deck.hand.has(c.card_id) and _fully_visible(c):
			card = c
			break
	check(card != null, "в маркете есть карта, доступная и видимая целиком")
	if card == null:
		return
	_click(card)
	check(player.deck.discard_pile.size() == _discard_before + 1,
		"после щелчка по маркету карта легла в сброс (было %d, стало %d)"
			% [_discard_before, player.deck.discard_pile.size()])


func _step_click_end_turn() -> void:
	_turn_owner = _screen.server.state.current_player()
	var button := _find_button(_screen, "Завершить ход")
	check(button != null and not button.disabled, "кнопка завершения хода доступна")
	if button != null:
		_click(button)


func _step_check_end_turn() -> void:
	check(_screen.server.state.current_player() != _turn_owner,
		"после щелчка по кнопке ход перешёл к другому игроку (%s -> %s)"
			% [_turn_owner, _screen.server.state.current_player()])


# --- вспомогательное ---------------------------------------------------------

func _current_player() -> PlayerState:
	return _screen.server.state.players[_screen.server.state.current_player()]


func check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
		print("  ok    %s" % description)
	else:
		_failed += 1
		print("  ПРОВАЛ %s" % description)


func _click(control: Control) -> void:
	var point: Vector2 = root.get_screen_transform() * control.get_global_rect().get_center()
	for is_pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if is_pressed else 0
		ev.pressed = is_pressed
		ev.position = point
		ev.global_position = point
		Input.parse_input_event(ev)
	Input.flush_buffered_events()


## Виден ли узел целиком, с учётом обрезки прокруткой у предков: тыкать в
## наполовину срезанную карточку бессмысленно, живой игрок сначала прокрутит.
func _fully_visible(control: Control) -> bool:
	var rect: Rect2 = control.get_global_rect()
	if rect.size.x < 1.0 or rect.size.y < 1.0:
		return false
	var node: Node = control.get_parent()
	while node != null and node is Control:
		var c: Control = node
		if c.clip_contents and not c.get_global_rect().encloses(rect):
			return false
		node = c.get_parent()
	return true


func _all_cards() -> Array:
	var cards: Array = []
	_collect_cards(_screen, cards)
	return cards


func _collect_cards(node: Node, out: Array) -> void:
	if node is CardView:
		out.append(node)
	for child in node.get_children():
		_collect_cards(child, out)


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null
