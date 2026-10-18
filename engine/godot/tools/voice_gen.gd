extends SceneTree

## Озвучка реплик карт через ElevenLabs (text-to-speech API): берёт строки из
## res://data/voice_lines.json и пишет res://assets/voice/<card_id>.mp3.
## Ключ — из переменной окружения ELEVENLABS_API_KEY (в файлы и вывод не попадает).
##   Godot --headless --path . --script res://tools/voice_gen.gd -- --card=48426
##   ... -- --all            все реплики, у которых ещё нет файла (--force — заново)
##   ... -- --list           голоса аккаунта (имя, id, описание)
##   ... -- --sfx=all        звуки постановок из data/fx_sounds.json -> assets/sfx/fx/
##   ... -- --card=48426 --take=2 --voice=George   ещё вариант (другим голосом): 48426_take2.mp3
## Если модель eleven_v3 недоступна, реплика повторяется на eleven_multilingual_v2
## (без тегов в квадратных скобках).

const LINES := "res://data/voice_lines.json"
const OUT := "res://assets/voice/"
const SFX_LINES := "res://data/fx_sounds.json"
const SFX_OUT := "res://assets/sfx/fx/"
const API := "https://api.elevenlabs.io"

## Стандартные голоса ElevenLabs (есть у любого аккаунта): имя -> id.
const KNOWN := {
	"callum": "N2lVS1w4EtoT3dr4eOWO",
	"george": "JBFqnCBsd6RMkjVDRZzb",
	"bill": "pqHfZKP75CvOlQylNhV4",
	"brian": "nPczCjzI2devNBz1zQrb",
	"daniel": "onwK4e9ZLuTAKqWW03F9",
	"clyde": "2EiwWnXFnvU5JabPnv8n",
}

var _key := ""
var _voices: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _arg(name: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + name:
			return "1"
		if a.begins_with("--%s=" % name):
			return a.substr(a.find("=") + 1)
	return ""


## Запрос через системный curl (HTTPRequest Godot терял POST на перенаправлении):
## тело и ответ — через временные файлы, ключ — только в заголовке. -> [код, байты].
func _request(url: String, method: int, body: String = "") -> Array:
	var tmp := OS.get_user_data_dir() + "/voice_gen_"
	var args := PackedStringArray(["-s", "-L", "-w", "%{http_code}", "-o", tmp + "out.bin",
		"-H", "xi-api-key: " + _key, "-H", "Content-Type: application/json", url])
	if method == HTTPClient.METHOD_POST:
		var f := FileAccess.open(tmp + "body.json", FileAccess.WRITE)
		f.store_string(body)
		f.close()
		args.append_array(["-X", "POST", "--data-binary", "@" + tmp + "body.json"])
	var out: Array = []
	OS.execute("curl", args, out, true)
	var code := int(String(out[0]).strip_edges().right(3)) if not out.is_empty() else 0
	var data := FileAccess.get_file_as_bytes(tmp + "out.bin")
	DirAccess.remove_absolute(tmp + "out.bin")
	DirAccess.remove_absolute(tmp + "body.json")
	return [code, data]


func _run() -> void:
	_key = OS.get_environment("ELEVENLABS_API_KEY").strip_edges()
	if _key == "":
		printerr("нет ключа: задайте переменную окружения ELEVENLABS_API_KEY")
		quit(1)
		return
	if _arg("sfx") != "":
		await _make_sfx(_arg("sfx"))
		quit()
		return
	_voices = KNOWN.duplicate()
	# список голосов аккаунта — если у ключа есть право voices_read; иначе хватит KNOWN
	var got := await _request(API + "/v1/voices", HTTPClient.METHOD_GET)
	var vj: Variant = JSON.parse_string((got[1] as PackedByteArray).get_string_from_utf8()) if int(got[0]) == 200 else null
	if not vj is Dictionary:
		print("список голосов недоступен (код %d) — беру известные: %s" % [got[0], ", ".join(KNOWN.keys())])
		vj = {}
	for v: Dictionary in (vj as Dictionary).get("voices", []):
		_voices[String(v["name"]).to_lower()] = String(v["voice_id"])
		if _arg("list") != "":
			var labels: Dictionary = v.get("labels", {})
			print("%-22s %s  %s" % [v["name"], v["voice_id"], ", ".join(labels.values())])
	if _arg("list") != "":
		quit()
		return
	var lines: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LINES))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var ids: Array = []
	if _arg("card") != "":
		ids = [_arg("card")]
	elif _arg("all") != "":
		for cid: String in lines:
			if not cid.begins_with("_"):
				ids.append(cid)
	var made := 0
	for cid: String in ids:
		if not lines.has(cid):
			printerr("%s: нет строки в voice_lines.json" % cid)
			continue
		var take := _arg("take")
		var name := cid if take == "" else "%s_take%s" % [cid, take]
		var path := ProjectSettings.globalize_path(OUT + name + ".mp3")
		if FileAccess.file_exists(path) and _arg("force") == "" and _arg("card") == "":
			continue
		if await _make(lines[cid], path):
			made += 1
			print("%s: %s" % [name, path])
	print("готово: %d" % made)
	quit()


## Одна реплика -> mp3. Сначала заданная модель, при отказе — multilingual_v2 без тегов.
func _make(line: Dictionary, path: String) -> bool:
	var voice := _arg("voice") if _arg("voice") != "" else String(line.get("voice", "Callum"))
	var vid: String = _voices.get(voice.to_lower(), voice)
	var models := [String(line.get("model", "eleven_v3"))]
	if models[0] != "eleven_multilingual_v2":
		models.append("eleven_multilingual_v2")
	for model: String in models:
		var text := String(line["text"])
		if model != "eleven_v3":
			text = _strip_tags(text)
		var body := JSON.stringify({"text": text, "model_id": model,
			"voice_settings": line.get("settings", {})})
		var got := await _request("%s/v1/text-to-speech/%s?output_format=mp3_44100_128" % [API, vid],
			HTTPClient.METHOD_POST, body)
		var data: PackedByteArray = got[1]
		if int(got[0]) == 200 and data.size() > 1000:
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_buffer(data)
			f.close()
			print("модель %s, голос %s" % [model, voice])
			return true
		printerr("%s: код %d: %s" % [model, got[0], data.get_string_from_utf8().left(300)])
	return false


static func _strip_tags(text: String) -> String:
	var re := RegEx.create_from_string("\\[[^\\]]*\\]\\s*")
	return re.sub(text, "", true).strip_edges()


## Звуки постановок (ElevenLabs sound-generation): data/fx_sounds.json ->
## assets/sfx/fx/<имя>.mp3; which — имя или all (all пропускает готовые без --force).
## --take=N пишет вариант <имя>_takeN.mp3 рядом.
func _make_sfx(which: String) -> void:
	var sounds: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SFX_LINES))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SFX_OUT))
	var names: Array = []
	for n: String in sounds:
		if not n.begins_with("_") and (which == "all" or which == n):
			names.append(n)
	var made := 0
	for n: String in names:
		var take := _arg("take")
		var file := n if take == "" else "%s_take%s" % [n, take]
		var path := ProjectSettings.globalize_path(SFX_OUT + file + ".mp3")
		if FileAccess.file_exists(path) and which == "all" and _arg("force") == "":
			continue
		var s: Dictionary = sounds[n]
		var body := JSON.stringify({"text": s["text"], "duration_seconds": float(s.get("duration", 2.0)),
			"prompt_influence": float(s.get("influence", 0.5))})
		var got := await _request(API + "/v1/sound-generation?output_format=mp3_44100_128", HTTPClient.METHOD_POST, body)
		var data: PackedByteArray = got[1]
		if int(got[0]) == 200 and data.size() > 1000:
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_buffer(data)
			f.close()
			made += 1
			print("%s: %s" % [file, path])
		else:
			printerr("%s: код %d: %s" % [n, got[0], data.get_string_from_utf8().left(300)])
	print("готово: %d" % made)
