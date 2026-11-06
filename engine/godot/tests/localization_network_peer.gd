extends SceneTree
const L10n := preload("res://scenes/localization.gd")
const Cards := preload("res://scenes/card_text.gd")
const Settings := preload("res://scenes/game_settings.gd")
var net:NetSession
var role:="client"
var elapsed:=0.0
var view:Dictionary={}
var updates:=0
var sent_version:=-1
var began:=false
var done:=false
var errors:=0
func _initialize()->void:
 role="host" if OS.get_cmdline_user_args().has("--host") else "client"
 Settings.path_override="res://.godot/localization_network_"+role+".cfg"
 Settings._cfg=null
 PlayerProfile.path_override="res://.godot/localization_network_profile_"+role+".cfg"
 L10n.set_locale("en" if role=="host" else "ru")
 _run.call_deferred()
func _run()->void:
 L10n.set_locale("en" if role=="host" else "ru")
 net=NetSession.new()
 net.name="Net"
 net.profile={"name":"L10n "+role,"emblem":""}
 net.rating_key="localization-test-"+role
 net.saves_dir="res://.godot/localization_net_saves/"
 net.replays_dir="res://.godot/localization_net_replays/"
 root.add_child(net)
 net.game_started.connect(func(_seat:String,_board:Dictionary,v:Dictionary):view=v)
 net.result_received.connect(func(error:int,_events:Array,v:Dictionary):
  if error!=GameServer.Error.OK:errors+=1
  updates+=1
  view=v)
 var err:=net.host(7798,2,GameSetup.MODE_STANDARD) if role=="host" else net.join("127.0.0.1",7798)
 if err!=OK:
  printerr("FAIL: network startup ",err)
  quit(1)
func _process(delta:float)->bool:
 elapsed+=delta
 if elapsed>45.0:
  printerr("FAIL: network timeout ",role," updates ",updates)
  quit(1)
 if net==null or done:return false
 if role=="host" and not began and net.is_full():
  began=true
  net.start_game(4242)
 if view.is_empty():return false
 if updates>=24:
  done=true
  var public:={}
  for key in ["current_player","turn_order","troops","spies","site_control","site_total_control","market","supplies","game_over"]:public[key]=view[key]
  public["resources"]={}
  for pid:String in view.players:
   public.resources[pid]={}
   for key in ["power","influence","vp_tokens","hand_size","deck_size","discard_size"]:
    public.resources[pid][key]=view.players[pid].get(key)
  if L10n.locale()!=("en" if role=="host" else "ru"):errors+=1
  var result:={"locale":L10n.locale(),"updates":updates,"errors":errors,"public":public,"card":Cards.field("48426","name")}
  var f:=FileAccess.open("res://.godot/localization_network_"+role+".json",FileAccess.WRITE)
  f.store_string(JSON.stringify(result))
  f.close()
  print("mixed locale network ",role,": ",updates," updates, errors ",errors,", locale ",L10n.locale())
  create_timer(1.0).timeout.connect(func():
   net.close()
   DirAccess.remove_absolute(Settings.path_override)
   DirAccess.remove_absolute(PlayerProfile.path())
   quit(1 if errors else 0))
  return false
 if sent_version==updates:return false
 var pd:Dictionary=view.get("pending_decision",{})
 if not pd.is_empty():
  if String(pd.player_id)==net.seat and not (pd.legal_options as Array).is_empty():
   sent_version=updates
   net.send_intent(Intent.make_decision(net.seat,pd.legal_options[0]))
 elif String(view.current_player)==net.seat:
  sent_version=updates
  net.send_intent(Intent.end_turn(net.seat))
 return false
