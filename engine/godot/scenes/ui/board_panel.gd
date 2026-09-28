class_name BoardPanel
extends PanelContainer

## Доска, поверх — войска, шпионы и подсветка доступных целей.
##
## Two looks (key H switches): the pixel-art schematic (default, see
## core/map/board_schematic.gd — tunnels as circuit traces, no hexes) and the
## real hex tiles with their rotations. Both come from the same board snapshot
## and the same slot ids, so clicks and highlights work the same way.
##
## До этого доска рисовалась схемой из кружков и была нечитаемой: координаты
## слотов брались из графа, где записано положение ВНУТРИ гекса, поэтому девять
## тайлов оказывались в одной точке. Теперь координаты приходят из
## BoardGeometry (арт гексов) и BoardSchematic (схема).
##
## Панель по-прежнему не знает правил: что подсвечивать, ей сообщает
## view["legal"], посчитанный сервером.
##
## Доска зафиксирована (решение владельца, 2026-09-19): ни масштаба колесом,
## ни перетаскивания, ни переключения вида. Она сама вписывается в отведённую
## зону и остаётся в ней, а мышь нужна только чтобы выбрать войско или локацию.
##
## Масштаб схемы подбирается не «как влезет», а так, чтобы один её пиксель
## занимал ЦЕЛОЕ число экранных (см. _fit_zoom). Иначе картинка мылилась:
## экран 960x540 растягивается на окно вдвое, и дробный масштаб размывал бы
## и трассы, и подписи локаций.

signal slot_clicked(slot_id: String)
signal site_clicked(site_id: String)
signal spy_clicked(site_id: String, owner: String)
## Прицел над убитым (вытесненным) войском сошёлся — удар. Экран по нему
## пускает трофей в зал убийцы и сажает войско вытеснившего.
signal kill_struck(slot_id: String, victim: String, killer: String, supplant: bool)

const PLAYER_COLORS := {
	"red": Color(0.85, 0.22, 0.22),
	"blue": Color(0.25, 0.50, 0.90),
	"green": Color(0.28, 0.70, 0.34),
	"purple": Color(0.62, 0.35, 0.78),
}
const NEUTRAL_TROOP_COLOR := Color(0.55, 0.55, 0.58)
const EMPTY_SLOT_COLOR := Color(0.0, 0.0, 0.0, 0.45)
const DEPLOY_COLOR := Color(0.35, 0.95, 0.45)
const KILL_COLOR := Color(1.0, 0.55, 0.15)
## Подсветка целей текущего pending-решения (assassinate/supplant/move/
## return/place spy и т.п.) — выбор цели делается кликом по доске, а не
## кнопкой в диалоге (см. decision_dialog.gd, game_screen.gd).
const DECISION_COLOR := Color(0.95, 0.75, 0.15)
## Места со строки сводки под мышью (см. show_places) — голубым: этот цвет
## не занят ни подсказками, ни игроками.
const FOCUS_COLOR := Color(0.35, 0.85, 1.0)

## Доска дёргается, когда на ней что-то случилось: убили войско, вытеснили
## чужое, захватили локацию. Дёргается ОТРИСОВКА (вся картинка целиком), а не
## узел: панель обрезает содержимое по себе, клики считаются по неподвижным
## координатам, а раскладку экрана тряска не трогает вовсе.
const SHAKE_TIME := 0.32
const SHAKE_FREQ := 52.0

## Искры: из точки события разлетаются несколько квадратиков, падают и гаснут.
## Квадратики целого размера и на целых координатах — иначе на пиксельной
## схеме они расплываются в грязь.
const SPARK_COUNT := 9
const SPARK_LIFE := 0.55
const SPARK_SPEED := 85.0
const SPARK_GRAVITY := 150.0
## Фишка долетела из барака до своего места (см. land): сколько живёт удар,
## сколько из него фишка белая, на сколько пикселей схемы расходится кольцо,
## сколько пылинок и как дёргается доска.
const IMPACT_TIME := 0.32
const FLASH_TIME := 0.06
const RING_GROW := 10.0
const DUST_COUNT := 10
const LAND_SHAKE := 2.0

## Убийство и вытеснение (решения владельца, 2026-09-28: игроки не видели,
## где это случилось; вид — по раскадровке B и C2). В виде убитой фишки уже
## нет, поэтому до конца анимации место рисует панель сама.
##
## Assassinate (B): фишку метит красное кольцо, она краснеет, вспыхивает и
## трескается, на KILL_STRIKE — удар: раскалывается пополам, половинки
## разъезжаются и падают, летят осколки, над местом всплывает и тает череп.
## Supplant (C2): под фишкой растекается лужа тени, фишка тонет, на
## SUPPLANT_STRIKE — удар (утонула), из той же лужи всплывает войско
## вытеснившего, лужа стягивается. Трофей ничем не летит — цифра зала
## убийцы вспыхивает в момент удара (решение владельца).
## Несколько убийств одного ответа сервера идут друг за другом через KILL_STEP.
## Метка и покраснение до KILL_CRACK, дальше вспышка с трещиной до удара.
const KILL_CRACK := 0.16
const KILL_STRIKE := 0.2
const SUPPLANT_STRIKE := 0.24
## Когда войско вытеснившего целиком всплыло из лужи.
const SUPPLANT_SURFACE := 0.48
const KILL_END := 0.6
const KILL_STEP := 0.5
const KILL_SHAKE := 4.0
const KILL_SHARDS := 14
const MARK_COLOR := Color(1.0, 0.2, 0.15)
const CRACK_COLOR := Color(0.08, 0.04, 0.06)
const POOL_COLOR := Color(0.06, 0.02, 0.1, 0.92)
const POOL_RIM := Color(0.3, 0.12, 0.42, 0.9)
## Череп над местом убийства, 5x5 пикселей схемы.
const SKULL := [
	".###.",
	"#####",
	"#.#.#",
	"#####",
	".#.#.",
]
const SKULL_COLOR := Color(0.95, 0.93, 0.85)

## Локация сменила хозяина — её обводка коротко вспыхивает в цвет захватчика.
## Отдельного события «захват» движок не шлёт: контроль пересчитывается из
## расстановки войск, поэтому панель сравнивает site_control с прошлым видом.
const CAPTURE_TIME := 1.2
## Прозрачность заливки локации цветом хозяина: контроль / полный контроль.
const CONTROL_FILL := 0.3
const CONTROL_FILL_TOTAL := 0.6
## Значки 5x5 столбика города с маркером контроля.
## Паутина — значок Influence на доске (города с маркером, табличка A2).
const INFLUENCE_WEB := ["10101", "01110", "11011", "01110", "10101"]
const MARKER_CROWN := ["10101", "10101", "11111", "11011", "11111"]

## Радиус кружка войска в МИРОВЫХ пикселях (печатные круги на арте примерно
## такого размера, шаг между слотами внутри локации ~47 px).
const SLOT_RADIUS_WORLD := 19.0
const ZOOM_MIN := 0.06
const ZOOM_MAX := 1.2
## The schematic is drawn at 1x pixels, so it zooms in much further.
const SCHEMATIC_ZOOM_MIN := 0.25
const SCHEMATIC_ZOOM_MAX := 6.0

var _board: Dictionary = {}
var _view: Dictionary = {}
var _viewer_id: String = ""
var _textures: Dictionary = {}   # hex_id -> Texture2D

var schematic_mode := true
## Stage 0 фонового арта гексов (PixelLab): если выкл — прежний вид, ни один
## расчёт больше нигде на этот флаг не смотрит. См. SchematicPainter.paint.
var art_layer := false
## Тематические объекты (PixelLab, владелец 2026-09-23) на 5 подобранных
## плитках — отдельно от art_layer, чтобы не путаться с ещё не принятым фоном
## гексов. См. SchematicPainter.OBJECT_TILES.
var object_layer := false
var _schematic_texture: ImageTexture = null
var _tokens: Dictionary = {}     # colour html -> ImageTexture

var _zoom := 0.0                 # 0 = ещё не подобран, подберётся под размер панели
var _pan := Vector2.ZERO         # центр обзора в мировых координатах

var _shake_left := 0.0
var _shake_power := 0.0          # амплитуда тряски в пикселях панели
## Кто чем владел в прошлый раз (site_id -> player_id) и что сейчас вспыхивает
## (site_id -> сколько ещё гореть).
var _control: Dictionary = {}
var _control_known := false
## Сменившие хозяина в последнем виде — ещё не решено, вспыхнуть сразу или
## после посадки войска (см. _flush_captures).
var _taken_now: Array[String] = []
## Захваченные локации, которые вспыхнут, когда в них приземлится войско.
var _captures_on_land: Dictionary = {}
var _captures: Dictionary = {}
## Летящие искры: pos и vel в координатах панели, не в мировых — живут они
## доли секунды, и доска за это время никуда не уедет.
var _sparks: Array[Dictionary] = []
## Фишки, которые ещё летят из барака (см. GameScreen._launch_token): в
## состоянии они уже стоят, но на месте их не рисуем, пока не долетят.
## Ключ "troop|<slot_id>" или "spy|<site_id>|<owner>" ->
## {"left": запас времени до посадки без land(), "t": близость к месту 0..1}.
var _arriving: Dictionary = {}
## Идущие удары приземлений: {key, pos (координаты панели), left, radius, colour}.
var _impacts: Array[Dictionary] = []
## Идущие убийства: {slot, victim, killer, supplant, wait (до начала анимации),
## t (сколько идёт), struck (удар был), surfaced (вытеснивший всплыл)}.
var _kills: Array[Dictionary] = []
## Места, подсвеченные со строки сводки под мышью (см. show_places).
var _focus: Array = []

## Мерцание подсказок (зелёные/жёлтые/оранжевые кружки): время пульса и флаг
## «на прошлом кадре была хоть одна подсказка» — пока он поднят, доска
## перерисовывается каждый кадр.
const PULSE_PERIOD := 1.1
var _pulse_t := 0.0
var _pulse_active := false


func _init() -> void:
	var style := StyleBoxFlat.new()
	# Подложка прозрачная: за доской видно живой фон экрана.
	style.bg_color = Color(SchematicPainter.BG, 0.0)
	style.set_corner_radius_all(0)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(200, 120)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	set_process(false)


func update_from_view(view: Dictionary, viewer_id: String, board: Dictionary) -> void:
	_view = view
	_viewer_id = viewer_id
	if board != _board:
		_board = board
		_load_textures()
		_zoom = 0.0  # новая доска — пересчитать обзор
	_note_captures(view.get("site_control", {}))
	queue_redraw()


## Сравнивает, кто владеет локациями, с прошлым видом: сменившие хозяина
## вспыхивают, доска коротко дёргается. Самый первый вид ничего не зажигает —
## это не захват, а стартовая расстановка.
func _note_captures(control: Dictionary) -> void:
	if not _control_known:
		_control = control.duplicate()
		_control_known = true
		return
	var taken := false
	for site_id: String in control:
		if String(_control.get(site_id, "")) != String(control[site_id]):
			_taken_now.append(site_id)
			taken = true
	_control = control.duplicate()
	# Вспыхивать не сразу: если локацию взяло войско, которое ещё только
	# вылетает из барака, захват покажем, когда оно приземлится. О полётах
	# доска узнаёт после этого вида (GameScreen._react_to_events), поэтому
	# решаем в конце кадра.
	if taken:
		_flush_captures.call_deferred()


## Захваты из последнего вида: локация, куда ещё летит войско, ждёт его
## посадки (land), остальные вспыхивают сразу.
func _flush_captures() -> void:
	var fire: Array[String] = []
	for site_id in _taken_now:
		if _troop_arriving_at(site_id) or _kill_pending_at(site_id):
			_captures_on_land[site_id] = true
		else:
			fire.append(site_id)
	_taken_now.clear()
	_fire_captures(fire)


func _fire_captures(sites: Array[String]) -> void:
	if sites.is_empty():
		return
	for site_id in sites:
		_captures[site_id] = CAPTURE_TIME
		spark_at_site(site_id, PLAYER_COLORS.get(String(_control.get(site_id, "")), Color(0.8, 0.8, 0.8)))
	shake(3.0)
	set_process(true)


## Летит ли сейчас войско в одно из мест локации site_id.
func _troop_arriving_at(site_id: String) -> bool:
	for key: String in _arriving:
		if key.begins_with("troop|") and _site_of_slot(key.substr(6)) == site_id:
			return true
	return false


## Ждёт ли удара убийство в одном из мест локации site_id.
func _kill_pending_at(site_id: String) -> bool:
	for k in _kills:
		if _site_of_slot(String(k["slot"])) == site_id:
			return true
	return false


## Захват локации site_id, отложенный до посадки войска или до удара,
## вспыхивает, когда там больше ничего не летит и не целится.
func _fire_capture_if_settled(site_id: String) -> void:
	if _captures_on_land.has(site_id) and not _troop_arriving_at(site_id) \
			and not _kill_pending_at(site_id):
		_captures_on_land.erase(site_id)
		var one: Array[String] = [site_id]
		_fire_captures(one)


# --- убийство и вытеснение ----------------------------------------------------

## Войско victim на месте slot_id убил (supplant — вытеснил) killer. Через
## delay секунд начинается анимация (см. KILL_STRIKE), на ударе — сигнал
## kill_struck. Пока она идёт, место рисует панель сама. false — места на
## доске нет, показывать нечего.
func kill_at(slot_id: String, victim: String, killer: String, supplant: bool,
		delay: float = 0.0) -> bool:
	if victim == "" or _slot_world(slot_id) == null:
		return false
	_kills.append({"slot": slot_id, "victim": victim, "killer": killer,
		"supplant": supplant, "wait": delay, "t": 0.0, "struck": false, "surfaced": false})
	set_process(true)
	queue_redraw()
	return true


## Для проверок: сколько убийств ещё анимируется.
func kill_count() -> int:
	return _kills.size()


## Для проверок: сколько из них уже ударило.
func struck_count() -> int:
	return _kills.filter(func(k: Dictionary) -> bool: return bool(k["struck"])).size()


## Шаг анимаций убийства на delta секунд. Удары и конец — после прохода по
## списку: сигнал удара может добавить новые.
func _step_kills(delta: float) -> void:
	var struck: Array[Dictionary] = []
	var done: Array[Dictionary] = []
	for k in _kills:
		var step := delta
		if float(k["wait"]) > 0.0:
			k["wait"] = float(k["wait"]) - delta
			if float(k["wait"]) > 0.0:
				continue
			# Очередь подошла посреди кадра — остаток кадра уже идёт на анимацию.
			step = -float(k["wait"])
		var t: float = float(k["t"]) + step
		k["t"] = t
		var supplant := bool(k["supplant"])
		if not bool(k["struck"]) and t >= (SUPPLANT_STRIKE if supplant else KILL_STRIKE):
			k["struck"] = true
			struck.append(k)
		if supplant and not bool(k["surfaced"]) and t >= SUPPLANT_SURFACE:
			k["surfaced"] = true
			_surface(k)
		if t >= KILL_END:
			done.append(k)
	for k in done:
		_kills.erase(k)
		_fire_capture_if_settled(_site_of_slot(String(k["slot"])))
	for k in struck:
		_strike(k)


## Удар. Assassinate: фишка раскалывается — вспышка с кольцом, осколки цвета
## жертвы, доска дёргается. Supplant: фишка утонула — из лужи брызги.
func _strike(k: Dictionary) -> void:
	var slot_id := String(k["slot"])
	var at: Variant = _slot_world(slot_id)
	if at != null:
		var pos: Vector2 = _to_screen(at)
		if bool(k["supplant"]):
			_burst(pos + Vector2(0, 4.0 * _zoom), POOL_RIM.lightened(0.3), SPARK_COUNT / 2)
		else:
			_impacts.append({"key": "kill|" + slot_id, "pos": pos, "left": IMPACT_TIME,
				"radius": _arrival_radius("troop|" + slot_id), "colour": MARK_COLOR})
			_burst(pos, troop_colour(String(k["victim"])), KILL_SHARDS)
			_burst(pos, KILL_COLOR, SPARK_COUNT / 2)
	shake(LAND_SHAKE if bool(k["supplant"]) else KILL_SHAKE)
	kill_struck.emit(slot_id, String(k["victim"]), String(k["killer"]), bool(k["supplant"]))


## Войско вытеснившего всплыло из лужи — кольцо в его цвет, как у посадки.
func _surface(k: Dictionary) -> void:
	var at: Variant = _slot_world(String(k["slot"]))
	if at == null:
		return
	var pos: Vector2 = _to_screen(at)
	_impacts.append({"key": "troop|" + String(k["slot"]), "pos": pos, "left": IMPACT_TIME,
		"radius": _arrival_radius("troop|"), "colour": troop_colour(String(k["killer"]))})
	shake(LAND_SHAKE)


## Места, где сейчас идёт убийство: там фишку рисует _draw_kills, а не
## обычная расстановка.
func _kill_slots() -> Dictionary:
	var busy := {}
	for k in _kills:
		busy[String(k["slot"])] = true
	return busy


func _draw_kills() -> void:
	for k in _kills:
		var at: Variant = _slot_world(String(k["slot"]))
		if at == null:
			continue
		var pos: Vector2 = _to_screen(at)
		var victim := String(k["victim"])
		if float(k["wait"]) > 0.0:
			_draw_troop(pos, victim)
		elif bool(k["supplant"]):
			_draw_supplant(pos, victim, String(k["killer"]), float(k["t"]))
		else:
			_draw_assassinate(pos, victim, float(k["t"]), _site_of_slot(String(k["slot"])))


## Assassinate по времени t (см. KILL_STRIKE): метка и покраснение, вспышка с
## трещиной, после удара — половинки разъезжаются и падают, всплывает череп.
func _draw_assassinate(pos: Vector2, victim: String, t: float, site_id: String) -> void:
	var z := _zoom
	var tl := _token_corner(pos)
	var r := float(BoardSchematic.SLOT_R)
	if t < KILL_STRIKE:
		if site_id != "":
			_outline_site(site_id, Color(MARK_COLOR, 0.9 if int(t / 0.05) % 2 == 0 else 0.4))
		_draw_troop(pos, victim)
		var centre := tl + Vector2(r + 0.5, r + 0.5) * z
		if t < KILL_CRACK:
			draw_arc(centre, (r + 2.0) * z, 0, TAU, 24, MARK_COLOR, maxf(1.0, roundf(z)))
			var red := clampf((t - 0.04) / 0.1, 0.0, 1.0) * 0.55
			if red > 0.0:
				draw_circle(centre, r * z, Color(MARK_COLOR, red))
		else:
			draw_circle(centre, r * z, Color(1, 1, 1, 0.6))
			for i in range(-2, 3):
				draw_rect(Rect2(tl + Vector2(r + i, r + i) * z, Vector2(z, z)), CRACK_COLOR)
		return
	var e := t - KILL_STRIKE
	var fade := 1.0 - clampf((e - 0.1) / 0.3, 0.0, 1.0)
	# Сразу после раскола щель тёмная: иначе в ней просвечивает светлая
	# плашка локации и выходит белая черта.
	if e < 0.1:
		var sil := _token(Color(CRACK_COLOR, 1.0))
		draw_texture_rect(sil, Rect2(tl, sil.get_size() * z), false, Color(1, 1, 1, 1.0 - e / 0.1))
	if fade > 0.0:
		var dx := 1.0 + 18.0 * e
		_draw_half(tl + Vector2(roundf(dx), roundf(-1.0 - 12.0 * e + 90.0 * e * e)) * z, victim, true, fade)
		_draw_half(tl + Vector2(roundf(-dx), roundf(1.0 + 12.0 * e + 90.0 * e * e)) * z, victim, false, fade)
	if e >= 0.1:
		var skull_alpha := 1.0 - clampf((e - 0.28) / 0.12, 0.0, 1.0)
		_draw_skull(tl, 6.0 + roundf(12.0 * (e - 0.1)), skull_alpha)


## Supplant по времени t: лужа тени растекается, старая фишка тонет, после
## удара из лужи всплывает войско вытеснившего, лужа стягивается.
func _draw_supplant(pos: Vector2, victim: String, killer: String, t: float) -> void:
	var tl := _token_corner(pos)
	var rx := 0.0
	if t < 0.1:
		rx = 4.0 + 40.0 * t
	elif t < 0.44:
		rx = 8.0
	else:
		rx = 8.0 * (1.0 - (t - 0.44) / (KILL_END - 0.44))
	if rx >= 1.0:
		_draw_pool(tl, int(roundf(rx)))
	var h := BoardSchematic.SLOT_R * 2 + 1
	if t < SUPPLANT_STRIKE:
		_draw_sunk(tl, victim, int(roundf(clampf((t - 0.04) / 0.2, 0.0, 1.0) * h)))
	elif t < 0.3:
		# Утонула — по луже бегут пузыри.
		var z := _zoom
		for b in [Vector2(-2, 2), Vector2(3, 1), Vector2(0, -1)]:
			draw_rect(Rect2(tl + (Vector2(4, 8) + b) * z, Vector2(z, z)), POOL_RIM.lightened(0.3))
	else:
		_draw_sunk(tl, killer, int(roundf(clampf(1.0 - (t - 0.3) / (SUPPLANT_SURFACE - 0.3), 0.0, 1.0) * h)))


## Левый верхний угол картинки фишки с центром в pos — как её ставит _draw_troop.
func _token_corner(pos: Vector2) -> Vector2:
	var side := float(BoardSchematic.SLOT_R * 2 + 1)
	return pos - Vector2(side, side) * 0.5 * _zoom


## Фишка owner, опущенная на sunk пикселей схемы: всё, что ниже её обычного
## низа, — в луже и не рисуется.
func _draw_sunk(tl: Vector2, owner: String, sunk: int) -> void:
	var tex := _token(troop_colour(owner), "" if owner == GameState.WHITE else PlayerProfile.emblem_of(owner))
	var side := int(tex.get_size().x)
	if sunk >= side:
		return
	draw_texture_rect_region(tex, Rect2(tl + Vector2(0, sunk) * _zoom, Vector2(side, side - sunk) * _zoom),
		Rect2(0, 0, side, side - sunk))


## Лужа тени полушириной rx пикселей схемы; её средняя строка — у низа фишки.
## Строками целых пикселей: овал из примитивов на пиксельной схеме мылится.
func _draw_pool(tl: Vector2, rx: int) -> void:
	var z := _zoom
	var r := BoardSchematic.SLOT_R
	var ry := maxi(1, int(roundf(rx / 2.5)))
	for pass_i in 2:
		var ax := rx - pass_i
		var ay := ry - pass_i
		if ax < 1 or ay < 0:
			continue
		for y in range(-ay, ay + 1):
			var w := int(floorf(ax * sqrt(maxf(0.0, 1.0 - pow(y / (ay + 0.5), 2.0)))))
			draw_rect(Rect2(tl + Vector2(r - w, r * 2 + y) * z, Vector2(w * 2 + 1, 1) * z),
				POOL_RIM if pass_i == 0 else POOL_COLOR)


## Половина фишки owner по линии раскола «\»: upper — верхняя правая.
func _draw_half(tl: Vector2, owner: String, upper: bool, alpha: float) -> void:
	var emblem := "" if owner == GameState.WHITE else PlayerProfile.emblem_of(owner)
	var key := "%s%s|half|%s" % [troop_colour(owner).to_html(), emblem, upper]
	if not _tokens.has(key):
		var img := SchematicPainter.token(troop_colour(owner), emblem)
		var h := img.get_width() / 2
		for y in img.get_height():
			for x in img.get_width():
				var d := (x - h) - (y - h)
				if d == 0 or (d > 0) != upper:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
		_tokens[key] = ImageTexture.create_from_image(img)
	var tex: ImageTexture = _tokens[key]
	draw_texture_rect(tex, Rect2(tl, tex.get_size() * _zoom), false, Color(1, 1, 1, alpha))


## Череп над фишкой с углом tl, поднятый на lift пикселей схемы над её верхом.
## Сначала тёмная обводка, потом сам череп — читается и на светлой плашке.
func _draw_skull(tl: Vector2, lift: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var z := _zoom
	var origin := tl + Vector2(BoardSchematic.SLOT_R - 2, -lift - 2) * z
	for outline in [true, false]:
		for y in SKULL.size():
			var row: String = SKULL[y]
			for x in row.length():
				if row[x] != "#":
					continue
				var cell := Rect2(origin + Vector2(x, y) * z, Vector2(z, z))
				if outline:
					draw_rect(cell.grow(z), Color(0.05, 0.03, 0.08, 0.8 * alpha))
				else:
					draw_rect(cell, Color(SKULL_COLOR, alpha))


# --- подсветка мест со строки сводки -----------------------------------------

## Зажечь места places (строка действия в сводке под мышью, см.
## TurnFeed.places_hovered); пустой список гасит. Место — "slot:<id>" (кольцо
## вокруг места и рамка его локации), "kill:<slot_id>" (кольцо и череп над
## местом), "supplant:<slot_id>" (кольцо и лужа тени под фишкой) или
## "site:<id>" (рамка локации).
func show_places(places: Array) -> void:
	_focus = places.duplicate()
	queue_redraw()


## Для проверок: сколько мест сейчас подсвечено со сводки.
func focus_count() -> int:
	return _focus.size()


func _draw_focus() -> void:
	if _focus.is_empty():
		return
	var k := _pulse()
	var colour := FOCUS_COLOR.lerp(Color.WHITE, 0.5 * k)
	var troops: Dictionary = _view.get("troops", {})
	for place in _focus:
		var kind := String(place).get_slice(":", 0)
		var id := String(place).substr(kind.length() + 1)
		if kind == "site":
			_outline_site(id, colour)
			continue
		var at: Variant = _slot_world(id)
		if at == null:
			continue
		var site_id := _site_of_slot(id)
		if site_id != "":
			_outline_site(site_id, colour)
		var pos: Vector2 = _to_screen(at)
		var owner := String(troops.get(id, ""))
		if kind == "supplant":
			_draw_pool(_token_corner(pos), 6)
			if owner != "":
				_draw_troop(pos, owner)
		_mark_slot(_snap(pos), colour, owner != "")
		if kind == "kill":
			_draw_skull(_token_corner(pos), 6.0, 1.0)



## Локация, которой принадлежит место slot_id, или "" (место в туннеле).
func _site_of_slot(slot_id: String) -> String:
	var sites: Dictionary = _board.get("sites", {})
	for site_id: String in sites:
		if ((sites[site_id] as Dictionary).get("slots", []) as Array).has(slot_id):
			return site_id
	return ""


## Искры из места войска — туда, где его убили или вытеснили.
func spark_at_slot(slot_id: String, colour: Color) -> void:
	var at: Variant = _slot_world(slot_id)
	if at != null:
		_burst(_to_screen(at), colour)


## Искры из середины локации — её только что захватили.
func spark_at_site(site_id: String, colour: Color) -> void:
	var centre: Variant = _site_centre(site_id)
	if centre != null:
		_burst(_to_screen(centre), colour)


func _burst(at: Vector2, colour: Color, count: int = SPARK_COUNT) -> void:
	for i in range(count):
		var angle := TAU * i / count + randf() * 0.5
		var speed := SPARK_SPEED * (0.5 + randf() * 0.8)
		var life := SPARK_LIFE * (0.7 + randf() * 0.5)
		_sparks.append({
			"pos": at,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"left": life,
			"life": life,
			"colour": colour,
		})
	set_process(true)
	queue_redraw()


## Для проверок: сколько искр сейчас в полёте.
func spark_count() -> int:
	return _sparks.size()


## Для проверок: сколько фишек ещё летит из барака.
func arriving_count() -> int:
	return _arriving.size()


## Для проверок: сколько ударных волн от приземлений сейчас расходится.
func impact_count() -> int:
	return _impacts.size()


# --- фишки, летящие из барака --------------------------------------------------

## Не рисовать фишку key, пока она летит к своему месту: приземление
## объявит land(). seconds — запас на случай, если land() так и не придёт
## (полёт оборвался): тогда фишка встанет на место сама.
func hold_arrival(key: String, seconds: float) -> void:
	_arriving[key] = {"left": seconds, "t": 0.0}
	set_process(true)
	queue_redraw()


## Насколько фишка key близка к месту (0..1) — по нему растёт тень.
func set_arrival_progress(key: String, t: float) -> void:
	if _arriving.has(key):
		(_arriving[key] as Dictionary)["t"] = clampf(t, 0.0, 1.0)
		queue_redraw()


## Фишка key долетела: встаёт на место белой вспышкой, от неё расходится
## кольцо и в стороны летит пыль. heavy — войско: ещё и доска вздрагивает;
## шпион приземляется тихо.
func land(key: String, heavy: bool = true) -> void:
	_arriving.erase(key)
	# Это войско взяло локацию — теперь, когда оно на месте, захват и
	# вспыхивает (если в ту же локацию не летит ещё одно).
	if key.begins_with("troop|"):
		var site_id := _site_of_slot(key.substr(6))
		_fire_capture_if_settled(site_id)
	var at: Variant = _arrival_spot(key)
	if at == null:
		queue_redraw()
		return
	var colour := troop_colour(_arrival_owner(key))
	_impacts.append({"key": key, "pos": at, "left": IMPACT_TIME,
		"radius": _arrival_radius(key), "colour": colour})
	_dust(at, colour)
	if heavy:
		shake(LAND_SHAKE)
	set_process(true)
	queue_redraw()


## Где на панели встаёт фишка key или null.
func _arrival_spot(key: String) -> Variant:
	var parts := key.split("|")
	if parts[0] == "troop":
		var at: Variant = _slot_world(parts[1])
		return _to_screen(at) if at != null else null
	if parts.size() == 3:
		var owners: Array = (_view.get("spies", {}) as Dictionary).get(parts[1], [])
		return _spy_spot(parts[1], maxi(owners.find(parts[2]), 0), maxi(owners.size(), 1))
	return null


func _arrival_owner(key: String) -> String:
	var parts := key.split("|")
	if parts[0] == "troop":
		return String((_view.get("troops", {}) as Dictionary).get(parts[1], ""))
	return parts[2] if parts.size() == 3 else ""


## Размер фишки key на экране (радиус): по нему тень, вспышка и кольцо.
func _arrival_radius(key: String) -> float:
	if key.begins_with("spy|"):
		return spy_half()
	return highlight_radius_world(false) * _zoom if _schematic_on() else troop_radius()


## Точка на целых экранных пикселях — как и всё на схеме.
func _snap(pos: Vector2) -> Vector2:
	var scale := window_scale()
	return (pos * scale).round() / scale


## Тень под летящей фишкой: растёт и темнеет по мере приближения — глаз
## заранее видит, куда она сядет.
func _draw_arrivals() -> void:
	for key: String in _arriving:
		var at: Variant = _arrival_spot(key)
		if at == null:
			continue
		var t: float = float((_arriving[key] as Dictionary)["t"])
		if t <= 0.0:
			continue
		var r := roundf(lerpf(0.3, 1.0, t) * _arrival_radius(key))
		if r >= 1.0:
			draw_circle(_snap(at), r, Color(0, 0, 0, lerpf(0.2, 0.6, t)))


## Приземление: первые мгновения фишка залита белым, кольцо в цвет
## владельца расходится на RING_GROW пикселей схемы и гаснет.
func _draw_impacts() -> void:
	var unit: float = maxf(1.0, roundf(_zoom))
	for imp in _impacts:
		var at := _snap(imp["pos"] as Vector2)
		var r: float = float(imp["radius"])
		var p: float = 1.0 - float(imp["left"]) / IMPACT_TIME
		if IMPACT_TIME * p < FLASH_TIME:
			draw_circle(at, r + unit, Color(1, 1, 1, 0.95))
		var ring := roundf(r + RING_GROW * unit * p)
		draw_arc(at, ring, 0, TAU, 32, Color((imp["colour"] as Color).lightened(0.35), 1.0 - p), unit)


## Пыль от приземления: низко над доской и в стороны, а не фонтаном вверх.
func _dust(at: Vector2, colour: Color) -> void:
	for i in range(DUST_COUNT):
		var side := -1.0 if i % 2 == 0 else 1.0
		var angle := (PI if side < 0.0 else 0.0) - side * randf_range(0.1, 0.55)
		var speed := SPARK_SPEED * randf_range(0.6, 1.2)
		var life := SPARK_LIFE * randf_range(0.5, 0.8)
		_sparks.append({
			"pos": at + Vector2(side * 2.0, 0),
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"left": life,
			"life": life,
			"colour": colour.lerp(Color(0.85, 0.82, 0.75), 0.5),
		})


## Центр места slot_id в глобальных координатах или null.
func slot_global(slot_id: String) -> Variant:
	var at: Variant = _slot_world(slot_id)
	if at == null or _zoom <= 0.0:
		return null
	return get_global_transform() * _to_screen(at)


## Центр ромбика шпиона owner у локации site_id в глобальных координатах или null.
func spy_global(site_id: String, owner: String) -> Variant:
	var owners: Array = (_view.get("spies", {}) as Dictionary).get(site_id, [])
	var i := owners.find(owner)
	if i < 0 or _zoom <= 0.0:
		return null
	var spot: Variant = _spy_spot(site_id, i, owners.size())
	if spot == null:
		return null
	return get_global_transform() * (spot as Vector2)


## Откуда улетает только что снятый шпион у локации site_id (глобальные
## координаты) или null. Его в виде уже нет, поэтому берём место, которое он
## занял бы последним в ряду шпионов этой локации.
func spy_departure_global(site_id: String) -> Variant:
	if _zoom <= 0.0:
		return null
	var count := ((_view.get("spies", {}) as Dictionary).get(site_id, []) as Array).size()
	var spot: Variant = _spy_spot(site_id, count, count + 1)
	return get_global_transform() * (spot as Vector2) if spot != null else null


## Фишка срывается с места slot_id (move, return) — облачко пыли там.
func dust_at_slot(slot_id: String, colour: Color) -> void:
	var at: Variant = _slot_world(slot_id)
	if at != null:
		_dust(_to_screen(at), colour)
		set_process(true)


## Место локации site_id, где стоит войско owner (стартовая расстановка
## сообщает только локацию), или "".
func troop_slot_of(site_id: String, owner: String) -> String:
	var troops: Dictionary = _view.get("troops", {})
	var site: Dictionary = (_board.get("sites", {}) as Dictionary).get(site_id, {})
	for slot_id in (site.get("slots", []) as Array):
		if String(troops.get(String(slot_id), "")) == owner:
			return String(slot_id)
	return ""


## Картинка фишки войска owner в том виде, как она нарисована на доске
## (на схеме), и её размер на экране. Для вида гексов картинки нет — null.
func troop_token(owner: String) -> Texture2D:
	if not _schematic_on():
		return null
	return _token(troop_colour(owner), "" if owner == GameState.WHITE else PlayerProfile.emblem_of(owner))


func token_zoom() -> float:
	return _zoom


func troop_radius() -> float:
	return maxf(_slot_radius_world() * _zoom, 3.0)


## Полуразмер ромбика шпиона на экране.
func spy_half() -> float:
	return maxf(4.0, _zoom * 4.0) if _schematic_on() else troop_radius() * 0.6


static func troop_colour(owner: String) -> Color:
	return NEUTRAL_TROOP_COLOR if owner == GameState.WHITE \
		else PLAYER_COLORS.get(owner, Color(0.6, 0.6, 0.6))


## Для проверок: сколько локаций сейчас вспыхивает захватом.
func capture_flashes() -> int:
	return _captures.size()


## Для проверок: доска сейчас трясётся.
func is_shaking() -> bool:
	return _shake_left > 0.0


## Тряхнуть доску: power — амплитуда в пикселях панели.
func shake(power: float) -> void:
	_shake_power = maxf(_shake_power * (_shake_left / SHAKE_TIME), power)
	_shake_left = SHAKE_TIME
	set_process(true)


func _process(delta: float) -> void:
	_shake_left = maxf(_shake_left - delta, 0.0)
	_pulse_t = fmod(_pulse_t + delta, PULSE_PERIOD)
	for site_id: String in _captures.keys():
		var left: float = float(_captures[site_id]) - delta
		if left <= 0.0:
			_captures.erase(site_id)
		else:
			_captures[site_id] = left
	for key: String in _arriving.keys():
		var arrival: Dictionary = _arriving[key]
		arrival["left"] = float(arrival["left"]) - delta
		if float(arrival["left"]) <= 0.0:
			land(key, false)
	_step_kills(delta)
	for i in range(_impacts.size() - 1, -1, -1):
		_impacts[i]["left"] = float(_impacts[i]["left"]) - delta
		if float(_impacts[i]["left"]) <= 0.0:
			_impacts.remove_at(i)
	for i in range(_sparks.size() - 1, -1, -1):
		var s: Dictionary = _sparks[i]
		s["left"] = float(s["left"]) - delta
		if float(s["left"]) <= 0.0:
			_sparks.remove_at(i)
			continue
		var vel: Vector2 = (s["vel"] as Vector2) + Vector2(0, SPARK_GRAVITY) * delta
		s["vel"] = vel
		s["pos"] = (s["pos"] as Vector2) + vel * delta

	if _shake_left <= 0.0 and _captures.is_empty() and _sparks.is_empty() \
			and _arriving.is_empty() and _impacts.is_empty() and _kills.is_empty() \
			and not _pulse_active:
		set_process(false)
	queue_redraw()


## Смещение всей картинки доски при тряске. Только целые пиксели: на дробном
## сдвиге пиксельная схема мылится.
func _shake_offset() -> Vector2:
	if _shake_left <= 0.0:
		return Vector2.ZERO
	var k := _shake_left / SHAKE_TIME
	var a := _shake_power * k * k
	return Vector2(
		roundf(sin(_shake_left * SHAKE_FREQ) * a),
		roundf(cos(_shake_left * SHAKE_FREQ * 1.37) * a * 0.7))


func _load_textures() -> void:
	_textures.clear()
	for tile: Dictionary in (_board.get("tiles", []) as Array):
		var hex_id := String(tile["hex_id"])
		if _textures.has(hex_id):
			continue
		var path := String(tile["texture"])
		if ResourceLoader.exists(path):
			_textures[hex_id] = load(path)
	_rebuild_schematic_texture()


func _rebuild_schematic_texture() -> void:
	_schematic_texture = null
	var schematic: Dictionary = _board.get("schematic", {})
	if not schematic.is_empty():
		var image := SchematicPainter.paint(schematic, art_layer, object_layer)
		image.generate_mipmaps()
		_schematic_texture = ImageTexture.create_from_image(image)


func _schematic_on() -> bool:
	return schematic_mode and _schematic_texture != null


func set_schematic_mode(on: bool) -> void:
	schematic_mode = on
	_zoom = 0.0
	queue_redraw()


## Stage 0: фон из арта гексов под схемой (см. SchematicPainter._paint_background).
func set_art_layer(on: bool) -> void:
	if art_layer == on:
		return
	art_layer = on
	_rebuild_schematic_texture()
	queue_redraw()


func set_object_layer(on: bool) -> void:
	if object_layer == on:
		return
	object_layer = on
	_rebuild_schematic_texture()
	queue_redraw()


# --- что где лежит в текущем виде ---------------------------------------------

func _slots() -> Dictionary:
	if _schematic_on():
		return (_board["schematic"] as Dictionary).get("slots", {})
	return _board.get("slots", {})


func _slot_world(slot_id: String) -> Variant:
	var slots := _slots()
	if not slots.has(slot_id):
		return null
	return Vector2(float(slots[slot_id]["x"]), float(slots[slot_id]["y"]))


func _slot_radius_world() -> float:
	return BoardSchematic.SLOT_R + 0.5 if _schematic_on() else SLOT_RADIUS_WORLD


## Box of a site on the schematic, or null in hex view.
func _site_rect(site_id: String) -> Variant:
	if not _schematic_on():
		return null
	var site: Dictionary = ((_board["schematic"] as Dictionary).get("sites", {}) as Dictionary).get(site_id, {})
	if site.is_empty():
		return null
	var r: Array = site["rect"]
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


## Центр локации в мировых координатах (среднее её слотов) или null.
func _site_centre(site_id: String) -> Variant:
	var rect: Variant = _site_rect(site_id)
	if rect != null:
		return (rect as Rect2).get_center()
	var sites: Dictionary = _board.get("sites", {})
	if not sites.has(site_id):
		return null
	var centre := Vector2.ZERO
	var counted := 0
	for slot_id in ((sites[site_id] as Dictionary)["slots"] as Array):
		var at: Variant = _slot_world(String(slot_id))
		if at != null:
			centre += at
			counted += 1
	return centre / counted if counted > 0 else null


func _zoom_limits() -> Vector2:
	return Vector2(SCHEMATIC_ZOOM_MIN, SCHEMATIC_ZOOM_MAX) if _schematic_on() else Vector2(ZOOM_MIN, ZOOM_MAX)


# --- преобразование мир <-> экран --------------------------------------------

func _board_rect() -> Rect2:
	if _schematic_on():
		# Без пустых полей картинки (IMAGE_MARGIN): доска на четверых бывает на
		# пару пикселей шире зоны, и из-за полей её ужимало бы вдвое. Поля же
		# пусть лучше уйдут за край — зона доски их обрезает.
		return Rect2(Vector2.ZERO, _schematic_texture.get_size()) \
			.grow(-float(BoardSchematic.IMAGE_MARGIN))
	var tiles: Array = _board.get("tiles", [])
	if tiles.is_empty():
		return Rect2()
	var radius: float = float(_board.get("hex_radius_px", 254.0))
	var rect := Rect2(Vector2(float(tiles[0]["x"]), float(tiles[0]["y"])), Vector2.ZERO)
	for tile: Dictionary in tiles:
		var c := Vector2(float(tile["x"]), float(tile["y"]))
		rect = rect.expand(c - Vector2(radius, radius)).expand(c + Vector2(radius, radius))
	return rect


## Во сколько раз окно растягивает расчётный экран 960x540. Игра стартует в
## полный экран на 1920x1080, то есть обычно это 2; в окне 960x540 — 1.
func window_scale() -> float:
	var vp := get_viewport()
	if vp == null:
		return 1.0
	var scale: float = vp.get_final_transform().get_scale().x
	return maxf(roundf(scale), 1.0)


## Масштаб схемы: самый крупный из тех, при которых один пиксель схемы
## занимает ЦЕЛОЕ число экранных пикселей и вся доска ещё влезает в зону.
## При растяжении окна вдвое это шаги 1/2, но крупнее 1:1 схема не бывает:
## каждый её пиксель ложится ровно в два экранных и остаётся чётким. Мельче
## 1:1 — только если окно меньше самой схемы.
func _fit_zoom() -> float:
	var span := _board_rect().size
	if span.x <= 0.0 or span.y <= 0.0:
		return 0.2
	var limits := _zoom_limits()
	var fit := minf(size.x / span.x, size.y / span.y)
	if not _schematic_on():
		return clampf(fit, limits.x, limits.y)
	var scale := window_scale()
	# Не крупнее 1:1, даже если на полном экране схема влезла бы в 1.5 раза
	# (решение владельца, 2026-09-27): один масштаб доски на любом экране.
	var steps := mini(floori(fit * scale + 0.001), roundi(scale))
	if steps >= 1:
		return clampf(float(steps) / scale, limits.x, limits.y)
	# Окно меньше самой схемы (расчётный размер один к одному): показываем
	# её целиком — пусть мягко, но без обрезанных краёв.
	return clampf(fit, limits.x, limits.y)


func _board_centre() -> Vector2:
	return _board_rect().get_center()


func _ensure_view() -> void:
	if _zoom <= 0.0:
		_zoom = _fit_zoom()
		# Центр обзора — в целых мировых пикселях: тогда и войска, и рамки
		# локаций ложатся на ту же сетку, что и сама картинка схемы.
		_pan = _board_centre().round()


## Центр видимой части. Окна решений доску не сдвигают: вопрос рисуется
## поверх неё (решение владельца, 2026-09-27).
func _view_centre() -> Vector2:
	var centre := size * 0.5
	# Центр кладём на сетку ЭКРАННЫХ пикселей: иначе схема съезжает на треть
	# пикселя и nearest рисует соседние ряды разной толщины.
	var scale := window_scale()
	return (centre * scale).round() / scale




func _to_screen(world: Vector2) -> Vector2:
	return (world - _pan) * _zoom + _view_centre()


func _to_world(screen: Vector2) -> Vector2:
	return (screen - _view_centre()) / _zoom + _pan


## Для пингов (Tab): точка доски в координатах схемы и обратно — так метка
## ложится на то же место доски у любого игрока.
func world_at(local: Vector2) -> Vector2:
	_ensure_view()
	return _to_world(local)


func local_of_world(world: Vector2) -> Vector2:
	_ensure_view()
	return _to_screen(world)


# --- отрисовка ----------------------------------------------------------------

func _draw() -> void:
	_pulse_active = false
	if _board.is_empty():
		return
	_ensure_view()

	# Вся доска рисуется со смещением тряски: дальше координаты считаются как
	# обычно, и ни один расчёт о тряске не знает.
	var shake := _shake_offset()
	if shake != Vector2.ZERO:
		draw_set_transform(shake)

	if _schematic_on():
		# Пиксель-арт: пока пиксель схемы занимает целое число экранных,
		# рисуем nearest — «жёсткими» квадратами. Мягкий фильтр остаётся
		# только для запасного случая (окно меньше самой схемы).
		var scale := window_scale()
		var steps := _zoom * scale
		var crisp: bool = absf(steps - roundf(steps)) < 0.01
		var filter := TEXTURE_FILTER_NEAREST if crisp else TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if texture_filter != filter:
			texture_filter = filter
		var origin := _to_screen(Vector2.ZERO)
		origin = (origin * scale).round() / scale
		draw_texture_rect(_schematic_texture, Rect2(origin, _schematic_texture.get_size() * _zoom), false)
	else:
		for tile: Dictionary in (_board.get("tiles", []) as Array):
			var texture: Texture2D = _textures.get(String(tile["hex_id"]))
			if texture == null:
				continue
			var centre := _to_screen(Vector2(float(tile["x"]), float(tile["y"])))
			# Рисуем в системе координат тайла: начало — геометрический центр
			# шестиугольника, поворот вокруг него же (вокруг начала координат арта
			# тайлы разъезжаются — claude/progress.md, ошибка 12).
			draw_set_transform(centre + shake, deg_to_rad(float(tile["rotation_deg"])), Vector2(_zoom, _zoom))
			draw_texture(texture, -Vector2(float(tile["tex_centre_x"]), float(tile["tex_centre_y"])))
		draw_set_transform(shake, 0.0, Vector2.ONE)

	_draw_control_fills()
	_draw_marker_icons()
	_draw_a2_frame()
	_draw_a2_plate()

	var slots := _slots()
	var troops: Dictionary = _view.get("troops", {})
	var legal: Dictionary = _view.get("legal", {})
	var deployable: Array = legal.get("deploy_slots", [])
	var killable: Array = legal.get("assassinate_slots", [])
	var radius: float = maxf(_slot_radius_world() * _zoom, 3.0)
	var busy := _kill_slots()

	for slot_id: String in slots.keys():
		var pos := _to_screen(Vector2(float(slots[slot_id]["x"]), float(slots[slot_id]["y"])))
		if pos.x < -radius or pos.y < -radius or pos.x > size.x + radius or pos.y > size.y + radius:
			continue
		var owner := String(troops.get(slot_id, ""))
		# Войско ещё летит из барака или на месте идёт убийство (его фишки
		# рисует _draw_kills) — место пока выглядит пустым.
		if _arriving.has("troop|" + slot_id) or busy.has(slot_id):
			owner = ""
		# Пустое место ничем не рисуем: круги под войска уже есть на арте тайла
		# и на схеме. Куда можно ставить — показывает зелёная подсветка ниже.
		if owner != "":
			_draw_troop(pos, owner)

		if deployable.has(slot_id):
			_mark_slot(pos, DEPLOY_COLOR, owner != "")
		elif killable.has(slot_id):
			_mark_slot(pos, KILL_COLOR, owner != "")

	_draw_kills()
	_draw_focus()
	_draw_arrivals()
	_draw_spies()
	_draw_spy_targets()
	_draw_decision_targets()
	_draw_captures()
	_draw_impacts()
	_draw_sparks()


## Фишка войска owner с центром в pos (координаты панели).
func _draw_troop(pos: Vector2, owner: String) -> void:
	var colour := troop_colour(owner)
	if _schematic_on():
		var token := _token(colour, "" if owner == GameState.WHITE else PlayerProfile.emblem_of(owner))
		draw_texture_rect(token, Rect2(pos - token.get_size() * 0.5 * _zoom, token.get_size() * _zoom), false)
	else:
		var radius: float = maxf(_slot_radius_world() * _zoom, 3.0)
		draw_circle(pos, radius, Color(0, 0, 0, 0.75))
		draw_circle(pos, radius * 0.82, colour)


## Искры рисуются последними — поверх войск и подсветок. Пока искра молодая,
## она в два пикселя, дальше — в один.
func _draw_sparks() -> void:
	# Размер искры считается в пикселях СХЕМЫ: когда доска приближена, её
	# пиксель занимает несколько экранных, и искра должна расти вместе с ней.
	var unit: float = maxf(1.0, roundf(_zoom))
	for s in _sparks:
		var k: float = float(s["left"]) / float(s["life"])
		var side: float = unit * (2.0 if k > 0.45 else 1.0)
		draw_rect(Rect2((s["pos"] as Vector2).round(), Vector2(side, side)),
			Color((s["colour"] as Color).lightened(0.2), k))


## Контролируемые локации заливаются цветом хозяина поверх схемы, под
## войсками: контроль — 30%, полный контроль — 60%. Только на схеме: в виде
## гексов у локации нет коробки.
func _draw_control_fills() -> void:
	var control: Dictionary = _view.get("site_control", {})
	var total: Array = _view.get("site_total_control", [])
	var scale := window_scale()
	for site_id: String in control:
		var rect: Variant = _site_rect(site_id)
		if rect == null:
			continue
		var colour: Color = PLAYER_COLORS.get(String(control[site_id]), Color(0.8, 0.8, 0.8))
		var alpha: float = CONTROL_FILL_TOTAL if total.has(site_id) else CONTROL_FILL
		var r := rect as Rect2
		var top_left := (_to_screen(r.position) * scale).round() / scale
		var bottom_right := (_to_screen(r.end) * scale).round() / scale
		draw_rect(Rect2(top_left, bottom_right - top_left), Color(colour, alpha))


## Столбик значков города с маркером контроля, слева от мест (решение
## владельца, 2026-09-28): «◆1» — Influence за контроль, «корона N» — VP за
## полный контроль. Пока награды нет, значок чёрный, как текст коробки;
## когда есть — в цвет хозяина.
func _draw_marker_icons() -> void:
	if not _schematic_on():
		return
	var control: Dictionary = _view.get("site_control", {})
	var total: Array = _view.get("site_total_control", [])
	var sites: Dictionary = (_board["schematic"] as Dictionary).get("sites", {})
	var scale := window_scale()
	var px := _zoom
	for site_id: String in sites:
		var site: Dictionary = sites[site_id]
		if not bool(site.get("marker", false)) or not site.has("icons_at"):
			continue
		var at: Array = site["icons_at"]
		var tl := (_to_screen(Vector2(float(at[0]), float(at[1]))) * scale).round() / scale
		var owner := String(control.get(site_id, ""))
		var lit: Color = PLAYER_COLORS.get(owner, SchematicPainter.INK)
		var inf: Color = lit if owner != "" else SchematicPainter.INK
		var vp: Color = lit if total.has(site_id) else SchematicPainter.INK
		_draw_bits(tl, INFLUENCE_WEB, inf, px)
		_draw_bits(tl + Vector2(6, 0) * px, PixelFontSmall.glyph("1"), inf, px)
		_draw_bits(tl + Vector2(0, 6) * px, MARKER_CROWN, vp, px)
		_draw_bits(tl + Vector2(6, 6) * px, PixelFontSmall.glyph(str(site.get("marker_vp", 0))), vp, px)


## Подсказка над городом с маркером: что он даёт и кому.
func _get_tooltip(at_position: Vector2) -> String:
	if not _schematic_on():
		return ""
	var world := _to_world(at_position)
	var sites: Dictionary = (_board["schematic"] as Dictionary).get("sites", {})
	for site_id: String in sites:
		var site: Dictionary = sites[site_id]
		if bool(site.get("marker", false)) and (_site_rect(site_id) as Rect2).grow(1.0).has_point(world):
			return _marker_hint(site_id, site)
	var a2 := _a2_rect()
	if a2.has_area() and a2.has_point(world):
		return _a2_hint()
	return ""


# --- бонус гекса A2 -------------------------------------------------------------
# Решение владельца (2026-09-28): пунктирная рамка вокруг трёх городов и
# таблички ярусов, в цвет того, кто контролирует все три; подсказка при
# наведении.

## Три города бонуса A2: [site_id], пусто, если гекса нет на доске.
func _a2_sites() -> Array[String]:
	var result: Array[String] = []
	if not _schematic_on():
		return result
	var sites: Dictionary = (_board["schematic"] as Dictionary).get("sites", {})
	for site_id: String in sites:
		if ClusterBonus.SITE_NAMES.has(String((sites[site_id] as Dictionary).get("name", ""))):
			result.append(site_id)
	return result if result.size() == ClusterBonus.SITE_NAMES.size() else ([] as Array[String])


## Рамка вокруг трёх городов A2 и таблички ярусов, в мировых координатах.
func _a2_rect() -> Rect2:
	var ids := _a2_sites()
	if ids.is_empty():
		return Rect2()
	var r := _site_rect(ids[0]) as Rect2
	for site_id in ids:
		r = r.merge(_site_rect(site_id) as Rect2)
	var plate := _a2_plate()
	if plate.has_area():
		r = r.merge(plate)
	return r.grow(3.0)


## Табличка ярусов A2: 3 строки «уровень + награды». Уровень — 1, 2 или 3
## точки 2x2 (решение владельца, 2026-09-28).
const A2_DOTS := [
	["00000000", "11000000", "11000000", "00000000", "00000000"],
	["00000000", "11011000", "11011000", "00000000", "00000000"],
	["00000000", "11011011", "11011011", "00000000", "00000000"],
]
const A2_SWORD := ["00100", "00100", "00100", "01110", "00100"]
## Награды ярусов: [значок, число].
const A2_ROWS := [
	[["influence", 1]],
	[["influence", 1], ["power", 1], ["vp", 1]],
	[["influence", 2], ["power", 2], ["vp", 4]],
]


## Место таблички — узел раскладки схемы (BoardSchematic.A2_LEGEND): соседи
## и туннели её уже обходят. Пусто, если гекса A2 нет.
func _a2_plate() -> Rect2:
	if not _schematic_on():
		return Rect2()
	var r: Array = (_board["schematic"] as Dictionary).get("a2_legend", [])
	if r.size() != 4:
		return Rect2()
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


## Табличка без подложки и рамки: значки и цифры белые. Строки 2 и 3
## (контроль, полный контроль) — в цвет того, кто их держит. Строка 1
## (войска во всех трёх) бывает у нескольких игроков сразу: у одного —
## в его цвет, у нескольких — белая, а справа квадратики их цветов.
func _draw_a2_plate() -> void:
	var plate := _a2_plate()
	if not plate.has_area():
		return
	var state := _a2_state()
	var troopers: Array = state["troopers"]
	var px := _zoom
	var scale := window_scale()
	var tl := (_to_screen(plate.position) * scale).round() / scale
	for row in 3:
		var ink := Color.WHITE
		if row == 0 and troopers.size() == 1:
			ink = PLAYER_COLORS.get(String(troopers[0]), ink)
		elif row > 0 and int(state["tier"]) == row + 1:
			ink = PLAYER_COLORS.get(String(state["holder"]), ink)
		var at := tl + Vector2(3, 3 + row * 7) * px
		_draw_bits(at, A2_DOTS[row], ink, px)
		var x := 10
		for reward: Array in (A2_ROWS[row] as Array):
			var icon: Array = INFLUENCE_WEB
			if reward[0] == "power":
				icon = A2_SWORD
			elif reward[0] == "vp":
				icon = MARKER_CROWN
			_draw_bits(at + Vector2(x, 0) * px, icon, ink, px)
			_draw_bits(at + Vector2(x + 6, 0) * px, PixelFontSmall.glyph(str(reward[1])), ink, px)
			x += 10
		if row == 0 and troopers.size() > 1:
			for i in troopers.size():
				draw_rect(Rect2(at + Vector2(x + 1 + i * 4, 1) * px, Vector2(3, 3) * px),
					PLAYER_COLORS.get(String(troopers[i]), Color.WHITE))


## Кто сейчас что получает с A2:
##   tier   — 3 полный контроль, 2 контроль всех трёх, 0 ни то ни другое;
##   holder — чей это контроль (один игрок или "");
##   troopers — у кого войска во всех трёх, кроме holder (он получает свой,
##              старший ярус): им ярус 1, их может быть несколько.
func _a2_state() -> Dictionary:
	var ids := _a2_sites()
	var control: Dictionary = _view.get("site_control", {})
	var total: Array = _view.get("site_total_control", [])
	var owner := String(control.get(ids[0], ""))
	var all_same := owner != ""
	var all_total := true
	for site_id in ids:
		if String(control.get(site_id, "")) != owner:
			all_same = false
		if not total.has(site_id):
			all_total = false
	var holder := owner if all_same else ""
	var troops: Dictionary = _view.get("troops", {})
	var present := {}
	var sites: Dictionary = (_board["schematic"] as Dictionary)["sites"]
	for site_id in ids:
		var here := {}
		for slot_id: String in ((sites[site_id] as Dictionary)["slots"] as Dictionary):
			var who := String(troops.get(slot_id, ""))
			if who != "" and who != GameState.WHITE:
				here[who] = true
		for who: String in here:
			present[who] = int(present.get(who, 0)) + 1
	var troopers: Array = []
	for who: String in present:
		if int(present[who]) == ids.size() and who != holder:
			troopers.append(who)
	troopers.sort()
	return {"tier": (3 if all_total else 2) if all_same else 0, "holder": holder, "troopers": troopers}


## Пунктирная рамка: золотая, у держателя контроля всех трёх — в его цвет.
func _draw_a2_frame() -> void:
	var r := _a2_rect()
	if not r.has_area():
		return
	var state := _a2_state()
	var colour: Color = SchematicPainter.MARKER_EDGE
	if int(state["tier"]) >= 2:
		colour = PLAYER_COLORS.get(String(state["holder"]), colour)
	var px := _zoom
	var scale := window_scale()
	var tl := (_to_screen(r.position) * scale).round() / scale
	var w := int(r.size.x)
	var h := int(r.size.y)
	# Чужой город у края рамки: пунктир под его коробкой не рисуется.
	var foreign: Array[Rect2] = []
	var ids := _a2_sites()
	for site_id: String in ((_board["schematic"] as Dictionary).get("sites", {}) as Dictionary):
		var box := (_site_rect(site_id) as Rect2).grow(1.0)
		if not ids.has(site_id) and box.intersects(r):
			foreign.append(box)
	var dots: Array[Vector2] = []
	for x in w:
		if (x / 3) % 2 == 0:
			dots.append(Vector2(x, 0))
			dots.append(Vector2(x, h - 1))
	for y in h:
		if (y / 3) % 2 == 0:
			dots.append(Vector2(0, y))
			dots.append(Vector2(w - 1, y))
	for d in dots:
		var world := r.position + d + Vector2(0.5, 0.5)
		if foreign.any(func(b: Rect2) -> bool: return b.has_point(world)):
			continue
		draw_rect(Rect2(tl + d * px, Vector2(px, px)), colour)


func _a2_hint() -> String:
	var state := _a2_state()
	var now: Array[String] = []
	match int(state["tier"]):
		3: now.append("%s — total control of all 3" % EventLogPanel.player_name(String(state["holder"])))
		2: now.append("%s — control of all 3" % EventLogPanel.player_name(String(state["holder"])))
	var names: Array[String] = []
	for who in (state["troopers"] as Array):
		names.append(EventLogPanel.player_name(String(who)))
	if not names.is_empty():
		now.append("%s — troops in all 3" % ", ".join(names))
	if now.is_empty():
		now.append("nobody")
	return "\n".join(["A2 BONUS: FOGTOWN, GALLENGHAST, DARKFLAME",
		"Troops in all 3: +1 Influence",
		"Control all 3: +1 Influence, +1 Power, +1 VP",
		"Total control of all 3: +2 Influence, +2 Power, +4 VP",
		"Paid as soon as reached: Influence and Power at once, VP at the end of the turn",
		"Now: " + "; ".join(now)])


func _marker_hint(site_id: String, site: Dictionary) -> String:
	var lines: Array[String] = [String(site.get("name", "")).to_upper(),
		"Control: +1 Influence each turn",
		"Total control: +%d VP at the end of your turn" % int(site.get("marker_vp", 0))]
	var owner := String((_view.get("site_control", {}) as Dictionary).get(site_id, ""))
	if owner == "":
		lines.append("Nobody controls it")
	elif (_view.get("site_total_control", []) as Array).has(site_id):
		lines.append("%s: total control" % EventLogPanel.player_name(owner))
	else:
		lines.append("%s: control" % EventLogPanel.player_name(owner))
	return "\n".join(lines)


## Рисунок из строк "0/1" пикселями схемы размера px.
func _draw_bits(tl: Vector2, rows: Array, colour: Color, px: float) -> void:
	for ry in rows.size():
		var row: String = rows[ry]
		for rx in row.length():
			if row[rx] == "1":
				draw_rect(Rect2(tl + Vector2(rx, ry) * px, Vector2(px, px)), colour)


## Только что захваченные локации: обводка в цвет нового хозяина, гаснущая
## вместе со вспышкой. Толщина в два пикселя — обводка выбора цели рисуется
## в один, и их не спутать.
func _draw_captures() -> void:
	for site_id: String in _captures:
		var owner := String(_control.get(site_id, ""))
		var colour: Color = PLAYER_COLORS.get(owner, Color(0.8, 0.8, 0.8))
		var k: float = float(_captures[site_id]) / CAPTURE_TIME
		_outline_site(site_id, Color(colour.lightened(0.25), k))


## Радиус кольца подсветки на схеме, в мировых пикселях: по самому кружку
## места, а вокруг фишки — на полпикселя шире (кружок 9 px при шаге 9).
## Больше делать нельзя: шаг между
## местами BoardSchematic.SLOT_PITCH, и кольца соседей начнут пересекаться
## (проверяется тестом).
static func highlight_radius_world(occupied: bool) -> float:
	return BoardSchematic.SLOT_R + (0.5 if occupied else 0.0)


## Подсветка одного места: пустое — бледной «заготовкой» войска внутри самого
## кружка, занятое — тонким кольцом вплотную вокруг фишки.
##
## Раньше вокруг каждого места рисовалась окружность радиусом слот+3 px. Шаг
## между местами на схеме — 10 px, поэтому в локации с восемью местами (Wells
## of Darkness) кольца налезали друг на друга и превращались в зелёное месиво,
## закрывавшее название локации. Теперь подсветка не выходит за половину шага,
## а её линия ложится на целые экранные пиксели — как и вся остальная схема.
func _mark_slot(pos: Vector2, colour: Color, occupied: bool) -> void:
	var scale := window_scale()
	var at := (pos * scale).round() / scale
	var width: float
	var r: float
	if _schematic_on():
		width = maxf(1.0, roundf(_zoom))
		r = highlight_radius_world(occupied) * _zoom
	else:
		r = _slot_radius_world() * _zoom * (1.18 if occupied else 1.0)
		width = maxf(2.0, r * 0.16)
	var k := _pulse()
	# Тёмная обводка изнутри кольца — чтобы оно читалось на светлом арте.
	# Изнутри, а не снаружи: наружу нельзя, упрёмся в кольцо соседа.
	draw_arc(at, maxf(r - width, 1.0), 0, TAU, 24, Color(0, 0, 0, 0.75), width)
	# Пустое место подкрашиваем мерцающей заливкой, но не до полной яркости:
	# иначе оно станет неотличимо от фишки зелёного игрока.
	if not occupied:
		draw_circle(at, maxf(r - width * 0.5, 1.0), Color(colour, lerpf(0.2, 0.55, k)))
	draw_arc(at, r, 0, TAU, 24, colour.lerp(Color.WHITE, 0.45 * k), width)


## Фаза мерцания подсказок: 0..1 по синусу. Заодно будит _process, чтобы
## подсказка мерцала, даже когда больше ничего не анимируется.
func _pulse() -> float:
	if not _pulse_active:
		_pulse_active = true
		if not is_processing():
			set_process(true)
	return 0.5 - 0.5 * cos(TAU * _pulse_t / PULSE_PERIOD)


func _token(colour: Color, emblem: String = "") -> ImageTexture:
	var key := colour.to_html() + emblem
	if not _tokens.has(key):
		_tokens[key] = ImageTexture.create_from_image(SchematicPainter.token(colour, emblem))
	return _tokens[key]


## Кольцо вокруг локации: на схеме — рамка вокруг её прямоугольника.
func _outline_site(site_id: String, colour: Color) -> void:
	var radius: float = maxf(_slot_radius_world() * _zoom, 3.0)
	var rect: Variant = _site_rect(site_id)
	if rect != null:
		var r := rect as Rect2
		# Рамка идёт по целым экранным пикселям и отступает от коробки ровно на
		# свою толщину — иначе линия «плывёт» и местами двоится.
		var scale := window_scale()
		var width: float = maxf(1.0, roundf(_zoom))
		var top_left := (_to_screen(r.position) * scale).round() / scale
		var bottom_right := (_to_screen(r.end) * scale).round() / scale
		draw_rect(Rect2(top_left, bottom_right - top_left).grow(width), colour, false, width)
		return
	var centre: Variant = _site_centre(site_id)
	if centre != null:
		draw_arc(_to_screen(centre), radius * 2.4, 0, TAU, 32, colour, maxf(2.0, radius * 0.22))


## Шпионы стоят не в троп-слотах, а «у названия локации» (рулбук стр. 12),
## поэтому рисуем их ромбиками над локацией.
func _draw_spies() -> void:
	var spies: Dictionary = _view.get("spies", {})
	if spies.is_empty():
		return
	var d := spy_half()
	for site_id: String in spies.keys():
		var owners: Array = spies[site_id]
		for i in range(owners.size()):
			# Ещё летит из барака — место за ним держим, но не рисуем.
			if _arriving.has("spy|%s|%s" % [site_id, String(owners[i])]):
				continue
			var spot: Variant = _spy_spot(site_id, i, owners.size())
			if spot == null:
				continue
			var colour: Color = PLAYER_COLORS.get(String(owners[i]), Color(0.7, 0.7, 0.7))
			var at: Vector2 = spot
			var diamond := PackedVector2Array([
				at + Vector2(0, -d), at + Vector2(d, 0), at + Vector2(0, d), at + Vector2(-d, 0)])
			draw_colored_polygon(diamond, colour)
			draw_polyline(diamond + PackedVector2Array([at + Vector2(0, -d)]), Color(0, 0, 0, 0.8), 1.5)


## Центр i-го из count ромбиков шпионов у локации (координаты панели) или null.
func _spy_spot(site_id: String, i: int, count: int) -> Variant:
	var d := spy_half()
	var pos: Vector2
	var rect: Variant = _site_rect(site_id)
	if rect != null:
		# above the box, on the tunnel-free strip over its name
		pos = _to_screen(Vector2((rect as Rect2).get_center().x, (rect as Rect2).position.y)) - Vector2(0, d + 2.0)
	else:
		var centre: Variant = _site_centre(site_id)
		if centre == null:
			return null
		pos = _to_screen(centre) - Vector2(0, troop_radius() * 2.2)
	return pos + Vector2((i - (count - 1) * 0.5) * d * 2.4, 0)


## Цели pending-решения (target_slot/target_site/target_return) подсвечиваются
## прямо на доске золотым кольцом — игрок выбирает клетку/локацию кликом, а не
## строкой в диалоге (см. decision_dialog.gd). target_return кодирует составные
## цели "troop|<slot_id>" и "spy|<site_id>|<owner>" — те же префиксы, что и в
## decision_dialog.gd::_board_label.
func _draw_decision_targets() -> void:
	var pending: Dictionary = _view.get("pending_decision", {})
	if pending.is_empty():
		return
	var choice_type := String(pending.get("choice_type", ""))
	if choice_type != "target_slot" and choice_type != "target_site" and choice_type != "target_return":
		return

	var slot_targets: Dictionary = {}
	var site_targets: Dictionary = {}
	var spy_targets: Array = []
	for opt in (pending.get("legal_options", []) as Array):
		var raw := String(opt)
		if raw == "":
			continue
		if choice_type == "target_slot":
			slot_targets[raw] = true
		elif choice_type == "target_site":
			site_targets[raw] = true
		elif raw.begins_with("troop|"):
			slot_targets[raw.substr(6)] = true
		elif raw.begins_with("spy|"):
			var rest: PackedStringArray = raw.substr(4).rsplit("|", true, 1)
			if rest.size() == 2:
				spy_targets.append(rest)

	var troops: Dictionary = _view.get("troops", {})
	for slot_id: String in slot_targets.keys():
		var at: Variant = _slot_world(slot_id)
		if at != null:
			_mark_slot(_to_screen(at), DECISION_COLOR, String(troops.get(slot_id, "")) != "")
	for site_id: String in site_targets.keys():
		_outline_site(site_id, DECISION_COLOR)
	for pair in spy_targets:
		_ring_spy(String(pair[0]), String(pair[1]), DECISION_COLOR)


## Вражеские шпионы, которых можно вернуть за 3 Power, — оранжевой рамкой
## вокруг самого ромбика (не всей локации: выбирают кликом по шпиону).
func _draw_spy_targets() -> void:
	var targets: Array = (_view.get("legal", {}) as Dictionary).get("return_spy", [])
	for t in targets:
		_ring_spy(String((t as Dictionary)["site_id"]), String((t as Dictionary)["spy_owner"]), KILL_COLOR)


## Рамка вокруг ромбика конкретного шпиона — его можно выбрать кликом.
func _ring_spy(site_id: String, owner: String, colour: Color) -> void:
	var owners: Array = (_view.get("spies", {}) as Dictionary).get(site_id, [])
	var i := owners.find(owner)
	if i == -1:
		return
	var spot: Variant = _spy_spot(site_id, i, owners.size())
	if spot == null:
		return
	var at: Vector2 = spot
	var d := spy_half() + 2.0
	var ring := PackedVector2Array([
		at + Vector2(0, -d), at + Vector2(d, 0), at + Vector2(0, d), at + Vector2(-d, 0), at + Vector2(0, -d)])
	draw_polyline(ring, colour, 1.0)


## Навести обзор на точку доски с заданным масштабом. Нужно интерфейсу
## (например, показать место, где что-то произошло) и проверкам скриншотами.
func focus_on(world_point: Vector2, zoom_level: float) -> void:
	var limits := _zoom_limits()
	_zoom = clampf(zoom_level, limits.x, limits.y)
	_pan = world_point
	queue_redraw()


# --- ввод ---------------------------------------------------------------------

## Размер зоны изменился (окно, полноэкранный режим) — доску вписываем заново.
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_zoom = 0.0
		queue_redraw()


## Единственное действие мышью: выбрать войско или локацию. Масштаба и
## перетаскивания у зафиксированной доски нет.
func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		_click_at(mb.position)
		accept_event()


## Попадание по шпиону, затем по ближайшему слоту, а если рядом слота нет —
## по локации (для решений, где цель — сама локация).
func _click_at(screen_point: Vector2) -> void:
	# Ромбик шпиона — самая мелкая цель, проверяем его первым, иначе клик
	# уходил в ближайший слот или во всю локацию и нельзя было выбрать,
	# ЧЕЙ шпион нужен.
	var spy_reach: float = maxf(spy_half() * 1.3, 5.0)
	var spies: Dictionary = _view.get("spies", {})
	for site_id: String in spies.keys():
		var owners: Array = spies[site_id]
		for i in range(owners.size()):
			var spot: Variant = _spy_spot(site_id, i, owners.size())
			if spot != null and screen_point.distance_to(spot) <= spy_reach:
				spy_clicked.emit(site_id, String(owners[i]))
				return

	var slots := _slots()
	var reach: float = maxf(_slot_radius_world() * _zoom * 1.4, 10.0)
	var best := ""
	var best_dist := reach
	for slot_id: String in slots.keys():
		var pos := _to_screen(Vector2(float(slots[slot_id]["x"]), float(slots[slot_id]["y"])))
		var d := screen_point.distance_to(pos)
		if d < best_dist:
			best_dist = d
			best = slot_id
	if best != "":
		slot_clicked.emit(best)
		return

	var sites: Dictionary = _board.get("sites", {})
	var world := _to_world(screen_point)
	var best_site := ""
	var best_site_dist: float = maxf(_slot_radius_world() * _zoom * 3.0, 24.0)
	for site_id: String in sites.keys():
		var rect: Variant = _site_rect(site_id)
		if rect != null:
			if (rect as Rect2).grow(2.0).has_point(world):
				best_site = site_id
				break
			continue
		var centre: Variant = _site_centre(site_id)
		if centre == null:
			continue
		var d2 := screen_point.distance_to(_to_screen(centre))
		if d2 < best_site_dist:
			best_site_dist = d2
			best_site = site_id
	if best_site != "":
		site_clicked.emit(best_site)
