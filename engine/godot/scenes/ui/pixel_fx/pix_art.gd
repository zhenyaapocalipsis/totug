class_name PixArt
extends RefCounted

## Спрайты, нарисованные вручную по пикселю: строка — ряд пикселей, буква — цвет
## (ключ задаёт сцена: одна и та же форма в разных палитрах), точка — пусто.
## Правила рисования: свет сверху-слева (светлые ступени у верхнего левого края
## формы), один-два пикселя блика, тёмная ступень снизу-справа; обводку рисует шейдер
## (pix_outline), поэтому в самих спрайтах контура нет — только форма и свет.

## Череп-душа (Lich, нежить): W — блик кости, B — кость, b — тень кости,
## e — глазницы (горят), n — нос.
const SKULL := [
	"..BBBBB..",
	".BWWBBBb.",
	"BWWBBBBbb",
	"BWeeBeebb",
	"BBeeBeebb",
	".BBBnBBb.",
	"..bBBBb..",
	"..BbBbB..",
	"...bbb...",
]

## Руны круга призыва, 5x7 (# — штрих).
const RUNES := [
	["..#..", ".###.", "#.#.#", "..#..", "..#..", ".#.#.", "#...#"],
	["#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#", "#####"],
	["####.", "#...#", "####.", "#.#..", "#..#.", "#...#", "#...#"],
	[".###.", "#...#", "#.#.#", "#.#.#", "#...#", ".###.", "..#.."],
	["#.#.#", "#.#.#", ".###.", "..#..", ".###.", "#...#", "#...#"],
	["..#..", ".#.#.", "#...#", "#####", "#...#", ".#.#.", "..#.."],
	["#....", "##...", "#.#..", "#..#.", "#.#..", "##...", "#...."],
	[".#.#.", "#####", ".#.#.", ".#.#.", ".#.#.", "#####", ".#.#."],
]

## Глаз бехолдера 21x13: L — веко светлое, l — веко тёмное, s — белок, S — белок
## в тени, v — прожилки, i/I — радужка (светлая/тёмная), p — зрачок, w — блик.
const BIG_EYE := [
	".......LLLLLLL.......",
	"....LLLLlllllLLLL....",
	"..LLlllsssssssllll...",
	".Llssssiiiiiissssll..",
	"Llsssiiiiiiiiiissvll.",
	"lssvsiIIIppIIIissssl.",
	"lsssiIIwppppIIIisSSl.",
	"lssssiIIppppIIisSvSl.",
	".lsssiiIIIIIIiisSSl..",
	"..lsSSiiiiiiiiSSSll..",
	"...llSSSSSSSSSSll....",
	".....llllllllll......",
]

static var _cache: Dictionary = {}


## Спрайт из строк rows по ключам keys (буква -> Color); кэшируется по имени key.
static func sprite(key: String, rows: Array, keys: Dictionary) -> Dictionary:
	if _cache.has(key):
		return _cache[key]
	var h := rows.size()
	var w := 0
	for r: String in rows:
		w = maxi(w, r.length())
	var px := PackedColorArray()
	px.resize(w * h)
	for y in h:
		var r: String = rows[y]
		for x in w:
			var ch := r[x] if x < r.length() else "."
			px[y * w + x] = keys[ch] if keys.has(ch) else Pix.NONE
	var s := {"w": w, "h": h, "px": px}
	_cache[key] = s
	return s


## Руна номер i (по кругу) цветом c.
static func rune(i: int, c: Color) -> Dictionary:
	var idx := posmod(i, RUNES.size())
	return sprite("rune%d/%s" % [idx, c.to_html()], RUNES[idx], {"#": c})
