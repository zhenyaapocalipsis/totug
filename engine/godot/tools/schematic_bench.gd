extends SceneTree

## Замер BoardSchematic.build и сверка результата с эталоном.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --path engine/godot --script res://tools/schematic_bench.gd -- --out=<file.json> [--ref=<file.json>]
## --out пишет результат всех досок в файл; --ref сравнивает с прежним файлом.

const PLAYERS := [2, 3, 4]
const SEEDS := [1, 3, 7, 11, 42, 99]


func _init() -> void:
	var out_path := ""
	var ref_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
		elif arg.begins_with("--ref="):
			ref_path = arg.trim_prefix("--ref=")
	var all := {}
	var total := 0
	for players in PLAYERS:
		for s in SEEDS:
			var ids: Array[String] = []
			ids.assign(["red", "blue", "green", "purple"].slice(0, players))
			var state := GameSetup.new_game(ids, s)
			var t := Time.get_ticks_usec()
			var schematic := BoardSchematic.build(state)
			var ms := (Time.get_ticks_usec() - t) / 1000
			total += ms
			print("%dp seed %3d: %d ms" % [players, s, ms])
			all["%d/%d" % [players, s]] = schematic
	print("total %d ms" % total)
	var text := JSON.stringify(all, "", true, true)
	if out_path != "":
		FileAccess.open(out_path, FileAccess.WRITE).store_string(text)
	if ref_path != "":
		var ref := FileAccess.get_file_as_string(ref_path)
		print("SAME AS REF" if ref == text else "DIFFERENT FROM REF")
	quit()
