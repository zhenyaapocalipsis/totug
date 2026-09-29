class_name Music
extends Node

## Фоновая музыка по образцу Balatro: пять версий одной композиции
## (assets/music/music1…5.ogg, одной длины, зациклены) играют одновременно и
## вровень, а слышна та, что подходит к настроению партии; при смене
## настроения версии плавно перетекают друг в друга, и мелодия не начинается
## заново. В меню по Esc музыка уходит «за стену» (фильтр срезает верха).
##
## Автозагрузка MusicPlayer (project.godot). Вызовы: Music.set_mood("turn"),
## Music.set_muffled(true). Без автозагрузки (тесты) ничего не делают.
##
## Громкость хранится в user://settings.cfg, меняется в меню по Esc.

const BUS := "Music"
const DIR := "res://assets/music/"
const TRACKS := ["music1", "music2", "music3", "music4", "music5"]
## Какая версия звучит при каком настроении.
const MOODS := {
	"menu": "music1",     # главное меню
	"turn": "music1",     # мой ход — основная версия
	"wait": "music4",     # ход соперника — спокойнее
	"tension": "music5",  # последний круг — самая напряжённая
	"end": "music2",      # итоги партии
}
## За сколько секунд версии перетекают друг в друга.
const FADE := 1.5
## Музыка тише звуков: общий уровень шины при громкости 100%.
const MIX_DB := -8.0
const SILENT_DB := -60.0
## Срез фильтра: обычный и «за стеной».
const OPEN_HZ := 20000.0
const MUFFLED_HZ := 700.0
const LEVELS: Array[float] = [1.0, 0.75, 0.5, 0.25, 0.0]

static var _instance: Music
static var volume := 1.0

## По проигрывателю на версию. Запущены в одном кадре и одной длины — идут
## вровень.
var _players: Array[AudioStreamPlayer] = []
var _levels: Array[float] = []
var _targets: Array[float] = []
var _mood := ""
var _muffled := false
var _lowpass: AudioEffectLowPassFilter


static func set_mood(mood: String) -> void:
	if _instance != null and MOODS.has(mood) and mood != _instance._mood:
		_instance._mood = mood
		for i in TRACKS.size():
			_instance._targets[i] = 1.0 if TRACKS[i] == MOODS[mood] else 0.0


static func set_muffled(muffled: bool) -> void:
	if _instance != null:
		_instance._muffled = muffled


static func mood() -> String:
	return _instance._mood if _instance != null else ""


static func cycle_volume() -> float:
	var i := LEVELS.find(volume)
	set_volume(LEVELS[(i + 1) % LEVELS.size()])
	return volume


static func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	_apply_volume()
	var cfg := ConfigFile.new()
	cfg.load(Sfx.SETTINGS_PATH)
	cfg.set_value("audio", "music_volume", volume)
	cfg.save(Sfx.SETTINGS_PATH)


static func volume_label() -> String:
	return "MUSIC OFF" if volume <= 0.0 else "MUSIC %d%%" % roundi(volume * 100.0)


static func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index(BUS)
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, volume <= 0.0)
	AudioServer.set_bus_volume_db(bus, MIX_DB + linear_to_db(maxf(volume, 0.0001)))


func _ready() -> void:
	_instance = self
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		var bus := AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, BUS)
		# Фильтр для меню по Esc.
		_lowpass = AudioEffectLowPassFilter.new()
		_lowpass.cutoff_hz = OPEN_HZ
		AudioServer.add_bus_effect(bus, _lowpass)
	var cfg := ConfigFile.new()
	if cfg.load(Sfx.SETTINGS_PATH) == OK:
		volume = float(cfg.get_value("audio", "music_volume", 1.0))
	_apply_volume()

	for track: String in TRACKS:
		var player := AudioStreamPlayer.new()
		player.stream = load("%s%s.ogg" % [DIR, track])
		player.bus = BUS
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)
		_levels.append(0.0)
		_targets.append(0.0)
	for player in _players:
		player.play()
	set_mood("menu")


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func _process(delta: float) -> void:
	# Настоящее время, а не игровое: стоп-кадр (time_scale) музыку не тормозит.
	var step := delta / maxf(Engine.time_scale, 0.01) / FADE
	for i in _levels.size():
		if _levels[i] != _targets[i]:
			_levels[i] = move_toward(_levels[i], _targets[i], step)
			_players[i].volume_db = maxf(linear_to_db(_levels[i]), SILENT_DB)
	if _lowpass != null:
		var target := MUFFLED_HZ if _muffled else OPEN_HZ
		# Плавно, по логарифму частоты: на слух это равномерно.
		var now := log(_lowpass.cutoff_hz)
		_lowpass.cutoff_hz = exp(move_toward(now, log(target), step * 4.0))
