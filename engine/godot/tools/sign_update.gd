extends SceneTree

## Ключ и подпись автообновления (этап Sec-1, см. scenes/update_sign.gd).
##
## Один раз, создать ключ (закрытый — в ~/.ssh, открытый — в игру):
##   Godot --headless --path engine/godot --script res://tools/sign_update.gd -- --genkey
## Подписать сборку (это делает server/deploy.sh):
##   ... -- --sign <путь к закрытому ключу> <номер> <sha256>
## Подпись печатается строкой "SIG:<base64>".

const KEY_GD := "res://scenes/update_key.gd"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1 and args[0] == "--genkey":
		quit(_genkey(args[1] if args.size() > 1 else default_key_path()))
	elif args.size() == 4 and args[0] == "--sign":
		quit(_sign(args[1], int(args[2]), args[3]))
	else:
		printerr("usage: -- --genkey [path]  |  -- --sign <key> <build> <sha256>")
		quit(1)


static func default_key_path() -> String:
	return OS.get_environment("USERPROFILE").replace("\\", "/").path_join(".ssh/tyrants_update.key")


func _genkey(path: String) -> int:
	if FileAccess.file_exists(path):
		printerr("key already exists: %s (delete it first if you really want a new one)" % path)
		return 1
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var key := Crypto.new().generate_rsa(4096)
	if key.save(path, false) != OK:
		printerr("cannot write %s" % path)
		return 1
	var f := FileAccess.open(KEY_GD, FileAccess.WRITE)
	f.store_string("extends RefCounted\n## Открытый ключ автообновления. Создан tools/sign_update.gd --genkey;\n"
		+ "## закрытая пара к нему — только у владельца (~/.ssh/tyrants_update.key).\n"
		+ "const PUBLIC_KEY := \"\"\"%s\"\"\"\n" % key.save_to_string(true).strip_edges())
	f.close()
	print("private key: %s" % path)
	print("public key written to %s" % KEY_GD)
	return 0


func _sign(path: String, build: int, sha: String) -> int:
	var key := CryptoKey.new()
	if key.load(path, false) != OK:
		printerr("cannot read private key %s" % path)
		return 1
	var sig := UpdateSign.sign(build, sha, key)
	# Подпись должна сходиться с ключом, зашитым в игру, — иначе игроки
	# молча перестанут получать обновления.
	if not UpdateSign.verify(build, sha, sig):
		printerr("signature does not match the public key in %s" % KEY_GD)
		return 1
	print("SIG:" + sig)
	return 0
