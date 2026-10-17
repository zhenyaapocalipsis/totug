# New Era: Ixtal → CHULT (этапы NE-31…32)

Полуколода Ixtal из мода Runeterra Reforged (картинки PDF **252–272**; 273 и дальше — Arcane) на существах джунглей Чульта и рядом: люди-ящеры, юань-ти, ааракокры, Sarrukh Tyrant. Ключ `ixtal`, тип `CHULT`, id **50100–50120** (50109 свободен — **Nidalee владелец велел не делать**). Флаг `wip`: колода доступна только кнопкой CHULT в режиме NEW ERA. **NE-32 (владелец): 40 карт / 20 уникальных** — по одной копии убрано у Bandit Deceiver, Lizardfolk Warden, Aarakocra Aeromancer (4 → 3) и Minotaur Archaeologist (3 → 2).

Эффекты — `engine/godot/core/cards/ixtal_cards.gd`, тест — `test_chult_deck`, арты — `cards/ixtal/` (кандидаты `cards/ixtal/cand`, `bg`, `more`, `sky`, `giff` в git не идут), лист всех карт — `Claude outputs/chult_cards_all.png`.

## Механика Explore
Правило мода: «Look at the top 2 cards of your deck. Reveal up to one card that matches terms that you're searching for. Put the rest onto the top or bottom of your deck in any order».
- Открытая карта идёт **в руку** (так читается Milio: «put all cards matching … into your hand»).
- Игра по очереди спрашивает: (1) какую подходящую карту взять (или ни одной); (2) какие из оставшихся положить под низ колоды; (3) если наверху остаётся 2+ разных карты — в каком порядке.
- Колода пуста — сначала в неё замешивается сброс (как при доборе).
- Слово **EXPLORE** жирное, подсказка по Alt.

## Карты

| id | Существо (D&D Beyond) | Карта мода | Цена | Аспект | Копий | VP |
|---|---|---|---|---|---|---|
| 50100 | Yuan-ti Infiltrator | Neeko | 7 | Guile | 1 | 3/7 |
| 50101 | Galeb Duhr | Malphite | 8 | Conquest | 1 | 6/12 |
| 50102 | Sarrukh Tyrant | Zilean | 9 | Ambition | 1 | 4/9 |
| 50103 | Lizardfolk Sovereign | Skarner | 7 | Conquest | 1 | 3/7 |
| 50104 | Chwinga | Milio | 6 | Ambition | 1 | 3/6 |
| 50105 | Troglodyte | Rengar | 6 | Malice | 1 | 3/6 |
| 50106 | Lizardfolk Geomancer | Zyra | 7 | Conquest | 1 | 3/7 |
| 50107 | Dao | Qiyana | 6 | Malice | 1 | 3/6 |
| 50108 | Knight of Eldraine | Ezreal | 6 | Ambition | 1 | 3/6 |
| 50110 | Bandit Deceiver | Treasure Seeker | 5 | Ambition | 3 | 3/5 |
| 50111 | Lizardfolk Warden | All Terrain Trooper | 3 | Conquest | 3 | 2/4 |
| 50112 | Yuan-ti Abomination | Avenging Vastaya | 4 | Malice | 3 | 2/4 |
| 50113 | Performer Maestro | Big Game Tycoon | 4 | Ambition | 2 | 2/5 |
| 50114 | Minotaur Archaeologist | Intrepid Archaeologist | 4 | Ambition | 2 | 2/4 |
| 50115 | Living Gust of Wind | Sky Squad | 3 | Conquest | 3 | 2/4 |
| 50116 | Bullywug Bog Sage | Curious Ecologist | 3 | Malice | 3 | 1/3 |
| 50117 | Cyclops Oracle | Axiomata Monk | 3 | Malice | 3 | 2/4 |
| 50118 | Kenku | Secret Keeper | 2 | Guile | 3 | 1/3 |
| 50119 | Aarakocra Aeromancer | Landing Party | 3 | Conquest | 3 | 2/4 |
| 50120 | Bone Naga | Yun Tal Initiate | 2 | Malice | 3 | 1/3 |

Все арты — со сценой-фоном (`art_bgcheck.gd` + контакт-лист). Особенные динозавры (Aerosaur, Altisaur, Regisaur, Fastieth, Clawfoot Raptor) и Grung, Tlincalli, Kamadan, Su-monster — на D&D Beyond только вырезанные фигуры; владелец решил делать **без динозавров**. Aarakocra Skirmisher (Sky Squad) заменён на Living Gust of Wind: у его арта вырезано небо.

## Толкования (мои — проверить владельцу)
- **Yuan-ti Infiltrator (Neeko)** «Copy the previous card you played» — эффект карты, сыгранной прямо перед ней в этот ход. «Copy a card in the market» — эффект любой карты рынка (без ограничения цены); в конце хода эта карта уходит под низ колоды рынка, слот пополняется.
- **Sarrukh Tyrant (Zilean)** — лишний ход **полный** (без лимита в 3 карты, как у Basilisk). Карта продвигается в конце хода.
- **Lizardfolk Sovereign (Skarner)** «flip any of your site tokens… activate 1 of them an additional time» — у нас маркер даёт +1 Influence (контроль) и VP (тотальный контроль, в конце хода). Значит: в этот ход **все твои маркеры считаются тотальным контролем** (VP в конце хода), и **лучший из них сразу даёт награду ещё раз** (+1 Influence и его VP).
- **Chwinga (Milio)** — при Explore в этот ход все подходящие карты сразу идут в руку, без вопроса.
- **Troglodyte (Rengar)** «Keep the top card revealed this turn; whenever it has a Power icon you may add it to your hand» — «с Power» = в тексте карты есть слово Power. Проверка верха — сразу, после каждого Explore и после каждой следующей сыгранной карты; открытая карта пишется в журнал.
- **Lizardfolk Geomancer (Zyra)** — базовое действие Deploy в этот ход можно оплатить 1 Influence вместо 1 Power (кнопки появляются и без Power). «If you've deployed 7 or more troops this turn, draw a card» — как только поставлено 7-е войско за ход (картами, действием, supplant), один раз берётся карта. **Бот этим не пользуется.**
- **Dao (Qiyana)** — цели считаются на момент розыгрыша: (1) за ход в трофеях прибавилось войско; (2) поставлено 3+ войск; (3) шпион поставлен или свой возвращён; (4) куплена/получена карта или что-то продвинуто.
- **Knight of Eldraine (Ezreal)** «Name a region» — регион = тип карты (CHULT, CELESTIAL, DROW…); на выбор все типы с рынка и из своей колоды.
- **Lizardfolk Warden** «If you deploy next to a player troop» — рядом с войском **другого** игрока (не белым).
- **Performer Maestro (Big Game Tycoon)** — войско берётся из барака и лежит на карте рынка, пока карта там; карта ушла (куплена, сожрана, под низ) — войска возвращаются в бараки хозяев. Каждое своё войско на карте: −1 к цене для тебя, +1 для соперников. На карте рынка — надпись «T1» цвета игрока.
- **Minotaur Archaeologist** — открывает верхнюю карту колоды; в этот ход карты рынка (не Obedience) с тем же аспектом на 1 дешевле. Открыта Obedience-карта — скидки нет.
- **Living Gust of Wind (Sky Squad)** «If this card is revealed from the top of your deck by a card effect» — срабатывает при Explore (берётся сверх подходящей карты), Troglodyte и Minotaur Archaeologist.
- **Cyclops Oracle (Axiomata Monk)** — третий вариант: вопрос «перемешать сброс в колоду?», потом Scry 3.
- **Kenku (Secret Keeper)** «If the site is full» — все места для войск локации заняты.
- **Aarakocra Aeromancer (Landing Party)** — «whenever you Explore» действует до конца хода (после каждого Explore — 1 войско за каждый сыгранный Aeromancer). Scry 2 — если к концу розыгрыша поставлено 4+ войск за ход.
- **Bone Naga (Yun Tal Initiate)** — смотрит аспект карты, сыгранной прямо перед ней; Valor = Malice; Obedience/нет карты — ничего.

## Чек-лист живой проверки
1. NEW ERA → кнопка **CHULT** (фон изумрудный), с CELESTIAL: на рынке карты с артами.
2. Bandit Deceiver → Explore: выбор карты из 2 верхних, потом «под низ/наверх».
3. Chwinga, потом Bandit Deceiver — подходящие карты сразу в руке.
4. Performer Maestro — надпись T1 на карте рынка, цена у тебя на 1 меньше, у соперника — на 1 больше.
5. Sarrukh Tyrant — после хода ещё один полный ход; карта в Внутреннем круге.
6. Lizardfolk Geomancer без Power — войска ставятся за Influence.
