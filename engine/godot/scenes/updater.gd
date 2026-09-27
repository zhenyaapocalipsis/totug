class_name Updater
extends Control

## Автообновление собранной игры (решение владельца, 2026-09-26).
##
## Игра у игрока — два файла в одной папке: TyrantsOfTheUnderdark.exe (движок
## Godot) и TyrantsOfTheUnderdark.pck (сама игра; движок сам грузит .pck с
## тем же именем рядом с собой). При запуске игра спрашивает у нашего сервера
## номер последней версии (version.txt: "<номер> <sha256 файла>"). Если он
## больше своего, скачивает новый .pck рядом (.pck.new) и закрывается, а
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

var _label: Label
var _http: HTTPRequest
var _server_build := 0
var _server_sha := ""


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
	DirAccess.remove_absolute(pck_path() + ".new")
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_version)
	if _http.request(BASE_URL + "version.txt") != OK:
		finished.emit()


## SharpScale переносит стартовую сцену в свой SubViewport, а HTTPRequest,
## выйдя из дерева, молча отменяет запрос — сигнала не будет, и экран навсегда
## застревал на CHECKING FOR UPDATES (2560x1440, сборка 1790521072).
## Поэтому после возвращения в дерево прерванный запрос отправляем заново.
func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE and _http != null:
		_resume.call_deferred()


func _resume() -> void:
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	if _http.request_completed.is_connected(_on_version):
		_http.request(BASE_URL + "version.txt")
	elif _http.request_completed.is_connected(_on_downloaded):
		_http.request(BASE_URL + "game.pck")


func _process(_delta: float) -> void:
	if _http != null and _server_build > 0 and _http.get_http_client_status() == HTTPClient.STATUS_BODY:
		var total := _http.get_body_size()
		if total > 0:
			_label.text = "DOWNLOADING UPDATE  %d%%" % int(100.0 * _http.get_downloaded_bytes() / total)


func _on_version(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_http.request_completed.disconnect(_on_version)
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		finished.emit()
		return
	var parts := body.get_string_from_utf8().strip_edges().split(" ", false)
	_server_build = int(parts[0]) if parts.size() > 0 else 0
	_server_sha = String(parts[1]) if parts.size() > 1 else ""
	print("Tyrants update: own build %d, server build %d" % [own_build(), _server_build])
	if _server_build <= own_build():
		finished.emit()
		return
	_label.text = "DOWNLOADING UPDATE..."
	_http.timeout = 0.0  # файл большой: ждём, пока идут данные
	_http.download_file = pck_path() + ".new"
	_http.request_completed.connect(_on_downloaded)
	if _http.request(BASE_URL + "game.pck") != OK:
		finished.emit()


func _on_downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_http.request_completed.disconnect(_on_downloaded)
	var fresh := pck_path() + ".new"
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 \
			or (_server_sha != "" and FileAccess.get_sha256(fresh) != _server_sha):
		printerr("Tyrants update: download failed (result %d, code %d)" % [result, code])
		DirAccess.remove_absolute(fresh)
		finished.emit()
		return
	_label.text = "RESTARTING..."
	if not _restart_with(fresh):
		DirAccess.remove_absolute(fresh)
		finished.emit()


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
		"move /y \"%s\" \"%s\" >nul" % [fresh.replace("/", "\\"), pck_path().replace("/", "\\")],
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
