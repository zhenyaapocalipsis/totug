# New Era: Void → FAR REALM (этапы NE-28…30)

Полуколода Void из мода Runeterra Reforged (картинки PDF **232–251**) на существах Далёкого Предела и Астрала: звёздные порождения, слаады, гит, три-крины. Ключ `void`, тип `FAR REALM`, id **50000–50020** (50009 свободен). Флаг `wip` — только кнопкой FAR REALM в режиме NEW ERA. **NE-29 (владелец): 40 карт / 20 уникальных** — Githzerai Monk, Hook Horror, Gray Slaad, Githyanki Dracomancer и Githyanki Warrior по 3 копии (было по 4). PROTOCOL 35.

Эффекты — `engine/godot/core/cards/void_cards.gd`, тест — `test_farrealm_deck`, арты — `cards/void/` (кандидаты `cards/void/cand_*` не в git), лист всех карт — `Claude outputs/farrealm_cards_all.png`.

## Правило колоды
- Мод: «40 (50 if you play with void half-deck) cubes» — если FAR REALM в партии, **у каждого игрока 50 войск** (`VoidCards.setup_troops`, `GameState.starting_troops`).
- «Swarm cards» (любые не-Obedience карты ценой 2) в тексте самих карт Void не встречаются — отдельной механики нет.

## Карты

| id | Существо (D&D Beyond) | Карта мода | Цена | Аспект | Копий |
|---|---|---|---|---|---|
| 50000 | Githyanki Knight | Kai'Sa | 6 | Malice | 1 |
| 50001 | Greater Star Spawn Emissary | Bel'Veth | 7 | Conquest | 1 |
| 50002 | Froghemoth Elder | Cho'Gath | 10 | Conquest | 1 |
| 50003 | Githzerai Zerth | Kassadin | 6 | Guile | 1 |
| 50004 | Thri-kreen Marauder | Kha'Zix | 7 | Guile | 1 |
| 50005 | Red Slaad | Kog'Maw | 6 | Malice | 1 |
| 50006 | Inquisitor of the Mind Fire | Malzahar | 6 | Conquest | 1 |
| 50007 | Groundling Stalker | Rek'Sai | 7 | Conquest | 1 |
| 50008 | Eye Monger | Vel'Koz | 9 | Ambition | 1 |
| 50010 | Lesser Star Spawn Emissary | Xer'Sai Hatchling | 3 | Malice | 2 |
| 50011 | Githzerai Monk | Belvethi Elder | 3 | Ambition | 3 |
| 50012 | Thri-kreen Psion | Xer'Sai Caller | 2 | Malice | 3 |
| 50013 | Hook Horror | Dune Swallower | 3 | Conquest | 3 |
| 50014 | Elder Thing | Xerxa'Reth Undertitan | 5 | Malice | 2 |
| 50015 | Carrion Stalker | Hive Herald | 2 | Guile | 3 |
| 50016 | Gray Slaad | Xer'Sai Dunebreaker | 2 | Ambition | 3 |
| 50017 | Green Slaad | Camouflaged Horror | 4 | Guile | 3 |
| 50018 | Blue Slaad | Void Abomination | 2 | Guile | 3 |
| 50019 | Githyanki Dracomancer | Void Blaster | 3 | Malice | 3 |
| 50020 | Githyanki Warrior | Voidling | 2 | Conquest | 3 |

Все арты — со сценой-фоном (проверка `art_bgcheck.gd` + контакт-лист). Книги Monsters of the Multiverse (star spawn, kruthik, oblex, choldrith, neothelid) дают только вырезанные фигуры — не взяты.

## Толкования (мои — проверить владельцу)
- **Froghemoth Elder (Cho'Gath)** «Remove a hex where you have presence» — **NE-30 (владелец): гекс уходит с доски по-настоящему.** Выбор — щелчком по любой локации гекса, где есть Присутствие. Все вражеские войска (и белые) гекса — в трофейный зал, свои — в барак, шпионы — хозяевам; его локации и места исчезают из игры (новый граф: `VoidCards.remove_hex` → `MapGraph.without_hex`). Тупиков в игре нет: места туннелей соседей, которые вели только в этот гекс, тоже убираются (`prune_dead_ends`, войска с них — хозяевам). На экране гекс и его туннели просто не рисуются (виден фон). Присутствие через убранный гекс больше не проходит. Если съеден гекс A2 — нет и бонуса A2 (рамка и табличка исчезают).
- **Githzerai Zerth (Kassadin)** «Whenever you Assassinate, you may Assassinate anywhere» — до конца хода любое убийство (карты и базовое за 3 Power) — без Присутствия. Supplant сюда не входит.
- **Thri-kreen Marauder (Kha'Zix)** «For every 4 troops in your trophy hall, gain one of these abilities permanently» — способности копятся у игрока навсегда (`PlayerState.evolutions`, не больше 4): при розыгрыше добирается по одной на каждые 4 трофея, потом срабатывают все накопленные.
- **Red Slaad (Kog'Maw)** «3 spaces away» — до 3 шагов по слотам от своего войска (слоты одной локации — одно место). Действует на deploy (карты и базовое), assassinate и supplant.
- **Inquisitor of the Mind Fire (Malzahar)** — «another card effect deploys troops»: только эффекты «Deploy N troops» карт (не supplant и не базовое действие), +2 войска один раз на каждую такую карту; свои +2 не размножаются.
- **Elder Thing (Undertitan)** — перед каждым «Deploy X troops» карты в этот ход вопрос «Deploy X troops / +X Power instead» (свой Deploy 3 тоже).
- **Eye Monger (Vel'Koz)** — отложенные карты лежат в `Deck.set_aside` (видно в журнале), разыгрываются в начале каждого хода владельца до конца партии, обе считаются в deck VP. **NE-30:** на экране — отдельным рядом слева от руки с подписью SET ASIDE (не кликаются).
- **Lesser Star Spawn Emissary (Hatchling)** — «если не ставил войск за ход» — считаются войска от карт, базового deploy и supplant.
- **Blue Slaad (Void Abomination)** — шпион на карте рынка: соперник покупает её, только заплатив 3 Power (шпион уходит хозяину), и тогда она стоит ему на 6 дешевле; бесплатно (Recruit free) соперник её не берёт. Карта ушла из слота любым путём — шпион возвращается хозяину. На рынке — надпись SPY цвета хозяина.
- **Green Slaad (Camouflaged Horror)** — три верхние карты колоды рынка сразу уходят под низ, выбранная (цена до 5) разыгрывается бесплатно, сама остаётся в колоде рынка.
- **Githyanki Warrior (Voidling)** — при тотальном контроле 4+ локаций все три варианта по порядку, без вопроса.
- **Groundling Stalker (Rek'Sai)** «Move up to 2 troops or spies» — дважды выбор: войско (по Присутствию) / свой шпион / хватит.

## Чек-лист живой проверки
1. NEW ERA → CELESTIAL + FAR REALM: фон лиловый, на рынке карты с артами, в бараке 50 войск.
2. Elder Thing: вопрос «Deploy 3 troops / +3 Power instead».
3. Inquisitor of the Mind Fire, потом Hook Horror «Deploy 3»: ставится 3 + 2 войска.
4. Red Slaad: подсвечиваются слоты для войск дальше обычного Присутствия.
5. Blue Slaad «Place a spy on a market card»: у соперника на карте SPY; без 3 Power купить нельзя, с 3 Power цена на 6 меньше.
6. Eye Monger: отложить карту из руки — она и Eye Monger стоят слева от руки (SET ASIDE); в начале следующего хода отложенная разыгрывается сама.
7. Froghemoth Elder: щелчок по локации — гекс исчезает с доски вместе с туннелями; вражеские войска с него в трофеях, свои в бараке.
