extends SceneTree

const Style := preload("res://scenes/ui/keyword_style.gd")
const PC := preload("res://tools/pixel_cards.gd")
const L10n := preload("res://scenes/localization.gd")
const Text := preload("res://scenes/card_text.gd")
var passed := 0
var failed := 0
func _initialize() -> void:
 _run.call_deferred()
func check(ok: bool, why: String) -> void:
 if ok: passed += 1
 else:
  failed += 1
  printerr("FAIL: ", why)
func luminance(c: Color) -> float:
 var linear := c.srgb_to_linear()
 return linear.r * 0.2126 + linear.g * 0.7152 + linear.b * 0.0722
func _run() -> void:
 check(Style.COLORS.size() == PC.KEYWORDS.size(), "palette covers every keyword")
 var distinct := {}
 for id: String in PC.KEYWORDS:
  check(Style.COLORS.has(id), "colour for " + id)
  var color: Color = Style.COLORS[id]
  check(not distinct.has(color.to_html()), "unique colour " + id)
  distinct[color.to_html()] = true
  check((luminance(PC.C_PARCH) + 0.05) / (luminance(color) + 0.05) >= 4.5, "parchment contrast " + id)
 check(Style.resolve("РАЗМЕСТИТЕ", ["2", "ШПИОНОВ."]) == "PLACE", "spy colour context")
 check(Style.resolve("РАЗМЕСТИТЕ", ["2", "ОТРЯДА."]) == "DEPLOY", "troop colour context")
 check(Style.resolve("ВОЗВЫСЬТЕ") == Style.resolve("PROMOTE"), "same semantic ID in both languages")
 check(PixelFont.glyph("Ю")[0] == "100110" and PixelFont.glyph("ю")[2] == "100110", "approved wider Ю and ю")
 check(PixelFont.advance("Ю") == 7 and PixelFont.advance("М") == 6, "wider Ю has its own gap")
 check(PixelFont.text_width("АЮА") == 18 and PC.text_width("АЮА", 1) == 18, "measured and rendered Ю agree")
 var a := Image.create(84, 16, false, Image.FORMAT_RGBA8)
 var b := a.duplicate() as Image
 a.fill(Color.TRANSPARENT)
 b.fill(Color.TRANSPARENT)
 CardLiveFace._draw_word(a, 0, 3, "УНИЧТОЖЬТЕ")
 for i in "УНИЧТОЖЬТЕ".length():
  PixelFont.draw_text(b, i * 7, 3, "УНИЧТОЖЬТЕ"[i], Style.COLORS.ASSASSINATE)
 check(a.get_data() == b.get_data(), "regular glyphs drawn once instead of synthetic bold")
 var opt := Image.create(84, 16, false, Image.FORMAT_RGBA8)
 opt.fill(Color.TRANSPARENT)
 OptionCard._draw_word(opt, 0, 3, "УНИЧТОЖЬТЕ")
 check(opt.get_data() == a.get_data(), "option and live face have identical keyword colour and weight")
 L10n.set_locale("en")
 for cid: String in CardLibrary.all_ids():
  var raw := CardView.pixel_texture(cid, "", false).get_image()
  if raw.is_compressed(): raw.decompress()
  raw.convert(Image.FORMAT_RGBA8)
  var rendered := CardView.pixel_texture(cid).get_image()
  var field := CardLiveFace.layout_for_card(cid, [], 176, 254)
  var source_field := CardLiveFace.text_layout(String(CardLibrary.card_data(cid).ability_text), [], 176, 254)
  check(field.top == source_field.top and field.box_h == source_field.box_h, "original English geometry " + cid)
  # Every pixel outside the pre-existing ability field must remain unchanged.
  var restored := rendered.duplicate() as Image
  var area := Rect2i(7, int(field.top), 162, int(field.box_h))
  restored.blit_rect(raw, area, area.position)
  check(restored.get_data() == raw.get_data(), "only English ability field changes " + cid)
 var sheet := Image.create(880, 800, false, Image.FORMAT_RGBA8)
 sheet.fill(PC.C_PARCH)
 var row := 0
 for id: String in PC.KEYWORDS:
  var russian := ""
  for word: String in Text.KEYWORDS:
   if Text.KEYWORDS[word] == id:
    russian = word
    break
  if id == "PLACE": russian = "РАЗМЕСТИТЕ ШПИОНА"
  var line := Image.create(210, 11, false, Image.FORMAT_RGBA8)
  line.fill(PC.C_PARCH)
  Style.draw_word(line, 0, 2, russian, id)
  PixelFont.draw_text(line, 135, 2, id, Style.COLORS[id])
  line.resize(840, 44, Image.INTERPOLATE_NEAREST)
  var x := 20 if row < 12 else 450
  var y := 20 + (row % 12) * 42
  # Two columns, shown at 2x with nearest sampling.
  line.resize(420, 22, Image.INTERPOLATE_NEAREST)
  sheet.blit_rect(line, Rect2i(Vector2i.ZERO,line.get_size()),Vector2i(x,y))
  row += 1
 L10n.set_locale("ru")
 var examples := ["48306", "48419", "48519", "48524"]
 for i in examples.size():
  var card := CardView.pixel_texture(examples[i]).get_image()
  sheet.blit_rect(card, Rect2i(Vector2i.ZERO,card.get_size()),Vector2i(30 + i * 210, 535))
 sheet.save_png("res://.godot/keyword_colours_ru.png")
 print("keyword typography: ", passed, " checks, failed ", failed)
 quit(1 if failed else 0)
