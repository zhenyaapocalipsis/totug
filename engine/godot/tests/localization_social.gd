extends SceneTree
const L10n := preload("res://scenes/localization.gd")
const Pages := preload("res://scenes/page_text.gd")
const Friends := preload("res://scenes/ui/friends_page.gd")
const Leaders := preload("res://scenes/ui/leaderboard_page.gd")
const Settings := preload("res://scenes/game_settings.gd")
var passed := 0
var failed := 0
func _initialize() -> void:
 Settings.path_override = "res://.godot/localization_social_settings.cfg"
 Settings._cfg = null
 _run.call_deferred()
func check(ok: bool, why: String) -> void:
 if ok: passed += 1
 else:
  failed += 1
  printerr("FAIL: ", why)
func controls(n: Node) -> Array:
 var ids := []
 for c in n.get_children():
  if c is Control: ids.append(c.get_instance_id())
  ids.append_array(controls(c))
 return ids
func _run() -> void:
 if DisplayServer.get_name() != "headless":
  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
  DisplayServer.window_set_size(Vector2i(960,540))
 L10n.set_locale("en")
 var host := Control.new()
 host.theme = PixelTheme.theme()
 root.add_child(host)
 var friends := Friends.new()
 host.add_child(friends)
 friends.set_process(false)
 friends._selected = "ONLINE"
 friends.show_data({"friends":[{"name":"ONLINE","status":"IN GAME","records":2,"room":"ABC","rated":false}],"incoming":["REQUESTS"],"outgoing":["SENT"],"note":"Friend request sent to REQUESTS."})
 await friends._show_thread("ONLINE",[{"mine":true,"text":"ONLINE\nREQUESTS"},{"mine":false,"text":"FRIENDS"}])
 friends._nick.text="ADD"
 friends._message.text="SEND"
 friends._nick.caret_column=2
 var nodes:=controls(friends)
 L10n.set_locale("ru")
 await process_frame
 check(controls(friends)==nodes,"friend controls retained")
 check(friends._selected=="ONLINE" and friends._nick.text=="ADD" and friends._message.text=="SEND" and friends._nick.caret_column==2,"selection, drafts and caret retained")
 check(friends._thread.get_child(0).text=="ВЫ: ONLINE\nREQUESTS" and friends._thread.get_child(1).text=="ONLINE: FRIENDS","chat bodies and nickname remain literal")
 check(friends._note.text=="Заявка в друзья отправлена: REQUESTS.","system note protects nickname")
 check(friends._status.text=="В ПАРТИИ   МИРОВЫЕ РЕКОРДЫ: 2","presence translated")
 if DisplayServer.get_name() != "headless":
  for i in 8: await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://.godot/localization_friends_ru.png")
 friends.hide()
 var leaders:=Leaders.new()
 host.add_child(leaders)
 leaders.set_process(false)
 leaders.show_data({"registered":10,"online":5,"in_game":2,"top":[{"name":"NAME","rating":0,"games":3,"wins":1}],"mine":{"rank":3,"rating":0}})
 nodes=controls(leaders)
 var mode:=leaders._mode
 L10n.set_locale("en")
 check(controls(leaders)==nodes and leaders._mode==mode,"rating controls and mode retained")
 check(leaders._grid.get_child(1).text=="NAME","nickname matches caption but stays literal")
 L10n.set_locale("ru")
 check(leaders._counts.text=="ТИРАНОВ: 10   В СЕТИ: 5   В ПАРТИИ: 2","population caption")
 check(leaders._mine.text=="ВЫ: #3   0\nНажмите на имя игрока, чтобы открыть профиль.","multi-line rank caption: "+leaders._mine.text)
 for source in ["ONLINE","REQUESTS","NAME"]:
  check(Pages.text("Invitation sent to %s." % source)=="Приглашение отправлено: %s." % source,"invitation protects "+source)
 if DisplayServer.get_name() != "headless":
  for i in 8: await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://.godot/localization_leaderboard_ru.png")
 host.free()
 DirAccess.remove_absolute(Settings.path_override)
 print("social localization: passed ",passed,", failed ",failed)
 quit(1 if failed else 0)
