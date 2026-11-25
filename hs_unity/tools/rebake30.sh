#!/bin/bash
# Перезапекание 30 эффектов с hideRx Quad_CardGlow_Backer (и grow у ignis).
export ProgramData='C:\ProgramData' ALLUSERSPROFILE='C:\ProgramData' SystemDrive='C:'
names="ignistheeternalflame grandmagisterrommath alakirthewindsoftime
nexusprinceshaffar thorimstormlord ebyssian lumia kologarn vexallus
tenwuoftheredsmoke godfreythebetrayer kazakusgolemshaper xortothbreakerofstar
exarchmaladaar archmagekalec uluutheeverdrifter chronolorddeios ozumat ulfar
thelivingplague morchok sathrovarr eldernadox malygosthespellweave
chogallmastermind trastathsoulparasite galakrondazerothsend dirdrarebelcaptain
golganneththethund kingsbane"
for n in $names; do
	echo "=== $n: начало $(date +%H:%M:%S)"
	bash hs_unity/tools/port.sh bake "$n" 2>&1 | tail -2
done
echo "=== ВСЕ ГОТОВЫ $(date +%H:%M:%S)"
