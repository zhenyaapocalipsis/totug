extends SceneTree
## Кадры игры через 0.3 с начиная с 3.4 с — проверка живности (CaveCritters)
## и шейдера пещеры: "Claude outputs/critters_0.png", "critters_4.png" и лента
## "critters_spiders.png". Run: Godot_v4.7.2-stable_win64.exe --path engine/godot --script res://tools/critters_shot.gd
var _t := 0.0
var _next := 3.4
var _shots: Array[Image] = []
func _initialize() -> void:
	var screen := GameScreen.new(7, [], GameScreen.player_ids_for(4))
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(screen)
func _process(delta: float) -> bool:
	_t += delta
	if _t < _next:
		return false
	_next += 0.3
	_shots.append(root.get_texture().get_image())
	if _shots.size() < 8:
		return false
	for k in [0, 4]:
		_shots[k].save_png("C:/tyrants of the underdark godot/Claude outputs/critters_%d.png" % k)
	var out := Image.create(4 * 300, 2 * 200, false, _shots[0].get_format())
	for k in 8:
		out.blit_rect(_shots[k], Rect2i(420, 300, 300, 200), Vector2i((k % 4) * 300, (k / 4) * 200))
	out.save_png("C:/tyrants of the underdark godot/Claude outputs/critters_spiders.png")
	return true
