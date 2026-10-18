extends SceneTree

## Снимки экрана розыгрыша карт New Era (визуальная проверка вопросов и
## отрисовки): для каждой карты — новая партия NEW ERA на 3 игроков, карта в
## руке ходящего, розыгрыш через GameScreen.send, снимок после розыгрыша и
## после каждого автоответа (первый настоящий вариант). Без --headless:
##   DECK=ixtal IDS="50113 50118" OUT=<папка> SHOTS=2 Godot --path engine/godot --script res://tools/new_era/card_shot.gd

var _deck := ""
var _ids: Array = []
var _out := ""
var _shots := 2
var _screen: GameScreen
var _i := -1
var _step := 0
var _wait := 0
var _pid := ""


func _initialize() -> void:
	_deck = OS.get_environment("DECK")
	_ids = Array(OS.get_environment("IDS").split(" ", false))
	_out = OS.get_environment("OUT")
	_shots = maxi(1, OS.get_environment("SHOTS").to_int()) if OS.get_environment("SHOTS") != "" else 2
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_next_card()


func _next_card() -> void:
	_i += 1
	if _screen != null:
		_screen.queue_free()
		_screen = null
	if _i >= _ids.size():
		quit()
		return
	var partner := "shadow" if _deck == "celestial" else "celestial"
	var mode := GameSetup.new_era_mode([_deck, partner])
	_screen = GameScreen.new(4242, [], GameScreen.player_ids_for(3), mode)
	root.add_child(_screen)
	# подготовка партии: рынок и стартовые локации — первыми вариантами
	var guard := 0
	while _screen.server.resolver.is_waiting() and guard < 20:
		guard += 1
		var pd: PendingDecision = _screen.server.resolver.pending
		_screen.send(Intent.make_decision(pd.player_id, pd.legal_options[0]))
	var state := _screen.server.state
	_pid = state.current_player()
	_prepare(state, _pid, String(_ids[_i]), GameSetup.expand_half_deck(_deck))
	_screen.viewer_id = _pid
	_screen.refresh(StateView.for_player_with_pending(state, _pid, _screen.server.resolver.pending))
	_step = 0
	_wait = 40


func _process(_delta: float) -> bool:
	if _screen == null:
		return false
	_wait -= 1
	if _wait > 0:
		return false
	var cid := String(_ids[_i])
	if _step == 0:
		_screen.send(Intent.play_card(_pid, cid))
		_step = 1
		_wait = _frames()
		return false
	_save("%s/%s_%d.png" % [_out, cid, _step])
	var r := _screen.server.resolver
	if _step >= _shots or not r.is_waiting():
		_next_card()
		return false
	var pd: PendingDecision = r.pending
	var ans = pd.legal_options[0]
	if pd.choice_type == "confirm":
		ans = true
	for o in pd.legal_options:
		if not ((typeof(o) == TYPE_STRING and o == "") or (typeof(o) == TYPE_INT and o == -1)):
			ans = o
			break
	# PICK="1,0": на шаге k — вариант номер PICK[k-1] (по списку вопроса)
	var picks := OS.get_environment("PICK").split(",", false)
	if _step - 1 < picks.size() and picks[_step - 1].to_int() < pd.legal_options.size():
		ans = pd.legal_options[picks[_step - 1].to_int()]
	_screen.send(Intent.make_decision(pd.player_id, ans))
	_step += 1
	_wait = _frames()
	return false


func _save(path: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.resize(image.get_width() / 2, image.get_height() / 2, Image.INTERPOLATE_NEAREST)
	image.save_png(path)
	print("saved ", path)


func _prepare(state: GameState, pid: String, cid: String, deck_cards: Array[String]) -> void:
	var me: PlayerState = state.players[pid]
	var others: Array = state.turn_order.filter(func(p): return p != pid)
	var owners := [pid, pid, pid, others[0], others[0], others[1], "white"]
	var placed := 0
	for slot: String in state.deployable_slots(pid):
		if placed >= owners.size():
			break
		if state.troops.get(slot, "") != "":
			continue
		state.troops[slot] = owners[placed]
		if owners[placed] != "white":
			state.stock(owners[placed]).troops_in_barracks -= 1
		placed += 1
	var sites := state.presence.sites_with_presence(pid, state.troops, state.spies)
	if sites.size() >= 2:
		for pair in [[sites[0], others[0]], [sites[1], pid]]:
			var arr: Array = state.spies.get(pair[0], [])
			arr.append(pair[1])
			state.spies[pair[0]] = arr
			state.stock(pair[1]).spies_in_barracks -= 1
	me.power = 4
	me.influence = 4
	me.vp_tokens = 2
	var aspect := CardLibrary.card_aspect(cid)
	var hand: Array[String] = [cid]
	for other: String in deck_cards:
		if other != cid and CardLibrary.card_aspect(other) == aspect and CardLibrary.card_cost(other) <= 4:
			hand.append(other)
			break
	for c: String in me.deck.hand:
		if hand.size() >= 5:
			break
		hand.append(c)
	me.deck.hand = hand
	me.deck.discard_pile.append_array([deck_cards[deck_cards.size() - 1], deck_cards[2]])
	me.deck.draw_pile.append_array([deck_cards[1], deck_cards[3]])


## Кадров между шагами (WAIT, по умолчанию 70): дольше — чтобы досмотреть анимации.
func _frames() -> int:
	return OS.get_environment("WAIT").to_int() if OS.get_environment("WAIT") != "" else 70
