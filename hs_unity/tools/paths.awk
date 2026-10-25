# Полные пути узлов префаба из hierarchy.txt (hsx extract) — для hide/under/controls/pin.
#   awk -f hs_unity/tools/paths.awk <папка префаба>/hierarchy.txt > paths.txt
#   grep -E "/(PS_Motes|VFX_Start)$" paths.txt      (узлы ControlRandomizedTrack из timeline)
#   grep -iE "glow|edge|token" paths.txt            (жетон HS и его контуры — прятать)
/^ *GO '/ {
	match($0, /^ */); lv = RLENGTH / 2
	s = $0; sub(/^ *GO '/, "", s); sub(/' active=.*/, "", s)
	st[lv] = s; p = ""
	for (i = 1; i <= lv; i++) p = (p == "" ? st[i] : p "/" st[i])
	print p
}
