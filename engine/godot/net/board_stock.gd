class_name BoardStock
extends RefCounted
## Запас готовых чертежей доски на выделенном сервере (владелец, 2026-10-12).
## На одном ядре VPS прокладка трасс не укладывалась в ROUTE_BUDGET_MS, и
## онлайн-доска 4p выходила по-старому. Пока сервер простаивает, он строит
## чертежи заранее, без спешки, и оставляет только те, что легли в сетку;
## партия берёт сид вместе с готовым чертежом и стартует сразу.
## Доска зависит только от сида и числа игроков: GameSetup.new_game раскладывает
## гексы первым делом, до колод и режима, — раздача с этим сидом даёт ту же
## доску (раскладку всё равно сверяем: same_layout).

const SIZE := 2                  # чертежей в запасе на каждое число игроков
const COUNTS: Array[int] = [2, 3, 4]
const BUDGET_MS := BoardSchematic.NO_BUDGET   # на один чертёж в запас — без спешки

var _ready := {}       # число игроков -> [{"seed", "layout", "schematic"}]
var _task := -1
var _building := {}    # что строится сейчас: {"players", "seed", "layout"}
var _result := {}      # чертёж из фоновой задачи
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()
	for n: int in COUNTS:
		_ready[n] = []


## Готовый чертёж на players игроков: {"seed", "layout", "schematic"} или пусто.
func take(players: int) -> Dictionary:
	var list: Array = _ready.get(players, [])
	return list.pop_front() if not list.is_empty() else {}


func count(players: int) -> int:
	return (_ready.get(players, []) as Array).size()


## Раскладка партии та же, что у чертежа из запаса.
static func same_layout(entry: Dictionary, state: GameState) -> bool:
	return String(entry.get("layout", "")) == JSON.stringify(state.layout)


## Каждый кадр сервера: забрать достроенный чертёж, начать следующий.
## Строится по одному за раз — ядро одно.
func tick() -> void:
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task):
			return
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		# не лёг в сетку и без лимита времени — такой доске в запасе не место
		if bool(_result.get("grid", false)):
			_ready[_building["players"]].append({"seed": _building["seed"],
				"layout": _building["layout"], "schematic": _result})
		_result = {}
	for n: int in COUNTS:
		if count(n) < SIZE:
			_start(n)
			return


func _start(players: int) -> void:
	var seed_value := _rng.randi()
	var ids: Array[String] = []
	ids.assign(GameRoom.PLAYER_IDS.slice(0, players))
	# раздача трогает общие статические поля правил — она здесь, в главном потоке;
	# в фоне только чертёж (как в NetSession._start_room)
	var state := GameSetup.new_game(ids, seed_value)
	BoardSchematic.warm_up(state)
	_building = {"players": players, "seed": seed_value, "layout": JSON.stringify(state.layout)}
	_task = WorkerThreadPool.add_task(_build.bind(state))


func _build(state: GameState) -> void:
	_result = BoardSchematic.build(state, true, BUDGET_MS)


## Сервер закрывается: фоновую задачу дождаться (бросить поток нельзя).
func close() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
