extends SceneTree
const L10n := preload("res://scenes/localization.gd")
const Bar := preload("res://scenes/ui/replay_bar.gd")
const StatsPanel := preload("res://scenes/ui/replay_stats_panel.gd")
const Settings := preload("res://scenes/game_settings.gd")
var passed:=0
var failed:=0
func _initialize() -> void:
 Settings.path_override="res://.godot/localization_replay_settings.cfg"
 Settings._cfg=null
 _run.call_deferred()
func check(ok: bool, why: String) -> void:
 if ok: passed+=1
 else:
  failed+=1
  printerr("FAIL: ",why)
func controls(n: Node) -> Array:
 var result:=[]
 for c in n.get_children():
  if c is Control: result.append(c.get_instance_id())
  result.append_array(controls(c))
 return result
func _run() -> void:
 if DisplayServer.get_name() != "headless":
  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
  DisplayServer.window_set_size(Vector2i(960,540))
 L10n.set_locale("en")
 var ids:=GameScreen.player_ids_for(4)
 var live:=GameServer.new(GameSetup.new_game(ids,4711,[],false,true,true,GameSetup.MODE_RANDOM_4))
 var log:=_autoplay(live,300)
 var header:=ReplayBook.header_for(live.state,ids,4711,GameSetup.MODE_RANDOM_4,live.with_mulligan,{},"blue","TEST",log)
 var replay:Dictionary=JSON.parse_string(JSON.stringify({"header":header,"intents":log}))
 var host:=Control.new()
 host.theme=PixelTheme.theme()
 host.size=Vector2(960,540)
 root.add_child(host)
 var bar:=Bar.new(replay)
 host.add_child(bar)
 bar.set_process(false)
 bar.seek(20)
 bar.playing=true
 bar.speed=4.0
 bar.watched="green"
 bar.follow=false
 bar._sync()
 var server:=bar.server
 var nodes:=controls(bar)
 L10n.set_locale("ru")
 check(bar.cursor==20 and bar.playing and bar.speed==4.0 and bar.watched=="green" and not bar.follow and bar.server==server and controls(bar)==nodes,"replay state and controls preserved")
 check(bar._play.text=="ПАУЗА" and bar._turn_label.text.begins_with("ХОД"),"replay captions")
 bar.hide()
 var data:=ReplayStats.collect(replay)
 var serialized:=JSON.stringify(data)
 var panel:=StatsPanel.new(data)
 host.add_child(panel)
 for tab in StatsPanel.TABS:
  panel.show_tab(tab)
  nodes=controls(panel)
  var page:Control=panel._pages[tab]
  L10n.set_locale("en")
  L10n.set_locale("ru")
  check(panel.current_tab()==tab and panel._pages[tab]==page and controls(panel)==nodes,"stats state preserved: "+tab)
  if DisplayServer.get_name() != "headless":
   for i in 8: await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://.godot/localization_stats_"+tab.to_lower()+"_ru.png")
 check(JSON.stringify(data)==serialized,"statistics source immutable")
 check(StatsPanel.turn_title(data,1).begins_with("ХОД 1, РАУНД 1,"),"hover turn label")
 check(panel._tab_buttons.BUYS.text=="ПОКУПКИ","stats tab caption")
 host.free()
 DirAccess.remove_absolute(Settings.path_override)
 print("replay localization: passed ",passed,", failed ",failed)
 quit(1 if failed else 0)
func _autoplay(server: GameServer, max_intents: int = 20000) -> Array:
 var log: Array = []
 var state := server.state
 var tries := 0
 while not state.game_over and log.size() < max_intents and tries < 200000:
  tries += 1
  var intents: Array[Intent] = []
  if server.resolver.is_waiting():
   var pending := server.resolver.pending
   intents.append(Intent.make_decision(pending.player_id, (pending.legal_options as Array)[0]))
  else:
   var pid := state.current_player()
   var me: PlayerState = state.players[pid]
   for card in me.deck.hand:
    intents.append(Intent.play_card(pid, String(card)))
   for i in state.market.display.size():
    intents.append(Intent.recruit(pid, i))
   var slots := state.presence.deployable_slots(pid, state.troops, state.spies)
   if not slots.is_empty():
    intents.append(Intent.deploy(pid, slots[0]))
   intents.append(Intent.end_turn(pid))
  for intent in intents:
   if int(server.apply_intent(intent)["error"]) == GameServer.Error.OK:
    log.append(intent.to_dict())
    break
 return log
