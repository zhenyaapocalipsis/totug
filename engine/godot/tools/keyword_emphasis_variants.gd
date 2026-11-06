extends SceneTree

const L10n := preload("res://scenes/localization.gd")
const Style := preload("res://scenes/ui/keyword_style.gd")
const PC := preload("res://tools/pixel_cards.gd")
const COLORS := {
 "DEVOUR": Color("#95106f"),
 "SUPPLANT": Color("#9a4300"),
 "DEPLOY": Color("#006b20"),
 "ASSASSINATE": Color("#b00020"),
 "PLACE": Color("#123bc4"),
 "RETURN": Color("#00747b"),
 "PROMOTE": Color("#7620b4"),
 "BRIBE": Color("#775d00"),
 "STEAL": Color("#ab006c"),
 "RECRUIT": Color("#3d6d00"),
 "RECRUITS": Color("#2b6100"),
 "MOVE": Color("#005c93"),
 "FOCUS": Color("#3633bd"),
 "SCRY": Color("#006c98"),
 "MIGHT": Color("#a23b18"),
 "FROSTBITE": Color("#006c9d"),
 "TRANSFORM": Color("#865300"),
 "DISTINCT": Color("#812a96"),
 "DEVOTION": Color("#a14700"),
 "RETAIN": Color("#006955"),
 "RETAINED": Color("#506300"),
 "GLAMOUR": Color("#a31679"),
 "EXPLORE": Color("#4c6c00"),
}
func _initialize() -> void:
 _run.call_deferred()
func _run() -> void:
 L10n.set_locale("ru")
 var sheet := Image.create(1104, 810, false, Image.FORMAT_RGBA8)
 sheet.fill(Color("#1d222a"))
 var titles := ["1. НАСЫЩЕННЫЙ ЦВЕТ", "2. ПОДЧЁРКИВАНИЕ", "3. ЛЁГКАЯ ПОДЛОЖКА"]
 var captions := ["ТОЛЬКО ЦВЕТ", "ЦВЕТ + ЛИНИЯ", "ЦВЕТ + ФОН"]
 for mode in 3:
  var x := 8 + mode * 368
  PixelFont.draw_text(sheet, x + 8, 22, titles[mode], Color.WHITE, 2)
  var face := CardView.pixel_texture("48419").get_image().duplicate() as Image
  var box := CardLiveFace.layout_for_card("48419", [], 176, 254)
  # Restore only the interior, keeping the original field and card frame.
  face.fill_rect(Rect2i(9, int(box.top) + 2, 158, int(box.box_h) - 4), PC.C_PARCH)
  for dot: Vector2i in box.bullets:
   CardLiveFace._text(face, dot.x, dot.y, "•", PC.C_INK, 1)
  var words: Array = box.words
  for i in words.size():
   var spot: Array = words[i]
   var word := String(spot[2])
   var following: Array = words.slice(i + 1, i + 5).map(func(item): return String(item[2]))
   var id := Style.resolve(word, following)
   if COLORS.has(id):
    draw_keyword(face, int(spot[0]), int(spot[1]), word, id, mode)
   else:
    CardLiveFace._text(face, int(spot[0]), int(spot[1]), word, PC.C_INK, 1)
  face.resize(352, 508, Image.INTERPOLATE_NEAREST)
  sheet.blit_rect(face, Rect2i(Vector2i.ZERO,face.get_size()),Vector2i(x,65))
  PixelFont.draw_text(sheet, x + 10, 602, captions[mode], Color.WHITE, 2)
  var swatch := Image.create(176, 78, false, Image.FORMAT_RGBA8)
  swatch.fill(PC.C_PARCH)
  draw_keyword(swatch, 10, 9, "УНИЧТОЖЬТЕ", "ASSASSINATE", mode)
  draw_keyword(swatch, 10, 26, "ЗАМЕНИТЕ", "SUPPLANT", mode)
  draw_keyword(swatch, 10, 43, "ВОЗВЫСЬТЕ", "PROMOTE", mode)
  draw_keyword(swatch, 10, 60, "ПОГЛОТИТЕ", "DEVOUR", mode)
  swatch.resize(352,156,Image.INTERPOLATE_NEAREST)
  sheet.blit_rect(swatch,Rect2i(Vector2i.ZERO,swatch.get_size()),Vector2i(x,640))
 sheet.save_png("res://.godot/keyword_emphasis_variants_ru.png")
 quit()
func draw_keyword(img: Image, x: int, y: int, word: String, id: String, mode: int) -> void:
 var bare := word.rstrip(".,:;")
 var color: Color = COLORS[id]
 var width := bare.length() * 7 - 1
 if mode == 2:
  img.fill_rect(Rect2i(x - 1, y - 1, width + 2, 9), PC.C_PARCH.lerp(color, 0.17))
 if mode == 1:
  img.fill_rect(Rect2i(x, y + 7, width, 1), color)
 for i in bare.length():
  PixelFont.draw_text(img, x + i * 7, y, bare[i], color)
 PixelFont.draw_text(img, x + bare.length() * 7, y, word.substr(bare.length()), PC.C_INK)
