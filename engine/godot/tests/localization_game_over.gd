extends SceneTree
const L10n := preload("res://scenes/localization.gd")
var passed := 0
var failed := 0
func _initialize() -> void:
	PlayerProfile.path_override = "res://.godot/localization_game_over_profile.cfg"
	_run.call_deferred()
func check(ok: bool, why: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		printerr("FAIL: ",why)
func ids(node: Node) -> Array:
	var result := []
	for child in node.get_children():
		if child is Control: result.append(child.get_instance_id())
		result.append_array(ids(child))
	return result
func cards(node: Node) -> Array:
	var result := []
	for child in node.get_children():
		if child is CardView: result.append([child.get_instance_id(),child.card_id,child.position,child.size])
		result.append_array(cards(child))
	return result
func captions(node: Node) -> Array:
	var result := []
	for child in node.get_children():
		if child is Label: result.append(child.text)
		result.append_array(captions(child))
	return result
func _run() -> void:
	var host := Control.new()
	host.theme = PixelTheme.theme()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	for count in [2,3,4,22]:
		L10n.set_locale("en")
		var order := ["red","blue","green","purple"].slice(0,4 if count==22 else count)
		var teams := {"red":"red","green":"red","blue":"blue","purple":"blue"} if count==22 else {}
		BoardPanel.team_of = teams
		PlayerProfile.seats={"red":{"name":"ABCDEFGHIJKL"},"blue":{"name":"MAIN MENU"},"green":{"name":"Green Name"},"purple":{"name":"Purple Name"}}
		var view := {"game_over":true,"turn_order":order,"teams":teams,"winners":["red","green"] if count==22 else ["red"],"final_scores":{},"final_decks":{}}
		var ratings := {}
		for pid in order:
			view.final_scores[pid]={"sites":12,"total_control":7,"trophies":2,"deck":15,"inner_circle":8,"tokens":26,"total":70}
			view.final_decks[pid]={"deck":["48320","48306","48340","48342","48344","48426"],"inner":["48320","48306"]}
			ratings[pid]={"rating":1234,"delta":16,"reward":{"boxes":1,"dust":25},"records":["vp","rounds","margin"] if pid=="red" else []}
		var panel := GameOverPanel.new()
		host.add_child(panel)
		panel.update_from_view(view)
		panel.set_ratings(ratings)
		var graph_calls := []
		panel.set_stats({},func():graph_calls.append(true))
		for i in 8: await process_frame
		var original := JSON.stringify(view)
		var rating_source := JSON.stringify(ratings)
		var nodes := ids(panel)
		var final_cards := cards(panel)
		var centre := panel._centre_w
		var table := panel._grid.get_global_rect()
		L10n.set_locale("ru")
		for i in 5: await process_frame
		check(ids(panel)==nodes and cards(panel)==final_cards,"same table and final card controls: "+str(count))
		check(JSON.stringify(view)==original and JSON.stringify(ratings)==rating_source,"scores, rewards and deck data unchanged: "+str(count))
		check(panel._centre_w==centre and panel._grid.get_global_rect()==table,"reserved columns preserve final layout: "+str(count))
		check(panel._head.text=="КОНЕЦ ИГРЫ" and panel._title.text.begins_with("ПОБЕДА:"),"translated result heading: "+str(count))
		check(panel._title.text.contains("КРАСНАЯ КОМАНДА") if count==22 else panel._title.text.contains("ABCDEFGHIJKL"),"team or literal winner: "+str(count))
		check(captions(panel).has("РЕКОРД: БЫСТРАЯ ПОБЕДА, КРУГИ") and captions(panel).has("ПЫЛЬ: +25"),"record and reward translated: "+str(count))
		check(captions(panel).any(func(t): return String(t).begins_with("MAIN MENU")),"nickname is literal: "+str(count))
		check(panel._buttons.get_child(0).text=="ДОСКА" and panel._buttons.get_child(1).text=="ГРАФИКИ","result action buttons: "+str(count))
		panel._stats_button.pressed.emit()
		check(graph_calls==[true],"graph callback preserved: "+str(count))
		if (count==4 or count==22) and DisplayServer.get_name()!="headless":
			for i in 8: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/localization_game_over_%s_ru.png" % count)
		panel._buttons.get_child(0).pressed.emit()
		L10n.set_locale("en")
		check(not panel.visible and panel._head.text=="GAME OVER","view board stays hidden after language change: "+str(count))
		view.abandoned_by="blue"
		panel.update_from_view(view)
		L10n.set_locale("ru")
		check(panel._head.text.contains("MAIN MENU НЕ ВЕРНУЛСЯ") and not panel.visible,"abandonment translated without reopening results: "+str(count))
		panel.queue_free()
		await process_frame
	var active := L10n.locale()
	check(L10n.text_for("en","gameover.record",{"label":{"l10n_key":"record.kills"}})=="RECORD: ASSASSINATIONS", "explicit language resolves nested descriptors")
	check(L10n.locale()==active,"measuring other language does not switch active locale")
	PlayerProfile.seats={}
	BoardPanel.team_of={}
	print("localized game over: ",passed," checks, failed ",failed)
	quit(1 if failed else 0)
