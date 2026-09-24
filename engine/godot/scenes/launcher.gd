extends Node

## Что запускать: игру или просмотрщик доски.
##
## В Godot главная сцена в проекте одна на все сборки, а собирать надо две
## разные программы — игру и просмотр доски этапа 1. Чтобы не переписывать
## project.godot перед каждой сборкой (и не собрать однажды не то), главной
## стоит этот переключатель, а нужный режим задаётся МЕТКОЙ пресета экспорта
## (`custom_features` в export_presets.cfg):
##
##   метка "viewer" -> просмотрщик доски
##   без метки      -> игра (и так же при запуске из редактора/командной строки)
##
## Можно переопределить вручную при запуске: `-- --viewer` или `-- --game`.
## `-- --server` — выделенный сервер сетевой игры (см. _start_server).

const GAME_SCENE := "res://scenes/ui/game_scene.tscn"
const VIEWER_SCENE := "res://scenes/board_view.tscn"


func _ready() -> void:
	var viewer := OS.has_feature("viewer")
	var server := OS.has_feature("dedicated_server")
	var port := NetSession.SERVER_PORT
	for arg in OS.get_cmdline_user_args():
		if arg == "--viewer":
			viewer = true
		elif arg == "--game":
			viewer = false
		elif arg == "--server":
			server = true
		elif arg.begins_with("--port="):
			port = int(arg.get_slice("=", 1))
	if server:
		_start_server.call_deferred(port)
		return
	# Через call_deferred: смена сцены прямо в _ready() происходит в момент,
	# когда дерево ещё добавляет узлы, и движок ругается
	# "Parent node is busy adding/removing children" (поймано на первом же
	# запуске собранной программы).
	get_tree().change_scene_to_file.call_deferred(VIEWER_SCENE if viewer else GAME_SCENE)


## Выделенный сервер (`-- --server [--port=N]`, обычно вместе с --headless):
## без окна и меню, только комнаты с кодами. Узел связи — в /root/Net, как у
## игроков, иначе RPC не найдут друг друга.
func _start_server(port: int) -> void:
	var net := NetSession.new()
	net.name = "Net"
	get_tree().root.add_child(net)
	var err := net.serve(port, true)
	if err != OK:
		printerr("Tyrants server: cannot open UDP port %d (error %d)" % [port, err])
		get_tree().quit(1)
		return
	print("Tyrants server: listening on UDP port %d, protocol %d" % [port, NetSession.PROTOCOL])
