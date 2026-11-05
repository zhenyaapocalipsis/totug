class_name Updater
extends Control

## Автообновление собранной игры (решение владельца, 2026-09-26).
##
## Игра у игрока — два файла в одной папке: TyrantsOfTheUnderdark.exe (движок
## Godot) и TyrantsOfTheUnderdark.pck (сама игра; движок сам грузит .pck с
## тем же именем рядом с собой). При запуске игра спрашивает у нашего сервера
## номер последней версии (version.txt: "<номер> <sha256 файла> <подпись>").
## Новые клиенты проверяют подписанный индекс патчей (два дополнительных
## поля version.txt), скачивают дельту для точного SHA своего файла и собирают
## новый .pck рядом. При отсутствии/ошибке патча скачивают полный пакет.
## После проверки итогового SHA игра закрывается, а
## скрытый update.bat дожидается её закрытия, подменяет файл и запускает
## игру снова. Пока игра открыта, свой .pck она держит открытым — поэтому
## подмена после выхода. (`--main-pack` готовые сборки Godot не принимают.)
##
## Нет связи или папка только для чтения — играем в то, что есть.
## Номер версии ставит server/deploy.sh в res://build_info.gd (файла нет в
## git; без него версия 0 — так из редактора обновление не идёт).

signal finished  # обновлять нечего — запускать игру

const BASE_URL := "http://%s/tyrants/" % NetSession.DEFAULT_SERVER
const TIMEOUT := 6.0
const STALL_TIMEOUT_MS := 30000
const PatchFile := preload("res://scenes/update_patch.gd")
const UpdateHTTP := preload("res://scenes/update_http.gd")
enum Stage { VERSION, INDEX, PATCH, FULL, DONE }

var _label: Label
var _http: UpdateHTTP
var _server_build := 0
var _server_sha := ""
var _speed_started_ms := 0
var _speed_started_bytes := 0
var _speed_mib := 0.0
var _stage := Stage.VERSION
var _index_sha := ""
var _target_size := -1
var _base_sha := ""
var _patch_sha := ""
var _patch_size := 0
var _request_path := ""
var _request_pending := false
var _needs_resume := false
var _full_attempted := false
var _worker: Thread
var _worker_result: Variant
var _patch_attempts := 0


func _pack_path() -> String:
	return pck_path()


func _local_build() -> int:
	return own_build()


func _url(relative: String) -> String:
	return BASE_URL + relative


func _verify_signature(build: int, sha: String, signature: String) -> bool:
	return UpdateSign.verify(build, sha, signature)


func _stall_timeout_ms() -> int:
	return STALL_TIMEOUT_MS


## Без потока HTTPRequest читает только одну порцию за кадр: 64 КиБ при
## 10 FPS = около 640 КиБ/с, даже если интернет быстрый. Загрузка не должна
## зависеть от FPS, VSync или свёрнутого окна.
static func create_http_request() -> UpdateHTTP:
	return UpdateHTTP.new()


## Нужна ли проверка: только в собранной игре с .pck рядом (не встроенным).
static func wanted() -> bool:
	if not OS.has_feature("template") or OS.get_cmdline_user_args().has("--no-update"):
		return false
	return FileAccess.file_exists(pck_path())


static func pck_path() -> String:
	return OS.get_executable_path().get_basename() + ".pck"


static func own_build() -> int:
	if not ResourceLoader.exists("res://build_info.gd"):
		return 0
	return int(load("res://build_info.gd").BUILD)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PixelTheme.theme()
	var bg := ColorRect.new()
	bg.color = PixelTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	_label.text = "CHECKING FOR UPDATES..."
	add_child(_label)

	# Недокачанный файл с прошлого раза.
	DirAccess.remove_absolute(_pack_path() + ".new")
	DirAccess.remove_absolute(_pack_path() + ".tdpatch")
	_http = create_http_request()
	_http.timeout = TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_response)
	_request("version.txt")


## SharpScale переносит стартовую сцену в свой SubViewport, а HTTPRequest,
## выйдя из дерева, молча отменяет запрос — сигнала не будет, и экран навсегда
## застревал на CHECKING FOR UPDATES (2560x1440, сборка 1790521072).
## Поэтому после возвращения в дерево прерванный запрос отправляем заново.
func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE and _http != null:
		_needs_resume = _request_pending
		_join_worker()
	elif what == NOTIFICATION_ENTER_TREE and _http != null:
		_resume.call_deferred()


func _resume() -> void:
	if not _needs_resume or not _request_pending:
		return
	_needs_resume = false
	_http.cancel_request()
	_request(_request_path)


func _request(relative: String) -> void:
	_request_path = relative
	_request_pending = true
	_http.stall_timeout_ms = _stall_timeout_ms()
	_http.timeout = TIMEOUT if _stage in [Stage.VERSION, Stage.INDEX] else 0.0
	_http.body_size_limit = 1024 * 1024 if _stage in [Stage.VERSION, Stage.INDEX] else (_patch_size if _stage == Stage.PATCH else _target_size)
	_http.download_file = _pack_path() + (".tdpatch" if _stage == Stage.PATCH else ".new") if _stage in [Stage.PATCH, Stage.FULL] else ""
	if _http.request(_url(relative)) != OK:
		_request_pending = false
		if _stage in [Stage.INDEX, Stage.PATCH]:
			_start_full()
		else:
			_finish()


func _join_worker() -> void:
	if _worker != null and _worker.is_started():
		_worker_result = _worker.wait_to_finish()


func _work(job: Callable) -> Variant:
	_worker = Thread.new()
	_worker_result = null
	if _worker.start(job) != OK:
		return null
	while _worker.is_alive():
		await get_tree().process_frame
	_join_worker()
	_worker = null
	return _worker_result


func _finish() -> void:
	_stage = Stage.DONE
	_request_pending = false
	DirAccess.remove_absolute(_pack_path() + ".new")
	DirAccess.remove_absolute(_pack_path() + ".tdpatch")
	finished.emit()


func _process(_delta: float) -> void:
	if _http != null and _stage in [Stage.PATCH, Stage.FULL] and _http.get_http_client_status() == HTTPClient.STATUS_BODY:
		var total := _http.get_body_size()
		var downloaded := _http.get_downloaded_bytes()
		var now := Time.get_ticks_msec()
		if now - _speed_started_ms >= 1000:
			_speed_mib = maxf(0.0, float(downloaded - _speed_started_bytes) * 1000.0 / (now - _speed_started_ms) / 1048576.0)
			_speed_started_ms = now
			_speed_started_bytes = downloaded
		if total > 0:
			_label.text = "DOWNLOADING %s  %d%%\n%.1f / %.1f MiB  |  %.1f MiB/s" % [
				"PATCH" if _stage == Stage.PATCH else "UPDATE", int(100.0 * downloaded / total), downloaded / 1048576.0, total / 1048576.0, _speed_mib]


func _on_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_request_pending = false
	if _stage == Stage.VERSION:
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			_finish()
		else:
			_on_version(body)
	elif _stage == Stage.INDEX:
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			_start_full()
		else:
			await _on_index(body)
	elif _stage == Stage.PATCH:
		await _on_patch(result, code)
	elif _stage == Stage.FULL:
		await _on_full(result, code)


func _on_version(body: PackedByteArray) -> void:
	var parts := body.get_string_from_utf8().strip_edges().split(" ", false)
	_server_build = int(parts[0]) if parts.size() > 0 else 0
	_server_sha = String(parts[1]) if parts.size() > 1 else ""
	var sig := String(parts[2]) if parts.size() > 2 else ""
	print("Tyrants update: own build %d, server build %d" % [_local_build(), _server_build])
	if _server_build <= _local_build():
		_finish()
		return
	# Без подписи владельца не качаем: version.txt мог подменить кто угодно
	# по дороге (этап Sec-1, scenes/update_sign.gd).
	if not _verify_signature(_server_build, _server_sha, sig):
		printerr("Tyrants update: bad or missing signature, keeping build %d" % _local_build())
		_finish()
		return
	if parts.size() >= 5 and _verify_signature(_server_build, parts[3], parts[4]):
		_index_sha = parts[3]
		_stage = Stage.INDEX
		_request("patches/%d/index.json" % _server_build)
	else:
		_start_full()


func _on_index(body: PackedByteArray) -> void:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(body)
	if hashing.finish().hex_encode() != _index_sha:
		_start_full()
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		_start_full()
		return
	var index: Dictionary = parsed
	if index.get("format") != 1 or index.get("build") != _server_build or index.get("target_sha") != _server_sha \
		or not PatchFile._uint(index.get("target_size")) or int(index.target_size) <= 0 \
		or not index.get("patches") is Array or index.patches.size() > 100:
		_start_full()
		return
	_target_size = int(index.target_size)
	_label.text = "CHECKING LOCAL FILES..."
	var base_hash: Variant = await _work(func(): return FileAccess.get_sha256(_pack_path()))
	_base_sha = base_hash if base_hash is String else ""
	for entry: Variant in index.patches:
		if not entry is Dictionary or entry.get("from_sha") != _base_sha or _base_sha.length() != 64:
			continue
		var sha: Variant = entry.get("sha256")
		if not sha is String or sha.length() != 64 or not PatchFile._uint(entry.get("size")) \
			or int(entry.size) <= 0 or int(entry.size) >= _target_size:
			continue
		_patch_sha = sha
		_patch_size = int(entry.size)
		_patch_attempts = 1
		_stage = Stage.PATCH
		_label.text = "DOWNLOADING PATCH..."
		_reset_speed()
		_request("patches/%d/%s.tdpatch" % [_server_build, _base_sha])
		return
	_start_full()


func _reset_speed() -> void:
	_speed_started_ms = Time.get_ticks_msec()
	_speed_started_bytes = 0
	_speed_mib = 0.0


func _start_full() -> void:
	if _full_attempted:
		_finish()
		return
	_full_attempted = true
	_stage = Stage.FULL
	DirAccess.remove_absolute(_pack_path() + ".tdpatch")
	DirAccess.remove_absolute(_pack_path() + ".new")
	_label.text = "DOWNLOADING UPDATE..."
	_reset_speed()
	_request("game.pck")


func _on_patch(result: int, code: int) -> void:
	var patch := _pack_path() + ".tdpatch"
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		if result != HTTPRequest.RESULT_SUCCESS and _patch_attempts < 2:
			_patch_attempts += 1
			_reset_speed()
			_request(_request_path)
			return
		_start_full()
		return
	_label.text = "APPLYING PATCH..."
	var valid: Variant = await _work(func():
		return FileAccess.get_sha256(patch) == _patch_sha and PatchFile.apply(
			_pack_path(), patch, _pack_path() + ".new", _base_sha, _server_sha, _server_build))
	DirAccess.remove_absolute(patch)
	if valid != true:
		printerr("Tyrants update: patch failed, downloading full package")
		_start_full()
		return
	_install()


func _on_full(result: int, code: int) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		printerr("Tyrants update: download failed (result %d, code %d)" % [result, code])
		_finish()
		return
	_label.text = "VERIFYING UPDATE..."
	var sha: Variant = await _work(func(): return FileAccess.get_sha256(_pack_path() + ".new"))
	if sha != _server_sha:
		printerr("Tyrants update: full package checksum failed")
		_finish()
		return
	_install()


func _install() -> void:
	_stage = Stage.DONE
	_label.text = "RESTARTING..."
	if not _restart_with(_pack_path() + ".new"):
		_finish()


## update.bat: дождаться, пока эта программа закроется, подменить .pck и
## запустить игру заново. Пути в кавычках и в UTF-8 (chcp 65001) — папка
## игрока может называться по-русски.
func _restart_with(fresh: String) -> bool:
	var exe := OS.get_executable_path().replace("/", "\\")
	var pid := str(OS.get_process_id())
	var args := " ".join(OS.get_cmdline_user_args())
	var lines := [
		"@echo off",
		"chcp 65001 >nul",
		":wait",
		"tasklist /FI \"PID eq %s\" 2>nul | find \"%s\" >nul && (timeout /t 1 /nobreak >nul & goto wait)" % [pid, pid],
		"move /y \"%s\" \"%s\" >nul || exit /b 1" % [fresh.replace("/", "\\"), _pack_path().replace("/", "\\")],
		"start \"\" \"%s\"%s" % [exe, (" -- " + args) if args != "" else ""],
	]
	var bat := OS.get_user_data_dir().path_join("update.bat")
	var f := FileAccess.open(bat, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string("\r\n".join(lines) + "\r\n")
	f.close()
	if OS.create_process("cmd.exe", ["/c", bat.replace("/", "\\")]) < 0:
		return false
	get_tree().quit()
	return true
