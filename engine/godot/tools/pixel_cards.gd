extends SceneTree

## Pixel-art card faces for every card in data/cards/cards.json.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --script "C:/tyrants of the underdark godot/engine/godot/tools/pixel_cards.gd"
## Art is cropped from the sheets in cards/ and reduced to 28 colours; frame, text,
## icons and VP are drawn with a 5x7 pixel font. Output: one 1x PNG per card_id
## (display with nearest filtering, e.g. at x4), plus x2 preview sheets.

const ROOT := "C:/tyrants of the underdark godot/"
const OUT := ROOT + "engine/godot/assets/cards_pixel/"
const OUT_MINI := ROOT + "engine/godot/assets/cards_mini/"
## Мелкая карта для руки и маркета: на экране 640x360 полная карта не влезает,
## а ужимать её нельзя — текст превратится в кашу. Поэтому у каждой карты есть
## второе лицо, нарисованное сразу маленьким: имя, цена, арт и оба VP.
##
## 58x84 — пропорции большой карты 176x254 (решение владельца, 2026-10-03).
## Размер один на все карты — иначе они не встанут ровным рядом в руке и маркете.
const MINI_W := 58
const MINI_H := 84
## Шапка — имя, до трёх строк по 9 букв: так влезают все имена, вплоть до
## WATER ELEMENTAL MYRMIDON. VP на мелкой карте нет (решение владельца,
## 2026-10-03). Справа в шапке колонка: цена, под ней значок аспекта, слева
## от неё вертикальная черта (2026-10-08). Первые MINI_SIDE_LINES строк имени
## стоят рядом с колонкой — в них 8 букв, остальные во всю ширину (9).
const MINI_HEAD := 26
const MINI_SIDE_X := 50  # x черты; 8 букв имени (тень на x=49) ещё влезают
const MINI_SIDE_LINES := 2
## Имена, которые рядом с колонкой не влезают в три строки, на мелкой карте
## сокращены; полное имя — на большой карте (владелец, 2026-10-08).
const MINI_SHORT_NAMES := {
	"CONSCRIPTION OFFICER": "CONSCR. OFFICER",
	"MASTER OF MELEE-MAGTHERE": "MASTER OF M.-MAGTHERE",
	"WATER ELEMENTAL MYRMIDON": "WATER ELEM. MYRMIDON",
	"FIRE ELEMENTAL MYRMIDON": "FIRE ELEM. MYRMIDON",
	"EARTH ELEMENTAL MYRMIDON": "EARTH ELEM. MYRMIDON",
	"AIR ELEMENTAL MYRMIDON": "AIR ELEM. MYRMIDON",
}
const MINI_ART_H := MINI_H - MINI_HEAD - 5
const MINI_LINE_H := 8
const MINI_NAME_LINES := 3
## Арт мелкой карты не ужимается, а вырезается 1:1 из арта готовой большой
## карты (assets/cards_pixel) — вокруг лица. По умолчанию вырез по центру и
## ближе к верху арта; карты, где лицо в другом месте, — в MINI_FACE.
const FULL_ART_POS := Vector2i(6, 34)
const MINI_FACE_DEFAULT := Vector2i(56, 12)
## card_id -> левый верхний угол выреза в арте большой карты (164x100);
## x не больше 112, y не больше 47. Подобрано на глаз по сетке.
const MINI_FACE := {
	48302: Vector2i(39, 0), 48306: Vector2i(47, 1), 48310: Vector2i(63, 0), 48312: Vector2i(26, 35),
	48314: Vector2i(84, 23), 48315: Vector2i(39, 0), 48316: Vector2i(21, 28), 48318: Vector2i(84, 8),
	48320: Vector2i(77, 0), 48322: Vector2i(56, 0), 48324: Vector2i(112, 0), 48325: Vector2i(82, 22),
	48327: Vector2i(83, 23), 48328: Vector2i(70, 0), 48329: Vector2i(53, 8), 48331: Vector2i(112, 10),
	48334: Vector2i(66, 0), 48336: Vector2i(81, 0), 48338: Vector2i(97, 11), 48339: Vector2i(20, 0),
	48340: Vector2i(39, 0), 48341: Vector2i(59, 24), 48342: Vector2i(56, 0), 48343: Vector2i(52, 2),
	48344: Vector2i(47, 0), 48345: Vector2i(16, 8),
	48400: Vector2i(83, 18), 48402: Vector2i(6, 28), 48403: Vector2i(16, 8), 48405: Vector2i(6, 21),
	48407: Vector2i(61, 1), 48409: Vector2i(63, 0), 48413: Vector2i(59, 0), 48415: Vector2i(69, 0),
	48418: Vector2i(60, 11), 48419: Vector2i(64, 0), 48421: Vector2i(27, 25), 48424: Vector2i(55, 0),
	48425: Vector2i(77, 21), 48426: Vector2i(21, 0), 48428: Vector2i(40, 10), 48429: Vector2i(83, 18),
	48432: Vector2i(69, 11), 48433: Vector2i(103, 18), 48436: Vector2i(87, 1), 48439: Vector2i(77, 8),
	48500: Vector2i(47, 8), 48501: Vector2i(63, 1), 48503: Vector2i(61, 47), 48506: Vector2i(63, 0),
	48509: Vector2i(51, 0), 48512: Vector2i(40, 22), 48513: Vector2i(73, 0), 48514: Vector2i(83, 0),
	48516: Vector2i(73, 21), 48519: Vector2i(49, 0), 48521: Vector2i(50, 8), 48524: Vector2i(93, 40),
	48527: Vector2i(74, 31), 48529: Vector2i(50, 35), 48531: Vector2i(53, 21), 48534: Vector2i(99, 5),
	48535: Vector2i(93, 8), 48537: Vector2i(101, 0), 48538: Vector2i(112, 38), 48539: Vector2i(81, 5),
	48600: Vector2i(101, 25), 48606: Vector2i(73, 0), 48610: Vector2i(97, 8), 48613: Vector2i(56, 11),
	48615: Vector2i(53, 11), 48617: Vector2i(40, 31), 48620: Vector2i(104, 21), 48623: Vector2i(11, 25),
	48625: Vector2i(76, 21), 48626: Vector2i(83, 1), 48628: Vector2i(83, 0), 48629: Vector2i(0, 15),
	48630: Vector2i(63, 5), 48632: Vector2i(60, 0), 48633: Vector2i(54, 5), 48636: Vector2i(7, 21),
	48638: Vector2i(53, 18), 48639: Vector2i(49, 0),
	48700: Vector2i(44, 3), 48701: Vector2i(63, 8), 48702: Vector2i(60, 36), 48703: Vector2i(53, 35),
	48704: Vector2i(87, 0), 48705: Vector2i(41, 0), 48706: Vector2i(66, 15), 48707: Vector2i(57, 45),
	48708: Vector2i(53, 5), 48709: Vector2i(53, 47), 48710: Vector2i(0, 25), 48711: Vector2i(97, 41),
	48712: Vector2i(53, 0), 48713: Vector2i(46, 33), 48714: Vector2i(97, 47), 48715: Vector2i(56, 30),
	48716: Vector2i(51, 25), 48717: Vector2i(59, 30), 48718: Vector2i(46, 25), 48719: Vector2i(80, 18),
	48720: Vector2i(63, 5), 48721: Vector2i(53, 0), 48722: Vector2i(87, 0), 48723: Vector2i(83, 0),
	48724: Vector2i(31, 0), 48725: Vector2i(36, 0), 48726: Vector2i(56, 28), 48727: Vector2i(37, 11),
	48728: Vector2i(66, 0), 48729: Vector2i(21, 0), 48730: Vector2i(26, 0), 48731: Vector2i(64, 5),
	48732: Vector2i(67, 5), 48733: Vector2i(84, 15), 48734: Vector2i(29, 0), 48735: Vector2i(64, 1),
	48736: Vector2i(37, 0), 48737: Vector2i(63, 35), 48738: Vector2i(69, 0), 48739: Vector2i(33, 31),
	49000: Vector2i(60, 25), 49001: Vector2i(52, 3), 49002: Vector2i(76, 35), 49003: Vector2i(56, 24),
	49004: Vector2i(56, 20), 49005: Vector2i(81, 37), 49006: Vector2i(38, 14), 49007: Vector2i(31, 12),
	49008: Vector2i(40, 16), 49009: Vector2i(42, 14), 49010: Vector2i(70, 34), 49011: Vector2i(52, 2),
	49012: Vector2i(59, 24), 49013: Vector2i(52, 26), 49014: Vector2i(24, 44), 49015: Vector2i(78, 8),
	49016: Vector2i(56, 20), 49017: Vector2i(37, 8), 49018: Vector2i(56, 32), 49019: Vector2i(38, 32),
	49020: Vector2i(56, 22), 49021: Vector2i(52, 13), 49022: Vector2i(52, 5), 49023: Vector2i(56, 24),
	49024: Vector2i(52, 21),
	49100: Vector2i(81, 0), 49101: Vector2i(56, 24), 49102: Vector2i(19, 15), 49103: Vector2i(3, 37),
	49104: Vector2i(49, 9), 49105: Vector2i(56, 24), 49106: Vector2i(52, 25), 49107: Vector2i(15, 5),
	49108: Vector2i(61, 25), 49109: Vector2i(102, 19), 49110: Vector2i(58, 43), 49111: Vector2i(80, 9),
	49112: Vector2i(75, 5), 49113: Vector2i(56, 5), 49114: Vector2i(111, 9), 49115: Vector2i(67, 0),
	49116: Vector2i(47, 28), 49117: Vector2i(69, 21), 49118: Vector2i(56, 25), 49119: Vector2i(55, 37),
	49120: Vector2i(54, 0), 49121: Vector2i(32, 9), 49122: Vector2i(56, 0), 49123: Vector2i(35, 36),
	49124: Vector2i(70, 14),
	49200: Vector2i(59, 19), 49201: Vector2i(75, 14), 49202: Vector2i(89, 7), 49203: Vector2i(55, 35),
	49204: Vector2i(86, 27), 49205: Vector2i(38, 18), 49206: Vector2i(66, 23), 49207: Vector2i(56, 35),
	49208: Vector2i(90, 10), 49209: Vector2i(52, 14), 49210: Vector2i(49, 39), 49211: Vector2i(62, 0),
	49212: Vector2i(49, 6), 49213: Vector2i(39, 19), 49214: Vector2i(33, 47), 49215: Vector2i(59, 29),
	49216: Vector2i(62, 17), 49217: Vector2i(60, 28), 49218: Vector2i(49, 19), 49219: Vector2i(69, 21),
	49220: Vector2i(33, 4),
	# Siege
	49300: Vector2i(69, 0), 49301: Vector2i(10, 0), 49303: Vector2i(88, 15), 49304: Vector2i(74, 4),
	49307: Vector2i(30, 15), 49308: Vector2i(95, 30), 49309: Vector2i(102, 5), 49310: Vector2i(50, 5),
	49311: Vector2i(26, 20), 49312: Vector2i(63, 0), 49314: Vector2i(69, 10), 49316: Vector2i(100, 10),
	49317: Vector2i(14, 29), 49318: Vector2i(69, 0), 49319: Vector2i(100, 20),
	# Mercenaries
	49400: Vector2i(14, 40), 49401: Vector2i(54, 9), 49402: Vector2i(18, 21), 49403: Vector2i(48, 25),
	49404: Vector2i(38, 20), 49405: Vector2i(64, 0), 49406: Vector2i(112, 29), 49407: Vector2i(48, 0),
	49408: Vector2i(96, 47), 49409: Vector2i(99, 4), 49410: Vector2i(4, 0), 49411: Vector2i(86, 20),
	49412: Vector2i(27, 15), 49413: Vector2i(80, 0), 49414: Vector2i(74, 0), 49415: Vector2i(80, 15),
	49416: Vector2i(54, 0), 49417: Vector2i(80, 4), 49418: Vector2i(48, 20), 49419: Vector2i(59, 44),
	49500: Vector2i(81, 24), 49501: Vector2i(70, 30), 49502: Vector2i(98, 40), 49503: Vector2i(112, 20),
	49504: Vector2i(88, 24), 49505: Vector2i(19, 47), 49506: Vector2i(74, 6), 49507: Vector2i(19, 14),
	49508: Vector2i(21, 7), 49509: Vector2i(39, 24), 49510: Vector2i(69, 34), 49511: Vector2i(78, 23),
	49512: Vector2i(63, 16), 49513: Vector2i(69, 0), 49514: Vector2i(83, 0), 49515: Vector2i(59, 14),
	49516: Vector2i(49, 19), 49517: Vector2i(52, 24), 49518: Vector2i(74, 29), 49519: Vector2i(69, 34),
	49520: Vector2i(56, 4), 49521: Vector2i(29, 29), 49522: Vector2i(69, 19), 49523: Vector2i(84, 24),
	49524: Vector2i(54, 24),
	# Icewind Dale (New Era Freljord)
	49600: Vector2i(49, 24), 49601: Vector2i(61, 13), 49602: Vector2i(23, 35), 49603: Vector2i(33, 30),
	49604: Vector2i(64, 12), 49605: Vector2i(99, 28), 49606: Vector2i(31, 32), 49607: Vector2i(58, 0),
	49608: Vector2i(52, 12), 49609: Vector2i(50, 10), 49610: Vector2i(65, 0), 49611: Vector2i(61, 23),
	49612: Vector2i(24, 34), 49613: Vector2i(57, 1), 49614: Vector2i(98, 0), 49615: Vector2i(94, 0),
	49616: Vector2i(71, 11), 49617: Vector2i(54, 17), 49618: Vector2i(47, 4),
	49620: Vector2i(81, 4), 49634: Vector2i(43, 24), 49635: Vector2i(110, 14), 49636: Vector2i(77, 30),
	# Calimshan (New Era Shurima)
	49700: Vector2i(57, 0), 49701: Vector2i(30, 21), 49702: Vector2i(79, 0), 49703: Vector2i(38, 14),
	49704: Vector2i(25, 12), 49705: Vector2i(31, 14), 49706: Vector2i(80, 15), 49707: Vector2i(7, 22),
	49708: Vector2i(47, 1), 49709: Vector2i(44, 16), 49710: Vector2i(40, 19), 49711: Vector2i(47, 28),
	49712: Vector2i(42, 12), 49713: Vector2i(71, 21), 49714: Vector2i(49, 14), 49715: Vector2i(42, 40),
	49716: Vector2i(54, 0), 49717: Vector2i(34, 5), 49718: Vector2i(71, 27), 49719: Vector2i(55, 24),
	49720: Vector2i(49, 5),
	# Kara-Tur (New Era Ionia)
	49800: Vector2i(40, 0), 49801: Vector2i(52, 0), 49802: Vector2i(100, 10), 49803: Vector2i(84, 40),
	49804: Vector2i(74, 7), 49805: Vector2i(21, 44), 49806: Vector2i(24, 34), 49807: Vector2i(64, 14),
	49808: Vector2i(71, 24), 49809: Vector2i(74, 0), 49810: Vector2i(57, 37), 49811: Vector2i(24, 47),
	49812: Vector2i(47, 24), 49813: Vector2i(61, 21), 49814: Vector2i(54, 41), 49815: Vector2i(51, 4),
	49816: Vector2i(47, 27), 49817: Vector2i(61, 14), 49818: Vector2i(51, 7), 49819: Vector2i(74, 44),
	49820: Vector2i(47, 17), 49821: Vector2i(31, 34), 49822: Vector2i(64, 31),
	# FEYWILD (Bandle City)
	49900: Vector2i(34, 0), 49901: Vector2i(71, 2), 49902: Vector2i(56, 32), 49903: Vector2i(46, 7),
	49904: Vector2i(53, 0), 49905: Vector2i(54, 0), 49906: Vector2i(35, 3), 49908: Vector2i(6, 0),
	49909: Vector2i(70, 23), 49910: Vector2i(37, 22), 49911: Vector2i(47, 5), 49912: Vector2i(96, 7),
	49913: Vector2i(37, 29), 49914: Vector2i(44, 2), 49915: Vector2i(52, 13), 49916: Vector2i(71, 20),
	49917: Vector2i(53, 2), 49918: Vector2i(74, 0), 49919: Vector2i(26, 15), 49920: Vector2i(65, 18),
	49921: Vector2i(62, 38), 49922: Vector2i(43, 29),
	# FAR REALM (Void)
	50000: Vector2i(0, 14), 50001: Vector2i(74, 0), 50002: Vector2i(56, 14), 50003: Vector2i(77, 27),
	50004: Vector2i(0, 41), 50005: Vector2i(50, 47), 50006: Vector2i(14, 31), 50007: Vector2i(54, 23),
	50008: Vector2i(36, 0), 50010: Vector2i(44, 11), 50011: Vector2i(24, 0), 50012: Vector2i(56, 11),
	50013: Vector2i(64, 4), 50014: Vector2i(41, 11), 50015: Vector2i(53, 0), 50016: Vector2i(44, 1),
	50017: Vector2i(21, 34), 50018: Vector2i(53, 31), 50019: Vector2i(84, 24), 50020: Vector2i(27, 14),
	# CHULT (Ixtal)
	50100: Vector2i(24, 10), 50101: Vector2i(51, 11), 50102: Vector2i(49, 0), 50103: Vector2i(18, 8),
	50104: Vector2i(35, 18), 50105: Vector2i(56, 0), 50106: Vector2i(62, 11), 50107: Vector2i(29, 5),
	50108: Vector2i(50, 0), 50110: Vector2i(0, 0), 50111: Vector2i(62, 7), 50112: Vector2i(112, 23),
	50113: Vector2i(44, 26), 50114: Vector2i(59, 4), 50115: Vector2i(70, 0), 50116: Vector2i(32, 22),
	50117: Vector2i(33, 4), 50118: Vector2i(27, 16), 50119: Vector2i(112, 1), 50120: Vector2i(20, 0),
}
const PREVIEW := ROOT + "Claude outputs/pixel_cards_preview/"
const AltArts := preload("res://tools/alt_arts.gd")
const W := 176
const ART_H := 100
const ART_COLORS := 28
const LINE_H := 9
const PARA_GAP := 3

const C_OUTLINE := Color("0a0612")
const C_FRAME := Color("24153f")
const C_FRAME_HI := Color("4a2f82")
const C_FRAME_LO := Color("160c28")
const C_LIGHT := Color("f0e6d2")
const C_GREY := Color("a89cc0")
const C_PARCH := Color("e6d9bc")
const C_PARCH_LO := Color("bfae88")
const C_INK := Color("2a1a30")
const C_IC := Color("3b2c96")
const C_IC_HI := Color("6a5ad0")
const C_GOLD := Color("f2d23c")

const ASPECT_COLOR := {
	"CONQUEST": Color("8fd3ff"), "AMBITION": Color("f2d23c"), "GUILE": Color("5ccf5c"),
	"MALICE": Color("d0283e"), "OBEDIENCE": Color("ffffff"), "": Color("a89cc0"),
}

const KEYWORDS := ["DEVOUR", "SUPPLANT", "DEPLOY", "ASSASSINATE", "PLACE", "RETURN", "PROMOTE", "BRIBE", "STEAL",
	"RECRUIT", "RECRUITS", "MOVE", "FOCUS",
	# новые слова New Era и фанатских колод (владелец, 2026-10-15)
	"SCRY", "MIGHT", "FROSTBITE", "TRANSFORM",
	# владелец, 2026-10-16
	"DISTINCT",
	# Calimshan (2026-10-16)
	"DEVOTION",
	# Kara-Tur (2026-10-17)
	"RETAIN", "RETAINED",
	# Feywild (2026-10-17)
	"GLAMOUR",
	# Chult (2026-10-18)
	"EXPLORE"]

## Где можно рвать слово, которое само шире строки мелкой карты: границы слогов
## (номер буквы, после которой ставится дефис). Берётся самая дальняя граница,
## что влезает в строку (решение владельца, 2026-09-24: переносить по слогам).
## Слова, которых тут нет, рвутся примерно посередине — генератор печатает их
## как "hyphenated", их стоит дописать сюда.
const NAME_BREAKS := {
	"AMBASSADOR": [2, 5, 7], "BLACKGUARD": [5], "BRAINWASHED": [5], "CONSCRIPTION": [3, 8], "DEATHBLADE": [5],
	"DEMOGORGON": [2, 4, 7], "DOPPELGANGER": [3, 6, 9], "DRAGONCLAW": [3, 6],
	"INFILTRATOR": [2, 5, 8], "INFORMATION": [2, 5, 7], "INQUISITOR": [2, 5, 7],
	"JACKALWERE": [4, 6], "MINDWITNESS": [4, 7], "NALFESHNEE": [3, 7],
	"NECROMANCER": [3, 5, 8], "NEGOTIATOR": [2, 4, 6, 7], "SHATTERKEEL": [4, 7],
	"SPELLSPINNER": [5, 9], "WEAPONMASTER": [6, 9], "WYRMSPEAKER": [4, 9],
	# Первые слова в 9 букв не влезают рядом с ценой (8 букв), рвём по слогу.
	"PRIESTESS": [6], "MERCENARY": [5], "UNDERDARK": [5], "ENCHANTER": [6],
	"GIBBERING": [6], "SPECTATOR": [4], "INTELLECT": [5], "PUPPETEER": [6],
	"ULITHARID": [3],
	# Рядом с колонкой цены и аспекта (2026-10-08) тоже 8 букв.
	"ELEMENTAL": [3, 6], "SOVEREIGN": [3], "HIPPOGRIFF": [5], "BERSERKER": [3],
	"PSEUDODRAGON": [6], "WERETIGER": [4],
}

# deck id -> [sheet file, columns, card w, card h, art rect (x, y, w, h) inside the card]
const SHEETS := {
	483: ["drow + obidience + insane outcast.jpg", 10, 749, 1046, Rect2i(25, 195, 693, 365)],
	484: ["dragons.jpg", 10, 749, 1046, Rect2i(25, 195, 693, 365)],
	485: ["demons.jpg", 10, 749, 1046, Rect2i(25, 195, 693, 365)],
	486: ["elemental.jpg", 10, 749, 1046, Rect2i(25, 195, 693, 365)],
	487: ["aberations + undead.jpg", 7, 750, 1000, Rect2i(24, 200, 690, 340)],
}
## Карты не из листов TTS: отдельная картинка карты и окно арта в ней.
const SINGLE_ART := {
	48345: ["conscription_officer.webp", Rect2i(148, 172, 587, 358)],
	# Celestial Order (New Era): арты монстров с D&D Beyond в cards/celestial/,
	# окно — вокруг лица (решение владельца: прозрачный фон -> чёрный, зум до лица).
	49000: ["celestial/warrior_infantry.jpg", Rect2i(330, 220, 440, 268)],
	49001: ["celestial/priest.jpg", Rect2i(330, 420, 440, 268)],
	49002: ["celestial/sphinx_of_wonder.png", Rect2i(250, 200, 520, 317)],
	49003: ["celestial/sphinx_of_valor.png", Rect2i(220, 140, 560, 341)],
	49004: ["celestial/djinni.png", Rect2i(170, 160, 460, 280)],
	49005: ["celestial/satyr.jpg", Rect2i(60, 0, 420, 256)],
	49006: ["celestial/couatl.jpg", Rect2i(200, 170, 460, 280)],
	49007: ["celestial/hippogriff.png", Rect2i(300, 80, 420, 256)],
	49008: ["celestial/pegasus.png", Rect2i(180, 60, 520, 317)],
	49009: ["celestial/druid.png", Rect2i(480, 60, 420, 256)],
	49010: ["celestial/planetar.png", Rect2i(60, 40, 440, 268)],
	49011: ["celestial/sphinx_of_lore.png", Rect2i(130, 40, 460, 280)],
	49012: ["celestial/griffon.png", Rect2i(470, 470, 399, 243)],
	49013: ["celestial/unicorn.png", Rect2i(200, 180, 460, 280)],
	49014: ["celestial/werebear.jpg", Rect2i(500, 170, 480, 293)],
	49015: ["celestial/solar.png", Rect2i(40, 60, 460, 280)],
	49016: ["celestial/erinyes.png", Rect2i(200, 90, 420, 256)],
	49017: ["celestial/warrior_veteran.jpg", Rect2i(60, 140, 440, 268)],
	49018: ["celestial/berserker.jpg", Rect2i(180, 200, 440, 268)],
	49019: ["celestial/scout.jpg", Rect2i(180, 250, 440, 268)],
	49020: ["celestial/adult_silver_dragon.png", Rect2i(440, 120, 500, 305)],
	49021: ["celestial/shield_guardian.png", Rect2i(0, 60, 550, 335)],
	49022: ["celestial/gold_dragon.png", Rect2i(0, 460, 360, 220)],
	49023: ["celestial/giant_eagle.jpg", Rect2i(279, 240, 520, 317)],
	49024: ["celestial/ancient_gold_dragon.jpg", Rect2i(130, 30, 520, 317)],
	# Shadow Isles (New Era): арты с фоном с D&D Beyond в cards/shadow/.
	49100: ["shadow/specter.jpeg", Rect2i(390, 10, 480, 293)],
	49101: ["shadow/vampire_familiar.jpeg", Rect2i(137, 79, 440, 268)],
	49102: ["shadow/death_dog.png", Rect2i(80, 420, 600, 366)],
	49103: ["shadow/shambling_mound.png", Rect2i(100, 0, 640, 390)],
	49104: ["shadow/awakened_tree.jpeg", Rect2i(80, 200, 700, 427)],
	49105: ["shadow/grick.png", Rect2i(50, 160, 560, 341)],
	49106: ["shadow/bearded_devil.png", Rect2i(300, 60, 600, 366)],
	49107: ["shadow/sea_hag.png", Rect2i(0, 0, 520, 317)],
	49108: ["shadow/gargoyle.jpeg", Rect2i(170, 230, 560, 341)],
	49109: ["shadow/crawling_claws.png", Rect2i(0, 120, 640, 390)],
	49110: ["shadow/lemure.png", Rect2i(160, 380, 600, 366)],
	49111: ["shadow/will_o_wisp.png", Rect2i(240, 0, 760, 463)],
	49112: ["shadow/spirit_naga.png", Rect2i(0, 60, 760, 463)],
	49113: ["shadow/rakshasa.png", Rect2i(180, 40, 640, 390)],
	49114: ["shadow/nightmare.png", Rect2i(50, 40, 900, 549)],
	49115: ["shadow/chain_devil.png", Rect2i(26, 0, 600, 366)],
	49116: ["shadow/barbed_devil.png", Rect2i(0, 0, 700, 427)],
	49117: ["shadow/ghast.png", Rect2i(60, 30, 520, 317)],
	49118: ["shadow/treant.png", Rect2i(130, 30, 700, 427)],
	49119: ["shadow/bone_devil.png", Rect2i(100, 200, 640, 390)],
	49120: ["shadow/drider.png", Rect2i(40, 280, 520, 317)],
	49121: ["shadow/green_hag.jpeg", Rect2i(20, 60, 600, 366)],
	49122: ["shadow/shadow.png", Rect2i(0, 0, 700, 427)],
	49123: ["shadow/phase_spider.png", Rect2i(60, 360, 500, 305)],
	49124: ["shadow/twig_blight.png", Rect2i(120, 120, 520, 317)],
	# Piltover & Zaun (New Era): арты 2024 года с фоном с D&D Beyond в cards/pz/.
	49200: ["pz/tough_boss.jpeg", Rect2i(0, 20, 440, 268)],
	49201: ["pz/wererat.jpeg", Rect2i(0, 60, 596, 363)],
	49202: ["pz/bandit_captain.jpeg", Rect2i(0, 270, 326, 199)],
	49203: ["pz/rust_monster.jpeg", Rect2i(0, 100, 700, 427)],
	49204: ["pz/black_pudding.png", Rect2i(0, 300, 560, 341)],
	49205: ["pz/spy.jpeg", Rect2i(0, 90, 446, 272)],
	49206: ["pz/otyugh.jpeg", Rect2i(250, 60, 700, 427)],
	49207: ["pz/clay_golem.png", Rect2i(133, 120, 540, 329)],
	49208: ["pz/gelatinous_cube.jpeg", Rect2i(0, 330, 800, 488)],
	49209: ["pz/ochre_jelly.png", Rect2i(150, 20, 700, 427)],
	49210: ["pz/mimic.png", Rect2i(50, 100, 820, 500)],
	49211: ["pz/stone_golem.jpeg", Rect2i(100, 0, 560, 341)],
	49212: ["pz/assassin.png", Rect2i(237, 60, 440, 268)],
	49213: ["pz/iron_golem.png", Rect2i(0, 0, 600, 366)],
	49214: ["pz/manticore.jpeg", Rect2i(300, 0, 700, 427)],
	49215: ["pz/homunculus.jpeg", Rect2i(0, 430, 495, 302)],
	49216: ["pz/chimera.png", Rect2i(300, 0, 700, 427)],
	49217: ["pz/archmage.png", Rect2i(100, 30, 700, 427)],
	49218: ["pz/basilisk.png", Rect2i(24, 0, 700, 427)],
	49219: ["pz/behir.png", Rect2i(0, 60, 554, 338)],
	49220: ["pz/harpy.png", Rect2i(100, 40, 700, 427)],
	# Siege и Mercenaries: арты вырезаны из самих карт PDF (cards/siege/,
	# cards/mercenaries/). В левом верхнем углу кадра — значок аспекта карты,
	# поэтому кадр либо ниже него (y >= 62), либо правее (x >= 100: при 64-70
	# в углу кадра оставался белый завиток значка).
	49300: ["siege/avatar_of_lolth.jpg", Rect2i(100, 0, 591, 360)],
	49301: ["siege/converter.jpg", Rect2i(100, 0, 591, 360)],
	49302: ["siege/relentless_siege.jpg", Rect2i(0, 62, 691, 421)],
	49303: ["siege/beast_tamer.jpg", Rect2i(100, 0, 591, 360)],
	49304: ["siege/warlord.jpg", Rect2i(0, 62, 691, 421)],
	49305: ["siege/siege_beast.jpg", Rect2i(0, 62, 691, 421)],
	49306: ["siege/spoils_of_war.jpg", Rect2i(0, 62, 691, 421)],
	49307: ["siege/hydra.jpg", Rect2i(0, 62, 691, 421)],
	49308: ["siege/scout_leader.jpg", Rect2i(0, 62, 691, 421)],
	49309: ["siege/siege_tower.jpg", Rect2i(100, 0, 591, 360)],
	49310: ["siege/shade_lingerer.jpg", Rect2i(0, 62, 691, 421)],
	49311: ["siege/chieftain.jpg", Rect2i(100, 0, 591, 360)],
	49312: ["siege/privateers.jpg", Rect2i(100, 0, 591, 360)],
	49313: ["siege/trebuchet.jpg", Rect2i(0, 62, 691, 421)],
	49314: ["siege/plunder.jpg", Rect2i(100, 0, 591, 360)],
	49315: ["siege/dread_ballista.jpg", Rect2i(0, 62, 691, 421)],
	49316: ["siege/ramming_beast.jpg", Rect2i(100, 0, 591, 360)],
	49317: ["siege/underdark_champion.jpg", Rect2i(0, 62, 691, 421)],
	49318: ["siege/guardian_brute.jpg", Rect2i(100, 0, 591, 360)],
	49319: ["siege/schemer.jpg", Rect2i(100, 0, 591, 360)],
	49400: ["mercenaries/goblinoid_ambushers.jpg", Rect2i(0, 69, 690, 421)],
	49401: ["mercenaries/hobgoblin_warlord.jpg", Rect2i(100, 0, 590, 360)],
	49402: ["mercenaries/artemis_entreri.jpg", Rect2i(100, 0, 590, 360)],
	49403: ["mercenaries/goblin_swarm.jpg", Rect2i(100, 0, 590, 360)],
	49404: ["mercenaries/bugbear.jpg", Rect2i(100, 0, 590, 360)],
	49405: ["mercenaries/dragonborn_hireling.jpg", Rect2i(100, 0, 590, 360)],
	49406: ["mercenaries/bregan_daerthe_agents.jpg", Rect2i(0, 69, 690, 421)],
	49407: ["mercenaries/nihiloor.jpg", Rect2i(100, 0, 590, 360)],
	49408: ["mercenaries/goblin_thief.jpg", Rect2i(100, 0, 590, 360)],
	49409: ["mercenaries/bazaar_trader.jpg", Rect2i(0, 69, 690, 421)],
	49410: ["mercenaries/security_guard.jpg", Rect2i(0, 69, 690, 421)],
	49411: ["mercenaries/bregan_daerthe_spy.jpg", Rect2i(100, 0, 590, 360)],
	49412: ["mercenaries/narl_xibrindas.jpg", Rect2i(100, 0, 590, 360)],
	49413: ["mercenaries/jarlaxle.jpg", Rect2i(100, 0, 590, 360)],
	49414: ["mercenaries/xanathar_smuggler.jpg", Rect2i(0, 69, 690, 421)],
	49415: ["mercenaries/shady_merchant.jpg", Rect2i(100, 0, 590, 360)],
	49416: ["mercenaries/sylgar.jpg", Rect2i(0, 69, 690, 421)],
	49417: ["mercenaries/ahmaergo.jpg", Rect2i(100, 0, 590, 360)],
	49418: ["mercenaries/xanathar_zushaxx.jpg", Rect2i(100, 0, 590, 360)],
	49419: ["mercenaries/xanathar_surveillance.jpg", Rect2i(0, 69, 690, 421)],
	# Avernus (New Era Noxus): D&D Beyond 2024, жетоны Half-Dragon — из PDF мода
	49500: ["avernus/bandit.jpeg", Rect2i(100, 220, 600, 366)],
	49501: ["avernus/wereboar.jpeg", Rect2i(0, 30, 559, 341)],
	49502: ["avernus/goblin_boss.png", Rect2i(0, 40, 600, 366)],
	49503: ["avernus/hell_hound.png", Rect2i(110, 110, 700, 427)],
	49504: ["avernus/pseudodragon.png", Rect2i(301, 480, 500, 305)],
	49505: ["avernus/medusa.jpeg", Rect2i(0, 20, 545, 332)],
	49506: ["avernus/bugbear_stalker.png", Rect2i(0, 60, 600, 366)],
	49507: ["avernus/guard_captain.jpeg", Rect2i(0, 40, 569, 347)],
	49508: ["avernus/bugbear_warrior.png", Rect2i(60, 20, 800, 488)],
	49509: ["avernus/mummy.png", Rect2i(0, 60, 600, 366)],
	49510: ["avernus/ogre.png", Rect2i(0, 110, 600, 366)],
	49511: ["avernus/minotaur.png", Rect2i(500, 150, 500, 305)],
	49512: ["avernus/hobgoblin_captain.png", Rect2i(197, 170, 400, 244)],
	49513: ["avernus/weretiger.jpeg", Rect2i(120, 0, 600, 366)],
	49514: ["avernus/lamia.png", Rect2i(500, 0, 500, 305)],
	49515: ["avernus/horned_devil.png", Rect2i(0, 80, 451, 275)],
	49516: ["avernus/efreeti.png", Rect2i(0, 20, 600, 366)],
	49517: ["avernus/azer_sentinel.jpeg", Rect2i(171, 0, 600, 366)],
	49518: ["avernus/ice_devil.jpeg", Rect2i(90, 50, 600, 366)],
	49519: ["avernus/troll.jpeg", Rect2i(0, 0, 571, 348)],
	49520: ["avernus/fire_giant.png", Rect2i(230, 0, 600, 366)],
	49521: ["avernus/half_dragon.png", Rect2i(0, 60, 700, 427)],
	49522: ["avernus/wyvern.png", Rect2i(100, 0, 800, 488)],
	49523: ["avernus/blade_fragment.jpg", Rect2i(250, 390, 1000, 610)],
	49524: ["avernus/blade_of_exile.jpg", Rect2i(250, 360, 1000, 610)],
	# Icewind Dale (New Era Freljord): D&D Beyond 2024
	49600: ["freljord/guard.jpeg", Rect2i(0, 0, 595, 363)],
	49601: ["freljord/skeleton.jpeg", Rect2i(30, 120, 656, 400)],
	49602: ["freljord/werewolf.png", Rect2i(10, 300, 400, 244)],
	49603: ["freljord/magmin.png", Rect2i(150, 0, 656, 400)],
	49604: ["freljord/centaur_trooper.jpeg", Rect2i(130, 220, 600, 366)],
	49605: ["freljord/bulette.png", Rect2i(150, 100, 750, 457)],
	49606: ["freljord/ice_mephit.jpeg", Rect2i(150, 20, 650, 396)],
	49607: ["freljord/invisible_stalker.png", Rect2i(80, 480, 656, 400)],
	49608: ["freljord/ettercap.png", Rect2i(150, 50, 656, 400)],
	49609: ["freljord/xorn.png", Rect2i(70, 280, 656, 400)],
	49610: ["freljord/giant_owl.jpeg", Rect2i(350, 30, 560, 341)],
	49611: ["freljord/winter_wolf.jpeg", Rect2i(300, 100, 600, 366)],
	49612: ["freljord/giant_hyena.jpeg", Rect2i(100, 40, 600, 366)],
	49613: ["freljord/owlbear.jpeg", Rect2i(60, 20, 620, 378)],
	49614: ["freljord/hill_giant.png", Rect2i(100, 0, 820, 500)],
	49615: ["freljord/cloud_giant.png", Rect2i(100, 20, 700, 427)],
	49616: ["freljord/remorhaz.png", Rect2i(150, 560, 600, 366)],
	49617: ["freljord/mammoth.png", Rect2i(0, 200, 608, 371)],
	49618: ["freljord/storm_giant.png", Rect2i(0, 60, 487, 297)],
	49620: ["freljord/frost_giant.png", Rect2i(0, 0, 640, 390)],
	49634: ["freljord/pirate_captain.jpeg", Rect2i(0, 200, 522, 318)],
	49635: ["freljord/blink_dog.jpeg", Rect2i(144, 130, 656, 400)],
	49636: ["freljord/young_white_dragon.png", Rect2i(300, 60, 560, 341)],
	# Calimshan (New Era Shurima), арты D&D Beyond
	49700: ["shurima/zombie.jpeg", Rect2i(0, 120, 777, 474)],
	49701: ["shurima/cockatrice.png", Rect2i(60, 400, 560, 341)],
	49702: ["shurima/brass_dragon_wyrmling.png", Rect2i(150, 150, 700, 427)],
	49703: ["shurima/steam_mephit.jpeg", Rect2i(0, 80, 638, 389)],
	49704: ["shurima/commoner.png", Rect2i(100, 230, 650, 396)],
	49705: ["shurima/tough.png", Rect2i(0, 150, 460, 280)],
	49706: ["shurima/incubus.png", Rect2i(0, 130, 572, 349)],
	49707: ["shurima/goblin_warrior.png", Rect2i(0, 230, 574, 350)],
	49708: ["shurima/goblin_minion.jpeg", Rect2i(100, 40, 700, 427)],
	49709: ["shurima/dragon_turtle.png", Rect2i(100, 100, 700, 427)],
	49710: ["shurima/magma_mephit.jpeg", Rect2i(300, 80, 700, 427)],
	49711: ["shurima/roper.jpeg", Rect2i(50, 220, 700, 427)],
	49712: ["shurima/ancient_brass_dragon.jpeg", Rect2i(50, 120, 600, 366)],
	49713: ["shurima/purple_worm.png", Rect2i(0, 520, 455, 277)],
	49714: ["shurima/guardian_naga.jpeg", Rect2i(50, 0, 700, 427)],
	49715: ["shurima/adult_brass_dragon.png", Rect2i(150, 180, 700, 427)],
	49716: ["shurima/stone_giant.png", Rect2i(250, 0, 700, 427)],
	49717: ["shurima/gorgon.png", Rect2i(200, 100, 600, 366)],
	49718: ["shurima/ankheg.png", Rect2i(0, 50, 755, 460)],
	49719: ["shurima/dust_mephit.jpeg", Rect2i(0, 220, 525, 320)],
	49720: ["shurima/deva.png", Rect2i(100, 80, 650, 396)],
	# Kara-Tur (New Era Ionia) — арты D&D Beyond, все с фоном
	49800: ["ionia/ancient_green_dragon.jpeg", Rect2i(0, 150, 500, 305)],
	49801: ["ionia/oni.png", Rect2i(0, 0, 600, 366)],
	49802: ["ionia/adult_bronze_dragon.png", Rect2i(200, 160, 600, 366)],
	49803: ["ionia/ancient_black_dragon.jpeg", Rect2i(130, 380, 540, 329)],
	49804: ["ionia/sprite.png", Rect2i(0, 0, 452, 276)],
	49805: ["ionia/dryad.png", Rect2i(0, 120, 500, 305)],
	49806: ["ionia/ancient_copper_dragon.jpeg", Rect2i(0, 80, 640, 390)],
	49807: ["ionia/ancient_blue_dragon.jpeg", Rect2i(150, 20, 500, 305)],
	49808: ["ionia/mage.jpeg", Rect2i(0, 280, 553, 337)],
	49809: ["ionia/violet_fungus.jpeg", Rect2i(0, 50, 614, 374)],
	49810: ["ionia/merfolk_skirmisher.jpeg", Rect2i(150, 40, 500, 305)],
	49811: ["ionia/tarrasque.jpeg", Rect2i(250, 0, 650, 396)],
	49812: ["ionia/copper_dragon_wyrmling.jpeg", Rect2i(150, 90, 560, 341)],
	49813: ["ionia/silver_dragon_wyrmling.png", Rect2i(250, 160, 520, 317)],
	49814: ["ionia/young_brass_dragon.png", Rect2i(150, 260, 560, 341)],
	49815: ["ionia/ancient_bronze_dragon.jpeg", Rect2i(300, 140, 460, 280)],
	49816: ["ionia/adult_copper_dragon.png", Rect2i(80, 40, 520, 317)],
	49817: ["ionia/merrow.png", Rect2i(0, 160, 401, 245)],
	49818: ["ionia/adult_silver_dragon.png", Rect2i(420, 120, 580, 354)],
	49819: ["ionia/shrieker_fungus.jpeg", Rect2i(0, 40, 536, 327)],
	49820: ["ionia/adult_gold_dragon.png", Rect2i(80, 100, 500, 305)],
	49821: ["ionia/ancient_silver_dragon.jpeg", Rect2i(40, 60, 520, 317)],
	49822: ["ionia/kraken.png", Rect2i(120, 40, 600, 366)],
	# FEYWILD (Bandle City)
	49900: ["bandle/satyr_thornbearer.jpeg", Rect2i(0, 0, 800, 488)],
	49901: ["bandle/high_fae_kindguard.jpeg", Rect2i(150, 0, 850, 518)],
	49902: ["bandle/high_fae_noble.jpeg", Rect2i(100, 120, 820, 500)],
	49903: ["bandle/lorehold_apprentice.jpeg", Rect2i(0, 40, 702, 428)],
	49904: ["bandle/silverquill_apprentice.jpeg", Rect2i(0, 0, 648, 395)],
	49905: ["bandle/faerie_pathlighter.jpeg", Rect2i(220, 0, 600, 366)],
	49906: ["bandle/faerie_dragon_youth.jpeg", Rect2i(0, 200, 767, 468)],
	49908: ["bandle/witherbloom_apprentice.jpeg", Rect2i(0, 0, 900, 549)],
	49909: ["bandle/witchkite.jpeg", Rect2i(200, 120, 800, 488)],
	49910: ["bandle/modron_monodrone.jpeg", Rect2i(0, 150, 800, 488)],
	49911: ["bandle/high_fae_mage.jpeg", Rect2i(50, 100, 800, 488)],
	49912: ["bandle/icewind_kobold.jpeg", Rect2i(0, 40, 719, 438)],
	49913: ["bandle/leprechaun.png", Rect2i(0, 330, 397, 242)],
	49914: ["bandle/faerie_pest.jpeg", Rect2i(150, 0, 850, 518)],
	49915: ["bandle/quandrix_apprentice.jpeg", Rect2i(100, 40, 800, 488)],
	49916: ["bandle/yeti_tyke.jpeg", Rect2i(0, 60, 867, 529)],
	49917: ["bandle/faerie_borrower.jpeg", Rect2i(150, 50, 750, 457)],
	49918: ["bandle/high_fae_impostor.jpeg", Rect2i(100, 0, 900, 549)],
	49919: ["bandle/pixie_wonderbringer.png", Rect2i(200, 250, 600, 366)],
	49920: ["bandle/ogre_chitterlord.jpeg", Rect2i(100, 120, 820, 500)],
	49921: ["bandle/goblin_hexer.png", Rect2i(0, 150, 578, 352)],
	49922: ["bandle/faerie_dragon_adult.jpeg", Rect2i(0, 190, 520, 317)],
	# FAR REALM (Void)
	50000: ["void/githyanki_knight.png", Rect2i(0, 0, 525, 320)],
	50001: ["void/greater_star_spawn_emissary.jpeg", Rect2i(100, 100, 800, 488)],
	50002: ["void/froghemoth_elder.jpeg", Rect2i(0, 0, 773, 471)],
	50003: ["void/githzerai_zerth.jpeg", Rect2i(0, 120, 525, 320)],
	50004: ["void/thri_kreen_marauder.png", Rect2i(60, 180, 483, 294)],
	50005: ["void/red_slaad.jpeg", Rect2i(0, 50, 613, 374)],
	50006: ["void/inquisitor_mind_fire.jpeg", Rect2i(0, 50, 495, 302)],
	50007: ["void/groundling_stalker.jpeg", Rect2i(100, 0, 740, 451)],
	50008: ["void/eye_monger.jpeg", Rect2i(150, 30, 850, 518)],
	50010: ["void/lesser_star_spawn_emissary.jpeg", Rect2i(0, 20, 576, 351)],
	50011: ["void/githzerai_monk.jpeg", Rect2i(0, 180, 555, 338)],
	50012: ["void/thri_kreen_psion.jpeg", Rect2i(0, 60, 547, 333)],
	50013: ["void/hook_horror.png", Rect2i(0, 50, 800, 488)],
	50014: ["void/elder_thing.jpeg", Rect2i(100, 0, 877, 535)],
	50015: ["void/carrion_stalker.png", Rect2i(100, 50, 820, 500)],
	50016: ["void/gray_slaad.jpeg", Rect2i(0, 250, 655, 400)],
	50017: ["void/green_slaad.jpeg", Rect2i(0, 280, 501, 305)],
	50018: ["void/blue_slaad.jpeg", Rect2i(0, 200, 537, 327)],
	50019: ["void/githyanki_dracomancer.png", Rect2i(0, 150, 523, 319)],
	50020: ["void/githyanki_warrior.png", Rect2i(0, 180, 529, 322)],
	# CHULT (Ixtal)
	50100: ["ixtal/yuanti_infiltrator.jpeg", Rect2i(0, 0, 450, 274)],
	50101: ["ixtal/galeb_duhr.png", Rect2i(130, 40, 600, 366)],
	50102: ["ixtal/sarrukh_tyrant.png", Rect2i(180, 0, 700, 427)],
	50103: ["ixtal/lizardfolk_sovereign.jpeg", Rect2i(0, 50, 600, 366)],
	50104: ["ixtal/chwinga.png", Rect2i(150, 430, 400, 244)],
	50105: ["ixtal/troglodyte.png", Rect2i(0, 0, 820, 500)],
	50106: ["ixtal/lizardfolk_geomancer.jpeg", Rect2i(250, 30, 650, 396)],
	50107: ["ixtal/dao.png", Rect2i(50, 60, 600, 366)],
	50108: ["ixtal/knight_of_eldraine.jpeg", Rect2i(350, 150, 650, 396)],
	50110: ["ixtal/bandit_deceiver.jpeg", Rect2i(0, 40, 800, 488)],
	50111: ["ixtal/lizardfolk_warden.jpeg", Rect2i(200, 60, 700, 427)],
	50112: ["ixtal/yuanti_abomination.png", Rect2i(0, 80, 400, 244)],
	50113: ["ixtal/performer_maestro.png", Rect2i(0, 300, 556, 339)],
	50114: ["ixtal/minotaur_archaeologist.png", Rect2i(50, 120, 700, 427)],
	50115: ["ixtal/living_gust_of_wind.jpeg", Rect2i(150, 0, 850, 518)],
	50116: ["ixtal/bullywug_bog_sage.png", Rect2i(0, 300, 427, 260)],
	50117: ["ixtal/cyclops_oracle.jpeg", Rect2i(0, 80, 516, 315)],
	50118: ["ixtal/kenku.png", Rect2i(0, 380, 465, 284)],
	50119: ["ixtal/aarakocra_aeromancer.png", Rect2i(250, 0, 750, 457)],
	50120: ["ixtal/bone_naga.png", Rect2i(100, 20, 750, 457)],
}

const FONT := {
	"A": ["01110","10001","10001","11111","10001","10001","10001"],
	"B": ["11110","10001","10001","11110","10001","10001","11110"],
	"C": ["01110","10001","10000","10000","10000","10001","01110"],
	"D": ["11110","10001","10001","10001","10001","10001","11110"],
	"E": ["11111","10000","10000","11110","10000","10000","11111"],
	"F": ["11111","10000","10000","11110","10000","10000","10000"],
	"G": ["01110","10001","10000","10111","10001","10001","01111"],
	"H": ["10001","10001","10001","11111","10001","10001","10001"],
	"I": ["01110","00100","00100","00100","00100","00100","01110"],
	"J": ["00111","00010","00010","00010","00010","10010","01100"],
	"K": ["10001","10010","10100","11000","10100","10010","10001"],
	"L": ["10000","10000","10000","10000","10000","10000","11111"],
	"M": ["10001","11011","10101","10101","10001","10001","10001"],
	"N": ["10001","10001","11001","10101","10011","10001","10001"],
	"O": ["01110","10001","10001","10001","10001","10001","01110"],
	"P": ["11110","10001","10001","11110","10000","10000","10000"],
	"Q": ["01110","10001","10001","10001","10101","10010","01101"],
	"R": ["11110","10001","10001","11110","10100","10010","10001"],
	"S": ["01111","10000","10000","01110","00001","00001","11110"],
	"T": ["11111","00100","00100","00100","00100","00100","00100"],
	"U": ["10001","10001","10001","10001","10001","10001","01110"],
	"V": ["10001","10001","10001","10001","10001","01010","00100"],
	"W": ["10001","10001","10001","10101","10101","10101","01010"],
	"X": ["10001","10001","01010","00100","01010","10001","10001"],
	"Y": ["10001","10001","10001","01010","00100","00100","00100"],
	"Z": ["11111","00001","00010","00100","01000","10000","11111"],
	"0": ["01110","10001","10011","10101","11001","10001","01110"],
	"1": ["00100","01100","00100","00100","00100","00100","01110"],
	"2": ["01110","10001","00001","00010","00100","01000","11111"],
	"3": ["11111","00010","00100","00010","00001","10001","01110"],
	"4": ["00010","00110","01010","10010","11111","00010","00010"],
	"5": ["11111","10000","11110","00001","00001","10001","01110"],
	"6": ["00110","01000","10000","11110","10001","10001","01110"],
	"7": ["11111","00001","00010","00100","01000","01000","01000"],
	"8": ["01110","10001","10001","01110","10001","10001","01110"],
	"9": ["01110","10001","10001","01111","00001","00010","01100"],
	".": ["00000","00000","00000","00000","00000","01100","01100"],
	",": ["00000","00000","00000","00000","01100","00100","01000"],
	":": ["00000","01100","01100","00000","01100","01100","00000"],
	";": ["00000","01100","01100","00000","01100","00100","01000"],
	">": ["00000","01000","01100","01110","01100","01000","00000"],
	"-": ["00000","00000","00000","11111","00000","00000","00000"],
	"+": ["00000","00100","00100","11111","00100","00100","00000"],
	"'": ["00100","00100","01000","00000","00000","00000","00000"],
	"\"": ["01010","01010","00000","00000","00000","00000","00000"],
	"(": ["00010","00100","01000","01000","01000","00100","00010"],
	")": ["01000","00100","00010","00010","00010","00100","01000"],
	"/": ["00001","00010","00010","00100","01000","01000","10000"],
	"&": ["01100","10010","10100","01000","10101","10010","01101"],
	"!": ["00100","00100","00100","00100","00100","00000","00100"],
	"?": ["01110","10001","00001","00010","00100","00000","00100"],
	"•": ["00000","00000","01110","01110","01110","00000","00000"],
	" ": ["00000","00000","00000","00000","00000","00000","00000"],
}
const CHAR_MAP := {"’": "'", "►": ">", "É": "E", "—": "-", "–": "-"}

const ICONS := {
	"CONQUEST": ["1010101","1111111","0111110","0110110","0111110","0111110","1111111"],
	"MALICE": ["0111110","1111111","1001001","1111111","0110110","0111110","0101010"],
	"AMBITION": ["0001000","1001001","1011101","1111111","1111111","0111110","0111110"],
	"GUILE": ["0111110","1000001","1011101","1010101","1011001","1000010","0111100"],
	"OBEDIENCE": ["0011100","0100010","0100010","1111111","1110111","1111111","0111110"],
}
## Те же значки шириной 5 — для колонки мелкой карты, иначе рядом с ней в
## строке имени остаётся 7 букв вместо 8.
const MINI_ICONS := {
	"CONQUEST": ["10101","11111","01110","01010","01110","01110","11111"],
	"MALICE": ["01110","11111","10101","11111","01010","01110","01010"],
	"AMBITION": ["00100","10101","10101","11111","11111","01110","01110"],
	"GUILE": ["01110","10001","10111","10101","10001","10010","01100"],
	"OBEDIENCE": ["01110","10001","10001","11111","11011","11111","01110"],
}

var img: Image
var sheets_cache := {}
## Режим "-- alt": арт карты берётся отсюда, а не из листа TTS.
var alt_art: Image = null
var alt_face := Vector2i(-1, -1)
var full_png := OUT
## card_id -> [x, y]: вырезы мини из tools/mini_crop_editor (data/cards/mini_faces.json).
var mini_faces := {}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DirAccess.make_dir_recursive_absolute(OUT_MINI)
	var all: Array = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "engine/godot/data/cards/cards.json"))
	var faces_path := ROOT + "engine/godot/data/cards/mini_faces.json"
	if FileAccess.file_exists(faces_path):
		mini_faces = JSON.parse_string(FileAccess.get_file_as_string(faces_path))

	# "-- mini": перерисовать только мелкие лица, не трогая большие карты. Полный
	# прогон долгий (подбор палитры для каждого арта), а разметку мелкой карты
	# приходится перебирать по многу раз.
	if OS.get_cmdline_user_args().has("mini"):
		render_mini_preview(all)
		return
	if OS.get_cmdline_user_args().has("copies"):
		patch_footers(all)
		return

	# One layout for the whole set: the text box fits the longest card text.
	var max_text_px := 0
	var max_name := ""
	for c: Dictionary in all:
		var h := text_block_height(layout_text(sv(c["ability_text"])))
		if h > max_text_px:
			max_text_px = h
			max_name = sv(c["name"])
	print("tallest text: ", max_name, " ", max_text_px, "px")
	# "-- measure": только высоты текстов (новые карты не должны раздувать
	# рамку всего набора — предел 85px, как у самой длинной старой карты).
	if OS.get_cmdline_user_args().has("measure"):
		for c: Dictionary in all:
			var th := text_block_height(layout_text(sv(c["ability_text"])))
			if th > 70:
				print("  ", th, "px ", c["card_id"], " ", c["name"])
		quit()
		return
	var text_top := 34 + ART_H + 5
	var text_h := max_text_px + 8
	var H := text_top + text_h + 22
	print("card size: ", W, "x", H)

	# "-- alt [only=файл,файл]": альтернативные арты из tools/alt_arts.gd.
	if OS.get_cmdline_user_args().has("alt"):
		render_alt(all, H, text_top, text_h)
		return

	# "-- only=50000,50004": перерисовать только эти карты (подбор кадра), без листов превью.
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("only="):
			for id_text in String(a).trim_prefix("only=").split(","):
				only.append(String(id_text).to_int())
	DirAccess.make_dir_recursive_absolute(PREVIEW)
	var rendered: Array[Image] = []
	for c: Dictionary in all:
		if not only.is_empty() and not only.has(int(c["card_id"])):
			continue
		if not SHEETS.has(int(c["card_id"]) / 100) and not SINGLE_ART.has(int(c["card_id"])):
			print("no art sheet for card ", c["card_id"], " ", c["name"])
			continue
		var card := render(c, H, text_top, text_h)
		card.save_png(OUT + "%d.png" % int(c["card_id"]))
		rendered.append(card)
		render_mini(c).save_png(OUT_MINI + "%d.png" % int(c["card_id"]))
	print("rendered: ", rendered.size())
	if not only.is_empty():
		quit()
		return

	# preview sheets: 5x5 cards at x2
	var s := 2
	var gap := 6
	var per_page := 25
	for page in ceili(rendered.size() / float(per_page)):
		var sheet := Image.create(5 * (W * s + gap) + gap, 5 * (H * s + gap) + gap, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.08, 0.08, 0.1))
		for i in range(page * per_page, mini(rendered.size(), (page + 1) * per_page)):
			var j := i - page * per_page
			var b := rendered[i].duplicate() as Image
			b.resize(W * s, H * s, Image.INTERPOLATE_NEAREST)
			sheet.blit_rect(b, Rect2i(0, 0, W * s, H * s), Vector2i(gap + (j % 5) * (W * s + gap), gap + (j / 5) * (H * s + gap)))
		sheet.save_png(PREVIEW + "sheet_%d.png" % (page + 1))
	quit()


func render(c: Dictionary, H: int, text_top: int, text_h: int) -> Image:
	img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(C_OUTLINE)
	rect(1, 1, W - 2, H - 2, C_FRAME)
	rect(1, 1, W - 2, 1, C_FRAME_HI)
	rect(1, 1, 1, H - 2, C_FRAME_HI)
	rect(1, H - 2, W - 2, 1, C_FRAME_LO)
	rect(W - 2, 1, 1, H - 2, C_FRAME_LO)

	var card_id := int(c["card_id"])
	var aspect := sv(c["aspect"])
	var aspect_col: Color = ASPECT_COLOR.get(aspect, C_GREY)

	# header: cost (2x, right) + name (2x if it fits, else 1x in one or two lines)
	var cost_str := "" if c["cost"] == null else str(int(c["cost"]))
	var cost_w := text_width(cost_str, 2)
	if cost_str != "":
		text(W - 7 - cost_w, 6, cost_str, C_LIGHT, 2, C_OUTLINE)
	var name := clean(sv(c["name"]))
	var name_room := W - 14 - (cost_w + 10 if cost_str != "" else 0)
	if text_width(name, 2) <= name_room:
		text(7, 6, name, C_LIGHT, 2, C_OUTLINE)
	else:
		var nl := wrap_plain(name, name_room)
		if nl.size() == 1:
			text(7, 10, nl[0], C_LIGHT, 1, C_OUTLINE)
		else:
			text(7, 3, nl[0], C_LIGHT, 1, C_OUTLINE)
			text(7, 13, nl[1], C_LIGHT, 1, C_OUTLINE)

	# aspect row
	if aspect != "":
		glyph_rows(7, 24, ICONS[aspect], aspect_col)
		text(17, 24, aspect, aspect_col, 1)
	var type_str := clean(sv(c["type"]))
	text(W - 7 - text_width(type_str, 1), 24, type_str, C_GREY, 1)

	# art
	var aw := W - 12
	var art := alt_art if alt_art != null else pixelize(art_region(card_id, aw, ART_H), aw, ART_H, ART_COLORS)
	rect(5, 33, aw + 2, ART_H + 2, C_OUTLINE)
	img.blit_rect(art, Rect2i(0, 0, aw, ART_H), Vector2i(6, 34))

	# text box
	rect(7, text_top, W - 14, text_h, C_OUTLINE)
	rect(8, text_top + 1, W - 16, text_h - 2, C_PARCH)
	rect(8, text_top + text_h - 2, W - 16, 1, C_PARCH_LO)
	rect(W - 9, text_top + 1, 1, text_h - 2, C_PARCH_LO)
	var paras := layout_text(sv(c["ability_text"]))
	var content_h := text_block_height(paras)
	var y := text_top + 4 + (text_h - 8 - content_h) / 2
	for p: Dictionary in paras:
		for li in p["lines"].size():
			var x := 11 + (8 if p["bullet"] else 0)
			if p["bullet"] and li == 0:
				text(11, y, "•", C_INK, 1)
			for tok: Array in p["lines"][li]:
				draw_word(x, y, String(tok[0]))
				x += word_width(String(tok[0])) + 5
			y += LINE_H
		y += PARA_GAP

	draw_footer(c, H)
	return img


## Нижняя строка: полуколода, число её копий в полуколоде (владелец,
## 2026-10-11: "3 COPIES"; у стартовых и карт запаса копий нет) и VP справа.
func draw_footer(c: Dictionary, H: int) -> void:
	var by := H - 19
	rect(2, by, W - 4, 17, C_FRAME)
	var card_id := int(c["card_id"])
	# Плашки VP такие же, как на мелкой карте (решение владельца, 2026-09-24).
	# Sylgar (Mercenaries): во Внутренний круг не попадает — на карте "-".
	var ic_text := "-" if c["inner_circle_vp"] == null else str(int(c["inner_circle_vp"]))
	var ic_x := mini_vp_badge(W - 7, by + 3, ic_text, C_IC_HI, C_LIGHT)
	mini_vp_badge(ic_x - 1, by + 3, str(int(c["deck_vp"])), C_PARCH, C_INK)
	var set_str := set_name(card_id, sv(c["type"]))
	text(9, by + 4, set_str, C_GREY, 1)
	var n := int(copies_of().get(str(card_id), 0))
	if n > 0:
		text(9 + text_width(set_str, 1) + 8, by + 4, ("%d COPIES" if n > 1 else "%d COPY") % n, C_LIGHT, 1, C_OUTLINE)


var _copies := {}

## card_id -> копий в полуколоде (data/cards/half_decks.json).
func copies_of() -> Dictionary:
	if _copies.is_empty():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "engine/godot/data/cards/half_decks.json"))
		for deck: Dictionary in (data["half_decks"] as Dictionary).values():
			for id: String in (deck.get("copies", {}) as Dictionary):
				_copies[id] = int(deck["copies"][id])
	return _copies


## "-- copies": перерисовать только нижнюю строку у готовых больших карт
## (assets/cards_pixel и альт-арты assets/cards_alt) — арты не трогаются.
func patch_footers(all: Array) -> void:
	var by_id := {}
	for c: Dictionary in all:
		by_id[int(c["card_id"])] = c
	var n := 0
	for dir: String in [OUT, ROOT + "engine/godot/assets/cards_alt/"]:
		for f: String in DirAccess.get_files_at(dir):
			if f.get_extension() != "png":
				continue
			var id := int(f.get_basename().get_slice("_", 0))
			if not by_id.has(id):
				continue
			img = Image.load_from_file(dir + f)
			img.convert(Image.FORMAT_RGBA8)
			draw_footer(by_id[id], img.get_height())
			img.save_png(dir + f)
			n += 1
	print("footers patched: ", n)
	quit()


func set_name(card_id: int, type: String) -> String:
	match card_id / 100:
		483: return "DROW"
		484: return "DRAGONS"
		485: return "DEMONS"
		486: return "ELEMENTAL"
		490: return "CELESTIAL"
		491: return "RAVENLOFT"
		492: return "WATERDEEP"
		493: return "SIEGE"
		494: return "MERCENARIES"
		495: return "AVERNUS"
		496: return "ICEWIND DALE"
		497: return "CALIMSHAN"
		498: return "KARA-TUR"
		499: return "FEYWILD"
		500: return "FAR REALM"
		501: return "CHULT"
	# the shared sheet: indices 0-19 and Umber Hulk (39) belong to the Aberrations half
	var idx := card_id % 100
	return "ABERRATIONS" if idx < 20 or idx == 39 else "UNDEAD"


func art_region(card_id: int, aw: int, ah: int) -> Image:
	if SINGLE_ART.has(card_id):
		var one: Array = SINGLE_ART[card_id]
		var src := Image.load_from_file(ROOT + "cards/" + String(one[0]))
		if src.detect_alpha() != Image.ALPHA_NONE:
			# вырезанный персонаж на прозрачном фоне — подкладываем чёрный
			src.convert(Image.FORMAT_RGBA8)
			var flat := Image.create(src.get_width(), src.get_height(), false, Image.FORMAT_RGBA8)
			flat.fill(Color.BLACK)
			flat.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i.ZERO)
			src = flat
		return crop_to(src, one[1], aw, ah)
	var deck := card_id / 100
	var idx := card_id % 100
	var info: Array = SHEETS[deck]
	if not sheets_cache.has(deck):
		sheets_cache[deck] = Image.load_from_file(ROOT + "cards/" + String(info[0]))
	var sheet: Image = sheets_cache[deck]
	var cols: int = info[1]
	var cw: int = info[2]
	var ch: int = info[3]
	var r: Rect2i = info[4]
	var cell := Vector2i((idx % cols) * cw, (idx / cols) * ch)
	return crop_to(sheet, Rect2i(cell + r.position, r.size), aw, ah)


func crop_to(sheet: Image, r: Rect2i, aw: int, ah: int) -> Image:
	# largest crop with the art window's aspect ratio, centred in the art area
	var want_w := int(r.size.y * aw / float(ah))
	var crop := r
	if want_w <= r.size.x:
		crop = Rect2i(r.position.x + (r.size.x - want_w) / 2, r.position.y, want_w, r.size.y)
	else:
		var want_h := int(r.size.x * ah / float(aw))
		crop = Rect2i(r.position.x, r.position.y + (r.size.y - want_h) / 2, r.size.x, want_h)
	return sheet.get_region(crop)


## Card text lines in cards.json are the printed line breaks, not paragraphs.
## Rejoin them: a new paragraph starts after "." or ":", before a bullet,
## after a resource line ("+2 Power"), or before an "<Aspect> Focus" line.
func layout_text(raw: String) -> Array:
	var paras: Array[String] = []
	for line in raw.split("\n"):
		line = line.strip_edges()
		if line == "":
			continue
		if paras.is_empty():
			paras.append(line)
			continue
		var prev := paras[-1]
		# "• +1 Power" и "+1 Power, +1 Influence" (Siege) — тоже строки ресурсов.
		var resource_line := RegEx.create_from_string("^(• )?(\\+\\d+ (Power|Influence),? ?)+$")
		var brk := prev.ends_with(".") or prev.ends_with(":") or line.begins_with("•") \
			or resource_line.search(prev) != null or line.begins_with("+") or line.contains("Focus ►")
		if prev.ends_with("►"):
			brk = false
		if brk:
			paras.append(line)
		elif prev.ends_with("-"):
			paras[-1] = prev + line
		else:
			paras[-1] = prev + " " + line
	var out: Array = []
	var room := W - 22
	for p in paras:
		var bullet := p.begins_with("•")
		if bullet:
			p = p.substr(1).strip_edges()
		var width := room - (8 if bullet else 0)
		var lines: Array = []
		var cur: Array = []
		var cur_w := 0
		for word in clean(p).split(" ", false):
			var ww := word_width(word)
			if cur.is_empty():
				cur = [[word]]
				cur_w = ww
			elif cur_w + 5 + ww <= width:
				cur.append([word])
				cur_w += 5 + ww
			else:
				lines.append(cur)
				cur = [[word]]
				cur_w = ww
		if not cur.is_empty():
			lines.append(cur)
		out.append({"bullet": bullet, "lines": lines})
	return out


func text_block_height(paras: Array) -> int:
	var h := 0
	for p: Dictionary in paras:
		h += p["lines"].size() * LINE_H + PARA_GAP
	return h - PARA_GAP - 2


func clean(s: String) -> String:
	s = s.to_upper()
	for k: String in CHAR_MAP:
		s = s.replace(k, CHAR_MAP[k])
	return s


func is_keyword(word: String) -> bool:
	return KEYWORDS.has(word.rstrip(".,:;"))


## Bold = glyph drawn twice, shifted one pixel right (1px wider per letter).
func word_width(word: String) -> int:
	var bare := word.rstrip(".,:;")
	var extra := bare.length() if is_keyword(word) else 0
	return text_width(word, 1) + extra


func draw_word(x: int, y: int, word: String) -> void:
	if not is_keyword(word):
		text(x, y, word, C_INK, 1)
		return
	var bare := word.rstrip(".,:;")
	for i in bare.length():
		var g: Array = glyph(bare[i])
		glyph_rows(x + i * 7, y, g, C_INK)
		glyph_rows(x + i * 7 + 1, y, g, C_INK)
	text(x + bare.length() * 7, y, word.substr(bare.length()), C_INK, 1)


func wrap_plain(s: String, max_px: int) -> Array[String]:
	var out: Array[String] = []
	var cur := ""
	for word in s.split(" "):
		var t := word if cur == "" else cur + " " + word
		if text_width(t, 1) > max_px and cur != "":
			out.append(cur)
			cur = word
		else:
			cur = t
	out.append(cur)
	return out


func text_width(s: String, scale: int) -> int:
	return max(0, s.length() * (6 * scale - (scale - 1)) - 1)


func glyph(ch: String) -> Array:
	if not FONT.has(ch):
		print("missing glyph: ", ch)
		return FONT[" "]
	return FONT[ch]


func rect(x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), c)


func glyph_rows(x: int, y: int, rows: Array, c: Color, s: int = 1) -> void:
	for ry in rows.size():
		var row: String = rows[ry]
		for rx in row.length():
			if row[rx] == "1":
				img.fill_rect(Rect2i(x + rx * s, y + ry * s, s, s), c)


func text(x: int, y: int, s: String, c: Color, scale: int, shadow := Color(0, 0, 0, 0)) -> void:
	for i in s.length():
		var g: Array = glyph(s[i])
		if shadow.a > 0:
			glyph_rows(x + i * (6 * scale - (scale - 1)) + scale, y + scale, g, shadow, scale)
		glyph_rows(x + i * (6 * scale - (scale - 1)), y, g, c, scale)


func pixelize(src: Image, tw: int, th: int, k: int) -> Image:
	var im := src.duplicate() as Image
	im.convert(Image.FORMAT_RGBA8)
	im.resize(tw, th, Image.INTERPOLATE_LANCZOS)
	var px: Array[Color] = []
	for y in th:
		for x in tw:
			var c := im.get_pixel(x, y)
			c = Color.from_hsv(c.h, clampf(c.s * 1.2, 0, 1), clampf(c.v * 1.05, 0, 1))
			im.set_pixel(x, y, c)
			px.append(c)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var centers: Array[Color] = []
	for i in k:
		centers.append(px[rng.randi_range(0, px.size() - 1)])
	for it in 14:
		var sums: Array[Vector3] = []
		var counts: Array[int] = []
		for i in k:
			sums.append(Vector3.ZERO)
			counts.append(0)
		for c in px:
			var b := nearest(centers, c)
			sums[b] += Vector3(c.r, c.g, c.b)
			counts[b] += 1
		for i in k:
			if counts[i] > 0:
				var m := sums[i] / counts[i]
				centers[i] = Color(m.x, m.y, m.z)
	for y in th:
		for x in tw:
			var p := centers[nearest(centers, im.get_pixel(x, y))]
			im.set_pixel(x, y, Color(p.r, p.g, p.b, 1))
	return im


func nearest(centers: Array[Color], c: Color) -> int:
	var best := 0
	var bd := 1e9
	for i in centers.size():
		var p := centers[i]
		var d := (p.r - c.r) * (p.r - c.r) * 0.3 + (p.g - c.g) * (p.g - c.g) * 0.59 + (p.b - c.b) * (p.b - c.b) * 0.11
		if d < bd:
			bd = d
			best = i
	return best


func sv(v: Variant) -> String:
	return "" if v == null else str(v)





## Мелкое лицо карты 58x84 для руки, маркета и полос сыгранных карт: шапка с
## именем, ценой и значком аспекта, под ней арт — и всё. Ни текста способности, ни
## VP здесь нет: их читают на большой карте под курсором. Большая карта должна
## быть уже нарисована — арт вырезается из неё.
func render_mini(c: Dictionary) -> Image:
	img = Image.create(MINI_W, MINI_H, false, Image.FORMAT_RGBA8)
	img.fill(C_OUTLINE)
	rect(1, 1, MINI_W - 2, MINI_H - 2, C_FRAME)
	rect(1, 1, MINI_W - 2, 1, C_FRAME_HI)
	# Низ рамки того же цвета, что бока (а не темнее, как у большой карты):
	# полоска в один пиксель под артом замыкает рамку, и карта перестаёт
	# выглядеть обрезанной по нижнему краю.
	rect(1, MINI_H - 2, MINI_W - 2, 1, C_FRAME)

	# Шапка цвета рамки карты, одна на все карты (решение владельца, 2026-09-24).
	rect(1, 1, MINI_W - 2, MINI_HEAD, C_FRAME)
	# Имя во всю ширину шапки: 9 букв (53 px) от x=2, тень уходит на x=55.
	# Первая строка короче на MINI_COST_W: в правом верхнем углу шапки цена.
	var room := MINI_W - 5
	var aspect := sv(c["aspect"])
	var has_side := c["cost"] != null or MINI_ICONS.has(aspect)
	var name := clean(sv(c["name"]))
	var name_lines := wrap_name(MINI_SHORT_NAMES.get(name, name), MINI_SIDE_X - 3 if has_side else room, room,
		MINI_SIDE_LINES, MINI_NAME_LINES)
	for i in name_lines.size():
		text(2, 2 + i * MINI_LINE_H, name_lines[i], C_LIGHT, 1, C_OUTLINE)
	# Справа от имени колонка: цена, под ней значок аспекта, от имени их
	# отделяет вертикальная черта (владелец, 2026-10-08). Цифра — тем же цветом
	# и с той же тенью, что имя. У стартовых карт цены нет.
	if has_side:
		rect(MINI_SIDE_X, 2, 1, MINI_SIDE_LINES * MINI_LINE_H, C_FRAME_HI)
		var x := MINI_SIDE_X + 2  # цифра и значок по 5 пикселей, до x=56
		if c["cost"] != null:
			text(x, 2, str(int(c["cost"])), C_LIGHT, 1, C_OUTLINE)
		if MINI_ICONS.has(aspect):
			glyph_rows(x + 1, 2 + MINI_LINE_H + 1, MINI_ICONS[aspect], C_OUTLINE)
			glyph_rows(x, 2 + MINI_LINE_H, MINI_ICONS[aspect], ASPECT_COLOR[aspect])

	# арт: кусок 1:1 из арта большой карты
	var art_y := 1 + MINI_HEAD + 1
	var aw := MINI_W - 6
	var full := Image.load_from_file(full_png if alt_art != null else OUT + "%d.png" % int(c["card_id"]))
	full.convert(Image.FORMAT_RGBA8)
	var face: Vector2i = MINI_FACE.get(int(c["card_id"]), MINI_FACE_DEFAULT)
	# Вырез, подогнанный вручную в tools/mini_crop_editor, главнее MINI_FACE.
	var hand: Array = mini_faces.get(str(int(c["card_id"])), [])
	if not hand.is_empty():
		face = Vector2i(int(hand[0]), int(hand[1]))
	if alt_art != null:
		face = alt_face
	# Чёрная обводка в пиксель по всему периметру арта, как на большой карте.
	rect(2, art_y - 1, aw + 2, MINI_ART_H + 2, C_OUTLINE)
	img.blit_rect(full, Rect2i(FULL_ART_POS + face, Vector2i(aw, MINI_ART_H)), Vector2i(3, art_y))
	return img


## Плашка VP высотой 9, правым краем на right: светлая — VP в колоде,
## фиолетовая — во внутреннем круге (цвета как на большой карте). Возвращает
## левый край плашки.
func mini_vp_badge(right: int, y: int, v: String, bg: Color, fg: Color) -> int:
	var w := text_width(v, 1) + 2
	rect(right - w, y, w, 9, bg)
	text(right - w + 1, y + 1, v, fg, 1)
	return right - w


## Имя мелкой карты: до max_lines строк. Первые blocked строк помещаются слева
## от цены (ширина beside), остальные идут под ней во всю ширину (free). Слово
## длиннее строки рвётся: по дефису, если он есть, иначе просто по месту с
## дефисом — иначе WEAPONMASTER и MELEE-MAGTHERE уезжают за край карты.
## Имя всегда начинается с первой строки — длинное слово рвётся переносом
## (владелец, 2026-10-06).
func wrap_name(s: String, beside: int, free: int, blocked: int, max_lines: int) -> Array[String]:
	var lines: Array[String] = []
	var words: Array = Array(s.split(" ", false))
	var cur := ""
	var i := 0
	while i < words.size():
		var room: int = free if lines.size() >= blocked else beside
		var word := String(words[i])
		var joined := word if cur == "" else cur + " " + word
		if text_width(joined, 1) <= room:
			cur = joined
			i += 1
		elif cur != "" and word.contains("-") and text_width(word, 1) > free \
				and text_width(cur + " " + word.get_slice("-", 0) + "-", 1) <= room:
			# Слово с дефисом всё равно рвать — пусть первая часть доберёт строку:
			# MASTER / OF MELEE- / MAGTHERE, а не четыре строки.
			var parts := split_word(word, room - text_width(cur + " ", 1) - 1)
			lines.append(cur + " " + parts[0])
			cur = ""
			words[i] = parts[1]
		elif cur != "":
			lines.append(cur)
			cur = ""
		else:
			var parts := split_word(word, room)
			lines.append(parts[0])
			words[i] = parts[1]
	if cur != "":
		lines.append(cur)
	if lines.size() > max_lines:
		print("name does not fit: ", s, " -> ", lines)
		lines.resize(max_lines)
		lines[max_lines - 1] = lines[max_lines - 1] + "."
	return lines


## Делит слово, которое само шире строки. Сначала пробуем последний дефис,
## который ещё влезает, потом границу слога из NAME_BREAKS, иначе ставим дефис
## сами — поближе к середине слова.
func split_word(word: String, room: int) -> Array[String]:
	for k in range(word.length() - 1, 0, -1):
		if word[k] == "-" and text_width(word.substr(0, k + 1), 1) <= room:
			return [word.substr(0, k + 1), word.substr(k + 1)]
	var fit := maxi((room + 1) / 6 - 1, 1)
	var cut := 0
	for b: int in NAME_BREAKS.get(word, []):
		if b <= fit:
			cut = maxi(cut, b)
	if cut == 0:
		cut = mini(fit, (word.length() + 1) / 2)
		print("hyphenated: ", word, " -> ", word.substr(0, cut), "- ", word.substr(cut))
	return [word.substr(0, cut) + "-", word.substr(cut)]


## Альтернативные арты: полная карта и мелкое лицо на каждый арт, файлы
## <card_id>_<n>.png, и листы превью (карта x2 + мини x2 + редкость под ними).
func render_alt(all: Array, H: int, text_top: int, text_h: int) -> void:
	var by_id := {}
	for c: Dictionary in all:
		by_id[int(c["card_id"])] = c
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5).split(",")
	var rejected := OS.get_cmdline_user_args().has("rejected")
	if rejected:
		AltArts.min_zoom_keep = 0.12
		AltArts.face_zoom_min = 0.25
	var out := ROOT + ("Claude outputs/alt_arts_rejected/" if rejected else "Claude outputs/alt_arts/")
	DirAccess.make_dir_recursive_absolute(out + "mini/")
	var counts := {}
	var tiles: Array[Image] = []
	for e: Array in (AltArts.REJECTED if rejected else AltArts.ALT):
		var id: int = e[0]
		if not only.is_empty() and not only.has(String(e[1]).get_basename()):
			continue
		var aw := W - 12
		var src := AltArts.source(e, aw, ART_H, 2)
		if src == null:
			print("DROPPED (too much background): ", e[1])
			continue
		counts[id] = counts.get(id, 0) + 1
		alt_art = pixelize(src, aw, ART_H, ART_COLORS)
		alt_face = e[4] if e[4] != AltArts.NO_FACE else MINI_FACE_DEFAULT
		if AltArts.FACE_CROP.has(e[1]):
			alt_face = Vector2i(56, 23)  # лицо в центре вырезa
		var tag := "%d_%d" % [id, counts[id]]
		var card := render(by_id[id], H, text_top, text_h)
		full_png = out + tag + ".png"
		card.save_png(full_png)
		var mini := render_mini(by_id[id])
		mini.save_png(out + "mini/" + tag + ".png")
		print(tag, " ", e[1], " ", e[2])

		# плитка превью: карта и мини в x2, под ними редкость и файл
		var s := 2
		img = Image.create(W * s + MINI_W * s + 6, H * s + 12, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.04, 0.03, 0.07))
		var big := card.duplicate() as Image
		big.resize(W * s, H * s, Image.INTERPOLATE_NEAREST)
		img.blit_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), Vector2i.ZERO)
		var small := mini.duplicate() as Image
		small.resize(MINI_W * s, MINI_H * s, Image.INTERPOLATE_NEAREST)
		img.blit_rect(small, Rect2i(Vector2i.ZERO, small.get_size()), Vector2i(W * s + 6, 0))
		var rar_col := C_GOLD if e[2] == "LEGENDARY" else C_IC_HI
		text(2, H * s + 2, String(e[2]) + "  " + clean(String(e[1]).get_basename().to_upper()), rar_col, 1)
		tiles.append(img)
	alt_art = null

	var cols := 4
	var rows := 2
	var tw := tiles[0].get_width() if not tiles.is_empty() else 1
	var th := tiles[0].get_height() if not tiles.is_empty() else 1
	var gap := 8
	for page in ceili(tiles.size() / float(cols * rows)):
		var sheet := Image.create(cols * (tw + gap) + gap, rows * (th + gap) + gap, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.02, 0.02, 0.03))
		for i in range(page * cols * rows, mini(tiles.size(), (page + 1) * cols * rows)):
			var j := i - page * cols * rows
			sheet.blit_rect(tiles[i], Rect2i(Vector2i.ZERO, tiles[i].get_size()),
				Vector2i(gap + (j % cols) * (tw + gap), gap + (j / cols) * (th + gap)))
		sheet.save_png(out + "sheet_%d.png" % (page + 1))
	print("alt rendered: ", tiles.size())
	quit()


## Мелкие лица в assets, а заодно листы в x4 для просмотра разметки глазом.
func render_mini_preview(all: Array) -> void:
	var dir := PREVIEW + "mini/"
	DirAccess.make_dir_recursive_absolute(dir)
	var rendered: Array[Image] = []
	var by_id := {}
	for c: Dictionary in all:
		if not SHEETS.has(int(c["card_id"]) / 100) and not SINGLE_ART.has(int(c["card_id"])):
			continue
		var m := render_mini(c)
		m.save_png(OUT_MINI + "%d.png" % int(c["card_id"]))
		rendered.append(m)
		by_id[int(c["card_id"])] = m
	print("mini rendered: ", rendered.size(), " ", MINI_W, "x", MINI_H)

	# Мелкие лица альт-артов (<card_id>_<n>.png): шапка у них та же, что у
	# обычного лица карты, — переносим её, арт под ней не трогаем.
	var alt_dir := ROOT + "engine/godot/assets/cards_alt_mini/"
	var alt_count := 0
	for f in DirAccess.get_files_at(alt_dir):
		if f.get_extension() != "png" or not by_id.has(int(f.get_slice("_", 0))):
			continue
		var alt := Image.load_from_file(alt_dir + f)
		alt.convert(Image.FORMAT_RGBA8)
		alt.blit_rect(by_id[int(f.get_slice("_", 0))], Rect2i(0, 0, MINI_W, 1 + MINI_HEAD), Vector2i.ZERO)
		alt.save_png(alt_dir + f)
		alt_count += 1
	print("alt mini headers: ", alt_count)

	var s := 4
	var gap := 8
	var cols := 6
	var rows := 4
	var per_page := cols * rows
	for page in ceili(rendered.size() / float(per_page)):
		var sheet := Image.create(cols * (MINI_W * s + gap) + gap, rows * (MINI_H * s + gap) + gap,
			false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.04, 0.03, 0.07))
		for i in range(page * per_page, mini(rendered.size(), (page + 1) * per_page)):
			var j := i - page * per_page
			var b := rendered[i].duplicate() as Image
			b.resize(MINI_W * s, MINI_H * s, Image.INTERPOLATE_NEAREST)
			sheet.blit_rect(b, Rect2i(0, 0, MINI_W * s, MINI_H * s),
				Vector2i(gap + (j % cols) * (MINI_W * s + gap), gap + (j / cols) * (MINI_H * s + gap)))
		sheet.save_png(dir + "sheet_%d.png" % (page + 1))
	quit()
