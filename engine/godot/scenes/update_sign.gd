class_name UpdateSign
extends RefCounted

## Подпись автообновления (этап Sec-1). version.txt качается по простому HTTP,
## поэтому sha256 из него сам по себе ничего не доказывает: кто сидит в сети
## игрока (общий Wi-Fi, взломанный роутер), подсунет и свой .pck, и его sha.
## Поэтому server/deploy.sh подписывает строку "<номер> <sha256>" закрытым
## ключом владельца (лежит только у него: ~/.ssh/tyrants_update.key, не в git),
## а игра проверяет подпись открытым ключом из scenes/update_key.gd.
## Номер версии входит в подпись — старую настоящую сборку под новым номером
## не выдать. Ключ создаёт и подпись ставит tools/sign_update.gd.

const KEY_SCRIPT := preload("res://scenes/update_key.gd")


static func digest(build: int, sha_hex: String) -> PackedByteArray:
	return ("%d %s" % [build, sha_hex]).sha256_buffer()


## Подпись в base64 — третье поле version.txt.
static func sign(build: int, sha_hex: String, private_key: CryptoKey) -> String:
	var sig := Crypto.new().sign(HashingContext.HASH_SHA256, digest(build, sha_hex), private_key)
	return Marshalls.raw_to_base64(sig)


## Правда ли владелец выпустил сборку build с файлом sha_hex.
## Нет подписи, нет ключа или подпись не та — нет.
static func verify(build: int, sha_hex: String, sig_b64: String, public_pem: String = KEY_SCRIPT.PUBLIC_KEY) -> bool:
	if build <= 0 or sha_hex.length() != 64 or sig_b64 == "" or public_pem == "":
		return false
	var key := CryptoKey.new()
	if key.load_from_string(public_pem, true) != OK:
		return false
	var sig := Marshalls.base64_to_raw(sig_b64)
	if sig.is_empty():
		return false
	return Crypto.new().verify(HashingContext.HASH_SHA256, digest(build, sha_hex), sig, key)
