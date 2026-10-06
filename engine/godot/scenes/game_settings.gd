extends RefCounted

## Настройки игры (меню SETTINGS и SETTINGS в меню по Esc): общая громкость,
## экран, клавиши и игровые мелочи. Громкость звуков и музыки — у Sfx и
## Music, всё хранится в одном файле user://settings.cfg.
##
## Подключается файлом (preload), без class_name: глобальные имена собирает
## редактор, а проект часто запускается из командной строки.

const PATH := "user://settings.cfg"

## Клавиши, которые можно переназначить (владелец, 2026-10-06). Esc — всегда
## меню, его не трогаем.
const ACTIONS: Array[String] = ["ping", "end_turn", "zoom", "fullscreen"]
const DEFAULT_KEYS := {"ping": KEY_TAB, "end_turn": KEY_SPACE, "zoom": KEY_ALT, "fullscreen": KEY_F11}
const ACTION_TITLES := {
	"ping": "PING / CHAT WHEEL",
	"end_turn": "END TURN (HOLD)",
	"zoom": "ENLARGE CARD (HOLD)",
	"fullscreen": "FULL SCREEN",
}

## Экран: окно, во весь экран (без рамки) или монопольно (exclusive).
const WINDOW_MODES: Array[String] = ["window", "full", "exclusive"]
const WINDOW_TITLES := {"window": "WINDOW", "full": "FULL SCREEN", "exclusive": "EXCLUSIVE"}
## Предел кадров в секунду; 0 — без предела.
const FPS_LIMITS: Array[int] = [30, 60, 120, 144, 240, 0]
## Сколько секунд держать клавишу конца хода.
const HOLD_STEPS: Array[float] = [1.0, 2.0, 3.0, 5.0]
## Скорость анимаций партии (Engine.time_scale; таймеры идут по настоящему
## времени).
const SPEED_STEPS: Array[float] = [1.0, 1.5, 2.0]

## Что лежит в файле по умолчанию: [раздел, ключ, значение].
const DEFAULTS := {
	"master_volume": ["audio", 1.0],
	"window_mode": ["video", "full"],
	"vsync": ["video", true],
	"max_fps": ["video", 0],
	"show_fps": ["video", false],
	"hold_seconds": ["game", 3.0],
	"anim_speed": ["game", 1.0],
	"move_hints": ["game", true],
}

static var _cfg: ConfigFile
## Тесты пишут в свой файл, не трогая настройки игрока.
static var path_override := ""


static func path() -> String:
	return path_override if path_override != "" else PATH


static func _file() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(path())
	return _cfg


static func value(name: String) -> Variant:
	var d: Array = DEFAULTS[name]
	return _file().get_value(String(d[0]), name, d[1])


static func set_value(name: String, v: Variant) -> void:
	var d: Array = DEFAULTS[name]
	# Sfx и Music пишут в тот же файл — сперва перечитать, чтобы не затереть.
	_file().load(path())
	_cfg.set_value(String(d[0]), name, v)
	_cfg.save(path())
	_apply(name)


## Следующее значение из списка steps (по кругу).
static func cycle(name: String, steps: Array) -> Variant:
	var i := steps.find(value(name))
	set_value(name, steps[(i + 1) % steps.size()])
	return value(name)


static func hold_seconds() -> float:
	return float(value("hold_seconds"))


static func anim_speed() -> float:
	return float(value("anim_speed"))


static func move_hints() -> bool:
	return bool(value("move_hints"))


# --- клавиши -------------------------------------------------------------------

static func key(action: String) -> int:
	return int(_file().get_value("keys", action, DEFAULT_KEYS[action]))


## Назначить клавишу. Если она уже у другого действия — они меняются местами.
static func set_key(action: String, keycode: int) -> void:
	var old := key(action)
	_file().load(path())
	for other: String in ACTIONS:
		if other != action and key(other) == keycode:
			_cfg.set_value("keys", other, old)
	_cfg.set_value("keys", action, keycode)
	_cfg.save(path())


static func reset_keys() -> void:
	_file().load(path())
	if _cfg.has_section("keys"):
		_cfg.erase_section("keys")
	_cfg.save(path())


static func key_name(action: String) -> String:
	return OS.get_keycode_string(key(action)).to_upper()


## Нажата ли клавиша действия (по коду клавиши или по физической).
static func is_key(event: InputEventKey, action: String) -> bool:
	var k := key(action)
	return event.keycode == k or (event.keycode == KEY_NONE and event.physical_keycode == k)


## Зажата ли клавиша-модификатор действия по флагу события (Alt, Shift, Ctrl
## приходят флагом и на движении мыши). null — клавиша не модификатор.
static func modifier_held(event: InputEventWithModifiers, action: String) -> Variant:
	match key(action):
		KEY_ALT:
			return event.alt_pressed
		KEY_SHIFT:
			return event.shift_pressed
		KEY_CTRL:
			return event.ctrl_pressed
	return null


# --- применение ------------------------------------------------------------------

## Всё сразу — при запуске игры (WindowKeys).
static func apply_all() -> void:
	for name: String in DEFAULTS:
		_apply(name)


static func _apply(name: String) -> void:
	match name:
		"master_volume":
			var v := float(value(name))
			AudioServer.set_bus_mute(0, v <= 0.0)
			AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))
		"window_mode":
			if DisplayServer.get_name() == "headless":
				return
			var mode := DisplayServer.WINDOW_MODE_FULLSCREEN
			match String(value(name)):
				"window":
					mode = DisplayServer.WINDOW_MODE_WINDOWED
				"exclusive":
					mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
			if DisplayServer.window_get_mode() != mode:
				DisplayServer.window_set_mode(mode)
		"vsync":
			if DisplayServer.get_name() != "headless":
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(value(name))
					else DisplayServer.VSYNC_DISABLED)
		"max_fps":
			Engine.max_fps = int(value(name))


## Экран сейчас (F11 переключает и мимо настроек).
static func window_mode_now() -> String:
	match DisplayServer.window_get_mode():
		DisplayServer.WINDOW_MODE_FULLSCREEN:
			return "full"
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			return "exclusive"
	return "window"


static func on_off(v: bool) -> String:
	return "ON" if v else "OFF"


static func fps_label(fps: int) -> String:
	return "NO LIMIT" if fps <= 0 else str(fps)


static func seconds_label(s: float) -> String:
	return "%s S" % (str(int(s)) if s == floorf(s) else str(s))


static func speed_label(s: float) -> String:
	return "x%s" % (str(int(s)) if s == floorf(s) else str(s))
