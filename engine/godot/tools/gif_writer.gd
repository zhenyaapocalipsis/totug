class_name GifWriter
extends RefCounted

## Запись анимированного GIF (GIF89a, LZW) из кадров Image — для превью эффектов
## розыгрыша карт. Пиксель-арт почти всегда умещается в 256 цветов; если нет —
## редкие цвета заменяются ближайшими из частых (по 15-битным корзинам).

var _out := PackedByteArray()
var _w := 0
var _h := 0


func _init(width: int, height: int) -> void:
	_w = width
	_h = height
	_out.append_array("GIF89a".to_ascii_buffer())
	_u16(width)
	_u16(height)
	_out.append_array(PackedByteArray([0x70, 0, 0]))  # без общей палитры
	# бесконечный повтор
	_out.append_array(PackedByteArray([0x21, 0xFF, 0x0B]))
	_out.append_array("NETSCAPE2.0".to_ascii_buffer())
	_out.append_array(PackedByteArray([3, 1, 0, 0, 0]))


func _u16(v: int) -> void:
	_out.append(v & 0xff)
	_out.append((v >> 8) & 0xff)


## Кадр img (RGB/RGBA, размер как у GIF), задержка в сотых долях секунды.
func add_frame(img: Image, delay_cs: int) -> void:
	img = img.duplicate()
	img.convert(Image.FORMAT_RGB8)
	var data := img.get_data()
	var n := _w * _h
	# палитра: частые цвета
	var counts := {}
	for i in n:
		var key := (data[i * 3] >> 3) << 10 | (data[i * 3 + 1] >> 3) << 5 | (data[i * 3 + 2] >> 3)
		counts[key] = int(counts.get(key, 0)) + 1
	var keys := counts.keys()
	keys.sort_custom(func(a: int, b: int) -> bool: return counts[a] > counts[b])
	if keys.size() > 256:
		keys.resize(256)
	var pal := PackedByteArray()
	var index := {}
	for i in keys.size():
		var k: int = keys[i]
		index[k] = i
		pal.append(((k >> 10) & 31) << 3 | 4)
		pal.append(((k >> 5) & 31) << 3 | 4)
		pal.append((k & 31) << 3 | 4)
	var bits := 1
	while (1 << bits) < keys.size():
		bits += 1
	bits = maxi(bits, 2)
	pal.resize((1 << bits) * 3)
	var idx := PackedByteArray()
	idx.resize(n)
	for i in n:
		var key := (data[i * 3] >> 3) << 10 | (data[i * 3 + 1] >> 3) << 5 | (data[i * 3 + 2] >> 3)
		if not index.has(key):
			index[key] = _nearest(key, keys)
		idx[i] = index[key]
	# управление кадром: задержка
	_out.append_array(PackedByteArray([0x21, 0xF9, 4, 0x04]))
	_u16(delay_cs)
	_out.append_array(PackedByteArray([0, 0]))
	# изображение с местной палитрой
	_out.append(0x2C)
	_u16(0)
	_u16(0)
	_u16(_w)
	_u16(_h)
	_out.append(0x80 | (bits - 1))
	_out.append_array(pal)
	_out.append(bits)
	var lzw := _lzw(idx, bits)
	var p := 0
	while p < lzw.size():
		var chunk := mini(255, lzw.size() - p)
		_out.append(chunk)
		_out.append_array(lzw.slice(p, p + chunk))
		p += chunk
	_out.append(0)


static func _nearest(key: int, keys: Array) -> int:
	var r := (key >> 10) & 31
	var g := (key >> 5) & 31
	var b := key & 31
	var best := 0
	var bd := 1 << 30
	for i in keys.size():
		var k: int = keys[i]
		var dr := ((k >> 10) & 31) - r
		var dg := ((k >> 5) & 31) - g
		var db := (k & 31) - b
		var d := dr * dr * 3 + dg * dg * 4 + db * db * 2
		if d < bd:
			bd = d
			best = i
	return best


static func _lzw(idx: PackedByteArray, min_bits: int) -> PackedByteArray:
	var clear := 1 << min_bits
	var eoi := clear + 1
	var out := PackedByteArray()
	var acc := 0
	var nacc := 0
	var size := min_bits + 1
	var dict := {}
	var next := eoi + 1
	# запись кода переменной длины
	var codes := PackedInt32Array()
	var sizes := PackedByteArray()
	codes.append(clear)
	sizes.append(size)
	var prefix := int(idx[0])
	for i in range(1, idx.size()):
		var c := int(idx[i])
		var key := (prefix << 8) | c
		if dict.has(key):
			prefix = dict[key]
			continue
		codes.append(prefix)
		sizes.append(size)
		if next < 4096:
			dict[key] = next
			next += 1
			if next > (1 << size) and size < 12:
				size += 1
		else:
			codes.append(clear)
			sizes.append(size)
			dict.clear()
			next = eoi + 1
			size = min_bits + 1
		prefix = c
	codes.append(prefix)
	sizes.append(size)
	codes.append(eoi)
	sizes.append(size)
	for i in codes.size():
		acc |= codes[i] << nacc
		nacc += sizes[i]
		while nacc >= 8:
			out.append(acc & 0xff)
			acc >>= 8
			nacc -= 8
	if nacc > 0:
		out.append(acc & 0xff)
	return out


func save(path: String) -> void:
	_out.append(0x3B)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(_out)
	f.close()
