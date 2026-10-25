#!/bin/bash
# Пробы кандидатов HS пачкой (GUIDE «Порядок для новой колоды», шаг 2).
#   bash hs_unity/tools/cand.sh <рабочая папка> make <CARD_ID>:<имя> ...
#     hsx extract, пути узлов, deps (+ Choice_Reveal из deps_worldbreaker), рецепт-проба
#     hs_unity/render/cand/<имя>.json: жетон и контуры HS в hide, корень в under,
#     ControlRandomizedTrack в controls. Рецепт проверить глазами: hide собран по именам.
#   bash hs_unity/tools/cand.sh <рабочая папка> render <имя> ...
#     Unity по одному (проект один), 10 кадров, лист <имя>_sheet.png и полоса
#     <имя>_strip.png (4 кадра у места карты) в hs_unity/render/cand. Запускать в фоне.
# В рабочей папке — hsx (сборка с cabmap.tsv, GUIDE §0 п.1) и выгрузки x/<CARD_ID>.
W=$1; mode=$2; shift 2
R="/c/tyrants of the underdark godot"; RW="C:/tyrants of the underdark godot"; C="$R/hs_unity/render/cand"
U="/c/Program Files/Unity/Hub/Editor/6000.6.6f1/Editor/Unity.exe"; G=/c/godot/Godot_v4.7.2-stable_win64_console.exe
FR=10,30,50,70,90,110,140,170,200,240
cd "$W" || exit 1

make_one() {
	local id=$1 n=$2
	[ -d "x/$id" ] || ./hsx/hsx.exe extract C:/Games/Hearthstone/Data/Win "x/$id" "$id" > "x_$id.log" 2>&1
	local p d guid cab root hide ctl line nm s e np
	p=$(grep -h "m_CustomSummonSpellPath ->" "x/$id"/*/index.txt "x/$id"/index.txt 2>/dev/null | head -1 | sed 's/.*-> //')
	d=$(ls -d "x/$id"/*/"$p" "x/$id/$p" 2>/dev/null | head -1)
	[ -z "$d" ] && { echo "$n: нет CustomSummon ($p)"; return 1; }
	awk -f "$R/hs_unity/tools/paths.awk" "$d/hierarchy.txt" > "$d/paths.txt"
	guid=$(head -1 "$d/hierarchy.txt" | grep -o 'guid=[0-9a-f]*' | cut -d= -f2)
	cab=$(head -1 "$d/hierarchy.txt" | grep -o 'CAB-[0-9a-f]*')
	./hsx/hsx.exe deps C:/Games/Hearthstone/Data/Win hsx/cabmap.tsv "d_$n.txt" "$cab" > /dev/null 2>&1
	awk '!seen[$0]++' "d_$n.txt" "$R/hs_unity/deps_worldbreaker.txt" > "$C/deps_$n.txt"
	root=$(sed -n 2,5p "$d/paths.txt" | grep -v / | head -1)
	hide=$(grep -E "(^|/)(OnToken|Token_Root|TokenRoot|Token_Root_OP|Opponent_Token_Root|Token \(Position\))$|TokenGlow|MinionEdgeGlow|MinionShell|Nightmare|Card_InPlay|TokenHider|Test_Minion" "$d/paths.txt" \
		| awk '{ for (i in kept) if (index($0, kept[i] "/") == 1) next; kept[NR] = $0; print }' | sed 's/.*/"&"/' | paste -sd, -)
	ctl=""
	while read -r line; do
		nm=$(echo "$line" | sed -E "s/^ *\[([0-9,]+) \.\. ([0-9,]+)\] '([^']+)'.*/\3/")
		s=$(echo "$line" | sed -E "s/^ *\[([0-9,]+) .*/\1/" | tr , .)
		e=$(echo "$line" | sed -E "s/^ *\[[0-9,]+ \.\. ([0-9,]+)\].*/\1/" | tr , .)
		np=$(grep -E "(^|/)$nm\$" "$d/paths.txt" | head -1)
		[ -n "$np" ] && ctl="$ctl{\"node\": \"$np\", \"start\": $s, \"end\": $e},"
	done < <(grep "ControlRandomizedPlayableAsset" "$d"/timeline_*.txt)
	cat > "$C/$n.json" <<J
{"deps": "deps_$n.txt", "fps": 60.0, "len": 4.5, "space": "gamma", "ldr": true,
 "layers": [{"prefab": "$guid", "at": 0.0, "pos": [-7.59, 0.0, -7.01], "usePos": true,
  "clip": "timeline", "hide": [$hide], "under": ["$root"], "controls": [${ctl%,}]}]}
J
	echo "$n: $p (выгрузка $W/$d)"
}

render_one() {
	local n=$1
	"$U" -batchmode -quit -projectPath "$RW/hs_unity" -executeMethod HsRender.Run -hsr-win C:/Games/Hearthstone/Data/Win \
		-hsr-recipe "$RW/hs_unity/render/cand/$n.json" -hsr-out "$RW/hs_unity/render/cand/$n" -hsr-frames $FR -logFile "$RW/hs_unity/render/cand/$n.log"
	"$G" --headless --path "$RW/engine/godot" --script res://tools/bake_sheet.gd -- --dir="$RW/hs_unity/render/cand/$n" --frames=$FR \
		--bg="$RW/hs_unity/render/clean_bg.png" --cols=4 --scale=0.5 --out="$RW/hs_unity/render/cand/${n}_sheet.png" > /dev/null 2>&1
	"$G" --headless --path "$RW/engine/godot" --script res://tools/bake_sheet.gd -- --dir="$RW/hs_unity/render/cand/$n" --frames=30,70,110,170 \
		--bg="$RW/hs_unity/render/clean_bg.png" --crop=200,60,580,480 --scale=0.5 --cols=4 --out="$RW/hs_unity/render/cand/${n}_strip.png" > /dev/null 2>&1
	echo "$n: кадров $(ls "$C/$n" 2>/dev/null | grep -c '^f')"
}

for a in "$@"; do
	case $mode in
		make) make_one "${a%%:*}" "${a##*:}" ;;
		render) render_one "$a" ;;
	esac
done
