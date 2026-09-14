extends SceneTree

## Проверка, что движок вообще умеет рисовать в этом контейнере.
## Запуск (нужен виртуальный экран, в контейнере нет настоящего):
##   xvfb-run -a godot47 --path . --rendering-driver opengl3 --script res://tests/render_smoke.gd
##
## Рисует цветной прямоугольник с текстом и сохраняет res://render_smoke.png.
##
## ВАЖНО про тайминг снимка (наступил на это сразу): нельзя снимать на первом
## же кадре и нельзя делать это через `await` внутри `_process` — `_process`
## обязан вернуть bool, а корутина возвращает объект ожидания, и снимок
## получается ДО отрисовки, то есть пустой белый лист. Правильно — считать
## кадры и снимать на N-м, когда сцена гарантированно нарисована.

const CAPTURE_ON_FRAME := 5

var _frame := 0


func _initialize() -> void:
	var panel := ColorRect.new()
	panel.color = Color(0.11, 0.09, 0.16)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(panel)

	var label := Label.new()
	label.text = "Godot 4.7.2 рисует в контейнере"
	label.add_theme_font_size_override("font_size", 42)
	label.position = Vector2(60, 120)
	root.add_child(label)

	var swatch := ColorRect.new()
	swatch.color = Color(0.85, 0.65, 0.2)
	swatch.position = Vector2(60, 220)
	swatch.size = Vector2(400, 80)
	root.add_child(swatch)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < CAPTURE_ON_FRAME:
		return false
	var image: Image = root.get_texture().get_image()
	var err := image.save_png("res://render_smoke.png")
	print("кадр %d: save_png -> %d (0 = OK), размер %dx%d" % [_frame, err, image.get_width(), image.get_height()])
	return true
