extends RefCounted

## Semantic colours shared by full cards, live values, options and export.
const Text := preload("res://scenes/card_text.gd")
const COLORS := {
 "DEVOUR": Color("#95106f"), "SUPPLANT": Color("#9a4300"),
 "DEPLOY": Color("#006b20"), "ASSASSINATE": Color("#b00020"),
 "PLACE": Color("#123bc4"), "RETURN": Color("#006a71"),
 "PROMOTE": Color("#7620b4"), "BRIBE": Color("#775b00"),
 "STEAL": Color("#ab006c"), "RECRUIT": Color("#3a6900"),
 "RECRUITS": Color("#2b6100"), "MOVE": Color("#005c93"),
 "FOCUS": Color("#3633bd"), "SCRY": Color("#00668f"),
 "MIGHT": Color("#a23b18"), "FROSTBITE": Color("#006692"),
 "TRANSFORM": Color("#865300"), "DISTINCT": Color("#812a96"),
 "DEVOTION": Color("#9b4000"), "RETAIN": Color("#006955"),
 "RETAINED": Color("#506300"), "GLAMOUR": Color("#a31679"),
 "EXPLORE": Color("#466600"),
}

static func resolve(word: String, following: Array = []) -> String:
 var keyword := Text.keyword(word)
 if word.to_upper().rstrip(".,:;") in ["РАЗМЕСТИТЕ", "РАЗМЕСТИТЬ"]:
  for next: String in following.slice(0, 4):
   if next.begins_with("ШПИОН"):
    return "PLACE"
   if next.ends_with(".") or COLORS.has(Text.keyword(next)):
    break
 return keyword

static func draw_word(img: Image, x: int, y: int, word: String, keyword: String) -> void:
 var bare := word.rstrip(".,:;")
 var color: Color = COLORS[keyword]
 # Keep the existing keyword advance so changing style never moves the text field.
 for i in bare.length():
  PixelFont.draw_text(img, x + i * 7, y, bare[i], color)
 PixelFont.draw_text(img, x + bare.length() * 7, y, word.substr(bare.length()), Color("#2a1a30"))
