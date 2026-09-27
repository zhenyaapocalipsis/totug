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
var _supplant_slot := ""
var _kill_slot := ""
## Фишки, летевшие до убийств: трофеи — только новые.
var _flights_before: Array = []
var _feed_before := 0
var _feed_cells_before := 0
var _foe_kills := 0
var _foe_vp := 0
var _foe_tags: Array[String] = []
var _foe_discard := ""
var _market_before: Array = []
var _ic_before := 0
var _trophy_hall := ""


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
		27: _step_showcase()
		28: _step_check_showcase()
		29: _step_recap()
		30: _step_check_recap()
		31: _step_hover_feed()
		32: _step_check_hover_feed()
		33: _step_hover_market()
		34: _step_check_hover_market()
		35: _step_forced_discard()
		36: _step_check_forced_discard()
		37: _step_market_devour()
		38: _step_check_market_devour()
		39: _step_inner_circle()
		40: _step_check_inner_circle()
		41: _step_promote_discard()
		42: _step_check_promote_discard()
		43: _step_choose_player()
		44: _step_click_player()
		45: _step_check_choose_player()
		46: _step_trophy()
		47: _step_click_trophy()
		48: _step_check_trophy()
		49: _step_kills()
		50: _step_check_kills()
		51: _step_hover_kill_row()
		52: _step_check_kill_row()
		53: _step_check_row_left()
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
		"в руке без Alt полной карты нет — по наведению она только у рынка и сводки")


func _step_alt_down() -> void:
	_key(KEY_ALT, true)


func _step_check_alt_preview() -> void:
	check(CardPreview.active.preview_size().x > CardView.PIXEL_SIZE.x,
		"с зажатым Alt карта руки показалась крупно (%s)" % CardPreview.active.preview_size())


func _step_alt_up() -> void:
	_key(KEY_ALT, false)


func _step_check_alt_gone() -> void:
	check(not CardPreview.active.has_preview(), "Alt отпущен — копия карты руки пропала")


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


## Витрина: чужая покупка, промоут верхней карты и съеденная карта рынка
## встают в очередь крупного показа; своя покупка щелчком — нет.
func _step_showcase() -> void:
	var me := _screen.viewer_id
	var foe := ""
	for pid in _screen.server.state.turn_order:
		if pid != me:
			foe = pid
	var cid := _screen._market_panel.card_id_at(0)
	_screen._react_to_events([
		{"type": "recruit", "player_id": me, "market_index": 0, "card_id": cid},
		{"type": "recruit", "player_id": foe, "market_index": 0, "card_id": cid},
		{"type": "promote", "player_id": me, "card_id": cid, "from": "top_of_deck"},
		{"type": "devour", "player_id": foe, "card_id": cid, "source": "market"}])


func _step_check_showcase() -> void:
	var showcase: CardShowcase = _screen._showcase
	check(showcase.is_busy() and showcase.queued() == 3,
		"витрина показывает чужую покупку, промоут и devour, свою покупку — нет (%d)" % showcase.queued())
	showcase.skip()
	check(showcase.queued() == 3, "промотка уводит карту, а не выкидывает её из очереди")


## Сводка ходов слева: каждая покупка, промоут и devour — любого игрока —
## сразу встаёт картой в колонку; конец хода начинает новый блок.
func _step_recap() -> void:
	var me := _screen.viewer_id
	var foe := ""
	for pid in _screen.server.state.turn_order:
		if pid != me:
			foe = pid
	var cid := _screen._market_panel.card_id_at(1)
	_feed_before = _screen._feed.card_count()
	_feed_cells_before = _screen._feed.group_count()
	# Длинное имя из профиля: заголовок хода должен ужаться до одного имени.
	PlayerProfile.seats[foe] = {"name": "Jekadiscoteka"}
	var played := String(_screen.server.state.players[foe].deck.hand[0])
	# Покупка раньше розыгрышей и devour между ними: группы всё равно
	# встают в порядке PLAYED, BOUGHT, DEVOURED.
	_screen._react_to_events([
		{"type": "turn_ended", "player_id": me, "game_over": false},
		{"type": "recruit", "player_id": foe, "market_index": 1, "card_id": cid},
		{"type": "play_card", "player_id": foe, "card_id": played},
		{"type": "devour", "player_id": foe, "card_id": cid, "source": "market"},
		{"type": "play_card", "player_id": foe, "card_id": played}])
	# Сброс, убийства и VP — только в сводку: анимаций для выдуманных слотов
	# не нужно.
	_screen._note_recap([
		{"type": "force_discard", "player_id": me, "card_id": played},
		{"type": "give_insane_outcast", "player_id": me, "count": 1},
		{"type": "removed_to_supply", "player_id": foe, "card_id": Supplies.INSANE_OUTCAST},
		{"type": "assassinate", "player_id": foe, "slot_id": "x", "victim": GameState.WHITE},
		{"type": "assassinate", "player_id": foe, "slot_id": "y", "victim": me},
		{"type": "gain_vp", "player_id": foe, "amount": 1},
		{"type": "vp_income", "player_id": foe, "granted": 2, "total_vp": 3}])
	_foe_tags = _screen._feed.last_block_tags()
	_foe_kills = _screen._feed.last_stat("kill")
	_foe_vp = _screen._feed.last_stat("vp")
	_screen._react_to_events([
		{"type": "turn_ended", "player_id": foe, "game_over": false},
		{"type": "recruit", "player_id": me, "market_index": 1, "card_id": cid}])


func _step_check_recap() -> void:
	var feed: TurnFeed = _screen._feed
	check(feed.visible and feed.card_count() - _feed_before == 8,
		"сводка слева пополнилась восемью картами (%d)" % (feed.card_count() - _feed_before))
	check(feed.group_count() - _feed_cells_before == 7,
		"сыгранные за ход карты легли одной группой (%d групп)" % (feed.group_count() - _feed_cells_before))
	var me_id := _screen.viewer_id
	check(_foe_tags == (["PLAYED", "BOUGHT", "OUTCAST:" + me_id, "DEVOURED", "TO SUPPLY", "DISCARDED:" + me_id] as Array[String]),
		"группы хода не перемешаны, чужие сброс и изгой — в блоке ходящего: %s" % [_foe_tags])
	check(_foe_kills == 2 and _foe_vp == 3,
		"строки действий: KILL %d, +%d VP" % [_foe_kills, _foe_vp])
	check(feed.get_global_rect().end.y >= _screen.size.y - GameScreen.MARGIN - 1.0,
		"сводка слева идёт до низа экрана")
	var fits := true
	for block in feed._blocks:
		var label: Label = block.title
		var w := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, label.get_theme_font_size("font_size")).x
		if w > TurnFeed.CARD.x and label.text.ends_with("'S TURN"):
			fits = false
	check(fits, "длинное имя не обрезает заголовок хода — остаётся одно имя")
	PlayerProfile.seats.clear()
	check(feed.get_global_rect().end.x < _screen._board_area.get_global_rect().position.x,
		"сводка стоит слева от доски и её не закрывает")


## Наведение на карту сводки слева — полная карта по центру, без Alt.
func _step_hover_feed() -> void:
	var feed: TurnFeed = _screen._feed
	var card: CardView = null
	for c in feed.find_children("*", "CardView", true, false):
		if c.is_visible_in_tree() and feed.get_global_rect().encloses(c.get_global_rect()):
			card = c
	check(card != null, "в сводке видна карта")
	if card != null:
		_move_mouse(card.get_global_rect().get_center())


func _step_check_hover_feed() -> void:
	check(not CardPreview.active.alt_held() and CardPreview.active.has_preview(),
		"наведение на карту сводки показало её полную версию без Alt")
	_move_mouse(Vector2(480, 200))


## Наведение на карту рынка — полная карта по центру, без Alt.
func _step_hover_market() -> void:
	var rect: Rect2 = _screen._market_panel.card_rect(0)
	check(rect.size.x > 0.0, "в рынке есть карта")
	_move_mouse(rect.get_center())


func _step_check_hover_market() -> void:
	check(CardPreview.active.has_preview() and CardPreview.active.preview_size() == CardView.PIXEL_SIZE,
		"наведение на карту рынка показало полную карту без Alt (%s)" % CardPreview.active.preview_size())
	_move_mouse(Vector2(480, 200))


## Соперник заставил сбросить карту (Cranium Rats): карту выбирают прямо в
## руке — без окна и затемнения, варианты подсвечены (решение владельца,
## 2026-09-27).
func _step_forced_discard() -> void:
	var state := _screen.server.state
	var me: String = state.current_player()
	state.players[me].deck.hand.append("48714")
	_screen.send(Intent.play_card(me, "48714"))
	var guard := 0
	while _screen.server.resolver.is_waiting() and guard < 10 \
			and _screen.server.resolver.pending.player_id == me:
		guard += 1
		var pd: PendingDecision = _screen.server.resolver.pending
		_screen.send(Intent.make_decision(me, pd.legal_options[0]))
	var pending: PendingDecision = _screen.server.resolver.pending
	check(pending != null and pending.player_id != me and pending.tag == "hand",
		"соперник решает, какую карту сбросить, — выбор в руке")
	if pending == null:
		return
	_foe_discard = pending.player_id
	var dlg: DecisionDialog = _screen._decision_dialog
	# Пока крупно показывается карта (витрина), вопрос ждёт — два затемнения
	# не складываются. Проматываем витрину до конца.
	if _screen._showcase.is_busy():
		check(not dlg.visible, "пока идёт показ карты, вопрос ждёт")
		_screen._showcase._queue.clear()
		_screen._showcase._next()
	check(dlg.visible and not dlg._dim.visible and dlg.at_top,
		"вопрос — полоса сверху, экран не затемнён")
	check(dlg._prompt.text.begins_with(EventLogPanel.player_name(_foe_discard)) and dlg._blink,
		"вопрос крупно и мерцая называет сбрасывающего (%s)" % dlg._prompt.text)
	var victim: PlayerState = state.players[_foe_discard]
	_hand_before = victim.deck.hand.size()
	_discard_before = victim.deck.discard_pile.size()
	var card: CardView = null
	for c: CardView in _all_cards():
		if c.clickable and c.get_parent() is HandPanel:
			card = c
			break
	check(card != null, "карты руки сбрасывающего кликаются")
	if card != null:
		_click(card)


func _step_check_forced_discard() -> void:
	var victim: PlayerState = _screen.server.state.players[_foe_discard]
	check(victim.deck.hand.size() == _hand_before - 1 and victim.deck.discard_pile.size() == _discard_before + 1,
		"щелчок по карте в руке сбросил её")
	check(not _screen.server.resolver.is_waiting(), "вопрос закрыт")


## Devour с рынка (Cult Fanatic): карту выбирают прямо на рынке, без окна.
func _step_market_devour() -> void:
	var state := _screen.server.state
	var me: String = state.current_player()
	state.players[me].deck.hand.append("48409")
	_screen.send(Intent.play_card(me, "48409"))
	var pending: PendingDecision = _screen.server.resolver.pending
	check(pending != null and pending.tag == "market", "Cult Fanatic спрашивает карту рынка")
	check(not _screen._decision_dialog._dim.visible, "экран не затемнён — рынок виден")
	_market_before = state.market.display.duplicate()
	var card: CardView = null
	for c: CardView in _all_cards():
		if c.clickable and _in_market(c) and c.visible:
			card = c
			break
	check(card != null, "карты рынка подсвечены и кликаются")
	if card != null:
		_click(card)


func _step_check_market_devour() -> void:
	check(_screen.server.state.market.display != _market_before, "щелчок по карте рынка её сожрал")
	check(not _screen.server.resolver.is_waiting(), "вопрос закрыт")


## Elder Brain: карты Inner Circle встают в ряд руки справа, за чертой; рука
## остаётся видна, но не кликается.
func _step_inner_circle() -> void:
	var state := _screen.server.state
	var me: String = state.current_player()
	var deck = state.players[me].deck
	deck.inner_circle.append_array(["48312", "48340"])  # Bounty Hunter, House Guard — без вопросов
	deck.hand.append("48700")
	_screen.send(Intent.play_card(me, "48700"))
	var pending: PendingDecision = _screen.server.resolver.pending
	check(pending != null and pending.tag == "inner_circle", "Elder Brain спрашивает карту Inner Circle")
	var hand_cards := 0
	var zone_cards := 0
	var card: CardView = null
	for c in _row_cards():
		if HandPanel._is_zone(c):
			zone_cards += 1
			if c.clickable and card == null:
				card = c
		else:
			hand_cards += 1
			if c.clickable:
				check(false, "карта руки %s не должна кликаться" % c.card_id)
	check(pending != null and zone_cards == pending.legal_options.size() and hand_cards == deck.hand.size(),
		"в ряду рука (%d) и справа Inner Circle (%d)" % [hand_cards, zone_cards])
	check(_hand_panel()._label.visible, "над Inner Circle подпись")
	check(not _screen._decision_dialog._dim.visible, "экран не затемнён")
	if card != null:
		_click(card)


func _step_check_inner_circle() -> void:
	var pending: PendingDecision = _screen.server.resolver.pending
	check(pending == null or pending.tag != "inner_circle", "щелчок по карте ответил на вопрос")
	var zone_left := _row_cards().filter(func(c): return HandPanel._is_zone(c)).size()
	check(zone_left == 0 and not _hand_panel()._label.visible, "карты Inner Circle из ряда убраны")


## Matron Mother: колода уходит в сброс, promote из сброса — карты сброса в
## ряду руки справа, с подписью DISCARD.
func _step_promote_discard() -> void:
	var state := _screen.server.state
	var me: String = state.current_player()
	var deck = state.players[me].deck
	deck.hand.append("48329")
	_screen.send(Intent.play_card(me, "48329"))
	var pending: PendingDecision = _screen.server.resolver.pending
	check(pending != null and pending.tag == "discard", "Matron Mother спрашивает карту сброса")
	var zone := _row_cards().filter(func(c): return HandPanel._is_zone(c))
	check(pending != null and zone.size() == pending.legal_options.filter(func(o): return o != "").size(),
		"карты сброса в ряду руки (%d)" % zone.size())
	check(_hand_panel()._label.visible and _hand_panel()._label.text == "DISCARD", "над ними подпись DISCARD")
	_ic_before = deck.inner_circle.size()
	if not zone.is_empty():
		_click(zone[0])


func _step_check_promote_discard() -> void:
	var deck = _current_player().deck
	check(deck.inner_circle.size() == _ic_before + 1, "щелчок повысил карту из сброса")
	check(_row_cards().filter(func(c): return HandPanel._is_zone(c)).is_empty(), "карты сброса из ряда убраны")


## Выбор соперника (Myconid Adult): щелчок по строке игрока в таблице игроков,
## без окна и затемнения.
func _step_choose_player() -> void:
	var state := _screen.server.state
	var me: String = state.current_player()
	state.supplies.counts[Supplies.INSANE_OUTCAST] = 5  # в этой партии стопки Outcast нет
	state.players[me].deck.hand.append("48527")
	_screen.send(Intent.play_card(me, "48527"))
	var pending: PendingDecision = _screen.server.resolver.pending
	check(pending != null and pending.choice_type == "target_player", "Myconid Adult спрашивает соперника")
	if pending == null:
		return
	_foe_discard = String(pending.legal_options[0])
	_discard_before = state.players[_foe_discard].deck.discard_pile.size()


## Кнопки таблицы встают по месту строк на следующем кадре — щёлкаем тогда.
func _step_click_player() -> void:
	var state := _screen.server.state
	var me: String = state.current_player()
	var panel: PlayersPanel = _screen._players_panel
	var b: Button = panel._choice_buttons.get(_foe_discard)
	check(b != null and b.is_visible_in_tree(), "строка соперника в таблице игроков — кнопка выбора")
	check(not panel._choice_buttons[me].visible, "свою строку выбрать нельзя")
	check(not _screen._decision_dialog._dim.visible, "экран не затемнён")
	if b != null:
		_click(b)


func _step_check_choose_player() -> void:
	check(not _screen.server.resolver.is_waiting(), "щелчок по строке выбрал соперника")
	var foe: PlayerState = _screen.server.state.players[_foe_discard]
	check(foe.deck.discard_pile.size() == _discard_before + 1, "соперник получил Insane Outcast в сброс")
	check(not _screen._players_panel._choice_buttons[_foe_discard].visible, "кнопки выбора убраны")


## Lich: взять войско из трофейного зала — щелчком по цифре в столбце TROPHY
## таблицы игроков, без окна и затемнения.
func _step_trophy() -> void:
	var state := _screen.server.state
	var me: String = state.current_player()
	for pid: String in state.turn_order:
		state.players[pid].trophies["white"] = 2
	state.players[me].deck.hand.append("48732")
	_screen.send(Intent.play_card(me, "48732"))
	var pending: PendingDecision = _screen.server.resolver.pending
	if pending != null and pending.choice_type == "target_site":
		# шпион — туда, где стоит войско соперника: только тогда Lich берёт трофей
		for site in pending.legal_options:
			if CardLibrary._site_has_enemy_troop(state, me, String(site)):
				_screen.send(Intent.make_decision(me, site))
				break
	pending = _screen.server.resolver.pending
	check(pending != null and pending.tag == "trophy_hall", "Lich спрашивает войско из трофейного зала")


func _step_click_trophy() -> void:
	var panel: PlayersPanel = _screen._players_panel
	check(not panel._trophy_buttons.is_empty(), "на цифрах трофеев — рамки выбора (%d)" % panel._trophy_buttons.size())
	check(not _screen._decision_dialog._dim.visible, "экран не затемнён")
	_trophy_hall = ""
	var pending: PendingDecision = _screen.server.resolver.pending
	if pending != null and not panel._trophy_buttons.is_empty():
		_trophy_hall = String(pending.data["trophies"][0]).get_slice("|", 0)
		_discard_before = int(_screen.server.state.players[_trophy_hall].trophies.get("white", 0))
		_click(panel._trophy_buttons[0][0])


func _step_check_trophy() -> void:
	var state := _screen.server.state
	check(_trophy_hall != "" and int(state.players[_trophy_hall].trophies.get("white", 0)) == _discard_before - 1,
		"щелчок по цифре забрал войско из зала")


## Убийство и вытеснение: убитая фишка остаётся на доске под прицелом, пока
## не ударит; вытеснившего доска до удара прячет. Два убийства — по очереди.
func _step_kills() -> void:
	var state := _screen.server.state
	var me := _screen.viewer_id
	var foe := ""
	for pid: String in state.turn_order:
		if pid != me:
			foe = pid
	var empty: Array[String] = []
	for slot_id: String in state.graph.slots.keys():
		if String(state.troops.get(slot_id, "")) == "":
			empty.append(slot_id)
	check(empty.size() >= 2, "есть два свободных места")
	if empty.size() < 2:
		return
	_supplant_slot = empty[0]
	state.troops[_supplant_slot] = me     # вытеснили белое войско
	_flights_before = _screen.get_children().filter(func(n): return n is FlyingToken)
	_screen.refresh(StateView.for_player_with_pending(
		state, me, _screen.server.resolver.pending))
	_screen._react_to_events([
		{"type": "supplant", "player_id": me, "slot_id": _supplant_slot, "victim": GameState.WHITE},
		{"type": "assassinate", "player_id": me, "slot_id": empty[1], "victim": foe}])
	_kill_slot = empty[1]
	var board: BoardPanel = _screen._board_panel
	check(board.kill_count() == 2 and board.struck_count() == 0, "оба убийства анимируются, удара ещё не было")
	check(not board._arriving.has("troop|" + _supplant_slot),
		"вытеснивший не летит из барака — всплывёт из лужи на месте")
	board._process(BoardPanel.SUPPLANT_STRIKE + 0.01)
	check(board.struck_count() == 1, "первый удар — второе убийство ещё ждёт своей очереди")


func _step_check_kills() -> void:
	var board: BoardPanel = _screen._board_panel
	board._process(BoardPanel.KILL_STEP)
	check(board.kill_count() == 1 and board.struck_count() == 1,
		"вытеснение доиграло, второй удар прошёл (%d, %d)" % [board.kill_count(), board.struck_count()])
	check(board.spark_count() > 0 and board.is_shaking(), "на ударе осколки и тряска")
	var flying := 0
	for child in _screen.get_children():
		if child is FlyingToken and not _flights_before.has(child):
			flying += 1
	check(flying == 0, "трофеи ничем не летят — засчитываются в зал (%d)" % flying)
	board._process(BoardPanel.KILL_END)
	check(board.kill_count() == 0, "обе анимации закончились")


## Наведение на строку KILL в сводке зажигает на доске место убийства,
## уход мыши со строки гасит.
func _step_hover_kill_row() -> void:
	var feed: TurnFeed = _screen._feed
	check(feed.last_places("kill") == ["kill:" + _kill_slot],
		"строка KILL помнит место убийства (%s)" % [feed.last_places("kill")])
	check(feed.last_places("supplant") == ["supplant:" + _supplant_slot],
		"строка SUPPLANT помнит место вытеснения")
	var row := feed.last_row("kill")
	check(row != null and row.is_visible_in_tree(), "строка KILL видна в сводке")
	if row != null:
		_move_mouse(row.get_global_rect().get_center())


func _step_check_kill_row() -> void:
	check(_screen._board_panel.focus_count() == 1, "под мышью строка KILL — место на доске подсвечено")
	_move_mouse(Vector2(480, 200))


func _step_check_row_left() -> void:
	check(_screen._board_panel.focus_count() == 0, "мышь ушла со строки — подсветка погасла")


## Карты ряда руки без улетающих.
func _row_cards() -> Array:
	var row := _hand_panel()
	return row.get_children().filter(func(n): return n is CardView and not row.leaving_cards().has(n))


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
