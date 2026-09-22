class_name PixelFontSmall
extends RefCounted

## 3x5 pixel font for the schematic board: site names and VP. The board has to
## fit its zone at 1:1 (owner's decision, 2026-09-22), and the 5x7 PixelFont
## made the site boxes wider than the tunnels around them. Capitals, digits and
## the few signs the short site names use; anything else is drawn as a space.
## Advance is 4 px per character.

const FONT := {
	"A": ["010","101","111","101","101"],
	"B": ["110","101","110","101","110"],
	"C": ["011","100","100","100","011"],
	"D": ["110","101","101","101","110"],
	"E": ["111","100","110","100","111"],
	"F": ["111","100","110","100","100"],
	"G": ["011","100","101","101","011"],
	"H": ["101","101","111","101","101"],
	"I": ["111","010","010","010","111"],
	"J": ["001","001","001","101","010"],
	"K": ["101","101","110","101","101"],
	"L": ["100","100","100","100","111"],
	"M": ["101","111","111","101","101"],
	"N": ["101","111","111","111","101"],
	"O": ["010","101","101","101","010"],
	"P": ["110","101","110","100","100"],
	"Q": ["010","101","101","110","011"],
	"R": ["110","101","110","101","101"],
	"S": ["011","100","010","001","110"],
	"T": ["111","010","010","010","010"],
	"U": ["101","101","101","101","111"],
	"V": ["101","101","101","101","010"],
	"W": ["101","101","111","111","101"],
	"X": ["101","101","010","101","101"],
	"Y": ["101","101","010","010","010"],
	"Z": ["111","001","010","100","111"],
	"0": ["111","101","101","101","111"],
	"1": ["010","110","010","010","111"],
	"2": ["110","001","010","100","111"],
	"3": ["110","001","010","001","110"],
	"4": ["101","101","111","001","001"],
	"5": ["111","100","110","001","110"],
	"6": ["011","100","111","101","111"],
	"7": ["111","001","010","010","010"],
	"8": ["111","101","111","101","111"],
	"9": ["111","101","111","001","110"],
	"-": ["000","000","111","000","000"],
	"'": ["010","010","000","000","000"],
	" ": ["000","000","000","000","000"],
}

const ADVANCE := 4
const HEIGHT := 5


static func glyph(ch: String) -> Array:
	return FONT.get(ch.to_upper(), FONT[" "])


static func text_width(s: String, scale: int = 1) -> int:
	if s.is_empty():
		return 0
	return s.length() * ADVANCE * scale - scale


static func draw_text(img: Image, x: int, y: int, s: String, c: Color, scale: int = 1) -> void:
	for i in s.length():
		var rows: Array = glyph(s[i])
		var gx := x + i * ADVANCE * scale
		for ry in rows.size():
			var row: String = rows[ry]
			for rx in row.length():
				if row[rx] == "1":
					img.fill_rect(Rect2i(gx + rx * scale, y + ry * scale, scale, scale), c)
