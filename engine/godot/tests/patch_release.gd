extends SceneTree

## Verify a real release delta end to end before publishing it:
## ... --script res://tests/patch_release.gd -- <build-dir> <base.pck>
const PatchFile := preload("res://scenes/update_patch.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(1)
		return
	var dir := args[0].replace("\\", "/")
	var base := args[1].replace("\\", "/")
	var parts := FileAccess.get_file_as_string(dir.path_join("version.txt")).strip_edges().split(" ", false)
	if parts.size() != 5 or not UpdateSign.verify(int(parts[0]), parts[1], parts[2]) or not UpdateSign.verify(int(parts[0]), parts[3], parts[4]):
		printerr("Invalid signed release")
		quit(1)
		return
	var patch_dir := dir.path_join("patches").path_join(parts[0])
	if FileAccess.get_sha256(patch_dir.path_join("index.json")) != parts[3]:
		quit(1)
		return
	var from_sha := FileAccess.get_sha256(base)
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(patch_dir.path_join("index.json")))
	for entry: Dictionary in index.patches:
		if entry.from_sha != from_sha:
			continue
		var delta := patch_dir.path_join(from_sha + ".tdpatch")
		var output := dir.path_join("release.verify.pck")
		var valid: bool = FileAccess.get_sha256(delta) == entry.sha256 and PatchFile.apply(base, delta, output, from_sha, parts[1], int(parts[0]))
		DirAccess.remove_absolute(output)
		print("Real release patch: %s; %d bytes vs %d full" % ["OK" if valid else "FAILED", entry.size, index.target_size])
		quit(0 if valid else 1)
		return
	printerr("No patch for this base")
	quit(1)
