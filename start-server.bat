@echo off
title Tyrants of the Underdark - SERVER
rem Local game server with room codes (UDP port 7780). Close this window to stop it.
"C:\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%~dp0engine\godot" -- --server
pause
