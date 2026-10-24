extends SceneTree

## Плавность эффекта HsPlay в реальном времени (не headless): время каждого кадра игры
## за розыгрыш, долгие кадры (>20 мс — с номером кадра эффекта) и пропуски кадров эффекта.
## Первые ~2 с окно прогревается (первые кадры окна дёргаются всегда) — меряем после.
##   Godot --path . --script res://tools/hs_smoothness.gd -- [--card=48426]

var hs: HsPlay
var last := 0
var dts: Array[float] = []
var shown: Array[int] = []


func _initialize() -> void:
	var cid := "48426"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--card="):
			cid = arg.substr(7)
	hs = HsPlay.new()
	hs.size = Vector2(960, 540)
	root.add_child(hs)
	for _i in 150:
		await process_frame
	hs.play(cid, HsPlay.face_of(cid), true, true)
	last = Time.get_ticks_usec()
	process_frame.connect(_tick)


func _tick() -> void:
	var now := Time.get_ticks_usec()
	dts.append((now - last) / 1000.0)
	shown.append(hs._main._shown if hs._main != null else -1)
	last = now
	if dts[-1] > 20.0:
		print("долгий кадр %.1f мс на кадре эффекта %d" % [dts[-1], shown[-1]])
	if not hs.is_ready():
		var over := 0
		var mx := 0.0
		for d in dts:
			mx = maxf(mx, d)
			if d > 25.0:
				over += 1
		var skips := 0
		for i in range(1, shown.size()):
			if shown[i] >= 0 and shown[i - 1] >= 0 and shown[i] - shown[i - 1] > 2:
				skips += 1
		dts.sort()
		print("кадров игры %d, медиана %.1f мс, макс %.1f, >25 мс: %d, скачков эффекта: %d" % [dts.size(), dts[dts.size() / 2], mx, over, skips])
		quit()
