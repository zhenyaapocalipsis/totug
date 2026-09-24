# Tyrants of the Underdark — Godot 4.7 port (Demonweb)

- Godot project: `engine/godot/` (rules engine `core/`, network layer `net/`, UI `scenes/`, tests `tests/`).
- Reference data: rulebook PDFs, TTS mod data (`2745860709.json`, `engine/main_lua_script.lua`), card sheets in `cards/`.
- Development plan and stage order: `Claude outputs/plan_dorabotki.md`.

## Commands
- Tests: `"C:\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "C:\tyrants of the underdark godot\engine\godot" --script res://tests/run_tests.gd` (last line: `пройдено: N, провалено: 0`).
- Network test: same command with `--script res://tests/net_loopback.gd` (host + client over 127.0.0.1; last line: `сеть: пройдено N, провалено 0`).
- Play: open `engine/godot/project.godot` in `C:\godot\Godot_v4.7.2-stable_win64.exe`, press F5.
- Build exe: `GAME 1v1/build-game.bat`.

## Workflow
- One stage at a time: change → tests pass → git commit "Stage N: ..." → short Russian checklist for the owner.
- Chat with the owner in Russian; code, identifiers and file names in Latin script; in-game text in English.
- Owner's rules rulings override OCR'd card text and old code comments.
