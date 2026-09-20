extends SceneTree

## Снимок интерфейса в PNG — так владелец игры видит результат, ничего не
## запуская сам. Заодно это единственный способ проверить вёрстку: тесты
## ловят правила, но не то, что панель уехала за край экрана.
##
##   xvfb-run -a godot47 --path . --rendering-driver opengl3 \
##       --script res://tests/ui_shot.gd -- --seed=7 --out=shot.png
##
## Дополнительно можно проиграть сценарий кликов, чтобы снять не пустой старт
## партии, а конкретную ситуацию (--script-name=play_card / decision).
##
## Про тайминг: снимать раньше нескольких кадров нельзя — получится пустой
## лист (наступали на это в tests/render_smoke.gd).

const SETTLE_FRAMES := 6
## Потолок ожидания: если рука почему-то не успокоится, снимок всё равно
## будет сделан, а не зависнет навсегда.
const MAX_FRAMES := 120

var _screen: GameScreen
var _out := "res://ui_shot.png"
var _scenario := ""
var _frame := 0
## Кадр, на котором снимать, когда снимок ждёт отыгранного события (-1 — ждать
## нечего). Нужен сценарию capture: искры живут доли секунды.
var _shot_at := -1
## Во сколько раз увеличить снимок при сохранении (--px=N), картинка та же.
var _zoom := 1
## Во сколько раз растянуть ОКНО (--scale=N): игра запускается в полный экран
## на 1920x1080, то есть втрое, и доска подбирает масштаб именно под это.
## Снимок тогда сохраняется как есть, в размере окна.
var _scale := 1


func _initialize() -> void:
	var game_seed := 7
	var players := 2
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			game_seed = int(arg.get_slice("=", 1))
		elif arg.begins_with("--players="):
			players = int(arg.get_slice("=", 1))
		elif arg.begins_with("--out="):
			_out = "res://" + arg.get_slice("=", 1)
		elif arg.begins_with("--px="):
			_zoom = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--scale="):
			_scale = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--scenario="):
			_scenario = arg.get_slice("=", 1)

	# Окно ровно в расчётный размер: тогда сцена рисуется пиксель в пиксель
	# и снимок не приходится пересчитывать. С --scale=N окно во столько же раз
	# больше — так видно настоящую картинку полноэкранной игры.
	DisplayServer.window_set_size(Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width", 640),
		ProjectSettings.get_setting("display/window/size/viewport_height", 360)) * _scale)
	_screen = GameScreen.new(game_seed, [], GameScreen.player_ids_for(players))
	root.add_child(_screen)
	_run_scenario()


## Курсор — в пустой угол, иначе снимок зависит от того, где стоит системная
## мышь: рука выезжает, карта под ней увеличивается. --hover=x,y — навести.
## Подаётся на каждом кадре: системный курсор при появлении окна шлёт своё.
func _fake_hover() -> void:
	var hover := Vector2(4, 4)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hover="):
			var xy := arg.get_slice("=", 1).split(",")
			hover = Vector2(float(xy[0]), float(xy[1]))
	var ev := InputEventMouseMotion.new()
	ev.position = root.get_screen_transform() * hover
	ev.global_position = ev.position
	Input.parse_input_event(ev)


## Сценарии прогоняются НАМЕРЕНИЯМИ, а не подделкой состояния: сцена ходит
## ровно теми же путями, что и живой игрок мышкой.
func _run_scenario() -> void:
	match _scenario:
		"":
			return
		"play_card":
			# Разыграть первую карту руки текущего игрока.
			var pid: String = _screen.server.state.current_player()
			var hand: Array = _screen.server.state.players[pid].deck.hand
			if not hand.is_empty():
				_screen.send(Intent.play_card(pid, String(hand[0])))
		"play_all":
			# Разыграть всю руку — так проявляются карты с вопросами. Сначала
			# закрываем выбор стартовых локаций, иначе рука ещё заблокирована.
			while _screen.server.resolver.is_waiting():
				var pd2: PendingDecision = _screen.server.resolver.pending
				_screen.send(Intent.make_decision(pd2.player_id, pd2.legal_options[0]))
			var pid2: String = _screen.server.state.current_player()
			for cid in (_screen.server.state.players[pid2].deck.hand as Array).duplicate():
				if _screen.server.resolver.is_waiting():
					break
				_screen.send(Intent.play_card(pid2, String(cid)))
		"decision":
			# Стартовая колода — только Noble и Soldier, они вопросов не задают,
			# а дождаться карты с выбором честной игрой — это десятки ходов.
			# Поэтому кладём нужную карту в руку и разыгрываем её обычным
			# намерением: подстроена ТОЛЬКО стартовая ситуация, сам розыгрыш
			# идёт ровно тем же путём, что у живого игрока.
			var card := "48325"  # Inquisitor: "choose one" — +2 Influence или Assassinate
			for arg2 in OS.get_cmdline_user_args():
				if arg2.begins_with("--card="):
					card = arg2.get_slice("=", 1)
			# сперва оба игрока выбирают стартовые локации (первый вариант)
			while _screen.server.resolver.is_waiting():
				var pd3: PendingDecision = _screen.server.resolver.pending
				_screen.send(Intent.make_decision(pd3.player_id, pd3.legal_options[0]))
			var pid3: String = _screen.server.state.current_player()
			_screen.server.state.players[pid3].deck.hand.append(card)
			_screen.refresh(StateView.for_player_with_pending(
				_screen.server.state, pid3, _screen.server.resolver.pending))
			_screen.send(Intent.play_card(pid3, card))
		"capture":
			# Захват локации запускается не здесь, а на кадре (_run_capture):
			# доска считает места искр по своему масштабу, а он подбирается
			# только когда панель получила размер.
			while _screen.server.resolver.is_waiting():
				var pdc: PendingDecision = _screen.server.resolver.pending
				_screen.send(Intent.make_decision(pdc.player_id, pdc.legal_options[0]))
		"zoom":
			# Приближаем доску к войску игрока — так проверяется, что масштаб и
			# сдвиг считаются правильно и арт читается вблизи.
			var board := _screen.get_node_or_null(".")  # панель ищем обходом
			var panel: BoardPanel = _find_board(_screen)
			if panel != null:
				var pid4: String = _screen.server.state.current_player()
				var target := Vector2.ZERO
				for slot_id: String in _screen.server.state.troops.keys():
					if _screen.server.state.troops[slot_id] == pid4:
						var sl: Dictionary = (_screen.board_data["slots"] as Dictionary).get(slot_id, {})
						if not sl.is_empty():
							target = Vector2(float(sl["x"]), float(sl["y"]))
						break
				var zoom_level := 0.42
				for arg3 in OS.get_cmdline_user_args():
					if arg3.begins_with("--zoom="):
						zoom_level = float(arg3.get_slice("=", 1))
				panel.focus_on(target, zoom_level)
		"two_turns":
			# Два хода целиком: так на экране появляется начисление VP за
			# контроль локаций и строка "в конце хода: +N VP".
			for round_index in range(2):
				var pid5: String = _screen.server.state.current_player()
				for cid5 in (_screen.server.state.players[pid5].deck.hand as Array).duplicate():
					if _screen.server.resolver.is_waiting():
						break
					_screen.send(Intent.play_card(pid5, String(cid5)))
				var guard5 := 0
				while _screen.server.resolver.is_waiting() and guard5 < 20:
					guard5 += 1
					var pd5: PendingDecision = _screen.server.resolver.pending
					var ans5 = pd5.legal_options[0] if not pd5.legal_options.is_empty() else null
					_screen.send(Intent.make_decision(pd5.player_id, ans5))
				var legal5: Dictionary = StateView.for_player_with_pending(
					_screen.server.state, pid5, null).get("legal", {})
				for slot5 in (legal5.get("deploy_slots", []) as Array):
					_screen.send(Intent.deploy(pid5, String(slot5)))
					break
				_screen.send(Intent.end_turn(pid5))
		"refuse":
			# Щёлкаем по слоту, до которого игроку не дотянуться, — проверяем,
			# что интерфейс объясняет ПРИЧИНУ, а не просто "сюда нельзя".
			var pid6: String = _screen.server.state.current_player()
			var far := ""
			for slot_id6: String in (_screen.board_data["slots"] as Dictionary).keys():
				if slot_id6.begins_with("b1:") and String(_screen.server.state.troops.get(slot_id6, "")) == "":
					far = slot_id6
					break
			if far != "":
				_screen._on_slot_clicked(far)
				# и по своему собственному войску — другая причина
				for slot_id7: String in _screen.server.state.troops.keys():
					if _screen.server.state.troops[slot_id7] == pid6:
						_screen._on_slot_clicked(slot_id7)
						break
		"tab":
			# Полный расклад по игрокам: в игре он виден, пока зажат Tab.
			var overlay := _find_overlay(_screen)
			if overlay != null:
				overlay.visible = true
		"deploy":
			# Подсветка мест для Deploy в САМОЙ БОЛЬШОЙ локации (Wells of
			# Darkness, восемь мест): именно там кольца подсветки раньше
			# сливались в сплошное зелёное пятно поверх названия.
			while _screen.server.resolver.is_waiting():
				var pd8: PendingDecision = _screen.server.resolver.pending
				var pick := String(pd8.legal_options[0])
				var most := -1
				for opt8 in pd8.legal_options:
					var site8: Dictionary = (_screen.board_data["sites"] as Dictionary).get(String(opt8), {})
					var count8: int = (site8.get("slots", []) as Array).size()
					if count8 > most:
						most = count8
						pick = String(opt8)
				_screen.send(Intent.make_decision(pd8.player_id, pick))
			var pid8: String = _screen.server.state.current_player()
			_screen.server.state.players[pid8].power = 5
			_screen.refresh(StateView.for_player_with_pending(
				_screen.server.state, pid8, _screen.server.resolver.pending))
		"end_turn":
			_screen.send(Intent.end_turn(_screen.server.state.current_player()))
		_:
			push_error("неизвестный сценарий: " + _scenario)


func _find_overlay(node: Node) -> PlayersOverlay:
	if node is PlayersOverlay:
		return node
	for child in node.get_children():
		var found := _find_overlay(child)
		if found != null:
			return found
	return null


func _find_board(node: Node) -> BoardPanel:
	if node is BoardPanel:
		return node
	for child in node.get_children():
		var found := _find_board(child)
		if found != null:
			return found
	return null


## Отдаёт зрителю все места одной ещё не его локации: доска замечает смену
## хозяина сама и отвечает вспышкой, искрами и толчком.
func _run_capture() -> void:
	var state := _screen.server.state
	var me := _screen.viewer_id
	for site_id: String in state.graph.sites.keys():
		if state.control.controller_of(site_id, state.troops) != me:
			for slot_id in state.graph.slots_of_site(site_id):
				state.troops[slot_id] = me
			break
	_screen.refresh(StateView.for_player_with_pending(
		state, me, _screen.server.resolver.pending))


## Доехал ли ряд карт руки до своих мест.
func _hand_settled() -> bool:
	for child in _screen.get_children():
		if child is HandPanel:
			return (child as HandPanel).is_settled()
	return true


func _process(_delta: float) -> bool:
	_frame += 1
	_fake_hover()
	if _frame < SETTLE_FRAMES + 12:
		return false
	# Рука раздаётся с анимацией: карты выезжают снизу друг за другом. Снимок
	# ждёт, пока ряд доедет, иначе на картинке будет полупустая рука.
	if _frame < MAX_FRAMES and not _hand_settled():
		return false
	# Захват показывают на ходу: сначала доска разложилась, потом локация
	# меняет хозяина, и через несколько кадров снимаем искры в полёте.
	if _scenario == "capture" and _shot_at < 0:
		_run_capture()
		_shot_at = _frame + 6
	if _shot_at >= 0 and _frame < _shot_at:
		return false
	var image: Image = root.get_texture().get_image()
	# Игра рисуется в 640x360; снимок берём ровно в этом размере (пиксель в
	# пиксель), а для просмотра увеличиваем целым числом раз без сглаживания.
	var design := Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width", 640),
		ProjectSettings.get_setting("display/window/size/viewport_height", 360)) * _scale
	if image.get_size() != design:
		image = image.get_region(Rect2i(Vector2i.ZERO, image.get_size()))
		image.resize(design.x, design.y, Image.INTERPOLATE_NEAREST)
	var shown := image.duplicate() as Image
	if _zoom > 1:
		shown.resize(design.x * _zoom, design.y * _zoom, Image.INTERPOLATE_NEAREST)
	var err := shown.save_png(_out)
	print("снимок: %s (код %d), сцена %dx%d x%d, сценарий '%s'"
		% [_out, err, image.get_width(), image.get_height(), _zoom, _scenario])
	return true
