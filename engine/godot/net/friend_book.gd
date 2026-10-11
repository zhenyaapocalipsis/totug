class_name FriendBook
extends RefCounted

## Друзья и почта (владелец, 2026-10-11). Ведёт выделенный сервер, файл рядом
## с рейтингами (ratings_friends.json). Игрока знаем по учётной записи
## (RatingBook.account_of — хеш ключа), находим по нику (RatingBook.names).
##
## Дружба — по заявке: A просит, B принимает. Встречная заявка (B сам уже
## просил A) — сразу дружба. Сообщения — только между друзьями; хранятся на
## сервере и доходят, даже если друг был не в сети (почта): у пары общая
## переписка (последние THREAD_MAX), у получателя — счётчик непрочитанных.

const THREAD_MAX := 50
const TEXT_MAX := 120

## Учётная запись -> {friends: {acc: true}, in: {acc: true}, out: {acc: true}}.
var links: Dictionary = {}
## Учётная запись -> {name, emblem, favourite} — последний профиль, с которым
## игрок заходил на сервер (имя для списков, эмблема и любимая карта для профиля).
var people: Dictionary = {}
## "acc1|acc2" (по порядку) -> [{from, text, time}].
var threads: Dictionary = {}
## Учётная запись -> {от кого: сколько непрочитанных}.
var unread: Dictionary = {}
var _path := ""


func _init(path: String) -> void:
	_path = path
	var data := RatingBook._read(path)
	links = data.get("links", {})
	people = data.get("people", {})
	threads = data.get("threads", {})
	unread = data.get("unread", {})


func save() -> void:
	RatingBook._write(_path, {"links": links, "people": people, "threads": threads, "unread": unread})


## Запомнить, под каким именем и с какой эмблемой игрок сейчас.
func note_person(account: String, player_name: String, emblem: String = "", favourite: String = "") -> void:
	if account == "" or player_name == "":
		return
	var old: Dictionary = people.get(account, {})
	var now := {"name": player_name, "emblem": emblem, "favourite": favourite}
	if old != now:
		people[account] = now
		save()


func name_of(account: String) -> String:
	return String((people.get(account, {}) as Dictionary).get("name", ""))


func _link(account: String) -> Dictionary:
	if not links.has(account):
		links[account] = {"friends": {}, "in": {}, "out": {}}
	return links[account]


func friends_of(account: String) -> Array:
	return ((links.get(account, {}) as Dictionary).get("friends", {}) as Dictionary).keys()


func incoming(account: String) -> Array:
	return ((links.get(account, {}) as Dictionary).get("in", {}) as Dictionary).keys()


func outgoing(account: String) -> Array:
	return ((links.get(account, {}) as Dictionary).get("out", {}) as Dictionary).keys()


func are_friends(a: String, b: String) -> bool:
	return friends_of(a).has(b)


## Заявка a -> b. Ответ: "sent", "friends" (встречная — сразу дружба),
## "already" (уже друзья или заявка уже есть), "self".
func request(a: String, b: String) -> String:
	if a == b:
		return "self"
	if are_friends(a, b) or outgoing(a).has(b):
		return "already"
	if incoming(a).has(b):
		answer(a, b, true)
		return "friends"
	_link(a)["out"][b] = true
	_link(b)["in"][a] = true
	save()
	return "sent"


## a отвечает на заявку от b. false — заявки не было.
func answer(a: String, b: String, accept: bool) -> bool:
	if not incoming(a).has(b):
		return false
	_link(a)["in"].erase(b)
	_link(b)["out"].erase(a)
	if accept:
		_link(a)["friends"][b] = true
		_link(b)["friends"][a] = true
	save()
	return true


## Убрать из друзей (или отозвать свою заявку). Переписка остаётся.
func remove(a: String, b: String) -> void:
	for pair: Array in [[a, b], [b, a]]:
		var l := _link(pair[0])
		(l["friends"] as Dictionary).erase(pair[1])
		(l["out"] as Dictionary).erase(pair[1])
		(l["in"] as Dictionary).erase(pair[1])
	save()


static func pair_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a


static func clean_text(text: String) -> String:
	return text.strip_edges().replace("\n", " ").left(TEXT_MAX)


## Сообщение a -> b (только друзьям). false — не друзья или пустой текст.
func send(a: String, b: String, text: String, time: int) -> bool:
	var clean := clean_text(text)
	if clean == "" or not are_friends(a, b):
		return false
	var key := pair_key(a, b)
	var list: Array = threads.get(key, [])
	list.append({"from": a, "text": clean, "time": time})
	while list.size() > THREAD_MAX:
		list.pop_front()
	threads[key] = list
	var box: Dictionary = unread.get(b, {})
	box[a] = int(box.get(a, 0)) + 1
	unread[b] = box
	save()
	return true


## Переписка a с b глазами a: [{mine, text, time}]; заодно всё прочитано.
func read_thread(a: String, b: String) -> Array:
	var out := []
	for m: Dictionary in threads.get(pair_key(a, b), []):
		out.append({"mine": m["from"] == a, "text": String(m["text"]), "time": int(m["time"])})
	if (unread.get(a, {}) as Dictionary).has(b):
		(unread[a] as Dictionary).erase(b)
		save()
	return out


func unread_from(a: String, b: String) -> int:
	return int((unread.get(a, {}) as Dictionary).get(b, 0))
