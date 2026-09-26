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
var _refused_card: CardView = null
var _played_view: CardView = null
var _capture_site := ""
var _move_to := ""


func _initialize() -> void:
	print("\n=== клики по интерфейсу ===\n")
	_screen = GameScreen.new(7)
	root.add_child(_screen)
	# Партия начинается с выбора стартовых локаций; пока он не сделан, карты и
	# кнопки заблокированы. Выбираем первые варианты — клики проверяем дальше.
	var guard := 0
	while _screen.server.resolver.is_waiting() and guard < 10:
		guard += 1
		var pd: PendingDecision = _screen.server.resolver.pending
		_screen.send(Intent.make_decision(pd.player_id, pd.legal_options[0]))


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < _next_step_at:
		return false
	# Первый шаг ждёт, пока рука доедет: карты раздачи выезжают снизу друг за
	# другом и в первые кадры ещё не на своих местах.
	if _step == 0:
		var hand := _hand_panel()
		if hand == null or not hand.is_settled():
			_next_step_at = _frame + 1
			return false
	_next_step_at = _frame + SETTLE
	_step += 1
	match _step:
		1: _step_hover_hand()
		2: _step_check_hover()
		3: _step_alt_down()
		4: _step_check_alt_preview()
		5: _step_alt_up()
		6: _step_check_alt_gone()
		7: _step_click_hand_card()
		8: _step_check_hand_card()
		9: _step_open_pile()
		10: _step_check_pile()
		11: _step_click_locked_market()
		12: _step_check_refusal()
		13: _step_prepare_market()
		14: _step_click_market_card()
		15: _step_click_end_turn()
		16: _step_check_end_turn()
		17: _step_timer_expire()
		18: _step_check_timer()
		19: _step_capture_site()
		20: _step_check_capture()
		21: _step_deploy_flight()
		22: _step_check_deploy_flight()
		23: _step_capture_by_flight()
		24: _step_check_capture_waits()
		25: _step_move_and_return()
		26: _step_check_move_and_return()
		_:
			print("\n=== пройдено: %d, провалено: %d ===\n" % [_passed, _failed])
			quit(1 if _failed > 0 else 0)
			return true
	return false


# --- шаги --------------------------------------------------------------------

## Рука целиком лежит на экране: наводим мышь прямо на карту, она должна
## слегка выдвинуться вверх, но НЕ увеличиться — увеличение только по Alt.
func _step_hover_hand() -> void:
	var card := _playable_hand_card()
	check(card != null, "в руке есть карта, помеченная как кликабельная")
	if card == null:
		return
	check(_on_screen(card), "карта руки целиком на экране и не выходит за нижний край (%s в %s)"
		% [card.get_global_rect(), _screen.get_global_rect()])
	_move_mouse(card.get_global_rect().get_center())
	_next_step_at = _frame + 12  # анимация выдвижения карты


func _step_check_hover() -> void:
	var hand := _hand_panel()
	check(hand != null and hand.hovered_index() >= 0, "карта под курсором выдвинулась из ряда")
	check(not CardPreview.active.has_preview(),
		"без Alt увеличенной копии нет — она больше не закрывает экран сама собой")


func _step_alt_down() -> void:
	_key(KEY_ALT, true)


func _step_check_alt_preview() -> void:
	check(CardPreview.active.has_preview(), "с зажатым Alt карта под курсором увеличилась")


func _step_alt_up() -> void:
	_key(KEY_ALT, false)


func _step_check_alt_gone() -> void:
	check(not CardPreview.active.has_preview(), "Alt отпущен — увеличенная копия пропала")


## Стопки сброса и Внутреннего круга открывают список карт.
func _step_open_pile() -> void:
	var zone: PileZone = _find_pile(_screen)
	check(zone != null, "на экране есть зона стопки")
	if zone != null:
		_click(zone)


func _step_check_pile() -> void:
	check(_screen._pile_dialog.visible, "щелчок по стопке открыл список её карт")
	_screen._pile_dialog.close_pile()
	check(not _screen._pile_dialog.visible, "список закрывается")


func _hand_panel() -> HandPanel:
	for child in _screen.get_children():
		if child is HandPanel:
			return child
	return null


func _find_pile(node: Node) -> PileZone:
	if node is PileZone:
		return node
	for child in node.get_children():
		var found := _find_pile(child)
		if found != null:
			return found
	return null


func _key(keycode: int, is_pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = is_pressed
	ev.alt_pressed = is_pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _playable_hand_card() -> CardView:
	var player := _current_player()
	for c: CardView in _all_cards():
		if c.clickable and player.deck.hand.has(c.card_id) and c.get_parent() is HandPanel:
			return c
	return null


## Играем САМУЮ ЛЕВУЮ карту руки: в руке три одинаковых Noble, и улететь
## должна именно она, а не одноимённая соседка справа.
func _step_click_hand_card() -> void:
	var player := _current_player()
	var card: CardView = null
	for c: CardView in _all_cards():
		if not c.clickable or not (c.get_parent() is HandPanel):
			continue
		if not player.deck.hand.has(c.card_id):
			continue
		if card == null or c.position.x < card.position.x:
			card = c
	_played_view = card
	if card == null:
		return
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
	check(_has_floating_text(), "над плашкой ресурсов всплыла цифра изменения")
	check(_screen._res_power.is_animating() or _screen._res_influence.is_animating(),
		"счётчик ресурсов накручивается и вспыхивает")
	var hand := _hand_panel()
	check(hand != null and hand.leaving_cards().has(_played_view),
		"улетает именно сыгранная карта, а не одноимённая соседка")


## Есть ли на экране хоть одна всплывающая цифра.
func _has_floating_text() -> bool:
	for child in _screen.get_children():
		if child is FloatingText:
			return true
	return false


## Карта маркета не по карману: щелчок по ней не покупает её, но и не молчит —
## карта дёргается и краснеет. Искать карту можно сразу после refresh: слоты
## маркета живут всю партию, карта в слоте меняется на месте.
func _step_click_locked_market() -> void:
	var player := _current_player()
	player.influence = 0
	_screen.refresh(StateView.for_player_with_pending(
		_screen.server.state, _screen.viewer_id, _screen.server.resolver.pending))
	_discard_before = player.deck.discard_pile.size()
	_refused_card = null
	for c: CardView in _all_cards():
		if not c.clickable and _in_market(c) and _fully_visible(c):
			_refused_card = c
			break
	check(_refused_card != null, "в маркете есть карта, которая сейчас не по карману")
	if _refused_card != null:
		_click(_refused_card)


func _step_check_refusal() -> void:
	if _refused_card == null:
		return
	check(_refused_card.is_shaking(), "щелчок по недоступной карте тряхнул её")
	check(_current_player().deck.discard_pile.size() == _discard_before,
		"недоступная карта не куплена — в сбросе ничего не прибавилось")


func _in_market(card: CardView) -> bool:
	var node: Node = card.get_parent()
	while node != null:
		if node is MarketPanel:
			return true
		node = node.get_parent()
	return false


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
	var arriving := false
	for c: CardView in _all_cards():
		if _in_market(c) and c.is_arriving():
			arriving = true
			break
	check(arriving, "на место купленной карты новая въехала со вспышкой")
	var flying := false
	for child in _screen.get_children():
		if child is CardView:   # копия в полёте лежит прямо на экране
			flying = true
			break
	check(flying, "купленная карта полетела в стопку сброса")


func _step_click_end_turn() -> void:
	_turn_owner = _screen.server.state.current_player()
	# Кнопку берём по ссылке, а не по надписи: сама кнопка пустая, «END TURN» и
	# чей ход лежат поверх неё отдельными Label (решение владельца, 2026-09-19).
	# Поиск по тексту находил её раньше и молча перестал — отсюда два провала.
	var button: Button = _screen._end_turn_button
	check(button != null and not button.disabled, "кнопка завершения хода доступна")
	if button != null and not button.disabled:
		_click(button)


func _step_check_end_turn() -> void:
	check(_screen.server.state.current_player() != _turn_owner,
		"после щелчка по кнопке ход перешёл к другому игроку (%s -> %s)"
			% [_turn_owner, _screen.server.state.current_player()])


## Таймер хода: обнуляем его и ждём, что ход завершится сам.
func _step_timer_expire() -> void:
	_turn_owner = _screen.server.state.current_player()
	_screen._time_left = 0.0


func _step_check_timer() -> void:
	check(_screen.server.state.current_player() != _turn_owner,
		"время вышло — ход завершился сам (%s -> %s)"
			% [_turn_owner, _screen.server.state.current_player()])


## Локация сменила хозяина — доска должна вспыхнуть её обводкой и дёрнуться.
## Отдельного события «захват» движок не шлёт: контроль считается из
## расстановки войск, поэтому расставляем войска прямо в состоянии и обновляем
## вид — ровно так это и приходит из сети.
func _step_capture_site() -> void:
	var state := _screen.server.state
	var me := _screen.viewer_id
	var target := ""
	for site_id: String in state.graph.sites.keys():
		if state.control.controller_of(site_id, state.troops) != me:
			target = site_id
			break
	check(target != "", "нашлась локация, которую зритель ещё не контролирует")
	if target == "":
		return
	for slot_id in state.graph.slots_of_site(target):
		state.troops[slot_id] = me
	_screen.refresh(StateView.for_player_with_pending(
		state, me, _screen.server.resolver.pending))


func _step_check_capture() -> void:
	var board: BoardPanel = _screen._board_panel
	check(board.capture_flashes() > 0, "захваченная локация вспыхнула на доске")
	check(board.is_shaking(), "доска дёрнулась на захвате")
	check(board.spark_count() > 0, "из захваченной локации полетели искры")


## Войско и шпион вылетают из барака: пока летят, доска их не рисует, над
## экраном висят летящие фишки. Событие подаём сами — так же оно приходит и
## из сети, и от своего хода.
func _step_deploy_flight() -> void:
	var state := _screen.server.state
	var me := _screen.viewer_id
	var slot := ""
	for slot_id: String in state.graph.slots.keys():
		if state.troops.get(slot_id, "") == "":
			slot = slot_id
			break
	var site: String = state.graph.sites.keys()[0]
	state.troops[slot] = me
	state.spies[site] = [me]
	_screen.refresh(StateView.for_player_with_pending(
		state, me, _screen.server.resolver.pending))
	_screen._react_to_events([
		{"type": "deploy", "player_id": me, "slot_id": slot},
		{"type": "place_spy", "player_id": me, "site_id": site}])


func _step_check_deploy_flight() -> void:
	var board: BoardPanel = _screen._board_panel
	check(board.arriving_count() == 2, "войско и шпион ещё летят — доска их не рисует")
	var flying := 0
	for child in _screen.get_children():
		if child is FlyingToken:
			flying += 1
	check(flying == 2, "над экраном летят две фишки из барака (%d)" % flying)
	# Посадка: фишки встают на места со вспышкой и расходящимся кольцом.
	for key: String in board._arriving.keys():
		board.land(key, key.begins_with("troop|"))
	check(board.arriving_count() == 0 and board.impact_count() == 2,
		"на посадке от каждой фишки пошла ударная волна (%d)" % board.impact_count())


## Войско, которое берёт локацию, ещё летит — захват не должен вспыхнуть
## раньше, чем оно приземлится.
func _step_capture_by_flight() -> void:
	var state := _screen.server.state
	var me := _screen.viewer_id
	_capture_site = ""
	for site_id: String in state.graph.sites.keys():
		var empty := true
		for slot_id in state.graph.slots_of_site(site_id):
			if state.troops.get(slot_id, "") != "":
				empty = false
		if empty and state.control.controller_of(site_id, state.troops) == "":
			_capture_site = site_id
			break
	check(_capture_site != "", "нашлась пустая ничья локация")
	if _capture_site == "":
		return
	var slot := String(state.graph.slots_of_site(_capture_site)[0])
	state.troops[slot] = me
	_screen.refresh(StateView.for_player_with_pending(
		state, me, _screen.server.resolver.pending))
	_screen._react_to_events([{"type": "deploy", "player_id": me, "slot_id": slot}])


func _step_check_capture_waits() -> void:
	var board: BoardPanel = _screen._board_panel
	check(not board._captures.has(_capture_site), "пока войско летит, захват не вспыхнул")
	for key: String in board._arriving.keys():
		board.land(key)
	check(board._captures.has(_capture_site), "войско приземлилось — захват вспыхнул")


## Move и Return: войско перелетает с места на место (доска прячет его на
## новом месте до посадки), вернутое войско улетает в барак.
func _step_move_and_return() -> void:
	var state := _screen.server.state
	var me := _screen.viewer_id
	var mine := ""
	var empty: Array[String] = []
	for slot_id: String in state.graph.slots.keys():
		var owner := String(state.troops.get(slot_id, ""))
		if owner == me and mine == "":
			mine = slot_id
		elif owner == "":
			empty.append(slot_id)
	check(mine != "" and empty.size() >= 2, "есть своё войско и свободные места")
	if mine == "" or empty.size() < 2:
		return
	_move_to = empty[0]
	state.troops[mine] = ""
	state.troops[_move_to] = me
	var back := empty[1]   # это войско поставим и тут же вернём в барак
	var before := _flying_tokens()
	_screen.refresh(StateView.for_player_with_pending(
		state, me, _screen.server.resolver.pending))
	_screen._react_to_events([
		{"type": "move_troop", "player_id": me, "from": mine, "to": _move_to, "owner": me},
		{"type": "return_troop", "slot_id": back, "owner": me}])
	check(_flying_tokens() - before == 2, "move и return запустили по полёту (%d)"
		% (_flying_tokens() - before))


func _step_check_move_and_return() -> void:
	var board: BoardPanel = _screen._board_panel
	check(board._arriving.has("troop|" + _move_to), "перемещённое войско ещё летит к новому месту")


func _flying_tokens() -> int:
	var n := 0
	for child in _screen.get_children():
		if child is FlyingToken and not child.is_queued_for_deletion():
			n += 1
	return n


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


func _move_mouse(point_in_screen: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	var point: Vector2 = root.get_screen_transform() * point_in_screen
	ev.position = point
	ev.global_position = point
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _on_screen(control: Control) -> bool:
	return _fully_visible(control) and _screen.get_global_rect().encloses(control.get_global_rect())


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
