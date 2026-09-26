@echo off
rem Opens one game window. Run it twice to test online play on one computer.
rem "start-game.bat 2" uses a second profile (own name, emblem and rating key),
rem so two windows on one computer count as two different players.
if "%~1"=="" (
  start "" "C:\godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0engine\godot"
) else (
  start "" "C:\godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0engine\godot" -- --profile=%~1
)
