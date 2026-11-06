extends SceneTree

const INK := Color("#29201a")
const PAPER := Color("#eedfbb")
const CUSTOM := {
 "Ж": ["101101","101101","011110","001100","011110","101101","101101"],
 "М": ["110011","111111","101101","101101","110011","110011","110011"],
 "Ю": ["100110","101001","101001","111001","101001","101001","100110"],
 "ж": ["000000","000000","101101","011110","001100","011110","101101"],
 "м": ["000000","000000","110011","111111","101101","110011","110011"],
 "ю": ["000000","000000","100110","101001","111001","101001","100110"],
}

func _init() -> void:
 var img := Image.create(1050, 560, false, Image.FORMAT_RGBA8)
 img.fill(Color("#1d222a"))
 PixelFont.draw_text(img, 24, 26, "Ж М Ю: СРАВНЕНИЕ НАЧЕРТАНИЙ", Color.WHITE, 3)
 var labels := ["1. БЫЛО", "2. РУЧНОЙ РИСУНОК", "3. БЕЗ УТОЛЩЕНИЯ"]
 for v in 3:
  var x := 18 + v * 344
  img.fill_rect(Rect2i(x, 82, 328, 346), PAPER)
  PixelFont.draw_text(img, x + 12, 100, labels[v], INK, 2)
  draw_sample(img, x + 20, 146, "Ж М Ю", v, 5)
  draw_sample(img, x + 20, 208, "ж м ю", v, 5)
  draw_sample(img, x + 16, 278, "УНИЧТОЖЬТЕ", v, 3)
  draw_sample(img, x + 16, 330, "ЗАМЕНИТЕ", v, 3)
  draw_sample(img, x + 16, 382, "ЧАРЫ / чары", v, 3)
 PixelFont.draw_text(img, 24, 460, "Ё ИСПРАВЛЕНА: Е Ё Е / е ё е / И Й И", Color.WHITE, 3)
 PixelFont.draw_text(img, 24, 518, "ВСЕ ВАРИАНТЫ: ПРЕЖНИЙ ШАГ БУКВ И МАКЕТ", Color("#a9b8cd"), 2)
 img.save_png("res://.godot/font_variants_ru.png")
 quit()

func draw_sample(img: Image, x: int, y: int, s: String, variant: int, scale: int) -> void:
 for i in s.length():
  var ch := s[i]
  var rows: Array = PixelFont.glyph(ch)
  var manual := variant == 1 and CUSTOM.has(ch)
  if manual:
   rows = CUSTOM[ch]
  for ry in rows.size():
   for rx in String(rows[ry]).length():
    if rows[ry][rx] != "1":
     continue
    var pos := Vector2i(x + (i * 7 + rx) * scale, y + (ry + PixelFont.y_offset(ch)) * scale)
    var color := Color("#6b3031") if variant == 2 else INK
    img.fill_rect(Rect2i(pos, Vector2i(scale, scale)), color)
    if variant < 2 and not manual:
     img.fill_rect(Rect2i(pos + Vector2i(scale, 0), Vector2i(scale, scale)), color)
