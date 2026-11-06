extends SceneTree
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failed+=1
		printerr("FAIL: ",message)
func _initialize() -> void:
	var ids: Array[String]=["red","blue","green","purple"]
	var seed_value:=1793974715
	var expected:=GameSetup.new_game(ids,seed_value,[],false,true,true,"random4")
	var copies: Dictionary=GameSetup._load_half_decks().half_decks.ionia.copies
	copies.erase("49805")
	copies[""]=3
	check(GameSetup._has_invalid_card_ids(GameSetup._load_half_decks()),"detect malformed cached ID")
	var rng:=RandomNumberGenerator.new()
	rng.seed=7
	var cards:=GameSetup.build_market_cards("random4",["dragons","ionia","siege","aberrations"] as Array[String],rng)
	check(not cards.has(""),"random market never includes blank IDs")
	check(cards.size()==80,"invalid IDs cannot add a fifth aspect bucket")
	check(not GameSetup.expand_half_deck("ionia").has(""),"standard/double expansion rejects blanks")
	copies["invalid_card"]=3
	check(not GameSetup.expand_half_deck("ionia").has("invalid_card"),"reject unknown IDs too")
	var repaired:=GameSetup.new_game(ids,seed_value,[],false,true,true,"random4")
	check(StateCopy.fingerprint(expected)==StateCopy.fingerprint(repaired),"reload restores the exact original deal, RNG and real cards")
	check(GameSetup.half_deck_copies("ionia").get("49805")==3,"restore the missing Dryad copies")
	var market:=Market.new()
	market.deck=["48342","","48344",""] as Array[String]
	check(market._draw_top()=="48344","skip blank top card")
	check(market._draw_top()=="48342","skip a second blank")
	market.deck=["",""] as Array[String]
	check(market._draw_top()=="" and market.deck.is_empty(),"all-blank deck exhausts cleanly")
	market.display=["48340","48343","48340","48343","48340","48343"] as Array[String]
	market.deck=["48342",""] as Array[String]
	market.repair_empty_slots()
	check(market.deck_size()==1 and not market.deck.has(""),"remove undrawn placeholders even with six occupied slots")
	var state:=GameSetup.new_game(["red","blue"] as Array[String],1,[],false,false,false)
	var server:=GameServer.new(state)
	server.build_views=false
	state.market.display[4]=""
	state.market.display[5]=""
	state.market.deck=["48340","","48343",""] as Array[String]
	state.players.red.deck.hand.append("48342")
	var result:=server.apply_intent(Intent.play_card("red","48342"))
	check(result.error==0 and not state.market.display.has(""),"accepted action repairs old vacancies")
	check(state.market.display[4]=="48343" and state.market.display[5]=="48340","repair draws real cards in order")
	check(state.game_end_triggered and state.game_end_reason=="market_empty","repair honors market exhaustion")
	# An unfinished replacement decision owns its vacancy until answered.
	state.market.display[4]=""
	state.market.deck=["48340"] as Array[String]
	var r:=EffectResolver.new()
	r.apply(SequenceEffect.new([ChooseEffect.new([GainPower.new(1),GainPower.new(2)],["one","two"]), ChooseEffect.new([GainPower.new(1),GainPower.new(2)],["one","two"])]),"red",state)
	server.resolver=r
	state.players.red.deck.hand.append("48342")
	server.apply_intent(Intent.play_card("red","48342"))
	check(state.market.display[4]=="","rejected actions do not repair a pending replacement")
	server.apply_intent(Intent.make_decision("red",0))
	check(server.resolver.is_waiting() and state.market.display[4]=="","accepted intermediate answers preserve pending vacancies")
	server.apply_intent(Intent.make_decision("red",0))
	check(not server.resolver.is_waiting() and state.market.display[4]=="48340","repair resumes once all decisions finish")
	print("market regression: failed ",failed)
	quit(1 if failed else 0)
