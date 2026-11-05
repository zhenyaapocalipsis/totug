extends RefCounted

## Blank profile slots are defaults; explicit user phrases stay literal.
const L10n := preload("res://scenes/localization.gd")

static func messages() -> Array[Dictionary]:
	var overrides := PlayerProfile.load_phrase_overrides()
	var result: Array[Dictionary] = []
	for i in PlayerProfile.PHRASE_COUNT:
		result.append({"l10n_key": "profile.phrase_%d" % i} if overrides[i] == "" else {"l10n_key": "lobby.raw", "parameters": {"value": overrides[i]}})
	return result

static func texts(values: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for message: Dictionary in values:
		result.append(L10n.text(message.l10n_key, message.get("parameters", {})))
	return result
