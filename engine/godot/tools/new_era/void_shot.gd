extends SceneTree

## Снимок экрана для проверки FAR REALM: съеденный гекс и отложенные карты
## Eye Monger. Запуск без --headless (нужна отрисовка):
##   OUT=<файл.png> Godot --path engine/godot --script res://tools/new_era/void_shot.gd

var _screen: GameScreen
var _frame := 0
var _out := ""


func _initialize() -> void:
	_out = OS.get_environment("OUT")
	DisplayServer.window_set_size(Vector2i(960, 540))
	_screen = GameScreen.new(7, ["drow", "demons"] as Array[String], GameScreen.player_ids_for(2))
	root.add_child(_screen)
	var state := _screen.server.state
	var me := state.current_player()
	# гекс с локацией, где нет стартового войска
	var hex := ""
	for site_id: String in state.graph.sites.keys():
		var h := MapGraph.hex_of(site_id)
		var busy := false
		for slot_id: String in state.graph.slots.keys():
			if MapGraph.hex_of(slot_id) == h and state.players.has(String(state.troops.get(slot_id, ""))):
				busy = true
		if not busy and h != "":
			hex = h
			break
	print("removing hex ", hex)
	VoidCards.remove_hex(state, hex)
	state.players[me].deck.set_aside.assign([VoidCards.VELKOZ, VoidCards.DUNEBREAKER])
	_screen.refresh(StateView.for_player_with_pending(state, me, _screen.server.resolver.pending))


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 90:
		return false
	var image: Image = root.get_texture().get_image()
	image.save_png(_out)
	print("saved ", _out, " ", image.get_size())
	return true
