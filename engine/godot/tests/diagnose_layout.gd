extends SceneTree

## Разовая диагностика вёрстки: печатает прямоугольники зон и карт руки.
## Нужна, чтобы не гадать по скриншоту, где именно уехала зона.
##
##   godot --headless --path . --script res://tests/diagnose_layout.gd

var _screen: GameScreen
var _frame := 0


func _initialize() -> void:
	_screen = GameScreen.new(7, [], GameScreen.player_ids_for(2))
	root.add_child(_screen)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 8:
		return false
	print("экран: %s" % _screen.get_global_rect())
	for child in _screen.get_children():
		if child is Control:
			print("  %-22s %s" % [child.get_class() + "/" + child.name, (child as Control).get_global_rect()])
	var cards: Array = []
	_collect(_screen, cards)
	for card in cards:
		var c: CardView = card
		if c.get_parent() is HandPanel:
			print("  рука: %s %s" % [c.card_id, c.get_global_rect()])
	print("— минимальные размеры —")
	_min_sizes(_screen, 0)
	return true


func _collect(node: Node, out: Array) -> void:
	if node is CardView:
		out.append(node)
	for child in node.get_children():
		_collect(child, out)


func _min_sizes(node: Node, depth: int) -> void:
	if node is Control and depth <= 2:
		print("    %s%s min=%s size=%s" % ["  ".repeat(depth), node.get_class(),
			(node as Control).get_combined_minimum_size(), (node as Control).size])
	for child in node.get_children():
		_min_sizes(child, depth + 1)
