# Tyrants of the Underdark — Godot 4.7 port (Demonweb)

- Godot project: `engine/godot/` (rules engine `core/`, network layer `net/`, UI `scenes/`, tests `tests/`).
- Reference data: rulebook PDFs, TTS mod data (`2745860709.json`, `engine/main_lua_script.lua`), card sheets in `cards/`.
- Development plan and stage order: `Claude outputs/plan_dorabotki.md`.

## Commands
- Tests: `"C:\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "C:\tyrants of the underdark godot\engine\godot" --script res://tests/run_tests.gd` (last line: `пройдено: N, провалено: 0`).
- Network test: same command with `--script res://tests/net_loopback.gd` (host + client over 127.0.0.1; last line: `сеть: пройдено N, провалено 0`).
- Play: open `engine/godot/project.godot` in `C:\godot\Godot_v4.7.2-stable_win64.exe`, press F5.
- Online: `start-server.bat` = local room-code server (UDP 7780, `-- --server`); `start-game.bat` opens one game window (run twice to test).
- Build exe: `GAME 1v1/build-game.bat`.
- Browse all HS legendary play effects live in Unity (no baking): `hs_unity/hs-browser.bat`; owner's favorites — `hs_unity/data/hs_favorites.tsv` (GUIDE «Просмотр всех легендарок HS»).
- Hearthstone card-play animations: read `hs_unity/GUIDE.md` first (§0 = step-by-step quick start for a new card; owner rules, pipeline, pitfalls; give HsRender ABSOLUTE -hsr-recipe/-hsr-out paths, relative ones resolve inside hs_unity/) and `hs_unity/CARD_MAP.md` (which HS legendary for which unique card). Effects are baked, not ported: recipe `hs_unity/recipes/<name>.json` -> `"C:\Program Files\Unity\Hub\Editor\6000.6.6f1\Editor\Unity.exe" -batchmode -quit -projectPath hs_unity -executeMethod HsRender.Run -hsr-win C:/Games/Hearthstone/Data/Win -hsr-recipe hs_unity/recipes/<name>.json -hsr-out engine/godot/assets/hs_fx/baked/<name>` (frames + meta.json; `-hsr-from N` resumes; then `--import` and in the frames' .import set `process/fix_alpha_border=false`, `compress/mode=1`, `compress/lossy_quality=0.9` (lossy WebP: Worldbreaker 31 MB instead of ~235 MB in BC7; alpha stays exact and HsPlay skips zero-alpha pixels, so compression noise in empty areas never shows; old bakes: `tools/bake_alpha_fix.gd` first)); HsPlay plays them (SCRIPTS: the play, actions per game event — supplant / return_spy / vp_site — placed on the target, and a looping play fog, FOGS). Check frames: `tools/bake_sheet.gd`; whole card in a match: `tests/ui_shot.gd -- --scenario=hs_dragon --gif=170`.

## Workflow
- One stage at a time: change → tests pass → git commit "Stage N: ..." → short Russian checklist for the owner.
- Chat with the owner in Russian; code, identifiers and file names in Latin script; in-game text in English.
- Owner's rules rulings override OCR'd card text and old code comments.
