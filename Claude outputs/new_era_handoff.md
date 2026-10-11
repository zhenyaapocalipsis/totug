# New Era — передача работы в новый чат (на 2026-10-11)

Как начать новый чат: «Продолжаем New Era, прочитай `Claude outputs/new_era_handoff.md`».

## Состояние сейчас (коротко)
- Готовы три колоды: **Celestial Order** (бывшая Demacia, NE-1…3), **Shadow Isles** (NE-4…5) и **Piltover & Zaun** (NE-6 правила, NE-7 арты). Все `wip`. Режим рынка **NEW ERA**: две колоды New Era выбираются переключателем под режимами (меню HOTSEAT и LOBBY), строка режима `newera:celestial,piltover`; просто `newera` = Celestial + Shadow Isles. **Названия в игре (2026-10-11): Shadow Isles → RAVENLOFT, Piltover & Zaun → WATERDEEP** (тип карт, подпись, кнопки меню); ключи колод `shadow`/`piltover` и классы в коде прежние, чтобы не ломать реплеи.
- Всё закоммичено, запушено на GitHub и задеплоено на сервер (`bash server/deploy.sh`, сборка 1791467650 от 2026-10-08; позже деплоили другие сессии).
- Тесты на 2026-10-11 (после NE-6): `пройдено: 1535, провалено: 0`, сеть `118 / 0`. В тесте карт 197 (126 + 25 Celestial + 25 Shadow Isles + 21 Piltover & Zaun).
- Не в git и не моё: `scenes/ui/card_fx.gd`, `tests/ui_shot.gd` — правки владельца, не трогать.
- **Владелец ещё не проверял обе колоды живьём.** Чек-листы — в конце разделов ниже.

### Что сделали другие сессии и касается New Era
- **NE-UI-1…3** (`dfd82f0`, `9e6b3d5`, `f7814ca`): вопросы карт полосой сверху, без затемнения; слева показывается карта, которая спрашивает. Green Hag жрёт карту выбором в ряду руки, соперники выбирают в своей руке.
- **Live-1** (`f64bef2`): «живой» текст карт — числа и условия на 35 картах (в том числе счётчики Insane Outcast) зелёные или красные по позиции смотрящего. **Цена со скидкой (Cursed Affinity, House Guard) теперь рисуется зелёным** — этот открытый пункт закрыт.
- **Lobby-1** (`7362b9c`): Promote из руки или сброса (Will-o'-Wisp, Celestial) — выбором в ряду руки.
- **Баланс** (`346dd2b`, отчёт `Claude outputs/balance/`, память `project_balance_findings`): 1600 игр вчетвером из всех 8 колод. Celestial как основная колода выигрывает 30,2% (интервал 26,7–33,9) при честных 25% — самая сильная. Shadow Isles — 26,6%, классические — 20,7–27,9%. По картам: Swarm of Crawling Claws сильная, Planetar и Grick слабые. Ослаблять или нет, владелец не решал.
- Боты (Bot-1…8) играют и New Era: `tests/balance_run.gd`, флаг `all_decks=1`.

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
- **Режим рынка NEW ERA** (`GameSetup.MODE_NEW_ERA`): сначала был Celestial + случайная классическая, с NE-4 — Celestial + Shadow Isles. Включается в меню HOTSEAT и LOBBY. Цвет фона партии — `UnderdarkBg.DECK_COLOURS["celestial"]`.
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

## Готово: Shadow Isles — правила (NE-4, `412727e`)
Тесты 1258/0, сеть 108/0. Всё по колоде — в `Claude outputs/new_era_shadow_isles.md` (таблица id → существо → карта мода, толкования).
- Карты 49100–49124, тип `SHADOW` (подпись SHADOW ISLES), полуколода `shadow` (wip), эффекты `core/cards/shadow_cards.gd`, тест `test_shadow_isles`.
- Решения владельца: Cursed Wanderer = Insane Outcast (стопка выкладывается и с Shadow Isles); Execute = Devour; Sapling = Twig Blight (запас 4); Elise ↔ Spider Elise = Drider ↔ Phase Spider; режим NEW ERA = Celestial + Shadow Isles.
- Новое в движке: `state.turn_flags` (счётчик Outcast за ход и т.п.), `ShadowCards.on_play` в `TurnEngine.play_card`, `ShadowCards.on_devour` в DevourCard, `Actions.market_cost` (Cursed Affinity), `PlayerState.start_of_turn_influence`, реакция `ShadowCards.ClawsReaction` (Swarm of Crawling Claws в руке) в GiveInsaneOutcast.
- **NE-5 (`164a8e1`) — арты.** Состав существ заменён без отдельного согласования (черновая нежить почти вся в платных книгах D&D Beyond, свободная нежить уже занята в игре): Rakshasa, Nightmare, Chain Devil, Barbed Devil, Ghast, Treant, Bone Devil, Drider ↔ Phase Spider, Green Hag, Shadow + 13 обычных. Таблица — `new_era_shadow_isles.md`. Владелец состав пока не комментировал. Картинки карт мода для сверки: 29–52, 0, 321, 326.
- `cards/shadow/cand*` — неиспользованные кандидаты артов (не в git), можно удалить.
- Чек-лист для живой проверки: (1) NEW ERA — на рынке обе колоды с артами, фон бирюзовый; (2) 2 Insane Outcast, затем Specter = +5 Power; (3) после двух Outcast Rakshasa на 2 дешевле (цена зелёная); (4) Shambling Mound, затем Gargoyle: +4 Influence, в конце хода Gargoyle сожран, в следующем ходу +3 Influence; (5) Swarm of Crawling Claws в руке соперника — ему предлагают взять раздаваемый Outcast в руку.
- **Совет для поиска артов:** у закрытых монстров fetch страницы падает — ловить ошибку на каждую страницу отдельно; арт брать строго из `<img ... class="monster-image">`. Свободны почти только монстры SRD (Basic Rules 2014 и Free Rules 2024).

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
2. **Найти арты.** Во встроенном браузере открыть dndbeyond.com/monsters/… и через javascript_tool сделать fetch(`/monsters?filter-search=Имя`). Затем fetch страницы монстра (каждую в своём try/catch: закрытая страница роняет fetch) и взять src из `<img ... class="monster-image">` — общая регулярка по `avatars/` ловит картинки оформления сайта. Скрипт запускать фоном (`window.R = …`), результат забирать через 40 с: у javascript_tool лимит 45 с. Скачивать curl'ом с `-A "Mozilla/5.0"`. Монстры из платных книг отдают `locked` — брать других. jpeg почти всегда с фоном, png бывает и с фоном, и без. Проверять контакт-листом с пурпурной подложкой (прозрачное видно сразу).
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
- Во вкладке CARDS коллекции (`scenes/ui/collection_page.gd`, FACTIONS) нет ни Celestial, ни Shadow Isles.
- Celestial по прогонам ботов сильнее остальных колод (30,2% побед основной колодой вчетвером) — вопрос владельцу, ослаблять ли.
- Колоды всё ещё `wip`: не входят в обычные случайные режимы. Убрать флаг — решение владельца (изменит сиды обычных режимов).
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
- Следующая колода по mapping-файлу — **Noxus** (Execute = Devour, Might). Владелец порядок не подтверждал.

## Piltover & Zaun — правила (NE-6) и арты (NE-7)
Всё по колоде — в `Claude outputs/new_era_piltover.md` (таблица id → существо → карта мода, толкования).
- Карты 49200–49220, тип `PILTOVER`, полуколода `piltover` (wip, **42 карты** — столько копий по кружкам), эффекты `core/cards/piltover_cards.gd`, тест `test_piltover_zaun`. Цвет фона — розовый (`UnderdarkBg.DECK_COLOURS["piltover"]`).
- Новое в движке:
  - `FocusEffect` с `need = 2` — Double Focus; `FocusEffect.support()` — сколько других карт аспекта (сыграно + в руке); флаг `focus_extra` повторяет Focus (копия эффекта пересобирается из карты по номеру Focus, `FocusEffect.registry`).
  - `ChooseEffect`: флаг `choose_all` — вариант «All of them».
  - `PlaceSpy`: флаг `spy_move` — после шпиона вопрос «Move a troop?».
  - Лишний ход: `GameState.extra_turn_for / in_extra_turn`, `GameEnd.advance_turn`, `turn_flags["card_limit"]`, `TurnEngine.can_play_card` (бот это учитывает), в view — `extra_turn`, `cards_left`.
  - Hydra: `PiltoverCards.after_buy` из GameServer после покупки.
  - Режимы: `GameSetup.is_new_era / is_mode / new_era_pair / new_era_mode`, `SetupScreen.mode_title`.
- **NE-7 (арты):** 21 арт в `cards/pz/`, окна и мини-лица в `pixel_cards.gd`; возможная доводка кадров — Spy (лицо в тени), Rust Monster и Iron Golem (тёмные). Кандидаты `cards/pz/cand*` не в git.
- В интерфейсе пока нет отдельной надписи «лишний ход, осталось N карт» — сервер просто не даёт сыграть четвёртую карту.
- Чек-лист для живой проверки: (1) NEW ERA → кнопки колод, выбрать CELESTIAL + PILTOVER, фон розово-золотой; (2) Homunculus «choose all», потом Wererat — есть вариант «All of them»; (3) Basilisk с двумя Malice в руке — лишний ход, четвёртая карта не играется; (4) Assassin показывает 2 верхние карты каждого; (5) Hydra с двумя Ambition — после покупки предлагает карту дешевле.
