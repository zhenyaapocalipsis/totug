@echo off
rem Unity with the HS legendaries browser (HsBrowser): all Hearthstone legendary play effects, favorites
start "" "C:\Program Files\Unity\Hub\Editor\6000.6.6f1\Editor\Unity.exe" -projectPath "%~dp0." -executeMethod HsBrowser.Open
