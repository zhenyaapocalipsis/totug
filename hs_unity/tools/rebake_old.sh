#!/bin/bash
# Перезапекание старых эффектов Кодекса: правильный echo_<cid> + без Quad_CardGlow_Backer.
# Запускать только когда свободен Unity (после rebake30.sh).
export ProgramData='C:\ProgramData' ALLUSERSPROFILE='C:\ProgramData' SystemDrive='C:'
while read -r n; do
	[ -z "$n" ] && continue
	echo "=== $n: начало $(date +%H:%M:%S)"
	bash hs_unity/tools/port.sh bake "$n" 2>&1 | tail -2
done < hs_unity/tools/rebake_old_list.txt
echo "=== ВСЕ СТАРЫЕ ГОТОВЫ $(date +%H:%M:%S)"
