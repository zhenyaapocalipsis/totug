extends SceneTree

class TestUpdater extends Updater:
	var pack := ""
	var endpoint := ""
	var public_pem := ""
	var installed := false
	var fast_stall := false

	func _pack_path() -> String:
		return pack

	func _local_build() -> int:
		return 1  # The target is 9: skipped releases need no patch chain.

	func _url(relative: String) -> String:
		return endpoint + relative

	func _verify_signature(build: int, sha: String, signature: String) -> bool:
		return UpdateSign.verify(build, sha, signature, public_pem)

	func _stall_timeout_ms() -> int:
		return 250 if fast_stall else STALL_TIMEOUT_MS

	func _restart_with(_fresh: String) -> bool:
		installed = true
		finished.emit()
		return true  # Inspect the result without launching/replacing a real game.


var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder := args[0].replace("\\", "/")
	var public_pem := FileAccess.get_file_as_string(folder.path_join("public.pem"))
	for scenario: String in args.slice(3):
		var pack := folder.path_join(scenario + ".pck")
		var source := folder.path_join("base-older.pck" if scenario == "older" else "base.pck")
		DirAccess.copy_absolute(source, pack)
		var old_sha := FileAccess.get_sha256(pack)
		var updater := TestUpdater.new()
		updater.pack = pack
		updater.endpoint = args[1] + scenario + "/"
		updater.public_pem = public_pem
		updater.fast_stall = scenario.begins_with("stalled-")
		root.add_child(updater)
		var holder: Node
		if scenario == "reparent":
			await process_frame
			holder = Node.new()
			root.add_child(holder)
			updater.reparent(holder)
		await updater.finished
		var expected_install := scenario not in ["bad-version-signature", "corrupt-full", "stalled-full"]
		var valid := updater.installed == expected_install and FileAccess.get_sha256(pack) == old_sha
		if expected_install:
			valid = valid and FileAccess.get_sha256(pack + ".new") == args[2]
		else:
			valid = valid and not FileAccess.file_exists(pack + ".new")
		valid = valid and not FileAccess.file_exists(pack + ".tdpatch")
		if not valid:
			_failed += 1
		print("Patch scenario %s: %s" % [scenario, "OK" if valid else "FAILED"])
		updater.queue_free()
		if holder != null:
			holder.queue_free()
		await process_frame
	await process_frame
	print("patch updater: failed %d" % _failed)
	quit(1 if _failed else 0)
