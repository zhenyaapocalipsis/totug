extends SceneTree
const L10n := preload("res://scenes/localization.gd")
const Events := preload("res://scenes/event_text.gd")
const Decisions := preload("res://scenes/decision_text.gd")
var passed := 0
var failed := 0
func _initialize() -> void:
	PlayerProfile.path_override = "res://.godot/localization_events_profile.cfg"
	_run.call_deferred()
func check(ok: bool, why: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		printerr("FAIL: ",why)
func _run() -> void:
	var board := {"sites":{"a":{"name":"Caer Sidi"}},"slots":{"x":{"site_id":"a"},"y":{"site_id":""}}}
	var fixture := {"player_id":"red","amount":2,"card_id":"48320","new_card_id":"48306","slot_id":"x","site_id":"a","from":"blue","to":"blue","victim":"blue","owner":"blue","spy_owner":"blue","hall":"blue","color":"white","resource":"power","cards":["48320"],"target":"blue","rival":"blue","ability":"power","what":"a card","markers":1,"marker_sites":["Lolth Shrine"],"cluster_bonus":4,"granted":5,"total_vp":12,"a2_power":2,"a2_influence":2,"marker_influence":1}
	var source := FileAccess.get_file_as_string("res://scenes/ui/event_log_panel.gd")
	var types := []
	var pattern := RegEx.create_from_string('(?m)^\t\t("[a-z0-9_]+"(?:, "[a-z0-9_]+")*):')
	for result: RegExMatch in pattern.search_all(source):
		for kind in result.get_string(1).replace('"','').split(", "):
			if not types.has(kind): types.append(kind)
	for key: String in L10n.catalog("en"):
		if key.begins_with("event.type_"):
			types.append(key.trim_prefix("event.type_"))
	var source_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/localization/decisions_ru.json"))
	var source_values: Array = source_data.exact.values()
	for entry: Dictionary in source_data.patterns: source_values.append(entry.target)
	var glyphs := {}
	for value: String in source_values:
		for ch in RegEx.create_from_string("[{]v[0-9]+[}]").sub(value,"2",true):
			if ch != "\n" and not glyphs.has(ch):
				glyphs[ch] = true
				check(PixelTheme.theme().default_font.has_char(ch.unicode_at(0)), "decision/note glyph: " + ch)
	var original := JSON.stringify(fixture)
	for kind: String in types:
		var event := fixture.duplicate(true)
		event.type = kind
		if kind == "extra_turn": event.cards = 3
		L10n.set_locale("en")
		var en := Events.describe(event,board)
		check(en == EventLogPanel.describe(event,board), "exact legacy English: " + kind)
		L10n.set_locale("ru")
		var ru := Events.describe(event,board)
		check(ru.begins_with("Красный") and not ru.contains("event.") and ru != en, "Russian semantic event: " + kind)
	check(JSON.stringify(fixture) == original,"event data unchanged")
	var expected_counts := {1:"1 карта",2:"2 карты",5:"5 карт",11:"11 карт",21:"21 карта",22:"22 карты",25:"25 карт",101:"101 карта",111:"111 карт"}
	for amount in expected_counts:
		fixture.type = "draw_cards"
		fixture.amount = amount
		check(Events.describe(fixture,board).ends_with(expected_counts[amount]), "card count: " + str(amount))
	check(Events.describe({"type":"future_type","player_id":"red"},board) == "Красный: future_type","unknown event type retained")
	var format := RegEx.create_from_string("%[sd]")
	for key: String in L10n.catalog("en"):
		if not key.begins_with("event."): continue
		var a := format.search_all(String(L10n.catalog("en")[key])).map(func(m):return m.get_string())
		var b := format.search_all(String(L10n.catalog("ru")[key])).map(func(m):return m.get_string())
		check(a==b,"same printf arguments: "+key)
	L10n.set_locale("en")
	var host := Control.new()
	host.theme = PixelTheme.theme()
	root.add_child(host)
	var log := EventLogPanel.new()
	log.size = Vector2(220,160)
	log.board = board
	host.add_child(log)
	var history := []
	for i in 330:
		history.append({"type":"gain_vp","player_id":"red","amount":i})
	log.add_events(history)
	log.set_process(false)
	for i in 4: await process_frame
	log._text.scroll_following = false
	log._text.get_v_scroll_bar().value = 50
	var scroll := log._text.get_v_scroll_bar().value
	var lines := JSON.stringify(log._lines)
	var queue := JSON.stringify(log._queue)
	var timer := log._next_in
	var fresh := [log._fresh_index,log._fresh_left]
	var label_id := log._text.get_instance_id()
	L10n.set_locale("ru")
	for i in 4: await process_frame
	check(JSON.stringify(log._lines)==lines and JSON.stringify(log._queue)==queue,"history and pending queue preserved")
	check(log._next_in==timer and [log._fresh_index,log._fresh_left]==fresh,"stagger and fresh highlight timing preserved")
	check(log._text.get_instance_id()==label_id and log._text.text.contains("получает") and log._text.get_v_scroll_bar().value==scroll,"same text node and scroll position")
	check(log._lines.size()==EventLogPanel.MAX_LINES,"history cap preserved")
	PlayerProfile.seats={"red":{"name":"[color=red]Yes"}}
	log.add_events([{"type":"gain_power","player_id":"red","amount":2}])
	log._process(1.0)
	log.set_process(false)
	check(log._text.text.contains("[lb]color=red]Yes"),"nickname escaped as literal BBCode")
	PlayerProfile.seats={}
	var toast := NoteToast.new()
	host.add_child(toast)
	var area := Control.new()
	area.size=Vector2(600,400)
	host.add_child(area)
	toast.area=area
	L10n.set_locale("en")
	toast.show_source("Not allowed: it is not your turn")
	for i in 3: await process_frame
	toast._tween.pause()
	var tween := toast._tween
	var elapsed := tween.get_total_elapsed_time()
	var alpha := toast.modulate.a
	L10n.set_locale("ru")
	for i in 3: await process_frame
	check(toast.last_text()=="Действие недоступно: сейчас не ваш ход","nested refusal translated: " + toast.last_text())
	check(toast._tween==tween and tween.get_total_elapsed_time()==elapsed and toast.modulate.a==alpha,"visible toast keeps animation and alpha")
	check(Decisions.text("Caer Sidi, space 2: your barracks are empty — use the \"Deploy for 1 VP\" button").begins_with("Каэр Сиди, место 2:"),"full refusal template recognized before em-dash splitting")
	print("localized events: ",passed," checks, failed ",failed)
	quit(1 if failed else 0)
