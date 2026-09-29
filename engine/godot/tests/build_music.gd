extends SceneTree

## Собирает фоновую музыку: один зацикленный трек из четырёх слоёв (pad,
## bass, lead, drums) одинаковой длины. Слои играют синхронно, а Music
## (scenes/music.gd) плавно включает и глушит их по ходу партии — приём
## музыки Balatro: мелодия не обрывается, меняется только «наполнение».
##
##   godot --headless --path . --script res://tests/build_music.gd
##
## Пишет res://assets/music/<слой>.wav; после сборки нужен --import.
##
## Ре минор, 92 удара в минуту, 8 тактов: Dm9 | Bbmaj7 | Gm7 | A7(b9) ×2.
## Всё слегка «плавает» по высоте, как магнитофонная лента (WOW_*): отсюда
## тёплый ламповый звук. Хвосты нот в конце цикла заворачиваются в начало,
## поэтому стык петли не слышен.

const OUT := "res://assets/music/"
const RATE := 22050
const BPM := 92.0
const BEAT := 60.0 / BPM
const BEATS := 32
## «Плавание ленты»: глубина (доля частоты) и сколько колебаний на петлю.
const WOW_DEPTH := 0.0025
const WOW_CYCLES := 5.0

## Аккорды по тактам (MIDI), голоса близко друг к другу — без скачков.
const CHORDS := [
	[53, 57, 60, 64],  # Dm9: F A C E
	[53, 57, 58, 62],  # Bbmaj7: F A Bb D
	[50, 53, 55, 58],  # Gm7: D F G Bb
	[49, 52, 55, 58],  # A7(b9): C# E G Bb
]
const ROOTS := [38, 34, 43, 45]  # D2, Bb1, G2, A2
## Удары аккорда в такте: [доля, длина в долях].
const PAD_HITS := [[0.0, 1.4], [1.5, 0.5], [2.5, 1.5]]
## Мелодия на 8 тактов: [доля, длина, MIDI].
const LEAD := [
	[0.0, 0.5, 69], [0.5, 0.5, 72], [1.0, 1.0, 74], [2.5, 0.5, 76], [3.0, 1.0, 77],
	[4.0, 1.5, 76], [5.5, 0.5, 74], [6.0, 2.0, 69],
	[8.0, 0.5, 70], [8.5, 0.5, 72], [9.0, 1.0, 74], [10.5, 0.5, 77], [11.0, 1.0, 74],
	[12.0, 1.0, 73], [13.0, 0.5, 76], [13.5, 0.5, 79], [14.0, 2.0, 76],
	[16.0, 0.5, 81], [16.5, 0.5, 79], [17.0, 1.0, 77], [18.5, 0.5, 76], [19.0, 1.0, 74],
	[20.0, 1.0, 77], [21.0, 1.0, 76], [22.0, 0.5, 74], [22.5, 1.5, 72],
	[24.0, 0.5, 70], [24.5, 0.5, 74], [25.0, 1.0, 77], [26.5, 0.5, 79], [27.0, 1.0, 77],
	[28.0, 1.5, 76], [29.5, 0.5, 73], [30.0, 1.0, 70], [31.0, 1.0, 69],
]

var _n := int(round(BEATS * BEAT * RATE))
var _wow_hz := WOW_CYCLES / (float(_n) / RATE)
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 92
	var stems := {
		"pad": _pad(),
		"bass": _bass(),
		"lead": _echo(_lead(), 0.75, 0.3),
		"drums": _drums(),
	}
	# Общий масштаб: все слои вместе не должны зашкаливать.
	var peak := 0.0
	for i in _n:
		var s := 0.0
		for name: String in stems:
			s += (stems[name] as PackedFloat32Array)[i]
		peak = maxf(peak, absf(s))
	var gain := 0.85 / peak
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for name: String in stems:
		_save(stems[name], gain, OUT + name + ".wav")
	print("музыка: %d слоя по %.2f с, общий пик %.2f -> x%.2f" % [stems.size(), float(_n) / RATE, peak, gain])
	quit()


static func _midi(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


## Множитель частоты «плавающей ленты» в момент t (с начала петли).
func _wow(t: float) -> float:
	return 1.0 + WOW_DEPTH * sin(TAU * _wow_hz * t)


func _empty() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_n)
	return out


## Электропиано (FM: синус, модулирующий сам себя; яркость атаки гаснет).
func _pad() -> PackedFloat32Array:
	var out := _empty()
	for bar in BEATS / 4:
		for hit: Array in PAD_HITS:
			for m: int in CHORDS[bar % 4]:
				_epiano(out, bar * 4 + float(hit[0]), float(hit[1]), _midi(m), 0.11)
	return out


func _epiano(out: PackedFloat32Array, beat: float, length: float, f: float, gain: float) -> void:
	var s0 := int(beat * BEAT * RATE)
	var dur := length * BEAT
	var ph := 0.0
	for i in int((dur + 0.4) * RATE):
		var t := float(i) / RATE
		ph += TAU * f * _wow(float(s0 + i) / RATE) / RATE
		var index := 1.4 * exp(-t * 3.0) + 0.2
		var env := minf(t * 200.0, 1.0) * exp(-t * 1.6)
		if t > dur:
			env *= exp(-(t - dur) * 14.0)
		out[(s0 + i) % _n] += sin(ph + index * sin(ph)) * env * gain


## Бас: корень, октава, квинта и подход к следующему корню — с «прыгом».
func _bass() -> PackedFloat32Array:
	var out := _empty()
	for bar in BEATS / 4:
		var root: int = ROOTS[bar % 4]
		var next: int = ROOTS[(bar + 1) % 4]
		var approach := next + (1 if next < root else -1)
		var b := bar * 4.0
		for note: Array in [[0.0, 0.9, root], [1.5, 0.4, root + 12], [2.0, 0.9, root + 7],
				[3.0, 0.4, root], [3.5, 0.4, approach]]:
			_bass_note(out, b + float(note[0]), float(note[1]), _midi(int(note[2])), 0.18)
	return out


func _bass_note(out: PackedFloat32Array, beat: float, length: float, f: float, gain: float) -> void:
	var s0 := int(beat * BEAT * RATE)
	var dur := length * BEAT
	var ph := 0.0
	for i in int((dur + 0.05) * RATE):
		var t := float(i) / RATE
		ph += TAU * f * _wow(float(s0 + i) / RATE) / RATE
		var env := minf(t * 200.0, 1.0) * exp(-t * 1.2)
		if t > dur:
			env *= exp(-(t - dur) * 60.0)
		var v := sin(ph) + 0.35 * sin(2.0 * ph) + 0.15 * sin(3.0 * ph)
		out[(s0 + i) % _n] += tanh(v * 1.5) * env * gain


## Мелодия: треугольник с узким прямоугольником, смягчённые фильтром, и
## вибрато, которое вступает на длинных нотах.
func _lead() -> PackedFloat32Array:
	var out := _empty()
	for note: Array in LEAD:
		_lead_note(out, float(note[0]), float(note[1]), _midi(int(note[2])), 0.26)
	return out


func _lead_note(out: PackedFloat32Array, beat: float, length: float, f: float, gain: float) -> void:
	var s0 := int(beat * BEAT * RATE)
	var dur := length * BEAT
	var ph := 0.0
	var y := 0.0
	for i in int((dur + 0.12) * RATE):
		var t := float(i) / RATE
		var vib := 1.0 + 0.006 * sin(TAU * 5.5 * t) * clampf((t - 0.2) * 4.0, 0.0, 1.0)
		ph += f * vib * _wow(float(s0 + i) / RATE) / RATE
		var frac := fmod(ph, 1.0)
		var x := 0.6 * (2.0 * absf(2.0 * frac - 1.0) - 1.0) + 0.25 * (1.0 if frac < 0.3 else -1.0)
		y += 0.3 * (x - y)
		var env := minf(t * 125.0, 1.0) * (0.6 + 0.4 * exp(-t * 3.0))
		if t > dur:
			env *= exp(-(t - dur) * 40.0)
		out[(s0 + i) % _n] += y * env * gain


## Эхо по кругу петли: delay_beats — задержка в долях, feedback — сколько
## возвращается. Два прохода — чтобы эхо с конца петли легло и на начало.
func _echo(dry: PackedFloat32Array, delay_beats: float, feedback: float) -> PackedFloat32Array:
	var d := int(delay_beats * BEAT * RATE)
	var out := dry.duplicate()
	for _pass in 2:
		for i in _n:
			out[i] = dry[i] + feedback * out[(i - d + _n) % _n]
	return out


## Ударные: бочка, хлопок на 2 и 4, тихие хэты восьмыми.
func _drums() -> PackedFloat32Array:
	var out := _empty()
	for bar in BEATS / 4:
		var b := bar * 4.0
		for k: float in [0.0, 1.75, 2.5]:
			_kick(out, b + k)
		for s: float in [1.0, 3.0]:
			_snare(out, b + s)
		for h in 8:
			_hat(out, b + h * 0.5, 0.05 if h % 2 == 1 else 0.03)
	return out


func _kick(out: PackedFloat32Array, beat: float) -> void:
	var s0 := int(beat * BEAT * RATE)
	var ph := 0.0
	for i in int(0.3 * RATE):
		var t := float(i) / RATE
		ph += TAU * (45.0 + 75.0 * exp(-t * 30.0)) / RATE
		out[(s0 + i) % _n] += sin(ph) * exp(-t * 14.0) * 0.5


func _snare(out: PackedFloat32Array, beat: float) -> void:
	var s0 := int(beat * BEAT * RATE)
	var prev := 0.0
	for i in int(0.25 * RATE):
		var t := float(i) / RATE
		var noise := _rng.randf_range(-1.0, 1.0)
		var bright := noise - prev
		prev = noise
		var v := bright * 0.5 * exp(-t * 22.0) + sin(TAU * 185.0 * t) * 0.4 * exp(-t * 30.0)
		out[(s0 + i) % _n] += v * 0.22


func _hat(out: PackedFloat32Array, beat: float, gain: float) -> void:
	var s0 := int(beat * BEAT * RATE)
	var prev := 0.0
	for i in int(0.06 * RATE):
		var t := float(i) / RATE
		var noise := _rng.randf_range(-1.0, 1.0)
		out[(s0 + i) % _n] += (noise - prev) * exp(-t * 80.0) * gain
		prev = noise


func _save(samples: PackedFloat32Array, gain: float, path: String) -> void:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	wav.save_to_wav(ProjectSettings.globalize_path(path))
