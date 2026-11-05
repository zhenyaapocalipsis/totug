extends SceneTree
const L10n := preload("res://scenes/localization.gd")
const Phrases := preload("res://scenes/phrase_text.gd")
const Cards := preload("res://scenes/card_text.gd")
var passed := 0
var failed := 0
func _initialize() -> void:
	PlayerProfile.path_override="res://.godot/localization_god_phrases_profile.cfg"
	_run.call_deferred()
func check(ok: bool, why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		printerr("FAIL: ",why)
func ids(node: Node) -> Array:
	var result:=[]
	for child in node.get_children():
		if child is Control: result.append(child.get_instance_id())
		result.append_array(ids(child))
	return result
func _run() -> void:
	L10n.set_locale("en")
	PlayerProfile.seats={"red":{"name":"CARDS"}}
	var host:=Control.new()
	host.theme=PixelTheme.theme()
	root.add_child(host)
	var panel:=GodPanel.new(["red","blue"])
	host.add_child(panel)
	panel.position=Vector2.ZERO
	panel.size=Vector2(160,540)
	panel.set_count(7)
	panel.set_tool(GodPanel.TOOL_SPY)
	panel.set_colour("blue")
	panel.zone="inner"
	panel.set_search("Dragon")
	panel.set_fx(true)
	panel.show_turn("red")
	for i in 5: await process_frame
	var visible:=panel.visible_cards()
	var nodes:=ids(panel)
	var scroll:=panel._list.get_parent() as ScrollContainer
	scroll.scroll_vertical=40
	var scroll_y:=scroll.scroll_vertical
	panel._search.grab_focus()
	panel._search.caret_column=3
	var card_button: Button
	for button: Button in panel._cards:
		if String(button.get_meta("card_id"))=="48426": card_button=button
	panel._show_preview("48426",card_button)
	var preview:=panel._preview.get_instance_id()
	var actions:=[]
	panel.action_requested.connect(func(a):actions.append(a))
	L10n.set_locale("ru")
	for i in 5: await process_frame
	check(panel.count==7 and panel.tool==GodPanel.TOOL_SPY and panel.colour=="blue" and panel.zone=="inner" and panel.fx,"tool, owner, count, zone and FX mode preserved")
	check(ids(panel)==nodes and panel.visible_cards()==visible,"same card controls, grouping and filter results")
	check(panel._search.text=="Dragon" and panel._search.caret_column==3 and panel._search.has_focus() and scroll.scroll_vertical==scroll_y,"search input, caret, focus and scroll preserved")
	check((panel._tool_buttons[GodPanel.TOOL_ERASE] as Button).get_global_rect().end.x <= panel.get_global_rect().end.x,"Russian tool buttons fit the existing panel width")
	check(panel._search.placeholder_text=="поиск карты..." and panel._pause_button.text=="ПАУЗА","panel captions translated")
	check(panel._turn_buttons.red.tooltip_text.contains("CARDS") and panel._turn_buttons.red.tooltip_text.contains("Передать ход"),"nickname stays literal in turn tooltip")
	check(panel._hint.text.begins_with("Нажмите на локацию"),"selected tool hint translated in place")
	check(panel._preview.get_instance_id()==preview and panel._preview.visible and panel._preview.texture==CardView.pixel_texture("48426"),"open card preview refreshed without replacing preview control")
	check(card_button.text.begins_with(Cards.field("48426","name")) and card_button.tooltip_text==GodPanel.card_name("48426"),"Russian card name and original English tooltip")
	panel._turn_buttons.red.pressed.emit()
	check(actions==[{"op":"set_turn","player_id":"red"}],"turn button sends original player ID")
	panel.give("48340")
	check(actions.back()=={"op":"give","card_id":"48340","count":7,"zone":"inner"},"give response retains IDs, count and zone")
	panel.set_fx(false)
	panel.set_search("Солдат")
	check(panel.visible_cards().has("48344"),"search by Russian card name")
	panel.set_search("Soldier")
	check(panel.visible_cards().has("48344"),"search by original card name")
	panel.set_search("БАЗОВЫЕ")
	check(panel.visible_cards().has("48340"),"search by Russian group name")
	PlayerProfile.save_phrases(["","Well played!","Моя фраза",""])
	var source:=FileAccess.get_file_as_string(PlayerProfile.path())
	var messages:=Phrases.messages()
	L10n.set_locale("en")
	var wheel:=ChatWheel.new()
	host.add_child(wheel)
	wheel.size=Vector2(960,540)
	wheel.open(Vector2(430,250),Phrases.texts(messages),Color.WHITE,messages)
	wheel.set_process(false)
	wheel.point_at(wheel.centre()+Vector2(0,-80))
	nodes=ids(wheel)
	var centre:=wheel.centre()
	var rects:=wheel._boxes.map(func(b):return b.get_rect())
	L10n.set_locale("ru")
	for i in 4: await process_frame
	check(wheel._labels[0].text=="Отличная игра!" and wheel._labels[3].text=="Удачи и хорошей игры!","blank slots use Russian default phrases")
	check(wheel._labels[1].text=="Well played!" and wheel._labels[2].text=="Моя фраза","explicit English and Russian user phrases remain literal")
	check(ids(wheel)==nodes and wheel.centre()==centre and wheel.selected()==0 and wheel._boxes.map(func(b):return b.get_rect())==rects,"open wheel retains controls, position, dimensions and selected side")
	check(wheel.close()=="Отличная игра!","default selection returns displayed Russian phrase")
	check(FileAccess.get_file_as_string(PlayerProfile.path())==source,"language switching does not rewrite saved phrases")
	var custom: Array[String]=["Well played!","Thinking...","Oops!","Good luck, have fun!"]
	wheel.open(Vector2(430,250),custom,Color.WHITE)
	L10n.set_locale("en")
	L10n.set_locale("ru")
	check(wheel._labels[0].text=="Well played!","plain wheel API treats strings literally even after previous default bindings")
	if DisplayServer.get_name()!="headless":
		panel.set_search("")
		wheel.open(Vector2(500,250),Phrases.texts(messages),Color.WHITE,messages)
		wheel.set_process(false)
		wheel.point_at(wheel.centre()+Vector2(0,-80))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/localization_god_phrases_ru.png")
	PlayerProfile.seats={}
	print("localized god/phrases: ",passed," checks, failed ",failed)
	quit(1 if failed else 0)
