@echo off
rem Manual crop of the card minis: drag the frame over the full card art.
rem Every change is saved at once; when the window closes the textures are reimported.
"C:\godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0engine\godot" res://tools/mini_crop_editor.tscn
"C:\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%~dp0engine\godot" --import
