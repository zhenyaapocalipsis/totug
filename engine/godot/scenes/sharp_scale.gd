extends Node

## «Чёткое сглаживание» (sharp bilinear) для экранов, куда 960x540 не
## укладывается целое число раз (2560x1440 — это x2.67). Обычный integer-режим
## оставляет там чёрные полосы, а простое растяжение ближайшим соседом делает
## пиксели разной ширины. Поэтому на таком экране игра рисуется во внутреннем
## SubViewport в ближайший целый масштаб сверху (x3 = 2880x1620, пиксели ровные)
## и уже готовая картинка плавно уменьшается до размера экрана.
##
## Пока масштаб целый (1920x1080, снимки тестов), ничего не меняется. Включившись
## один раз, режим остаётся: при целом масштабе он даёт ту же картинку пиксель в
## пиксель. Сцены, которые change_scene_to_file кладёт в корень, переносятся
## внутрь SubViewport; get_tree().current_scene при этом становится null.

const TOLERANCE := 0.01

var _container: SubViewportContainer
var _view: SubViewport


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return  # сервер и тесты без окна: рисовать некуда
	get_tree().root.size_changed.connect(_update)
	get_tree().scene_changed.connect(_adopt_scene)
	_update.call_deferred()


func _base() -> Vector2:
	return Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))


func _update() -> void:
	var root := get_tree().root
	var base := _base()
	var k := minf(root.size.x / base.x, root.size.y / base.y)
	if _container == null:
		if absf(k - roundf(k)) < TOLERANCE:
			return
		_activate()
	var n := maxi(1, ceili(k - TOLERANCE))
	_view.size = Vector2i(base * n)
	_container.size = _view.size
	var s := k / n
	_container.scale = Vector2(s, s)
	_container.position = ((Vector2(root.size) - Vector2(_view.size) * s) / 2.0).floor()


func _activate() -> void:
	var root := get_tree().root
	print("SharpScale: on, window %s, scene %s" % [root.size, get_tree().current_scene])
	_view = SubViewport.new()
	_view.size_2d_override = Vector2i(_base())
	_view.size_2d_override_stretch = true
	_view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_view.gui_embed_subwindows = true
	_view.handle_input_locally = true
	_container = SubViewportContainer.new()
	_container.name = "SharpView"
	_container.stretch = false
	_container.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_container.add_child(_view)
	root.add_child(_container)
	_adopt_scene()
	# Последним: смена режима тут же шлёт size_changed, а с ним и _update.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED


## Переносит текущую сцену из корня в SubViewport, старую сцену удаляет.
func _adopt_scene() -> void:
	if _view == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	for old in _view.get_children():
		old.queue_free()
	scene.reparent(_view, false)
