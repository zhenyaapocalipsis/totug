# New Era — передача работы в новый чат (на 2026-10-08)

Как начать новый чат: «Продолжаем New Era, прочитай `Claude outputs/new_era_handoff.md`».

## Что это за работа
Владелец переносит в игру полуколоды фан-мода **Runeterra Reforged**, но в сеттинге D&D:
- из карт берутся **только способности**;
- имена и арты — существа из бестиария D&D Beyond;
- существа не должны совпадать с картами, которые уже есть в игре (drow, dragons, demons, elementals, aberrations, undead и стартовые);
- игра некоммерческая, поэтому арты D&D Beyond можно брать.

**Источники:**
- карты: `new era/Runeterra Reforged A4 3x3.pdf` (479 картинок, текста в PDF нет);
- правила мода: Google Doc `1R3F9vdMJEdAaDBVpxuQ2muXKox_lLTnbbFP4NyOnwIE`, глава «New (and Changed) Keywords» (читать через коннектор Google Drive, read_file_content);
- соответствие регионов и существ, описание каждой полуколоды: `Claude outputs/new_era_dnd_mapping.md`. Таблица точная только для Demacia, для остальных регионов это черновик.

## Готово: Celestial Order (бывшая Demacia)
Коммиты: **NE-1** `3804aca`, **NE-2** `69fc428`, **NE-3** `19c56a5`. Тесты: `пройдено: 1201, провалено: 0`, сеть 105/0.

- **Карты:** id 49000–49024, тип `CELESTIAL`, данные в `engine/godot/data/cards/cards.json`.
- **Полуколода:** `celestial` в `data/cards/half_decks.json`, 45 карт, флаг `"wip": true`, поэтому её нет в обычном пуле случайного выбора. Иначе бы поменялись сиды и журналы старых партий.
- **Режим рынка NEW ERA** (`GameSetup.MODE_NEW_ERA`): Celestial плюс одна случайная классическая полуколода. Включается в меню HOTSEAT и LOBBY. Цвет фона партии — `UnderdarkBg.DECK_COLOURS["celestial"]`.
- **Эффекты карт:** `engine/godot/core/cards/celestial_cards.gd`. CardLibrary берёт эффект оттуда, если своего нет. `CardLibrary.on_gain()` — триггер «когда получаешь карту» (Scout кладёт в сброс Giant Eagle).
- **Новые примитивы** в `core/effects/primitives/`:
  - ReturnOwnTroops — вернуть свои войска как плату «стрелкой» или «сколько угодно»;
  - ScryCards;
  - FetchFromTop;
  - GainSupplyToHand;
  - CallbackEffect;
  - ShieldGuard.
- **Новые параметры старых примитивов:**
  - MoveTroop: свои войска, одна локация, колбэк по окончании;
  - SupplantTroop: одна локация;
  - DeployTroop и ReturnTroopOrSpy: локация, которую назвала карта (без Присутствия).
- **Скидки на ход:** `GameState.turn_discounts` (сбрасываются в `start_turn`). Цены считают `Actions.assassinate_cost / return_spy_cost / supply_cost`, в view они лежат в `costs`.
- **Очки:** `Scoring.card_bonus_vp`. Couatl даёт VP за своих шпионов, Druid — бонус за самую большую колоду (вдвоём 3/1, иначе 5/2).
- **Shield Guardian (49021):** реакция в чужой ход. Если соперник картой или базовым действием убивает, вытесняет, двигает или возвращает юнит владельца, тот получает вопрос (`pd.player_id` = жертва). Если согласен — сбрасывает карту, ставит 4 войска и тянет карту. Базовые действия обрабатывает GameServer, для этого Actions разбит на `can_assassinate / kill_at / can_return_enemy_spy / remove_spy`.
- **Важно про resolver.resume:** он вызывает эффект от имени того, кто ответил на вопрос. Если отвечает другой игрок, атакующего нужно хранить в самом эффекте (как `ShieldGuard.attacker`).
- **Названия вариантов выбора:** `scenes/ui/option_card.gd`, словарь NAMES. Тест падает, если у варианта нет названия.
- **Тесты:** `test_celestial_order`, `test_shield_guardian_reaction` в `tests/run_tests.gd`. Число карт в тесте — 151.

Соответствие «карта мода → существо (id)»: Laurent→Warrior Infantry 49000, Dawnspeakers→Priest 49001, Insightful Investigator→Sphinx of Wonder 49002, Garen→Sphinx of Valor 49003, Lux→Djinni 49004, Durand→Satyr 49005, Conservator→Couatl 49006, Ranger-Knight→Hippogriff 49007, Silverwing→Pegasus 49008, Greenfang→Druid 49009, Radiant Guardian→Planetar 49010, Inquisitor→Sphinx of Lore 49011, Dauntless→Griffon 49012, Investigator→Unicorn 49013, Grizzled Ranger→Werebear 49014, Kayle→Solar 49015, Morgana→Erinyes 49016, Poppy→Warrior Veteran 49017, Fiora→Berserker 49018, Quinn→Scout 49019 + Valor→Giant Eagle 49023 (не в маркете), Jarvan→Silver Dragon 49020, Galio→Shield Guardian 49021, Shyvana→Gold Dragon 49022 ↔ Ancient Gold Dragon 49024 (не в маркете).

## Решения владельца (действуют для всех колод)
- Стартовые карты мода не вводим. Vanguard Cavalry = House Guard, Battlefield Sergeant = Priestess of Lolth. Стартовая колода остаётся 7 Noble + 3 Soldier (у нас Conscription Officer вместо одного Noble).
- Аспект Valor из мода → MALICE.
- Реакции в чужой ход делаем честно (Rammus, Shen, Tahm Kench, Braum — по тому же образцу ShieldGuard).
- **Арты:** брать с D&D Beyond, **обязательно с хоть каким-то фоном**. Вырезанных персонажей на прозрачном фоне владелец забраковал. Кадр приближать к лицу. Если прозрачный фон всё же остался, он становится чёрным (это делает `pixel_cards.gd`).
- Число копий карты = белые кружки внизу карты в PDF. Полуколода — 45 карт.
- Extra Champions (Vayne, Sona, Xin Zhao, Sylas, Lucian и др.) пока не берём.
- Работа маленькими этапами: «Stage NE-N: …», после каждого — тесты, коммит и короткий чек-лист на русском.

## Как делать следующую колоду (конвейер)
1. **Читать карты.** Картинки карт из PDF уже извлечены во временную папку, в новом чате её не будет. Извлечь заново скриптом Godot, который ищет JPEG-потоки (FFD8…`endstream`): Read-инструмент не открывает PDF больше 100 МБ, а Python здесь не работает. Порядок карт в PDF:

   | Регион | Листы |
   |---|---|
   | Demacia | 0–27 |
   | Shadow Isles | ~28–55 |
   | Piltover & Zaun | следом |
   | Noxus | следом |
   | Bilgewater | следом |
   | Freljord | следом |
   | Shurima | следом |
   | Ionia | следом |
   | Bandle City | следом |
   | Targon | следом |
   | Void | следом |
   | Ixtal | следом |
   | Arcane | следом |
   | Extra Champions | следом |
   | Jungle Monsters, Items, Stances, Guns | следом |
   | Poro | в конце |

   Демасия при извлечении (картинки 0000–0027): 0 Cursed Wanderer, 1 Battlefield Sergeant, 2 Vanguard Cavalry, 3 Captain, 4 Officer, 5 Bannerman, 6–27 карты Демасии, 28 Shyvana, 341 Sylas, 360 Lucian.
2. **Найти арты.** Во встроенном браузере открыть dndbeyond.com/monsters/… и через javascript_tool сделать fetch(`/monsters?filter-search=Имя`). Затем fetch страницы монстра и в HTML найти регуляркой `avatars/thumbnails/.../1000/1000/....(png|jpeg)`. Скрипт запускать фоном (`window.R = …`), результат забирать через 40 с: у javascript_tool лимит 45 с. Скачивать curl'ом с `-A "Mozilla/5.0"`. Монстры из платных книг отдают `locked` — брать других. jpeg почти всегда с фоном, png бывает и с фоном, и без. Проверять контакт-листом с пурпурной подложкой (прозрачное видно сразу).
3. **Положить данные.** Арты — в `cards/<колода>/`. Новые карты дописать в конец `cards.json` (следующий диапазон id, например 49100+), полуколоду — в `half_decks.json` с `"wip": true`, тип — для подписи. В `tools/pixel_cards.gd` добавить:
   - в `SINGLE_ART` — `id: ["папка/файл", Rect2i(окно арта)]`, пропорция 164:100;
   - в `MINI_FACE` — левый верхний угол выреза 52x53 в арте 164x100;
   - в `set_name()` — подпись для `card_id/100`.
4. **Сгенерировать карты:** `Godot --headless --path engine/godot --script res://tools/pixel_cards.gd` (~2,5 мин). `-- mini` перерисует только мини-карты, `-- measure` покажет высоты текстов: текст новой карты не должен превышать 85 px, иначе раздуется рамка всего набора. После генерации — `--import`.
5. **Кадры** удобнее подбирать по сетке 10 px на окне арта (вырезать `(6,34,164,100)` из `assets/cards_pixel/<id>.png`, увеличить x3, сетка). Оценки «на глаз» по общему листу дважды ошиблись.
6. **Эффекты** — в новом файле `core/cards/<deck>_cards.gd` по образцу celestial_cards.gd, подключить в `CardLibrary._build_effect`. Добавить названия вариантов в `option_card.gd` и тест колоды. Режим рынка — по образцу MODE_NEW_ERA (или обобщить его на выбор колоды).
7. **Тесты:** `run_tests.gd` и `net_loopback.gd`. После новых `class_name` сначала выполнить `--import`, иначе «Identifier not declared».

## Открытые вопросы и что не сделано
- Владелец ещё не проверял Celestial живьём. Чек-лист был: режим NEW ERA, покупка Scout, Gladiator→Berserker со скидками, превращение Gold Dragon, реакция Shield Guardian.
- Во вкладке CARDS коллекции (`scenes/ui/collection_page.gd`, FACTIONS) Celestial нет.
- Djinni (бывшая Deva) предлагает «2 Influence → карта» только при розыгрыше, а не в любой момент хода.
- У Solar «развернул N войск» считается как «столько войск ушло из барака».
- Возможная доводка кадров: Solar (лицо мелкое), Giant Eagle (голова слева).
- `cards/celestial/cand` и `cand2` — неиспользованные кандидаты (не в git). Удалить вручную, если не нужны.
- Механики следующих колод по правилам мода:
  - Execute (бывший Devour) / Might;
  - Cursed Wanderer + Cursed Affinity;
  - Focus — уже есть в игре;
  - Retain;
  - Frostbite (срабатывает у карты, когда её сбрасывают из руки);
  - Devotion (при покупке или Promote);
  - Glamour (1 жетон VP);
  - Tribute / Gems (+1 Power к цене убийства или вытеснения войска с самоцветом);
  - Voyage (сейчас и в начале следующего хода);
  - Explore (2 верхние карты);
  - Swarm (не-Obedience карты стоимостью 2);
  - Hextech / Shimmer (колоды по 30);
  - Transform (уже сделан).
- Какую колоду делать следующей, владелец пока не сказал. В разговоре был порядок из mapping-файла: Shadow Isles → P&Z → Noxus → …
