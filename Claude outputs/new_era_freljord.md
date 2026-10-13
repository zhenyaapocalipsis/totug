# New Era: Freljord → ICEWIND DALE (этапы NE-11, NE-12)

Полуколода Freljord из мода Runeterra Reforged на существах ледяного Севера D&D.
Ключ в коде `freljord`, тип карт `ICEWIND`, id 49600–49633, эффекты `core/cards/freljord_cards.gd`,
тест `test_icewind_deck`. Картинки мода: 121–143 (127 — Troll Scout + Rimetusk Shaman),
жетоны: 324 Eggnivia, 441–450 предметы Ornn.

## Карты

| id | Существо | Карта мода | Цена | Аспект | Копий | VP |
|---|---|---|---|---|---|---|
| 49600 | Guard | Avarosan Sentry | 2 | MALICE | 2 | 1/2 |
| 49601 | Cultist Fanatic | Bone Scryer | 5 | GUILE | 3 | 3/5 |
| 49602 | Werewolf | Ruthless Raider | 4 | MALICE | 3 | 2/4 |
| 49603 | Giant Goat | Lorekeeper | 2 | CONQUEST | 2 | 1/3 |
| 49604 | Centaur Trooper | Icevale Archer | 3 | MALICE | 3 | 2/4 |
| 49605 | Bulette | Troll Scout | 3 | CONQUEST | 3 | 2/4 |
| 49606 | Ice Mephit | Rimetusk Shaman | 4 | AMBITION | 3 | 2/4 |
| 49607 | Giant Elk | Valhir's Prophet | 3 | GUILE | 2 | 2/4 |
| 49608 | Giant Badger | Avarosan Trapper | 2 | GUILE | 3 | 1/3 |
| 49609 | Boar | Avarosan Hearthguard | 3 | AMBITION | 4 | 1/3 |
| 49610 | Giant Owl | Starlit Seer | 2 | GUILE | 3 | 1/3 |
| 49611 | Winter Wolf | Murkwolf Shaman | 3 | CONQUEST | 2 | 1/3 |
| 49612 | Giant Hyena | Scarmother | 3 | CONQUEST | 2 | 2/4 |
| 49613 | Owlbear | Nunu & Willump | 6 | AMBITION | 1 | 3/6 |
| 49614 | Hill Giant | Braum | 6 | MALICE | 1 | 3/6 |
| 49615 | Cloud Giant | Lissandra | 7 | GUILE | 1 | 3/7 |
| 49616 | Remorhaz | Ashe | 7 | MALICE | 1 | 3/7 |
| 49617 | Mammoth | Sejuani | 7 | CONQUEST | 1 | 3/7 |
| 49618 | Storm Giant | Volibear | 8 | CONQUEST | 1 | 4/8 |
| 49619 | Roc | Anivia | 8 | MALICE | 1 | 4/8 |
| 49620 | Frost Giant | Tryndamere | 7 | CONQUEST | 1 | 3/7 |
| 49621 | Stone Giant | Ornn | 8 | MALICE | 1 | 4/8 |
| 49622 | Giant Ape | Trundle | 6 | CONQUEST | 1 | 4/7 |

Не в рынке: 49623 Roc Egg (Eggnivia) и колода Masterwork (предметы Ornn, D&D-имена):
49624 Frost Brand (Infinity Edge), 49625 Rod of Rulership (Rod of Ages), 49626 Hat of Wizardry
(Rabadon's Deathcap), 49627 Sword of Answering (Blade of the Ruined King), 49628 Armor of
Invulnerability (Warmog's), 49629 Boots of Speed (Shurelya's), 49630 Horn of Valhalla (Trinity Force),
49631 Cloak of Elvenkind (Bloodthirster), 49632 Demon Armor (Thornmail), 49633 Scarab of Protection
(Zhonya's Hourglass).

Арты — D&D Beyond 2024 (у всех есть фон), лежат в `cards/freljord/`. Кандидаты `cards/freljord/cand*` — не в git.

## Толкования
- **Frostbite** срабатывает при сбросе из руки эффектом, в свой или чужой ход. **Сброс руки в конце хода — нет** (решение владельца, 2026-10-14). Все пути сброса зовут `FreljordCards.on_discard`; новые карты со сбросом тоже должны его звать.
- Valor → MALICE; Cursed Wanderer → Insane Outcast; Execute → Devour.
- Cultist Fanatic (Bone Scryer): «сброс с верха колоды» = сброс при Scry, действует до конца хода.
- Giant Hyena (Scarmother): «another player discarded» — любой сброс эффектом не текущим игроком.
- Hill Giant (Braum): отменяет сброс и Insane Outcast от соперника; «discard down to N» отменяется целиком. Принудительного Devour от соперника в игре нет — эта часть не нужна.
- Cloud Giant (Lissandra): «+2 Power и карта» — за КАЖДОГО возвращённого шпиона.
- Remorhaz (Ashe): у кого больше 4 карт — сам прячет лишние, разыгравший выбирает 1 из 4 раскрытых.
- Storm Giant (Volibear): раунд = сбрасывать по одной, «стоп» — добор; каждый следующий раунд добирает не больше, чем на 1 меньше прошлого.
- **Glacial Storm (Roc) и Ice Pillar (Giant Ape)** — на одну локацию, до начала следующего хода владельца (в моде у Glacial Storm срок не указан, «hex» → локация). Соперники платят там +2 Power, чтобы поставить войско (картой тоже), поставить шпиона, вытеснить любое войско или убить войско владельца. Нет Power на доплату — действие там недоступно.
- Roc Egg: лёд на своё войско в локации; в начале следующего хода, если войско стоит, Roc «откуда угодно» (колода, сброс, Внутренний круг, сожранные, рынок, чужие стопки) идёт в руку. Яйцо и лёд уходят в любом случае.
- Stone Giant (Ornn): предметы лежат перед игроком (`state.front`), эффекты «в начале хода» срабатывают сами; Scarab — только когда его эффект вызвал Stone Giant, потом уходит из игры. Колода Masterwork и Insane Outcast у доски появляются, если в рынке есть Stone Giant.
- Frost Giant (Tryndamere): карта из Внутреннего круга играется и остаётся там.
