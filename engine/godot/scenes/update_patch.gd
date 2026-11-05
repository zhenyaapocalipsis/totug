extends RefCounted

## A delta reconstructs the exact signed PCK, including deletions and directory
## metadata. No runtime overlays, preload ordering or growing patch chain.
const MAGIC := "TYRDELTA"
const BUFFER_SIZE := 1024 * 1024
const MAX_HEADER_SIZE := 8 * 1024 * 1024
const MAX_TARGET_SIZE := 8 * 1024 * 1024 * 1024


static func _uint(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) >= 0 and float(value) == floor(float(value)) and float(value) <= MAX_TARGET_SIZE


static func _plan(patch: FileAccess, base_size: int, from_sha: String, target_sha: String, build: int) -> Dictionary:
	if patch.get_length() < 12 or patch.get_buffer(8).get_string_from_ascii() != MAGIC:
		return {}
	var header_size := patch.get_32()
	if header_size <= 0 or header_size > MAX_HEADER_SIZE or header_size > patch.get_length() - 12:
		return {}
	var parsed: Variant = JSON.parse_string(patch.get_buffer(header_size).get_string_from_utf8())
	if not parsed is Dictionary:
		return {}
	var header: Dictionary = parsed
	if header.get("format") != 1 or header.get("build") != build \
		or header.get("from_sha") != from_sha or header.get("target_sha") != target_sha \
		or not _uint(header.get("target_size")) or int(header.target_size) <= 0 \
		or not header.get("ops") is Array or header.ops.size() > 100000:
		return {}
	var payload_start := 12 + header_size
	var size := 0
	for op: Variant in header.ops:
		if not op is Array or op.size() != 3 or not _uint(op[0]) or not _uint(op[1]) or not _uint(op[2]):
			return {}
		var kind := int(op[0])
		var offset := int(op[1])
		var count := int(op[2])
		var source_size := base_size if kind == 0 else patch.get_length() - payload_start
		if kind not in [0, 1] or count <= 0 or offset > source_size or count > source_size - offset:
			return {}
		size += count
		if size > int(header.target_size):
			return {}
	if size != int(header.target_size):
		return {}
	header["payload_start"] = payload_start
	return header


static func apply(base_path: String, patch_path: String, output_path: String, from_sha: String, target_sha: String, build: int) -> bool:
	if base_path == output_path or patch_path == output_path or FileAccess.get_sha256(base_path) != from_sha:
		return false
	var base := FileAccess.open(base_path, FileAccess.READ)
	var patch := FileAccess.open(patch_path, FileAccess.READ)
	if base == null or patch == null:
		return false
	var plan := _plan(patch, base.get_length(), from_sha, target_sha, build)
	if plan.is_empty():
		return false
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	if output == null:
		return false
	var valid := true
	for op: Array in plan.ops:
		var source: FileAccess = base if int(op[0]) == 0 else patch
		source.seek(int(op[1]) + (int(plan.payload_start) if int(op[0]) == 1 else 0))
		var remaining := int(op[2])
		while remaining > 0:
			var count := mini(remaining, BUFFER_SIZE)
			var bytes := source.get_buffer(count)
			if bytes.size() != count:
				valid = false
				break
			output.store_buffer(bytes)
			if output.get_error() != OK:
				valid = false
				break
			remaining -= count
		if not valid:
			break
	output.flush()
	valid = valid and output.get_error() == OK and output.get_length() == int(plan.target_size)
	output.close()
	base.close()
	patch.close()
	valid = valid and FileAccess.get_sha256(output_path) == target_sha
	if not valid:
		DirAccess.remove_absolute(output_path)
	return valid
