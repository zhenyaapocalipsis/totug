extends RefCounted
const L10n := preload("res://scenes/localization.gd")

static func message(id: String) -> Dictionary:
	var key := "record." + id
	return {"l10n_key": key} if L10n.catalog("en").has(key) else {"l10n_key": "lobby.raw", "parameters": {"value": RecordBook.label_of(id)}}

static func label_of(id: String) -> String:
	var value := message(id)
	return L10n.text(value.l10n_key, value.get("parameters", {}))
