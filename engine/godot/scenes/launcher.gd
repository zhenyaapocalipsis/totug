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

const GAME_SCENE := "res://scenes/ui/game_scene.tscn"
const VIEWER_SCENE := "res://scenes/board_view.tscn"


func _ready() -> void:
	var viewer := OS.has_feature("viewer")
	for arg in OS.get_cmdline_user_args():
		if arg == "--viewer":
			viewer = true
		elif arg == "--game":
			viewer = false
	# Через call_deferred: смена сцены прямо в _ready() происходит в момент,
	# когда дерево ещё добавляет узлы, и движок ругается
	# "Parent node is busy adding/removing children" (поймано на первом же
	# запуске собранной программы).
	get_tree().change_scene_to_file.call_deferred(VIEWER_SCENE if viewer else GAME_SCENE)
