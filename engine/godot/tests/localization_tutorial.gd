extends SceneTree
const L10n := preload("res://scenes/localization.gd")
const Tutorial := preload("res://scenes/ui/how_to_play_screen.gd")
const Offer := preload("res://scenes/ui/tutorial_offer_screen.gd")
const Settings := preload("res://scenes/game_settings.gd")
var passed:=0
var failed:=0
func _initialize() -> void:
 Settings.path_override="res://.godot/localization_tutorial_settings.cfg"
 Settings._cfg=null
 _run.call_deferred()
func check(ok: bool, why: String) -> void:
 if ok: passed+=1
 else:
  failed+=1
  printerr("FAIL: ",why)
func _run() -> void:
 if DisplayServer.get_name()!="headless":
  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
  DisplayServer.window_set_size(Vector2i(960,540))
 var host:=Control.new()
 host.theme=PixelTheme.theme()
 host.size=Vector2(960,540)
 root.add_child(host)
 L10n.set_locale("en")
 var tutorial:=Tutorial.new()
 host.add_child(tutorial)
 tutorial.position=Vector2(240,20)
 tutorial.size.x=470
 var ru:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/localization/tutorial_ru.json"))
 check(tutorial.page_count()==14 and ru.size()==14,"all tutorial pages translated")
 for i in tutorial.page_count():
  tutorial.show_page(i)
  var next:=tutorial._next
  var prev:=tutorial._prev
  var counter:=tutorial._counter
  var en_text:=tutorial._text.text
  L10n.set_locale("ru")
  for frame in 5: await process_frame
  check(tutorial.current_page()==i and tutorial._next==next and tutorial._prev==prev and tutorial._counter==counter,"page and navigation retained: "+str(i+1))
  check(tutorial._text.text==ru[i].text and tutorial._title.text==ru[i].title,"page text: "+str(i+1))
  check(tutorial.get_global_rect().end.y<=540,"page fits height: "+str(i+1)+" "+str(tutorial.get_global_rect()))
  check(tutorial.get_global_rect().end.x<=960,"page fits width: "+str(i+1))
  if DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://.godot/localization_tutorial_%02d_ru.png" % (i+1))
  L10n.set_locale("en")
  check(tutorial._text.text==en_text,"English restored: "+str(i+1))
 var pages:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/localization/pages_ru.json"))
 var font:=PixelTheme.theme().default_font
 for value:String in pages.exact.values():
  for ch:String in value.replace("\n",""):
   check(font.has_char(ch.unicode_at(0)),"owned caption glyph: "+ch)
 tutorial.free()
 var offer:=Offer.new()
 host.add_child(offer)
 L10n.set_locale("ru")
 check(offer.get_child_count()>0,"welcome screen loads")
 host.free()
 DirAccess.remove_absolute(Settings.path_override)
 print("tutorial localization: passed ",passed,", failed ",failed)
 quit(1 if failed else 0)
