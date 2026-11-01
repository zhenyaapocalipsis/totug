# New Era: Ionia → KARA-TUR (этап NE-23, 2026-10-17)

Источник: `new era/Runeterra Reforged A4 3x3.pdf`, картинки 165–187 (Ionia; 171 Jhin не взят) и 373 (Hwei из Extra Champions).
Решение владельца: **Jhin заменён на Hwei** (2026-10-17). В колоде все 45 карт мода (23 уникальные) — урезать до 40/20 владелец решит сам по листу `Claude outputs/karatur_cards_all.png`.

- Ключ `ionia`, тип `KARA-TUR`, id 49800–49822, полуколода `wip` (кнопка KARA-TUR в NEW ERA, не в обычном пуле).
- Эффекты: `engine/godot/core/cards/ionia_cards.gd`, тест `test_karatur_deck`.
- Арты D&D Beyond (все с фоном): `cards/ionia/`. Фон партии — сакура (`UnderdarkBg.DECK_COLOURS["ionia"]`). PROTOCOL 32.
- Название KARA-TUR — восточный край Forgotten Realms (аналог Ионии). Сначала колода была «драконья» (13 драконов из 23).
- **NE-34 (2026-11-01, владелец: «в игре слишком много драконов»):** 11 драконов заменены существами D&D Beyond со сценой, которых выбрал владелец (эффекты и id не менялись): Biha Babir, Thessalheart Construct, Murder Comet, Nafas, Elemental Cataclysm, Bodytaker Podling, Gas Spore Fungus, Brackish Trudge, Bodytaker Plant, Tempest Hart, Khargra. Драконами остались Ancient Bronze и Ancient Silver. Старые арты драконов удалены из `cards/ionia/`.

## Таблица

| id | Существо | Карта мода | Цена | Аспект | VP | Копий |
|---|---|---|---|---|---|---|
| 49800 | Biha Babir | Akali | 6 | Guile | 3/7 | 1 |
| 49801 | Oni | Shen | 6 | Malice (Valor) | 3/6 | 1 |
| 49802 | Thessalheart Construct | Kinkou Wayfinder | 3 | Conquest | 2/4 | 0 (убран, NE-24) |
| 49803 | Murder Comet | Zed | 7 | Guile | 3/6 | 1 |
| 49804 | Sprite | Airis | 3 | Ambition | 1/3 | 3 (вернул владелец, NE-25) |
| 49805 | Dryad | Blossoming Blade | 3 | Ambition | 1/3 | 3 |
| 49806 | Nafas | **Hwei** (вместо Jhin) | 6 | Guile | 3/6 | 1 |
| 49807 | Elemental Cataclysm | Yasuo | 7 | Malice (Valor) | 3/7 | 1 |
| 49808 | Mage | The Witness | 4 | Ambition | 2/4 | 3 |
| 49809 | Violet Fungus | Navori Conspirator | 3 | Guile | 1/3 | 0 (убран, NE-24) |
| 49810 | Merfolk Skirmisher | Rivershaper | 2 | Ambition | 1/2 | 3 |
| 49811 | Tarrasque | Lee Sin | 6 | Malice (Valor) | 3/6 | 1 |
| 49812 | Bodytaker Podling | Navori Highwayman | 2 | Conquest | 1/3 | 4 |
| 49813 | Gas Spore Fungus | Greenglade Duo | 2 | Conquest | 1/3 | 3 |
| 49814 | Brackish Trudge | Swole Squirrel | 3 | Malice (Valor) | 1/3 | 0 (убран, NE-25) |
| 49815 | Ancient Bronze Dragon | Irelia | 6 | Conquest | 3/6 | 1 |
| 49816 | Bodytaker Plant | Pathless Ancient | 3 | Malice (Valor) | 1/3 | 3 |
| 49817 | Merrow | Kinkou Lifeblade | 3 | Malice (Valor) | 1/3 | 3 |
| 49818 | Tempest Hart | The Schemer | 4 | Guile | 2/4 | 2 |
| 49819 | Shrieker Fungus | Shadowblade Fanatic | 4 | Guile | 2/4 | 3 |
| 49820 | Khargra | Ahri | 6 | Guile | 3/7 | 1 |
| 49821 | Ancient Silver Dragon | Karma | 6 | Ambition | 3/7 | 1 |
| 49822 | Kraken | Master Yi | 6 | Malice (Valor) | 3/6 | 1 |

Итого 30 обычных + 10 чемпионов = 40. NE-24 (2026-10-17): владелец убрал Thessalheart Construct, Sprite, Violet Fungus, Mage и Brackish Trudge по 3. NE-25: Brackish Trudge заменён на Sprite (3 копии). Убранные остались в cards.json. PROTOCOL 33.

## Retain
Правило мода: карта остаётся в руке после конца хода; новая рука — 5 карт без удержанных, потом удержанные добавляются.
- Карту со словом **Retain** в свой ход можно не сыграть, а удержать: при щелчке по ней вопрос полосой сверху «Play this card now / Retain it». Удержанная уходит из руки в отдельную стопку (`Deck.retained`), в ряду руки она видна справа с подписью RETAINED. В конце хода после добора до 5 она возвращается в руку.
- Бонус «Retain: …» срабатывает сразу при удержании (иначе +1 Power у Elemental Cataclysm сгорал бы в конце хода).
- Любое удержание — своё, через Ancient Silver Dragon (ещё 2 карты), Tempest Hart (сыгранная карта), верхняя карта колоды (Tempest Hart, Shrieker Fungus) — считается «Retain a card»: бонус карты и «whenever you Retain» (Bodytaker Plant, Merfolk Skirmisher, Gas Spore Fungus) срабатывают.
- Соперники видят только число удержанных карт; верхняя карта колоды в журнал не пишется.

## Толкования (можно поменять)
- **Hwei (Nafas):** «Based on the previous 2 Aspects you played» — две последние карты, сыгранные перед ней в этот ход; два одинаковых Аспекта дают эффект дважды; Obedience/стартовые не дают ничего.
- **Shen (Oni):** реакция из руки только на эффекты **карт** соперника (не на базовые действия): убийство, вытеснение, возврат, перемещение войска или шпиона. Ответ — сбросить Oni, отменить удар, взять 2 карты. Порядок вопросов: Shield Guardian, Ankheg, Oni.
- **Zed (Murder Comet):** «Play a copy for each card you Retain this turn» — повторов столько, сколько карт удержано в этот ход **до** розыгрыша (не больше 2).
- **Airis / Kinkou Lifeblade (Sprite, Merrow):** карта становится названным Аспектом (для Focus, Hwei, Copper Wyrmling) и даёт +1 за каждую карту этого Аспекта в этот ход, включая себя.
- **Swole Squirrel (Brackish Trudge):** удержать её саму можно, только сбросив другую карту из руки (Frostbite срабатывает); жетоны Acorn копятся до конца партии. Если её удержали другим путём — жетон даётся без сброса.
- **Lee Sin (Tarrasque):** «you may treat other players' troops as neutral» — до конца хода все чужие войска считаются белыми (флаг Siege `all_white`).
- **Irelia (Ancient Bronze Dragon):** «Return all spies from a hex» — все шпионы соперников в одной локации с Присутствием. «Double your Power» в паре выполняется вторым.
- **The Witness (Mage):** следующая сыгранная карта ценой ≤ 5 срабатывает ещё раз (как Echo у Ravenloft).
- **Ahri (Khargra):** скидка 1 на найм до конца хода (и рынок, и стопки); второй вариант — после каждого найма (покупка, бесплатный найм) вопрос «убить войско» с пропуском.
- **Karma (Ancient Silver Dragon):** в конце хода — по желанию продвинуть сыгранную карту (можно и её саму) и бесплатно нанять карту рынка ценой до «цена продвинутой + 2».
- **Master Yi (Kraken):** «+1 Power whenever you Assassinate or Supplant» — с момента розыгрыша до конца хода, любым путём (карта или базовое действие).
- **Navori Conspirator (Violet Fungus):** «more than 5 cards» — у соседа слева или справа в руке 6+ карт (удержанные карты это делают возможным).
- **Blossoming Blade (Dryad):** Retain — посмотреть руку соперника (вдвоём — сразу, иначе выбор игрока).

## Чек-лист живой проверки
1. NEW ERA → CELESTIAL + KARA-TUR: на рынке карты с артами, фон розовый (сакура).
2. Купить Elemental Cataclysm. Когда придёт в руку, щёлкнуть — вопрос «Play / Retain». Retain: +1 Power, карта справа от руки с подписью RETAINED; в следующем ходу в руке 6 карт.
3. Сыграть Bodytaker Plant, потом удержать карту с Retain — ещё +1 Power.
4. Сыграть Mage, затем Gas Spore Fungus — его выбор срабатывает дважды.
5. Oni в руке соперника: при убийстве его войска картой — вопрос «сбросить Oni»; базовым действием (3 Power) — вопроса нет.
6. Nafas после двух Ambition-карт — +6 Influence.
