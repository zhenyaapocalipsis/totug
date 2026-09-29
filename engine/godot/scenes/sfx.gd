class_name Sfx
extends Node

## Звуки игры. Автозагрузка SfxPlayer (project.godot) держит несколько
## проигрывателей на шине "SFX". Основные звуки — файлы из наборов Kenney
## (CC0, assets/sfx/), а писк наведения и гудение отказа синтезируются
## при запуске.
##
## Вызов из любого места: Sfx.play("card"). Без автозагрузки (прогон тестов
## скриптом) вызовы ничего не делают. Все кнопки (BaseButton) сами щёлкают
## при нажатии и чуть слышно — при наведении.
##
## Громкость хранится в user://settings.cfg, меняется в меню по Esc.

const BUS := "SFX"
const SETTINGS_PATH := "user://settings.cfg"
const DIR := "res://assets/sfx/"
const RATE := 22050
const VOICES := 8
## Ходы соперника звучат тише своих.
const OTHER_DB := -6.0
## Ступени громкости для кнопки в меню (по кругу).
const LEVELS: Array[float] = [1.0, 0.75, 0.5, 0.25, 0.0]

static var _instance: Sfx
static var volume := 1.0

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next := 0


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
	# У звука может быть несколько вариантов — играет случайный.
	_streams = {
		"click": _files("click", 1),
		"hover": [_wav(_hover())],
		"card": _files("card", 4),
		"coins": _files("coins", 2),
		"error": [_wav(_buzz())],
	}
	get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func _play(sound: String, db: float) -> void:
	if not _streams.has(sound) or volume <= 0.0:
		return
	var p := _voices[_next]
	_next = (_next + 1) % _voices.size()
	p.stream = (_streams[sound] as Array).pick_random()
	p.volume_db = db
	# Лёгкий разброс высоты: один и тот же звук подряд не звучит механически.
	# Кнопка — всегда ровно (решение владельца).
	p.pitch_scale = 1.0 if sound == "click" else randf_range(0.95, 1.05)
	p.play()


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button == null:
		return
	button.pressed.connect(func(): play("click"))
	button.mouse_entered.connect(func():
		if not button.disabled:
			play("hover"))


## Варианты звука из файлов: res://assets/sfx/<name>_1.ogg … _<count>.ogg.
static func _files(name: String, count: int) -> Array:
	var out := []
	for i in range(1, count + 1):
		out.append(load("%s%s_%d.ogg" % [DIR, name, i]))
	return out


# --- Синтез -------------------------------------------------------------

static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


static func _buffer(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	return out


static func _square(phase: float) -> float:
	return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0


## Наведение: едва слышный высокий писк.
static func _hover() -> PackedFloat32Array:
	var out := _buffer(0.02)
	for i in out.size():
		var t := float(i) / RATE
		out[i] = sin(TAU * 1900.0 * t) * exp(-t * 200.0) * 0.08
	return out


## Отказ: низкое гудение с падающим тоном.
static func _buzz() -> PackedFloat32Array:
	var out := _buffer(0.16)
	for i in out.size():
		var t := float(i) / RATE
		var env := minf(t * 200.0, 1.0) * exp(-t * 12.0)
		out[i] = _square(t * (120.0 - 80.0 * t)) * env * 0.2
	return out
