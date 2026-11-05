extends Node

## Poll a nonblocking HTTPClient on a worker. HTTPRequest's blocking worker can
## hang cancel_request() on a stalled body; this worker always checks cancellation.
signal request_completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray)

var timeout := 6.0
var stall_timeout_ms := 30000
var body_size_limit := -1
var download_file := ""
var _thread: Thread
var _mutex := Mutex.new()
var _cancelled := false
var _running := false
var _serial := 0
var _status := HTTPClient.STATUS_DISCONNECTED
var _total := -1
var _downloaded := 0


func get_body_size() -> int:
	_mutex.lock()
	var value := _total
	_mutex.unlock()
	return value


func get_downloaded_bytes() -> int:
	_mutex.lock()
	var value := _downloaded
	_mutex.unlock()
	return value


func get_http_client_status() -> int:
	_mutex.lock()
	var value := _status
	_mutex.unlock()
	return value


func _stopped() -> bool:
	_mutex.lock()
	var value := _cancelled
	_mutex.unlock()
	return value


func _publish(status: int, total: int, downloaded: int) -> void:
	_mutex.lock()
	_status = status
	_total = total
	_downloaded = downloaded
	_mutex.unlock()


func request(url: String) -> Error:
	if not is_inside_tree():
		return ERR_UNCONFIGURED
	if _running:
		return ERR_BUSY
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	_serial += 1
	_mutex.lock()
	_cancelled = false
	_mutex.unlock()
	_publish(HTTPClient.STATUS_DISCONNECTED, -1, 0)
	_running = true
	_thread = Thread.new()
	var err := _thread.start(_fetch.bind(_serial, url, download_file, timeout, body_size_limit, stall_timeout_ms))
	if err != OK:
		_running = false
	return err


func cancel_request() -> void:
	_serial += 1  # Ignore completion already queued by the cancelled request.
	_mutex.lock()
	_cancelled = true
	_mutex.unlock()
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	_running = false
	_publish(HTTPClient.STATUS_DISCONNECTED, -1, 0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		cancel_request()


func _complete(serial: int, result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if serial != _serial:
		return
	if _thread.is_started():
		_thread.wait_to_finish()
	_running = false
	request_completed.emit(result, code, headers, body)


func _fetch(serial: int, url: String, destination: String, max_seconds: float, limit: int, stall_ms: int) -> void:
	var parsed := RegEx.create_from_string("^(https?)://([^/:]+)(?::([0-9]+))?(/.*)?$").search(url)
	var result := HTTPRequest.RESULT_CANT_CONNECT
	var code := 0
	var headers := PackedStringArray()
	var body := PackedByteArray()
	var file: FileAccess
	var client := HTTPClient.new()
	client.read_chunk_size = 1024 * 1024
	client.set_blocking_mode(false)
	var started := Time.get_ticks_msec()
	var last_data := started
	var received := 0
	var total := -1
	var sent := false
	var got_headers := false
	if parsed != null:
		var tls := parsed.get_string(1) == "https"
		var port := int(parsed.get_string(3)) if parsed.get_string(3) != "" else (443 if tls else 80)
		var route := parsed.get_string(4) if parsed.get_string(4) != "" else "/"
		if client.connect_to_host(parsed.get_string(2), port, TLSOptions.client() if tls else null) == OK:
			while not _stopped():
				if got_headers and total >= 0 and received == total:
					result = HTTPRequest.RESULT_SUCCESS
					break
				var now := Time.get_ticks_msec()
				if (max_seconds > 0 and now - started > max_seconds * 1000) or now - last_data > stall_ms:
					result = HTTPRequest.RESULT_TIMEOUT
					break
				if client.poll() != OK:
					result = HTTPRequest.RESULT_CONNECTION_ERROR
					break
				var status := client.get_status()
				_publish(status, total, received)
				if status in [HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_CANT_RESOLVE, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR]:
					result = HTTPRequest.RESULT_CONNECTION_ERROR
					break
				if status == HTTPClient.STATUS_CONNECTED and not sent:
					if client.request(HTTPClient.METHOD_GET, route, PackedStringArray()) != OK:
						break
					sent = true
				if sent and not got_headers and client.has_response():
					got_headers = true
					code = client.get_response_code()
					headers = client.get_response_headers()
					total = client.get_response_body_length()
					if limit >= 0 and total > limit:
						result = HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED
						break
					if destination != "":
						file = FileAccess.open(destination, FileAccess.WRITE)
						if file == null:
							result = HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN
							break
				if status == HTTPClient.STATUS_BODY:
					var bytes := client.read_response_body_chunk()
					if not bytes.is_empty():
						last_data = now
						received += bytes.size()
						if limit >= 0 and received > limit:
							result = HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED
							break
						if file != null:
							file.store_buffer(bytes)
							if file.get_error() != OK:
								result = HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR
								break
						else:
							body.append_array(bytes)
				elif got_headers and status in [HTTPClient.STATUS_CONNECTED, HTTPClient.STATUS_DISCONNECTED]:
					result = HTTPRequest.RESULT_SUCCESS if total < 0 or received == total else HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH
					break
				elif status == HTTPClient.STATUS_DISCONNECTED:
					break
				OS.delay_usec(1000)
	if file != null:
		file.flush()
		if file.get_error() != OK:
			result = HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR
		file.close()
	client.close()
	_publish(HTTPClient.STATUS_DISCONNECTED, total, received)
	if _stopped():
		if destination != "":
			DirAccess.remove_absolute(destination)
		return
	_complete.call_deferred(serial, result, code, headers, body)
