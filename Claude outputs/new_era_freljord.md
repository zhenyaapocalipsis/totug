# New Era: Freljord → ICEWIND DALE (этапы NE-11, NE-12, NE-17)

Полуколода Freljord из мода Runeterra Reforged на существах ледяного Севера D&D.
Ключ в коде `freljord`, тип карт `ICEWIND`, id 49600–49618, 49620, 49634–49636, эффекты `core/cards/freljord_cards.gd`,
тест `test_icewind_deck`. Картинки мода: 121–143 (127 — Troll Scout + Rimetusk Shaman),
новые чемпионы из Extra Champions: 359 Gragas (правая карта), 372 Aurora, 383 Olaf.

## Карты

| id | Существо | Карта мода | Цена | Аспект | Копий | VP |
|---|---|---|---|---|---|---|
| 49600 | Guard | Avarosan Sentry | 2 | MALICE | 2 | 1/2 |
| 49601 | Skeleton | Bone Scryer | 5 | GUILE | 3 | 3/5 |
| 49602 | Werewolf | Ruthless Raider | 4 | MALICE | 3 | 2/4 |
| 49603 | Magmin | Lorekeeper | 2 | CONQUEST | 3 | 1/3 |
| 49604 | Centaur Trooper | Icevale Archer | 3 | MALICE | 3 | 2/4 |
| 49605 | Bulette | Troll Scout | 3 | CONQUEST | 3 | 2/4 |
| 49606 | Ice Mephit | Rimetusk Shaman | 4 | AMBITION | 3 | 2/4 |
| 49607 | Invisible Stalker | Valhir's Prophet | 3 | GUILE | 2 | 2/4 |
| 49608 | Ettercap | Avarosan Trapper | 2 | GUILE | 3 | 1/3 |
| 49609 | Xorn | Avarosan Hearthguard | 3 | AMBITION | 4 | 1/3 |
| 49610 | Giant Owl | Starlit Seer | 2 | GUILE | 3 | 1/3 |
| 49611 | Winter Wolf | Murkwolf Shaman | 3 | CONQUEST | 2 | 1/3 |
| 49612 | Giant Hyena | Scarmother | 3 | CONQUEST | 2 | 2/4 |
| 49613 | Owlbear | Nunu & Willump | 6 | AMBITION | 1 | 3/6 |
| 49614 | Hill Giant | Braum | 6 | MALICE | 1 | 3/6 |
| 49615 | Cloud Giant | Lissandra | 7 | GUILE | 1 | 3/7 |
| 49616 | Remorhaz | Ashe | 7 | MALICE | 1 | 3/7 |
| 49617 | Mammoth | Sejuani | 7 | CONQUEST | 1 | 3/7 |
| 49618 | Storm Giant | Volibear | 8 | CONQUEST | 1 | 4/8 |

| 49620 | Frost Giant | Tryndamere | 7 | CONQUEST | 1 | 3/7 |

| 49634 | Pirate Captain | Gragas (картинка 359) | 6 | MALICE | 1 | 3/6 |
| 49635 | Blink Dog | Aurora (картинка 372) | 6 | MALICE | 1 | 3/7 |
| 49636 | Young White Dragon | Olaf (картинка 383) | 7 | CONQUEST | 1 | 3/6 |

**2026-10-14 (NE-17):** владелец убрал Roc (Anivia), Stone Giant (Ornn) и Giant Ape (Trundle) со всеми их механиками (Glacial Storm, Ice Pillar, лёд, Roc Egg, колода Masterwork и 10 предметов, стопка FRONT); id 49619, 49621–49633 удалены из cards.json. Вместо них — чемпионы Extra Champions мода: Gragas, Aurora, Olaf.

**2026-10-15 (NE-19):** владелец попросил вместо животных существ поинтереснее: Giant Goat → Magmin, Giant Badger → Ettercap, Giant Elk → Invisible Stalker, Boar → Xorn, Cultist Fanatic → Skeleton (id и правила те же).

Арты — D&D Beyond 2024 (у всех есть фон), лежат в `cards/freljord/`. Кандидаты `cards/freljord/cand*` — не в git.

## Толкования
- **Frostbite** срабатывает при сбросе из руки эффектом, в свой или чужой ход. **Сброс руки в конце хода — нет** (решение владельца, 2026-10-14). Все пути сброса зовут `FreljordCards.on_discard`; новые карты со сбросом тоже должны его звать.
- Valor → MALICE; Cursed Wanderer → Insane Outcast; Execute → Devour.
- Skeleton (Bone Scryer): «сброс с верха колоды» = сброс при Scry, действует до конца хода.
- Giant Hyena (Scarmother): «another player discarded» — любой сброс эффектом не текущим игроком.
- Hill Giant (Braum): отменяет сброс и Insane Outcast от соперника; «discard down to N» отменяется целиком. Принудительного Devour от соперника в игре нет — эта часть не нужна.
- Cloud Giant (Lissandra): «+2 Power и карта» — за КАЖДОГО возвращённого шпиона.
- Remorhaz (Ashe): у кого больше 4 карт — сам прячет лишние, разыгравший выбирает 1 из 4 раскрытых.
- Storm Giant (Volibear): раунд = сбрасывать по одной, «стоп» — добор; каждый следующий раунд добирает не больше, чем на 1 меньше прошлого.
- **Pirate Captain (Gragas):** «получить карту» — покупка (рынок, запас, сожранные), бесплатный найм, Insane Outcast, Twig Blight, Blade Fragment, карта из запаса в руку (`FreljordCards.note_gain`). Если за ход ничего не получил — в конце хода вопрос, карта из сыгранных ложится на верх колоды и приходит в новую руку. Если её же повысили в этот ход — вопроса нет.
- **Blink Dog (Aurora), вариант 1 (решение владельца 2026-10-14):** «hex» = локация, где есть твоё войско; войска других игроков и белые оттуда можно переставить на пустые места рядом с локацией (`slots_adjacent_to_site`). Вариант 2: до 3 своих войск куда угодно, +1 Power за каждое, вставшее рядом с войском другого игрока (не белым).
- **Young White Dragon (Olaf) (решение владельца 2026-10-14):** сам тоже считается — его 3 войска дают +3 Power. Каждое войско, поставленное картой (`DeployTroop`), до конца хода даёт +1 Power; эта Power «заперта» (`turn_flags.olaf_locked`): базовое действие Deploy и Chimera не могут её тратить, убийство и возврат шпиона тратят её первой.
- Frost Giant (Tryndamere): карта из Внутреннего круга играется и остаётся там.
