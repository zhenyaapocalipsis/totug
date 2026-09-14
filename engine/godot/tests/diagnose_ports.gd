extends SceneTree

## Диагностика: к какому узлу гекса подключается туннель с каждого печатного
## ребра (до поворота). Сверять с картинками assets/hexes/*.png.

func _init() -> void:
	var data := BoardData.load_all()
	var builder := BoardData.make_builder()
	var names := {}
	for hex_id: String in (data["sites"] as Dictionary).keys():
		for site: Dictionary in data["sites"][hex_id]:
			for slot: Dictionary in site["troop_slots"]:
				names[slot["id"]] = site["name"]
	var hexes: Array = (data["edges"] as Dictionary).keys()
	hexes.sort()
	for hex_id: String in hexes:
		var line := hex_id + ":"
		for dir: String in data["edges"][hex_id]:
			line += "  %s=%s" % [dir, names.get(builder.port_name(hex_id, dir), builder.port_name(hex_id, dir))]
		print(line)
	quit()
