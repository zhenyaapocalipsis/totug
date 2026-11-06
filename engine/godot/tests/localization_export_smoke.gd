extends SceneTree
const L10n := preload("res://scenes/localization.gd")
const Cards := preload("res://scenes/card_text.gd")
const Pages := preload("res://scenes/page_text.gd")
const Settings := preload("res://scenes/game_settings.gd")
var failed:=0
func _initialize()->void:
 _run.call_deferred()
func check(ok:bool,why:String)->void:
 if not ok:
  failed+=1
  printerr("FAIL: ",why)
func _run()->void:
 Settings.path_override="user://localization_export_smoke.cfg"
 Settings._cfg=null
 check(Cards.translations().size()==391,"all translated cards packaged")
 check(FileAccess.file_exists("res://data/localization/options_ru.json"),"action options packaged")
 check(FileAccess.file_exists("res://data/localization/tutorial_ru.json"),"tutorial packaged")
 L10n.set_locale("ru")
 check(Cards.field("48426","name")=="Красный дракон","Russian card name")
 check(Pages.text("OPEN BOX")=="ОТКРЫТЬ","secondary UI catalog")
 var face:=CardView.pixel_texture("48426")
 check(face!=null and face.get_width()==176,"runtime card face")
 var tutorial=preload("res://scenes/ui/how_to_play_screen.gd").new(11)
 root.add_child(tutorial)
 check(tutorial._title.text=="12. КАК ЧИТАТЬ КАРТЫ","packaged tutorial translation")
 L10n.set_locale("en")
 check(Cards.field("48426","name")=="Red Dragon","English retained")
 tutorial.free()
 DirAccess.remove_absolute(Settings.path_override)
 print("export localization: 8 checks, failed ",failed)
 quit(1 if failed else 0)
