#!/bin/bash
# Перенос назначений владельца в игру (GUIDE «Перенос назначений владельца»), после cand.sh make/render.
#   bash hs_unity/tools/port.sh recipe <имя> <cid> <удар, с> [len]
#     recipes/<имя>.json из пробы render/cand/<имя>.json + слой Choice_Reveal (at = удар + 0.02,
#     tintHue — главный оттенок кадра пробы после удара, hs_hue.gd); deps -> hs_unity/deps_<имя>.txt
#   bash hs_unity/tools/port.sh bake <имя>
#     Unity -> engine/godot/assets/hs_fx/baked/<имя>, импорт с настройками сжатия кадров (GUIDE §0 п.7)
#   bash hs_unity/tools/port.sh rebake <имя> <cid>
#     готовый рецепт для другой карты: контур echo_<cid>, запечь в render/<имя>_bake, png и meta.json поверх
#   bash hs_unity/tools/port.sh sounds <имя> <папка префаба в выгрузке>
#     .fsb (без VO и стингеров) -> wav в assets/hs_fx/<имя>; печатает громкости AudioSource, дорожки
#     звука и тряски Timeline (или звуки, тряску и ожидания FSM) — для SCRIPTS в hs_play.gd
#   bash hs_unity/tools/port.sh check <имя> <cid>
# HSPROJ=<копия hs_unity> — запекать в копии проекта, когда hs_unity занят (HsBrowser, пробы)
#     ui_shot в партии: render/<имя>.gif и лист render/<имя>_sheet.png
R="/c/tyrants of the underdark godot"; RW="C:/tyrants of the underdark godot"
U="/c/Program Files/Unity/Hub/Editor/6000.6.6f1/Editor/Unity.exe"; G=/c/godot/Godot_v4.7.2-stable_win64_console.exe
C="$R/hs_unity/render/cand"; FR=(10 30 50 70 90 110 140 170 200 240)
mode=$1; n=$2

unity_free() {
	[ -n "$HSPROJ" ] && return 0  # своя копия проекта (scratchpad) — открытый HsBrowser не мешает
	if wmic process where "name='Unity.exe'" get CommandLine 2> /dev/null | grep -v -i batchmode | grep -q hs_unity; then
		echo "$n: проект hs_unity открыт в Unity (HsBrowser) — закрыть окно Unity"; return 1
	fi
}

hue_of() {
	"$G" --headless --path "$RW/engine/godot" --script res://tools/hs_hue.gd -- "$1" 2> /dev/null | grep '^hue' | head -1 | awk '{print $2}'
}

import_frames() {
	local b="$R/engine/godot/assets/hs_fx/baked/$1"
	rm -f "$b/hsr_log.txt"
	"$G" --headless --path "$RW/engine/godot" --import > /dev/null 2>&1
	sed -i 's/^compress\/mode=0/compress\/mode=1/; s/^compress\/lossy_quality=0.7/compress\/lossy_quality=0.9/; s/^process\/fix_alpha_border=true/process\/fix_alpha_border=false/' "$b"/*.import
	"$G" --headless --path "$RW/engine/godot" --import > /dev/null 2>&1
}

case $mode in
recipe)
	cid=$3; hit=$4; len=${5:-4.0}
	[ -f "$C/$n.json" ] || { echo "нет пробы $C/$n.json (cand.sh make/render)"; exit 1; }
	cp "$C/deps_$n.txt" "$R/hs_unity/deps_$n.txt"
	# кадр пробы ~0.25 с после удара: эффект в силе
	want=$(awk -v h="$hit" 'BEGIN { printf "%d", h * 60 + 15 }'); best=${FR[0]}
	for f in "${FR[@]}"; do [ $(( (f - want) * (f - want) )) -lt $(( (best - want) * (best - want) )) ] && best=$f; done
	fr=$(printf "%03d" "$best"); hue=$(hue_of "$RW/hs_unity/render/cand/$n/u$fr.png")
	[ -z "$hue" ] && hue=$(hue_of "$RW/hs_unity/render/cand/$n/f$fr.png")
	[ -z "$hue" ] && hue=0.75
	layer=$(tr -d '\n' < "$C/$n.json" | sed -E 's/.*"layers": \[(.*)\]\}[[:space:]]*$/\1/')
	# трещины в земле и виньетки на весь экран — макет HS (GUIDE §1, §5): спрятать; папки *Root
	# с трещинами в имени не трогать (в них бывают камни и пыль удара). Выгрузка — render/port_dirs.tsv
	dx=$(awk -F'\t' -v n="$n" '$1 == n { print $2 }' "$R/hs_unity/render/port_dirs.tsv" 2> /dev/null)
	W=${PORT_W:-C:/Users/JEKADI~1/AppData/Local/Temp/claude/C--Users-jekadiscoteka--claude-spares-spare-17Dj3d/aff98ce0-2454-4200-8e94-1e32296e0b4b/scratchpad}
	if [ -n "$dx" ] && [ -f "$W/$dx/paths.txt" ]; then
		extra=$(awk '{ k = split($0, p, "/"); last = p[k]
			if (!(last ~ /[Vv]ignette/ || (last ~ /[Cc]rack/ && last !~ /Root$/))) next
			for (i in kept) if (index($0, kept[i] "/") == 1) next
			kept[NR] = $0; print }' "$W/$dx/paths.txt" | sed 's/.*/"&"/' | paste -sd, -)
		if [ -n "$extra" ]; then
			layer=$(echo "$layer" | sed -E "s|\"hide\": \[\]|\"hide\": [$extra]|; t; s|\"hide\": \[|\"hide\": [$extra, |")
			echo "$n: спрятаны трещины и виньетки: $extra" | cut -c1-200
		fi
	fi
	under=$(echo "$layer" | sed -E 's/.*"under": (\[[^]]*\]).*/\1/')
	at=$(awk -v h="$hit" 'BEGIN { printf "%.2f", h + 0.02 }')
	cat > "$R/hs_unity/recipes/$n.json" <<J
{
  "deps": "../deps_$n.txt",
  "fps": 60.0,
  "len": $len,
  "space": "gamma",
  "ldr": true,
  "layers": [
    ${layer%\}}, "measure": $under},
    {
      "prefab": "b5e71dd8e88c71947ab2566113e0ec90",
      "at": $at,
      "only": "Root/Bursts_Root/Burst0_New",
      "place": [-7.616, 3.802, -6.81],
      "usePlace": true,
      "scale": 0.3715,
      "under": ["Root/Bursts_Root/Burst0_New/MeshRoot"],
      "measure": ["Root/Bursts_Root/Burst0_New/MeshRoot/Quad_CardGlow"],
      "hidePS": ["Root/Bursts_Root/Burst0_New"],
      "tintHue": $hue,
      "tintNodes": ["Root/Bursts_Root/Burst0_New/MeshRoot"]
    }
  ],
  "textures": [
    {"name": "GenFX_AbilityCard_Echo_BW", "file": "textures/echo_$cid.png"}
  ]
}
J
	[ -f "$R/hs_unity/recipes/textures/echo_$cid.png" ] || echo "нет контура textures/echo_$cid.png — GUIDE §0 п.4 (hs_bake_prep.gd)"
	echo "$n: recipes/$n.json, Choice_Reveal $at, tintHue $hue (кадр пробы $fr), reveal в SCRIPTS = $(awk -v a="$at" 'BEGIN { printf "%.2f", a + 0.45 }')"
	;;
bake)
	unity_free || exit 1
	"$U" -batchmode -quit -projectPath "${HSPROJ:-$RW/hs_unity}" -executeMethod HsRender.Run -hsr-win C:/Games/Hearthstone/Data/Win \
		-hsr-recipe "$RW/hs_unity/recipes/$n.json" -hsr-out "$RW/engine/godot/assets/hs_fx/baked/$n" -logFile "$RW/hs_unity/render/${n}_bake.log"
	k=$(ls "$R/engine/godot/assets/hs_fx/baked/$n" 2> /dev/null | grep -c '^f.*\.png$')
	[ "$k" -eq 0 ] && { echo "$n: нет кадров — $(grep -m1 -E 'Multiple Unity instances|prefab not found|Exception' "$R/hs_unity/render/${n}_bake.log")"; exit 1; }
	import_frames "$n"
	echo "$n: кадров $k, $(du -sh "$R/engine/godot/assets/hs_fx/baked/$n" | cut -f1)"
	;;
rebake)
	cid=$3; unity_free || exit 1
	sed -i -E "s/echo_[0-9]+\.png/echo_$cid.png/" "$R/hs_unity/recipes/$n.json"
	rm -rf "$R/hs_unity/render/${n}_bake"
	"$U" -batchmode -quit -projectPath "${HSPROJ:-$RW/hs_unity}" -executeMethod HsRender.Run -hsr-win C:/Games/Hearthstone/Data/Win \
		-hsr-recipe "$RW/hs_unity/recipes/$n.json" -hsr-out "$RW/hs_unity/render/${n}_bake" -logFile "$RW/hs_unity/render/${n}_bake.log"
	N="$R/hs_unity/render/${n}_bake"; B="$R/engine/godot/assets/hs_fx/baked/$n"
	if diff <(ls "$N" | grep -v hsr_log) <(ls "$B" | grep -v '\.import$') > /dev/null; then
		cp "$N"/*.png "$N/meta.json" "$B/"
		"$G" --headless --path "$RW/engine/godot" --import > /dev/null 2>&1
		echo "$n: перепечено с echo_$cid"
	else
		echo "$n: набор кадров отличается — сравнить $N и $B"; exit 1
	fi
	;;
sounds)
	d=$3; out="$R/engine/godot/assets/hs_fx/$n"; mkdir -p "$out"
	tmp="$(cygpath -u "$TEMP")/hsport"; mkdir -p "$tmp"
	shopt -s nullglob
	# звуки бывают и в соседних папках выгрузки (<N>_<имя>_Sound): лишние wav удалить после SCRIPTS
	# звуки дорожек Timeline по имени (апостроф и пробел в имени .fsb — «_»); без разбиения по словам
	: > "$TEMP/hsport_snds.txt"
	grep -h "SoundTimelineAsset" "$d"/timeline_*.txt 2> /dev/null | sed -E "s/^ *\[[^]]*\] '(.*)'  SoundTimelineAsset.*/\1/; s/[^A-Za-z0-9_]/_/g" \
		| while read -r s; do find "$(dirname "$d")" -path "*/audio/$s.fsb" 2> /dev/null; done > "$TEMP/hsport_snds.txt"
	mapfile -t sib < "$TEMP/hsport_snds.txt"
	for f in "$d"/audio/*.fsb "$(dirname "$d")"/*CustomSummon*/audio/*.fsb "$(dirname "$d")"/*CustomSpawn*/audio/*.fsb "${sib[@]}"; do
		[ -f "$out/$(basename "$f" .fsb).wav" ] && continue
		b=$(basename "$f" .fsb)
		case $b in VO_*|*Stinger*) continue ;; esac
		cp "$f" "$tmp/a.fsb"
		"$R/hs_unity/tools/vgmstream/vgmstream-cli.exe" -o "$out/$b.wav" "$tmp/a.fsb" > /dev/null || echo "не сконвертирован $b"
		echo "звук $b"
	done
	awk '/^ *GO \x27/ { go = $0 } /\[AudioSource\]/ { a = 1 } a && /m_Volume =/ { sub(/^ */, "", go); print "AudioSource " $3 "  " go; a = 0 }' "$d/hierarchy.txt" | sort -u
	ls "$d"/timeline_*.txt > /dev/null 2>&1 && grep -hE "^TRACK|CameraShaker2Asset|SoundTimelineAsset" "$d"/timeline_*.txt | grep -B1 -E "CameraShaker2Asset|SoundTimelineAsset" | grep -v "^--" | cut -c1-200
	# FSM: состояния, переходы, звуки (m_Sound — SoundDef, имя смотреть в refs.txt), тряска, ожидания
	ls "$d"/fsm_*.txt > /dev/null 2>&1 && grep -hE "^STATE|^  on |Audio|Shake|Wait " "$d"/fsm_*.txt | grep -v "(disabled)" \
		| sed -E 's/m_(SpecificCamera|NamedCamera|WhichCamera|ParentObject|SpatialBlend|Category|TemplateSource|IsMinionSummonVO|IsKeywordVO)=[^ ]* *//g' | cut -c1-220
	;;
script)
	# заготовка SCRIPTS по Timeline: port.sh script <имя> <папка префаба> <reveal> — cues из
	# SoundTimeline (громкость AudioSource узла), shakers из CameraShaker2; комментарий дописать руками
	d=$3; rev=$4
	awk -v n="$n" -v rev="$rev" '
		function num(s) { gsub(/,/, ".", s); return s + 0 }
		FNR == 1 { file++ }
		file == 1 && /^ *GO \x27/ { go = $0; sub(/^ *GO \x27/, "", go); sub(/\x27 active.*/, "", go) }
		file == 1 && /\[AudioSource\]/ { a = 1 }
		file == 1 && a && /m_Volume =/ { vol[go] = num($3); a = 0 }
		file == 2 && /SoundTimelineAsset/ {
			# имя звука — имя клипа дорожки (дорожка бывает привязана к null)
			snd = $0; sub(/^ *\[[^]]*\] \x27/, "", snd); sub(/\x27  SoundTimelineAsset.*/, "", snd)
			s = $0; sub(/^ *\[/, "", s); sub(/ \.\..*/, "", s)
			v = (snd in vol) ? vol[snd] : 1.0
			# имя файла = имя .fsb: апостроф и пробел в нём стали «_» (Timecap_n)
			f = snd; gsub(/[^A-Za-z0-9_]/, "_", f)
			cues = cues (cues == "" ? "" : ", ") sprintf("[%.3g, \"%s\", %.2g]", num(s), f, v)
		}
		file == 2 && /CameraShaker2Asset/ {
			s = $0; sub(/^ *\[/, "", s); e = s; sub(/ \.\..*/, "", s); sub(/.*\.\. /, "", e); sub(/\].*/, "", e)
			am = $0; sub(/.*m_Amount=\(/, "", am); sub(/\).*/, "", am); split(am, xy, ", ")
			amp = num(xy[1]) > num(xy[2]) ? num(xy[1]) : num(xy[2])
			cv = $0; sub(/.*curve\[/, "", cv); sub(/\].*/, "", cv); k = split(cv, pts, " "); c = ""
			for (i = 1; i <= k; i++) { split(pts[i], tv, ":"); t = num(tv[1]); if (t < 0) t = 0; if (t > 1) t = 1; vv = num(tv[2]); if (vv < 0) vv = 0
				c = c (c == "" ? "" : ", ") sprintf("[%.3g, %.3g]", t, vv) }
			iv = $0; sub(/.*m_interval=/, "", iv); sub(/[^0-9,.].*/, "", iv)
			sh = sh (sh == "" ? "" : ", ") sprintf("[%.4g, %.4g, %.3g, [%s], %.3g]", num(s), num(e), amp, c, num(iv))
		}
		END {
			printf "\t\"%s\": {\"frames\": \"%s\", \"sounds\": \"%s\",\n", n, n, n
			printf "\t\t\"card\": {\"face\": \"mini\", \"reveal\": %s, \"sweep\": 0.6, \"hold\": 1.0, \"out\": 0.35, \"center\": Vector2(490, 365)},\n", rev
			printf "\t\t# Sound Timeline (громкость — AudioSource)\n\t\t\"cues\": [%s]", cues
			if (sh != "") printf ",\n\t\t# CameraShaker2\n\t\t\"shakers\": [%s]", sh
			printf "},\n"
		}' "$d/hierarchy.txt" $(ls "$d"/timeline_*.txt 2> /dev/null | head -1)
	;;
check)
	cid=$3
	"$G" --path "$RW/engine/godot" --script res://tests/ui_shot.gd -- --scenario=hs_play --card=$cid --gif=110 \
		--out=../../hs_unity/render/$n.png 2>&1 | grep -E "gif:|SCRIPT ERROR"
	;;
esac
