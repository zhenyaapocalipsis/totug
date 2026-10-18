extends SceneTree

## Озвучка реплик карт через ElevenLabs (text-to-speech API): берёт строки из
## res://data/voice_lines.json и пишет res://assets/voice/<card_id>.mp3.
## Ключ — из переменной окружения ELEVENLABS_API_KEY (в файлы и вывод не попадает).
##   Godot --headless --path . --script res://tools/voice_gen.gd -- --card=48426
##   ... -- --all            все реплики, у которых ещё нет файла (--force — заново)
##   ... -- --list           голоса аккаунта (имя, id, описание)
##   ... -- --card=48426 --take=2   ещё один вариант рядом: 48426_take2.mp3
## Если модель eleven_v3 недоступна, реплика повторяется на eleven_multilingual_v2
## (без тегов в квадратных скобках).

const LINES := "res://data/voice_lines.json"
const OUT := "res://assets/voice/"
const API := "https://api.elevenlabs.io"

var _key := ""
var _http: HTTPRequest
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


func _request(url: String, method: int, body: String = "") -> Array:
	var headers := PackedStringArray(["xi-api-key: " + _key, "Content-Type: application/json",
		"Accept: application/json, audio/mpeg"])
	var err := _http.request(url, headers, method, body)
	if err != OK:
		return [0, PackedByteArray()]
	var res: Array = await _http.request_completed
	return [int(res[1]), res[3] as PackedByteArray]


func _run() -> void:
	_key = OS.get_environment("ELEVENLABS_API_KEY").strip_edges()
	if _key == "":
		printerr("нет ключа: задайте переменную окружения ELEVENLABS_API_KEY")
		quit(1)
		return
	_http = HTTPRequest.new()
	_http.timeout = 120.0
	root.add_child(_http)
	var got := await _request(API + "/v1/voices", HTTPClient.METHOD_GET)
	if int(got[0]) != 200:
		printerr("голоса не получены, код %d: %s" % [got[0], (got[1] as PackedByteArray).get_string_from_utf8().left(300)])
		quit(1)
		return
	var vj: Dictionary = JSON.parse_string((got[1] as PackedByteArray).get_string_from_utf8())
	for v: Dictionary in vj.get("voices", []):
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
	var voice := String(line.get("voice", "Callum"))
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
