class_name Sfx
extends Node

## Звуки игры. Автозагрузка SfxPlayer (project.godot) держит несколько
## проигрывателей на шине "SFX". Все звуки — файлы из наборов Kenney
## (CC0, assets/sfx/).
##
## Вызов из любого места: Sfx.play("card"). Без автозагрузки (прогон тестов
## скриптом) вызовы ничего не делают. Все кнопки (BaseButton) сами щёлкают
## при нажатии и чуть слышно — при наведении.
##
## Громкость хранится в user://settings.cfg, меняется в меню по Esc.

const BUS := "SFX"
const SETTINGS_PATH := "user://settings.cfg"
const DIR := "res://assets/sfx/"
const VOICES := 8
## Ходы соперника звучат тише своих.
const OTHER_DB := -6.0
## Ступени громкости для кнопки в меню (по кругу).
const LEVELS: Array[float] = [1.0, 0.75, 0.5, 0.25, 0.0]
## Все звуки игры (имя = файл в DIR). Доска: посадка войска и шпиона, удар
## Assassinate, «утонул» при Supplant, фишку сняли с доски (lift), локация
## сменила хозяина. Колокол не использовать (решение владельца, 2026-09-29).
const SOUNDS := [
	"click", "hover", "card", "coins", "error",
	"deploy", "spy", "kill", "sink", "lift", "capture",
	"turn", "victory", "defeat", "last_round",
	"ping", "phrase",
]
## Звуки без разброса высоты.
const STEADY := ["click", "turn", "victory", "defeat"]
## Поправка громкости отдельных звуков (дБ): наведение — еле слышно.
const GAIN_DB := {"hover": -10.0}

static var _instance: Sfx
static var volume := 1.0

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next := 0
## Откуда играть файл (сек): начало удара без тишины перед ним.
static var _starts: Dictionary = {}


## Проиграть звук по имени; quiet — чуть тише (действие соперника).
static func play(sound: String, quiet: bool = false) -> void:
	if _instance != null:
		_instance._play(sound, OTHER_DB if quiet else 0.0)


## Следующая ступень громкости (по кругу), сразу сохраняется.
static func cycle_volume() -> float:
	var i := LEVELS.find(volume)
	set_volume(LEVELS[(i + 1) % LEVELS.size()])
	return volume


static func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	_apply_volume()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "sfx_volume", volume)
	cfg.save(SETTINGS_PATH)


## Подпись для кнопки меню: «SOUND 75%» / «SOUND OFF».
static func volume_label() -> String:
	return "SOUND OFF" if volume <= 0.0 else "SOUND %d%%" % roundi(volume * 100.0)


static func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index(BUS)
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, volume <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))


func _ready() -> void:
	_instance = self
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS)
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		volume = float(cfg.get_value("audio", "sfx_volume", 1.0))
	_apply_volume()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		add_child(p)
		_voices.append(p)
	# У каждого звука одна запись (решение владельца): res://assets/sfx/<name>.ogg.
	for sound: String in SOUNDS:
		var stream: AudioStream = load("%s%s.ogg" % [DIR, sound])
		_streams[sound] = stream
		_starts[stream] = _onset(stream)
	get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func _play(sound: String, db: float) -> void:
	if not _streams.has(sound) or volume <= 0.0:
		return
	var p := _voices[_next]
	_next = (_next + 1) % _voices.size()
	p.stream = _streams[sound]
	p.volume_db = db + float(GAIN_DB.get(sound, 0.0))
	# Лёгкий разброс высоты: один и тот же звук подряд не звучит механически.
	# Кнопка (решение владельца) и мелодии — всегда ровно.
	p.pitch_scale = 1.0 if sound in STEADY else randf_range(0.95, 1.05)
	p.play(_starts.get(p.stream, 0.0))


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button == null:
		return
	button.pressed.connect(func(): play("click"))
	button.mouse_entered.connect(func():
		if not button.disabled:
			play("hover"))



## Где в записи начинается сам звук: первый отсчёт громче 10% пика, минус
## 5 мс, чтобы не срезать атаку. У card-place удар идёт через 0,25–0,4 с
## после начала файла — без этого розыгрыш звучал с задержкой.
static func _onset(stream: AudioStream) -> float:
	var playback := stream.instantiate_playback()
	playback.start(0.0)
	var frames := playback.mix_audio(1.0, int(stream.get_length() * 44100.0))
	playback.stop()
	var peak := 0.0
	for f in frames:
		peak = maxf(peak, absf(f.x))
	for i in frames.size():
		if absf(frames[i].x) > peak * 0.1:
			return maxf(float(i) / 44100.0 - 0.005, 0.0)
	return 0.0

