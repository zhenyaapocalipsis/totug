extends SceneTree

## Run via node tests/updater_download_test.cjs. A separate local HTTP server
## keeps this regression independent of the internet and of the render loop.
const PAYLOAD_SIZE := 4 * 1024 * 1024
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _download(request: HTTPRequest, url: String) -> float:
	root.add_child(request)
	var path := "user://updater_download_test.tmp"
	request.download_file = path
	request.timeout = 20.0
	var started := Time.get_ticks_msec()
	if request.request(url) != OK:
		_failed += 1
		request.queue_free()
		return 0.0
	var result: Array = await request.request_completed
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	var expected := PackedByteArray()
	expected.resize(PAYLOAD_SIZE)
	expected.fill(90)
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(expected)
	if result[0] != HTTPRequest.RESULT_SUCCESS or result[1] != 200 \
			or FileAccess.get_sha256(path) != hashing.finish().hex_encode():
		printerr("Download failed or contents differ: ", result.slice(0, 2))
		_failed += 1
	request.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	await process_frame
	return elapsed


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		quit(1)
		return
	Engine.max_fps = 10
	var baseline: float = await _download(HTTPRequest.new(), args[0])
	var threaded: float = await _download(Updater.create_http_request(), args[0])
	print("Updater 4 MiB at 10 FPS: old %.2f s, fixed %.2f s" % [baseline, threaded])
	# Large margin for slow CI machines: the network must progress between frames.
	if threaded <= 0.0 or threaded >= baseline * 0.5:
		printerr("Download is still limited by the main loop")
		_failed += 1
	print("updater download: failed %d" % _failed)
	quit(1 if _failed else 0)
