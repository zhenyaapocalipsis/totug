extends SceneTree
## Скрытие «как в HsBrowser» для рецептов HsRender (владелец 2026-10-29: при переносе пропали
## детали — узел жетона прятался целиком вместе с шлейфами, разрезами и свечениями эффекта).
## В слое эффекта (первый слой) из hide остаются только виньетки на весь экран и корни
## стороны соперника; сетки жетона и интерфейса карты HS прячет hideMeshRx (частицы остаются).
##   Godot --headless --script res://../../hs_unity/tools/hide_like_browser.gd -- <рецепт.json> ...
const MESH_RX := "TokenGlow|MinionEdgeGlow|MinionShell|MinionGlow|Mesh_FlashGlow|Top_Nightmare|Card_InPlay|TokenHider|Test_Minion|^Minion|Health|Attack|UberText|Portrait|Gem_|Unique_Ally|Location_InPlay|Wep_|TokenEdge|Token_Edge|EdgeGlow|Token_SoftGlow|Token_GlowBacking|Token_DarkCover|LengendaryToken|LegendaryToken|SpotlightGlow|Token_BackGlow|Minion_BackGlow|Token_Cracks|Token_GlassCracking"
const KEEP_RX := "[Vv]ignette|Opponent|_OP$|_OP/"

func _init() -> void:
	var keep := RegEx.create_from_string(KEEP_RX)
	for path in OS.get_cmdline_user_args():
		var rec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var layer: Dictionary = rec["layers"][0]
		var old: Array = layer.get("hide", [])
		var hide: Array = old.filter(func(h: String) -> bool: return keep.search(h) != null)
		layer["hide"] = hide
		layer["hideMeshRx"] = MESH_RX
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(rec, "  ", false) + "\n")
		print("%s: hide %d -> %d %s" % [path.get_file(), old.size(), hide.size(), str(hide)])
	quit()
