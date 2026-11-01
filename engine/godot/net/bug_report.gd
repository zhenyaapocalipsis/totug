class_name BugReport
extends RefCounted

## Кнопка BUG REPORT (этап Bug-1, владелец 2026-11-01): отчёт игрока об ошибке.
## Клиент собирает текст, снимок экрана, хвост журнала игры и запись партии,
## кладёт в user://bug_outbox/ и отправляет на сервер, как только есть связь
## (сразу — из меню и онлайн-партии; из хотсита и партии с ботами — при
## возврате в главное меню). Сервер складывает каждый отчёт в свою папку
## user://bug_reports/<дата>_<ник>/: report.txt, screen.jpg, log.txt, game.replay
## (реплей — смотреть, скопировав в user://replays/).

const OUTBOX := "user://bug_outbox/"
const DIR := "user://bug_reports/"
const TEXT_MAX := 2000
const LOG_MAX := 48 * 1024
const SHOT_MAX := 1536 * 1024
const SHOT_WIDTH := 1280
const INTENTS_MAX := 6000
## Сервер: отчётов не больше (старые стираются первыми) и не чаще.
const KEEP_MAX := 300
const PEER_COUNT := 3
const PEER_WINDOW_MS := 10 * 60 * 1000
const IP_COUNT := 20
const IP_WINDOW_MS := 24 * 60 * 60 * 1000


## Клиент: отчёт. where — где нажали (menu, hotseat, bots, online, replay),
## shot — снимок экрана (null — без него), record — {header, intents} локальной
## партии ({} — нет; онлайн запись прикладывает сервер), extra — что ещё
## знает экран (цвет игрока, ход).
static func make(text: String, where: String, shot: Image, record: Dictionary = {},
		extra: Dictionary = {}) -> Dictionary:
	var report := {
		"id": "%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 1000000],
		"text": text.strip_edges().left(TEXT_MAX),
		"name": String(PlayerProfile.load_local().get("name", "")),
		"where": where,
		"build": Updater.own_build(),
		"protocol": NetSession.PROTOCOL,
		"os": "%s %s" % [OS.get_name(), OS.get_version()],
		"window": "%dx%d" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"extra": extra,
		"log": log_tail(),
		"shot": shot_bytes(shot),
		"record": record,
	}
	return report


## Конец журнала игры (user://logs/godot.log) — там ошибки скриптов.
static func log_tail(path: String = "") -> String:
	if path == "":
		path = String(ProjectSettings.get_setting("debug/file_logging/log_path", "user://logs/godot.log"))
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var size := f.get_length()
	f.seek(maxi(0, size - LOG_MAX))
	return f.get_buffer(mini(size, LOG_MAX)).get_string_from_utf8()


## Снимок в JPG не шире SHOT_WIDTH (полный экран 2560 в PNG — несколько МБ).
static func shot_bytes(shot: Image) -> PackedByteArray:
	if shot == null or shot.is_empty():
		return PackedByteArray()
	var image := shot.duplicate() as Image
	if image.get_width() > SHOT_WIDTH:
		image.resize(SHOT_WIDTH, maxi(1, image.get_height() * SHOT_WIDTH / image.get_width()),
			Image.INTERPOLATE_BILINEAR)
	if image.get_format() != Image.FORMAT_RGB8:
		image.convert(Image.FORMAT_RGB8)
	return image.save_jpg_to_buffer(0.85)


# --- клиент: исходящие ------------------------------------------------------

static func queue(report: Dictionary, dir: String = OUTBOX) -> bool:
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir + String(report["id"]) + ".bin", FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(report)
	f.close()
	return true


static func pending(dir: String = OUTBOX) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for name in d.get_files():
		if not name.ends_with(".bin"):
			continue
		var f := FileAccess.open(dir + name, FileAccess.READ)
		var data = f.get_var() if f != null else null
		if typeof(data) == TYPE_DICTIONARY and data.has("id"):
			out.append(data)
		else:
			DirAccess.remove_absolute(dir + name)
	return out


static func done(id: String, dir: String = OUTBOX) -> void:
	if id.is_valid_filename() and FileAccess.file_exists(dir + id + ".bin"):
		DirAccess.remove_absolute(dir + id + ".bin")


# --- сервер -----------------------------------------------------------------

## Отчёт от клиента — только знакомые поля нужных типов и не больше пределов;
## {} — мусор.
static func clean(data: Dictionary) -> Dictionary:
	var id = data.get("id", "")
	if typeof(id) != TYPE_STRING or id == "" or id.length() > 40 or not id.is_valid_filename():
		return {}
	var out := {"id": id}
	for key in ["text", "where", "os", "window", "log"]:
		var v = data.get(key, "")
		out[key] = String(v).left(LOG_MAX if key == "log" else TEXT_MAX) if typeof(v) == TYPE_STRING else ""
	for key in ["build", "protocol"]:
		out[key] = int(data.get(key, 0)) if typeof(data.get(key, 0)) == TYPE_INT else 0
	var extra = data.get("extra", {})
	out["extra"] = JSON.stringify(extra).left(TEXT_MAX) if typeof(extra) == TYPE_DICTIONARY else ""
	var shot = data.get("shot", PackedByteArray())
	out["shot"] = shot if typeof(shot) == TYPE_PACKED_BYTE_ARRAY and shot.size() <= SHOT_MAX \
		else PackedByteArray()
	var record = data.get("record", {})
	out["record"] = {}
	if typeof(record) == TYPE_DICTIONARY and typeof(record.get("header")) == TYPE_DICTIONARY \
			and typeof(record.get("intents")) == TYPE_ARRAY and record["intents"].size() <= INTENTS_MAX:
		out["record"] = {"header": record["header"], "intents": record["intents"]}
	return out


## Сохранить отчёт в свою папку. who — ник отправителя, room — код комнаты
## ("" — не в партии). Возвращает имя папки ("" — не вышло).
static func store(report: Dictionary, who: String, room: String, dir: String = DIR) -> String:
	var now := int(Time.get_unix_time_from_system())
	var stamp := Time.get_datetime_string_from_unix_time(now).replace(":", "").replace("-", "").replace("T", "_")
	var nick := PlayerProfile.clean_name(who).validate_filename().replace(" ", "_")
	var folder := "%s_%s_%s" % [stamp, nick if nick != "" else "player", String(report["id"]).right(6)]
	var path := dir + folder + "/"
	if DirAccess.make_dir_recursive_absolute(path) != OK:
		return ""
	var lines := PackedStringArray([
		"date: %s UTC" % Time.get_datetime_string_from_unix_time(now, true),
		"player: %s" % who,
		"where: %s" % report["where"],
		"room: %s" % room,
		"build: %d  protocol: %d" % [report["build"], report["protocol"]],
		"os: %s  window: %s" % [report["os"], report["window"]],
		"extra: %s" % report["extra"],
		"",
		String(report["text"]),
	])
	_write(path + "report.txt", "\n".join(lines))
	if not report["log"].is_empty():
		_write(path + "log.txt", report["log"])
	if not report["shot"].is_empty():
		var f := FileAccess.open(path + "screen.jpg", FileAccess.WRITE)
		if f != null:
			f.store_buffer(report["shot"])
	var record: Dictionary = report["record"]
	if not record.is_empty():
		ReplayBook.save(record["header"], record["intents"], path, "game" + ReplayBook.EXT)
	return folder


static func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)


## Сервер: папок отчётов не больше max_folders, старые стираются первыми.
static func prune(dir: String = DIR, max_folders: int = KEEP_MAX) -> int:
	var d := DirAccess.open(dir)
	if d == null:
		return 0
	var names := Array(d.get_directories())
	names.sort()
	names.reverse()
	var removed := 0
	for i in range(max_folders, names.size()):
		var sub := dir + String(names[i]) + "/"
		var s := DirAccess.open(sub)
		if s != null:
			for f in s.get_files():
				DirAccess.remove_absolute(sub + f)
		DirAccess.remove_absolute(sub)
		removed += 1
	return removed
