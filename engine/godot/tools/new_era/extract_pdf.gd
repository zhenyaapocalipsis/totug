extends SceneTree

# Pulls every JPEG stream (FFD8FF ... endstream) out of the mod PDF.
func _init() -> void:
	var src := "C:/tyrants of the underdark godot/new era/Runeterra Reforged A4 3x3.pdf"
	var out := OS.get_environment("OUT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var b := FileAccess.get_file_as_bytes(src)
	var n := b.size()
	var pos := 0
	var idx := 0
	while true:
		pos = b.find(0xFF, pos)
		if pos < 0 or pos + 2 >= n:
			break
		if b[pos + 1] == 0xD8 and b[pos + 2] == 0xFF:
			var e := pos + 3
			var end := -1
			while true:
				e = b.find(0x65, e)
				if e < 0 or e + 9 > n:
					break
				if b[e + 1] == 0x6E and b[e + 2] == 0x64 and b[e + 3] == 0x73 and b[e + 4] == 0x74 and b[e + 5] == 0x72 and b[e + 6] == 0x65 and b[e + 7] == 0x61 and b[e + 8] == 0x6D:
					end = e
					break
				e += 1
			if end < 0:
				break
			var f := FileAccess.open(out + "/%04d.jpg" % idx, FileAccess.WRITE)
			f.store_buffer(b.slice(pos, end))
			f.close()
			idx += 1
			pos = end + 9
		else:
			pos += 1
	print("images: ", idx)
	quit()
