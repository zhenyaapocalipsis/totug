extends SceneTree
const L10n := preload("res://scenes/localization.gd")
const Pages := preload("res://scenes/page_text.gd")
const Analysis := preload("res://scenes/ui/games_analysis_panel.gd")
const Settings := preload("res://scenes/game_settings.gd")
var passed:=0
var failed:=0
func _initialize() -> void:
 Settings.path_override="res://.godot/localization_secondary_settings.cfg"
 Settings._cfg=null
 PlayerProfile.path_override="res://.godot/localization_secondary_profile.cfg"
 _run.call_deferred()
func check(ok:bool,why:String)->void:
 if ok:passed+=1
 else:
  failed+=1
  printerr("FAIL: ",why)
func controls(n:Node)->Array:
 var list:=[]
 for c in n.get_children():
  if c is Control:list.append(c.get_instance_id())
  list.append_array(controls(c))
 return list
func _run()->void:
 L10n.set_locale("en")
 var host:=Control.new()
 host.theme=PixelTheme.theme()
 host.size=Vector2(960,540)
 root.add_child(host)
 var panel:=Analysis.new("res://.godot/nonexistent_replays/")
 host.add_child(panel)
 for page:Control in panel._pages.values():page.free()
 panel._pages.clear()
 panel.data=ReplayStats.aggregate([{"won":true,"vp":60,"power":5.0,"influence":8.0,"buys":["48306","48426"],"curve":[10,20,40,60],"rival":[8,18,35,50]}])
 var serialized:=JSON.stringify(panel.data)
 for tab in Analysis.TABS:
  panel.show_tab(tab)
  var nodes:=controls(panel)
  L10n.set_locale("ru")
  check(panel.current_tab()==tab and controls(panel)==nodes,"analysis tab retained: "+tab)
  if tab=="VP BY ROUND":
   var chart=panel._pages[tab]
   chart._hover=1
   chart._update_readout()
   check(chart._readout.text.contains("ВЫ В ПОБЕДАХ") and chart._readout.text.begins_with("РАУНД 2"),"owned chart series and round localized")
  L10n.set_locale("en")
 check(JSON.stringify(panel.data)==serialized,"aggregate source unchanged")
 var show:=CardShowcase.new()
 host.add_child(show)
 var arts:=AltArts.arts_of("48426")
 show.show_card("48426","ONLINE RECRUITS",Color.RED,null,Vector2(10,10),false,"",arts[0],true)
 show.show_card("48306","REQUESTS PROMOTES",Color.BLUE,null,Vector2(20,20))
 show.set_process(false)
 show._phase="morph"
 show._t=0.43
 var face:Texture2D=show._item.face
 var queued:=show.queued()
 var banners:=controls(show)
 L10n.set_locale("ru")
 check(show._phase=="morph" and is_equal_approx(show._t,0.43) and show.queued()==queued and controls(show)==banners,"showcase phase, queue and controls retained")
 check(show._item.face!=face and show._item.face==CardView.pixel_texture("48426") and show._item.alt_face==CardView.pixel_texture("48426",arts[0]),"current original and alternate face refresh")
 check(show._queue[0].face==CardView.pixel_texture("48306"),"queued face refresh")
 check((show._banners[0].get_child(0) as Label).text=="ONLINE НАНИМАЕТ","showcase caption protects nickname")
 check(Pages.text("REQUESTS invites you to a lobby.")=="REQUESTS приглашает вас в лобби.","invitation nickname literal")
 host.free()
 DirAccess.remove_absolute(Settings.path_override)
 DirAccess.remove_absolute(PlayerProfile.path())
 print("secondary localization: passed ",passed,", failed ",failed)
 quit(1 if failed else 0)
