extends RefCounted

## Semantic colours shared by full cards, live values, options and export.
const Text := preload("res://scenes/card_text.gd")
const COLORS := {
 "DEVOUR": Color("#6a2d58"), "SUPPLANT": Color("#7a420b"),
 "DEPLOY": Color("#245529"), "ASSASSINATE": Color("#9b2636"),
 "PLACE": Color("#283a85"), "RETURN": Color("#17616a"),
 "PROMOTE": Color("#643d86"), "BRIBE": Color("#70580b"),
 "STEAL": Color("#87345f"), "RECRUIT": Color("#3c5b21"),
 "RECRUITS": Color("#44591b"), "MOVE": Color("#1c536f"),
 "FOCUS": Color("#3f438f"), "SCRY": Color("#22627f"),
 "MIGHT": Color("#7b3e2b"), "FROSTBITE": Color("#246380"),
 "TRANSFORM": Color("#654d20"), "DISTINCT": Color("#6d3a6b"),
 "DEVOTION": Color("#8a4721"), "RETAIN": Color("#385e57"),
 "RETAINED": Color("#4b5a39"), "GLAMOUR": Color("#843b65"),
 "EXPLORE": Color("#425d15"),
}

static func resolve(word: String, following: Array = []) -> String:
 var keyword := Text.keyword(word)
 if word.to_upper().rstrip(".,:;") == "РАЗМЕСТИТЕ":
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
