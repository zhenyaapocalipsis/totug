class_name Intent
extends RefCounted

## Typed-намерение от клиента к серверу (этап 6, claude/architecture.md).
##
## Клиент никогда не трогает GameState напрямую — он только строит Intent и
## отдаёт его GameServer.apply_intent(). Весь рандом и вся валидация — на
## сервере (host-authoritative). Клиент — тупой рендерер + генератор Intent.
##
## Поля заполняются в зависимости от `type`; неиспользуемые остаются
## значениями по умолчанию (пустая строка / -1) и игнорируются сервером.

enum Type {
	PLAY_CARD,            # card_id
	ACTION_ASSASSINATE,   # slot_id
	ACTION_DEPLOY,        # slot_id
	ACTION_RECRUIT,       # market_index
	ACTION_RECRUIT_SUPPLY,# card_id — House Guard / Priestess of Lolth из общей стопки
	ACTION_RETURN_SPY,    # site_id, spy_owner
	MAKE_DECISION,        # answer (тип зависит от pending.choice_type)
	END_TURN,
}

var type: int
var player_id: String = ""

## PLAY_CARD
var card_id: String = ""

## ACTION_ASSASSINATE / ACTION_DEPLOY
var slot_id: String = ""

## ACTION_RECRUIT
var market_index: int = -1

## ACTION_RETURN_SPY
var site_id: String = ""
var spy_owner: String = ""

## MAKE_DECISION — сырое значение, специфичное для PendingDecision.choice_type
## (см. core/effects/pending_decision.gd): int для choose_option/target_market_index,
## bool для confirm, String для target_slot/target_site/target_card/target_player/
## target_return, null чтобы пропустить необязательное решение (choice == "" / -1
## уже обрабатывают сами эффекты).
var answer = null


func _init(intent_type: int, pid: String) -> void:
	type = intent_type
	player_id = pid


static func play_card(pid: String, cid: String) -> Intent:
	var i := Intent.new(Type.PLAY_CARD, pid)
	i.card_id = cid
	return i


static func assassinate(pid: String, slot: String) -> Intent:
	var i := Intent.new(Type.ACTION_ASSASSINATE, pid)
	i.slot_id = slot
	return i


static func deploy(pid: String, slot: String) -> Intent:
	var i := Intent.new(Type.ACTION_DEPLOY, pid)
	i.slot_id = slot
	return i


static func recruit(pid: String, index: int) -> Intent:
	var i := Intent.new(Type.ACTION_RECRUIT, pid)
	i.market_index = index
	return i


## Покупка из общей стопки рядом с маркетом (House Guard / Priestess of Lolth).
## Отдельный тип намерения, а не ACTION_RECRUIT с особым индексом: у этих карт
## нет слота на дисплее, стопка не пополняется из колоды маркета и её
## исчерпание не заканчивает партию.
static func recruit_supply(pid: String, cid: String) -> Intent:
	var i := Intent.new(Type.ACTION_RECRUIT_SUPPLY, pid)
	i.card_id = cid
	return i


static func return_spy(pid: String, site: String, owner: String) -> Intent:
	var i := Intent.new(Type.ACTION_RETURN_SPY, pid)
	i.site_id = site
	i.spy_owner = owner
	return i


static func make_decision(pid: String, ans) -> Intent:
	var i := Intent.new(Type.MAKE_DECISION, pid)
	i.answer = ans
	return i


static func end_turn(pid: String) -> Intent:
	return Intent.new(Type.END_TURN, pid)
