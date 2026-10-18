class_name PixPal
extends RefCounted

## Палитры эффектов: лесенки цветов от самого светлого к самому тёмному, подобраны
## вручную. Принцип (Kirokaze, waneella, Blasphemous): к свету оттенок уходит в
## жёлтый и почти белый, к тени — в фиолетовый/синий и теряет насыщенность; соседние
## ступени заметно отличаются по яркости (никаких «почти одинаковых» цветов).
## Свет и огонь в эффектах — 2-4 плоских цвета: белое ядро и один-два цветных края.

const RAMPS := {
	# огонь: добела раскалённое ядро -> жёлтый -> оранжевый -> красный -> багровый
	"fire": ["fffbe8", "ffe680", "ffb52e", "f2691d", "c4301f", "7a1830", "3b0f2e"],
	# дым: тёплый серо-фиолетовый, свет сверху-слева
	"smoke": ["8a7a86", "5e5066", "40354d", "2a2138", "1a1426"],
	# святой свет и золото
	"holy": ["ffffff", "fff4b8", "f7d35e", "dd982d", "a05a20", "5e2e1e"],
	# некромантия: бледно-салатовый -> ядовито-зелёный -> бирюзовая тень
	"necro": ["f2ffe2", "c0f76c", "62d64a", "25a050", "15665c", "163c4c", "131e33"],
	# кость и пергамент
	"bone": ["f4ecd8", "cdbf9d", "938570", "5c5049", "322a33"],
	# тайная магия: фиолетовый
	"arcane": ["ffffff", "ecccff", "b97dff", "7b43e0", "4626a3", "261761", "140c33"],
	# лёд и холод
	"frost": ["ffffff", "d8f6ff", "8fdbff", "4a9ae8", "2d5bb5", "1f3175", "141a40"],
	# кровь: насыщенный малиновый (Blasphemous), без коричневого
	"blood": ["ff6a6a", "e01e44", "a3102f", "5e0a27", "2e0819"],
	# тьма, пустота, тень
	"void": ["e4d4ff", "8d70d8", "4c3a90", "2b2358", "16112c", "07050f"],
	# яд и кислота
	"poison": ["efffa8", "aee34c", "5ea83a", "2f6e3a", "1a3d33"],
	# молния
	"storm": ["ffffff", "d6f2ff", "7dccff", "3a7dff", "2a3fb5", "1b1f66"],
	# плоть (глаз бехолдера и т. п.)
	"flesh": ["ffe0c8", "f0a08c", "c25e6c", "7e3054", "41193b", "20101f"],
	# чешуя красного дракона
	"dragon": ["ff8a5c", "d8442e", "9c2229", "5e1527", "2d0d1f", "12060f"],
	# радужка глаза рептилии
	"iris": ["fffbd0", "ffe24a", "ffa31f", "d1531c", "7a1d1d"],
	# вода и глубина
	"water": ["e8ffff", "9cf0f0", "3fb8d6", "1f7aa8", "1a4775", "13254a"],
	# камень и земля
	"earth": ["e6d2a8", "b39268", "7d5e45", "4d3a33", "2a1f24"],
	# свет, который ПРИБАВЛЯЕТСЯ к картинке (слой glow, смешение ADD): тёмные цвета,
	# иначе всё выгорает в белое; от ядра к краю
	"glow_fire": ["8a3a0c", "5a2208", "341204"],
	"glow_necro": ["2c6a1e", "1a4214", "0e260c"],
	"glow_arcane": ["5a2c8a", "3a1a5c", "200e34"],
	"glow_holy": ["8a7030", "5a4820", "342810"],
	"glow_frost": ["2a5a8a", "1a3a5c", "0e2034"],
	"glow_blood": ["7a1020", "4a0a14", "2a060c"],
}

static var _cache: Dictionary = {}


## Лесенка name (светлое первым) в виде чисел для Pix; kind — MATTER или LIGHT.
static func ramp(name: String, kind: int = Pix.MATTER) -> PackedColorArray:
	var key := "%s/%d" % [name, kind]
	if not _cache.has(key):
		var out := PackedColorArray()
		for h: String in RAMPS[name]:
			out.append(Pix.hex(h, kind))
		_cache[key] = out
	return _cache[key]


## Ступень лесенки по доле k (0 — самая светлая, 1 — самая тёмная).
static func at(r: PackedColorArray, k: float) -> Color:
	return r[clampi(floori(k * float(r.size())), 0, r.size() - 1)]


static func color(name: String, i: int) -> Color:
	var r: Array = RAMPS[name]
	return Color(String(r[clampi(i, 0, r.size() - 1)]))
