# New Era: Shurima → CALIMSHAN (этап NE-21, 2026-10-16)

Источник: `new era/Runeterra Reforged A4 3x3.pdf`, картинки 144–164 (Shurima) и 380 (Naafiri из Extra Champions).
Решения владельца: **Azir заменён на Naafiri** (2026-10-16); сначала в колоде были все 45 карт мода, 2026-10-17 (NE-22) владелец урезал до **40 / 20**.

- Ключ `shurima`, тип `CALIMSHAN`, id 49700–49720, полуколода `wip` (в переключателе NEW ERA, не в обычном пуле).
- Эффекты: `engine/godot/core/cards/shurima_cards.gd`, тест `test_calimshan_deck`.
- Арты D&D Beyond (все с фоном): `cards/shurima/`. Кандидаты — `cards/shurima/cand*` (не в git).
- Фон партии — песочно-латунный (`UnderdarkBg.DECK_COLOURS["shurima"]`). PROTOCOL 31.

## Таблица

| id | Существо | Карта мода | Цена | Аспект | VP | Копий |
|---|---|---|---|---|---|---|
| 49700 | Zombie | Voice of the Risen | 3 | Conquest | 1/3 | 0 (убран, NE-22) |
| 49701 | Cockatrice | Baccai Witherclaw | 3 | Malice (Valor) | 1/3 | 3 |
| 49702 | Brass Dragon Wyrmling | Sandcrafter | 3 | Conquest | 2/4 | 3 |
| 49703 | Steam Mephit | Reaper of the Sands | 3 | Guile | 1/3 | 3 |
| 49704 | Commoner | Dunekeeper | 3 | Ambition | 1/3 | 4 |
| 49705 | Tough | Inspiring Marshal | 3 | Ambition | 1/3 | 2 |
| 49706 | Incubus | Darkinthrall | 5 | Guile | 3/5 | 3 |
| 49707 | Goblin Warrior | Rampaging Baccai | 3 | Conquest | 2/4 | 3 |
| 49708 | Goblin Minion | Baccai Reaper | 3 | Guile | 2/4 | 3 |
| 49709 | Dragon Turtle | Bloodthirsty Marauder | 5 | Conquest | 2/5 | 2 |
| 49710 | Magma Mephit | Priestess of Desert Light | 3 | Malice (Valor) | 1/3 | 4 |
| 49711 | Roper | **Naafiri** (вместо Azir) | 6 | Conquest | 3/6 | 1 |
| 49712 | Ancient Brass Dragon | Xerath | 8 | Guile | 4/8 | 1 |
| 49713 | Purple Worm | Renekton | 8 | Ambition | 4/8 | 1 |
| 49714 | Guardian Naga | Nasus | 8 | Malice (Valor) | 4/8 | 1 |
| 49715 | Adult Brass Dragon | Sivir | 7 | Ambition | 3/6 | 1 |
| 49716 | Stone Giant | Taliyah | 6 | Ambition | 3/6 | 1 |
| 49717 | Gorgon | K'Sante | 6 | Malice (Valor) | 3/6 | 1 |
| 49718 | Ankheg | Rammus | 6 | Conquest | 3/6 | 1 |
| 49719 | Dust Mephit | Amumu | 6 | Ambition | 3/6 | 1 |
| 49720 | Deva | Akshan | 6 | Malice (Valor) | 3/7 | 1 |

Итого 30 обычных + 10 чемпионов = 40 (NE-22, 2026-10-17: владелец убрал Zombie, по 1 копии Cockatrice и Brass Dragon Wyrmling; Zombie остался в cards.json).

## Devotion
Правило мода: «You may activate a card's Devotion ability when it is either recruited or promoted».
- Срабатывает у того, кто карту нанял (покупка на рынке, бесплатный найм — Dust Mephit и др.) или продвинул (любой путь promote, в том числе в конце хода и «promote вместо сброса»).
- Эффекты Devotion выгодны всегда, поэтому идут без вопроса. Вопрос только у Deva (Akshan): «положить наверх колоды?» — при promote это снимет карту из Внутреннего круга.
- Power/Influence от Devotion при promote в конце хода сгорают (как у других эффектов конца хода).
- Ключевое слово DEVOTION — жирным на картах, подсказка по Alt.

## Толкования (можно поменять)
- **Roper (Naafiri):** «Whenever you deploy troops from a card effect, Assassinate a troop» — раз на каждый эффект карты, ставящий войска (не на каждое войско); вытеснение (Supplant) не считается. «Whenever you deploy troops using Power from a card, gain up to 1 additional Power per card» — базовое действие Deploy возвращает 1 Power, но не больше раз, чем сыграно карт начиная с Roper (она тоже считается).
- **Ankheg (Rammus):** реакция из руки, как у Shield Guardian, но только на убийство и вытеснение войска (картой или базовым действием). Ответ — вытеснить войско нападавшего **где угодно**. Если в руке и Shield Guardian, и Ankheg — сначала вопрос про Shield Guardian.
- **Tough (Inspiring Marshal):** игрок выбирает, кого спросить: соседа слева, справа, обоих или никого (вдвоём — одного соперника). Сосед называет карту **рынка**; её нельзя нанять в этот ход (ни за Influence, ни бесплатно), +1 Influence за каждую.
- **Ancient Brass Dragon (Xerath):** «If you have presence to none of those troops» — ни одно убитое войско не стояло там, где было Присутствие до убийства; хотя бы одно убийство нужно.
- **Purple Worm (Renekton):** «each troop you assassinated or supplanted this turn» — рост трофеев с начала хода.
- **Adult Brass Dragon (Sivir):** число разных цен среди сыгранных в этот ход карт (сама она тоже); стартовые карты — цена 0.
- **Gorgon (K'Sante):** «Move an opponent troop then Supplant it» — войско другого игрока (не белое) в Присутствии, на новом месте вытесняется без Присутствия.
- **Deva (Akshan):** «take a troop from their trophy hall and deploy it» — из трофеев того, чьё войско вытеснили; войско ставится своим цветом, нужно Присутствие (как у Lich); по желанию.
- «Site is full» (Incubus, Goblin Minion) — в локации нет свободных мест для войск.
- «Move a troop» / «Move 2 troops» — как везде в игре, чужие войска в Присутствии.
- Magma Mephit (Priestess, «Choose two») — один вопрос из 6 пар.
- Название колоды CALIMSHAN и все существа выбраны мной, владелец их ещё не видел. Зверей нет (правило владельца NE-19): Hyena, Panther, Giant Wasp, Giant Toad, Giant Venomous Snake, Giant Scorpion заменены на Roper, Goblin Minion, Goblin Warrior, Dragon Turtle, Incubus, Deva. Отброшены: Cultist (на арте нет фигуры), Ghoul (имя занято классической нежитью).

## Чек-лист живой проверки
1. NEW ERA → CELESTIAL + CALIMSHAN: на рынке карты с артами, фон песочный.
2. Купить Magma Mephit — сразу +1 Influence (в журнале «Devotion»).
3. Сыграть Goblin Warrior, потом купить карту с Devotion — ещё +1 Power.
4. Сыграть Tough — выбрать «соседа»; названная карта на рынке не покупается.
5. Ankheg в руке соперника — при убийстве его войска он может сбросить Ankheg и вытеснить твоё войско.
6. Roper, затем карта, ставящая войска (Goblin Warrior) — после постановки войск вопрос «убить войско»; базовый Deploy возвращает 1 Power.
