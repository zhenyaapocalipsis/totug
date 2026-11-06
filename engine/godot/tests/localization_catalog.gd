extends SceneTree
const L10n := preload("res://scenes/localization.gd")
const Text := preload("res://scenes/card_text.gd")
const PC := preload("res://tools/pixel_cards.gd")
var passed := 0
var failed := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		printerr("FAIL: ",why)
func _run() -> void:
	var selected := "translated"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--deck="): selected=arg.trim_prefix("--deck=")
	for keyword: String in CardPreview.KEYWORD_TIPS:
		check(L10n.catalog("en").has("keyword."+keyword) and L10n.catalog("ru").has("keyword."+keyword),"both languages cover keyword tooltip: "+keyword)
		if keyword!="PLACE": check(Text.KEYWORDS.values().has(keyword),"Russian surface word resolves keyword ID: "+keyword)
	var all: Dictionary = Text.translations()
	if OS.get_cmdline_user_args().has("--complete"):
		check(all.size()==CardLibrary.all_ids().size(),"complete catalog has exactly all source IDs")
		for cid: String in CardLibrary.all_ids(): check(all.has(cid),"complete catalog: "+cid)
	var unique_names:={}
	for cid: String in all:
		var normalized:=String(all[cid].get("name", "")).to_lower()
		check(not unique_names.has(normalized),"unique full Russian name: "+cid)
		unique_names[normalized]=cid
	var ids: Array = all.keys()
	if selected=="base": ids=["48340","48341","48342","48343","48344","48345"]
	elif selected!="translated":
		var decks: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cards/half_decks.json")).half_decks
		ids=(decks.get(selected,{}) as Dictionary).get("copies",{}).keys()
	check(not ids.is_empty(),"nonempty requested catalog portion")
	var make_sheet:=ids.size()<=24
	var sheet:=Image.create(3*244 if make_sheet else 1,ceili(ids.size()/3.0)*278 if make_sheet else 1,false,Image.FORMAT_RGBA8)
	sheet.fill(PixelTheme.BG)
	var originals:={}
	var mechanics:={}
	L10n.set_locale("en")
	for cid: String in ids:
		check(all.has(cid),"translated card exists: "+cid)
		if not all.has(cid): continue
		mechanics[cid]=JSON.stringify(CardLibrary.card_data(cid))
		originals[cid]=CardView.pixel_texture(cid,"",false).get_image()
	L10n.set_locale("ru")
	check(CardLiveFace.keyword_spots("48722",[],176,254).any(func(spot):return spot[1]=="PLACE"),"Russian spy instruction resolves PLACE rather than DEPLOY")
	for i in ids.size():
		var cid:=String(ids[i])
		if not all.has(cid): continue
		var row: Dictionary=CardLibrary.card_data(cid)
		var value: Dictionary=all[cid]
		for key: String in ["name","short_name","race_name","set_name","ability_text"]:
			check(value.has(key) and String(value[key]).strip_edges()!="","required field "+cid+"/"+key)
		check(value.has("aspect_name") and (row.aspect==null or String(value.aspect_name)!=""),"aspect label "+cid)
		for key: String in value:
			check(["name","short_name","race_name","set_name","aspect_name","ability_text"].has(key),"no mechanical override: "+cid+"/"+key)
		var mini_lines:=PC.wrap_name(String(value.short_name).to_upper(),PC.MINI_SIDE_X-3,PC.MINI_W-5,PC.MINI_SIDE_LINES,PC.MINI_NAME_LINES)
		check("".join(mini_lines).replace("-","").replace(" ","")==String(value.short_name).to_upper().replace("-","").replace(" ",""),"short name is fully rendered: "+cid)
		var cost: String="" if row.cost==null else str(int(row.cost))
		var full_name_lines:=PC.header_name_layout(String(value.name).to_upper(),cost)
		var header_text: Array[String]=[]
		for item: Dictionary in full_name_lines: header_text.append(item.text)
		check("".join(header_text).replace(" ","")==String(value.name).to_upper().replace(" ",""),"full name is fully rendered: "+cid)
		var expected_ids: Array[String]=[]
		for rule: Array in CardLive.RULES.get(cid,[]): expected_ids.append(CardLive.hint_id(cid,rule))
		for marker: RegExMatch in RegEx.create_from_string("[{]LIVE:([^}]+)[}]").search_all(Text.ability(cid,true)):
			check(expected_ids.has(marker.get_string(1)),"no unknown live marker: "+cid+"/"+marker.get_string(1))
		var original: Image=originals[cid]
		if original.is_compressed(): original.decompress()
		original.convert(Image.FORMAT_RGBA8)
		var w:=original.get_width()
		var h:=original.get_height()
		var plain:=CardLiveFace.layout_for_card(cid,[],w,h)
		var source:=CardLiveFace.text_layout(String(row.ability_text),[],w,h)
		check(plain.top==source.top and plain.box_h==source.box_h,"original text-box geometry: "+cid)
		check(not plain.overflow,"Russian body fits source box: "+cid)
		var stress: Array=[]
		for rule: Array in CardLive.RULES.get(cid,[]):
			var id:=CardLive.hint_id(cid,rule)
			check(Text.ability(cid,true).contains("{LIVE:%s}"%id),"stable live anchor: "+id)
			stress.append({"id":id,"text":"(999/%d)"%int(rule[3]) if rule[1]=="need" else ("(YES)" if rule[1]=="have" else ("(-999)" if rule[1]=="less" else ("(999)" if rule[1]=="count" else "(+999)"))),"ok":true})
		if not stress.is_empty():
			var live:=CardLiveFace.layout_for_card(cid,stress,w,h)
			var en:=CardLiveFace.text_layout(String(row.ability_text),Text.source_notes(cid,stress),w,h)
			check(live.top==en.top and live.box_h==en.box_h and not live.overflow,"live values fit unchanged English live geometry: "+cid+" content="+str(live.content_h)+" room="+str(live.box_h-8))
			var marks: int = live.words.filter(func(word):return String(word[2]).begins_with(CardLiveFace.MARK_OK)).size()
			check(marks==stress.size(),"each stable live ID rendered once: "+cid)
			check(not (stress[0] as Dictionary).has("phrase"),"normalizing live IDs does not mutate incoming notes: "+cid)
		var image:=CardView.pixel_texture(cid).get_image()
		if image.is_compressed(): image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		check(image.get_region(Rect2i(6,34,w-12,PC.ART_H)).get_data()==original.get_region(Rect2i(6,34,w-12,PC.ART_H)).get_data(),"art area unchanged: "+cid)
		var badge_width:=CardLiveFace._width(str(int(row.deck_vp)),1)+2
		var ic_width:=CardLiveFace._width("-" if row.inner_circle_vp==null else str(int(row.inner_circle_vp)),1)+2
		var badge_left:=w-7-ic_width-1-badge_width
		check(image.get_region(Rect2i(badge_left,h-19,w-badge_left-2,17)).get_data()==original.get_region(Rect2i(badge_left,h-19,w-badge_left-2,17)).get_data(),"printed VP badges unchanged: "+cid)
		var copies:=Text.copy_count(cid)
		var footer_right:=9+CardLiveFace._width(String(value.set_name),1)
		if copies>0: footer_right+=8+CardLiveFace._width(Text.copy_label(copies),1)+1
		check(footer_right<badge_left,"translated footer does not reach VP badges: "+cid)
		if row.aspect!=null:
			check(17+CardLiveFace._width(String(value.aspect_name),1)+4<=w-7-CardLiveFace._width(String(value.race_name),1),"aspect and race stay in separate source fields: "+cid)
		var mini:=CardView.mini_texture(cid).get_image()
		var mini_en:=(load("res://assets/cards_mini/"+cid+".png") as Texture2D).get_image()
		if mini.is_compressed(): mini.decompress()
		if mini_en.is_compressed(): mini_en.decompress()
		mini.convert(Image.FORMAT_RGBA8)
		mini_en.convert(Image.FORMAT_RGBA8)
		check(mini.get_region(Rect2i(1,PC.MINI_HEAD+1,PC.MINI_W-2,PC.MINI_H-PC.MINI_HEAD-2)).get_data()==mini_en.get_region(Rect2i(1,PC.MINI_HEAD+1,PC.MINI_W-2,PC.MINI_H-PC.MINI_HEAD-2)).get_data(),"mini art and printed VP unchanged: "+cid)
		var visible_text:=Text.field(cid,"name")+Text.field(cid,"short_name")+Text.field(cid,"race_name")+Text.field(cid,"aspect_name")+Text.field(cid,"set_name")+Text.ability(cid)
		var glyphs:={}
		for ch in CardLiveFace.clean(visible_text):
			if ch==" " or ch=="\n" or glyphs.has(ch): continue
			glyphs[ch]=true
			check(PixelFont.glyph(ch)!=PixelFont.FONT[" "],"card glyph "+cid+"/"+ch)
		if make_sheet: sheet.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i((i%3)*244,(i/3)*278))
		if make_sheet: sheet.blit_rect(mini,Rect2i(Vector2i.ZERO,mini.get_size()),Vector2i((i%3)*244+180,(i/3)*278))
		check(JSON.stringify(CardLibrary.card_data(cid))==mechanics[cid],"rules data unchanged: "+cid)
	if make_sheet: check(sheet.save_png("res://.godot/localization_catalog_%s_ru.png"%selected)==OK,"saved contact sheet")
	var option_rows: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/localization/options_ru.json"))
	for id: String in option_rows:
		var source:=String(option_rows[id].get("source", ""))
		check(Text.option_id(source)==id and (OptionCard.NAMES.has(source) or Text.OPTION_IDS.has(source)),"stable option ID matches known source: "+id)
		var name:=Text.option_field(source,"name","")
		var body:=Text.option_field(source,"text","")
		check(name!="" and body!="","option has name and body: "+source)
		var option_control:=OptionCard.new("48306",source)
		check(option_control.tooltip_text.contains(String(OptionCard.NAMES[source])) and option_control._source_text==source,"English action title available without changing source answer: "+source)
		option_control.free()
		check(OptionCard._wrap(body).size()*OptionCard.LINE_H-2<=OptionCard.TEXT_H-4,"option body stays in source field: "+source)
		var title_lines:=OptionCard._wrap_plain(name.to_upper(),OptionCard.W-14)
		check(title_lines.size()<=2,"option name fits original header: "+source)
		for line: String in title_lines: check(OptionCard._text_width(line,1)<=OptionCard.W-14,"option title line stays inside header: "+source)
		var option_image:=OptionCard.render("48306",source)
		var raw:=CardView.pixel_texture("48306","",false).get_image()
		if raw.is_compressed(): raw.decompress()
		raw.convert(Image.FORMAT_RGBA8)
		check(option_image.get_region(Rect2i(6,34,164,PC.ART_H)).get_data()==raw.get_region(Rect2i(6,34,164,PC.ART_H)).get_data(),"translated option keeps source art: "+source)
	L10n.set_locale("en")
	var green_source:="Return one of your spies -> supplant a troop at that spy's site, then gain VP per site controlled"
	check(Text.option_field(green_source,"text",green_source).contains("site control marker"),"Green Dragon English option matches current card and control-marker rule")
	check(Text.option_field(green_source,"name",OptionCard.NAMES[green_source])=="Coup","Green Dragon English action name preserved")
	for cid: String in ids:
		if not originals.has(cid): continue
		var image:=CardView.pixel_texture(cid).get_image()
		if image.is_compressed(): image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		check(image.get_data()==(originals[cid] as Image).get_data(),"English raster restored exactly: "+cid)
	print("localized catalog ",selected,": ",passed," checks, failed ",failed)
	quit(1 if failed else 0)
