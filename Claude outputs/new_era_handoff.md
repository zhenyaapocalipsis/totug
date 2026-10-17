# New Era — передача работы в новый чат (на 2026-10-16)

Как начать новый чат: «Продолжаем New Era, прочитай `Claude outputs/new_era_handoff.md`».

## NE-21/22 (2026-10-16/17): Shurima → CALIMSHAN — задеплоено (сборка 1792227394, PROTOCOL 31, push 5c2a12e)
- Ключ `shurima`, тип `CALIMSHAN`, id 49700–49720, `wip` (кнопка CALIMSHAN в NEW ERA, не в обычном пуле). Эффекты `core/cards/shurima_cards.gd`, тест `test_calimshan_deck`, справка `Claude outputs/new_era_shurima.md`, лист всех карт `Claude outputs/calimshan_cards_all.png`.
- Владелец: **Azir заменён на Naafiri** (картинка PDF 380, Extra Champions). NE-22 (2026-10-17): колода урезана до **40 / 20** — убран Zombie (остался в cards.json), Cockatrice и Brass Dragon Wyrmling по 3. Флаг `wip` — пока владелец не скажет.
- **Devotion**: `ShurimaCards.on_recruit` (GameServer после покупки, RecruitFree) и `on_promote` (после каждого `log_event("promote")` — PromoteCard, Celestial, Mercenary, Noxus, Siege, ForceDiscard). Новые пути найма/promote тоже должны их звать.
- **Ankheg (Rammus)** — реакция внутри `ShieldGuard` (параметр `kill`): только убийство/вытеснение войска. **Roper (Naafiri)** — хуки в `DeployTroop._deploy_at` и `Actions.deploy`. **Tough** — `turn_flags["no_recruit"]`, `Actions.market_cost` = -1.
- PROTOCOL **31**. Тесты 1968/0, сеть 151/0. Звери заменены на чудищ/гуманоидов (правило NE-19).

## Коротко на 2026-10-16 (читать первым)
- **Всё закоммичено и запушено** (`main`, последний коммит `9df122f`). На сервере сборка **1792092861**, **PROTOCOL 30** (`net/net_session.gd`).
- **Тесты на 2026-10-16:** `пройдено: 1939, провалено: 0`, сеть `151 / 0`. В тесте карт 285 (126 классических + 25 Celestial + 25 Shadow + 21 Piltover + 20 Siege + 20 Mercenaries + 25 Avernus + 23 Icewind Dale). Сетевой `[server4] … доска легла в сетку` иногда падает по времени — повторный прогон проходит.
- **Все 7 колод New Era в обычном пуле** (NE-20, без `wip`): 13 полуколод в STANDARD/RANDOM и онлайн-поиске.
- **Правило владельца для полуколод: 40 карт / 20 уникальных** (NE-13…NE-18 урезали все колоды; лишние карты остаются в `cards.json`, но не в `half_decks.json`). Новую колоду сразу делать 40/20 — какие карты мода не брать, спросить владельца или предложить.
- **Что ещё поменялось вокруг колод (другие сессии):**
  - **Market-1/2:** RANDOM-рынок берёт ровно 5 одиночных карт с каждой полуколоды. Если аспекту в RANDOM 3 не хватает до 20 карт, добавляются третьи копии обычных карт.
  - **Ban-1:** в онлайн-поиске каждый банит одну полуколоду.
  - **Keywords-1…3:** SCRY, MIGHT, FROSTBITE, TRANSFORM, DISTINCT — жирным, с подсказками по Alt. Новое ключевое слово (например, DEVOTION у Shurima) тоже нужно добавить в подсказки — смотреть, как сделан FROSTBITE.
  - **Profile-2/Radar:** профиль-шестиугольник; на колоды не влияет.
- **Новая колода и протокол:** новая колода или правка правил → поднять `PROTOCOL`, затем деплой `bash server/deploy.sh`. Проверка: `curl http://129.101.123.70/tyrants/version.txt`. Деплой и push — только по слову владельца.
- **Следующий шаг (не назначен):** следующая колода — **Shurima** (Bilgewater владелец пропустил), картинки PDF с 144: 144 Azir, 145 Xerath, 146 Renekton, 147 Nasus… Механика **Devotion** — срабатывает при покупке или Promote карты. Либо живая проверка колод владельцем.
- Не трогать и не коммитить: `scenes/ui/card_fx.gd`, `tests/ui_shot.gd` (правки владельца).

## Состояние подробнее (история)
- Колоды из мода Runeterra Reforged:

  | В игре | Регион мода | Ключ в коде | id | Этапы |
  |---|---|---|---|---|
  | **CELESTIAL** (Celestial Order) | Demacia | `celestial` | 49000–49024 | NE-1…3 |
  | **RAVENLOFT** | Shadow Isles | `shadow` | 49100–49124 | NE-4, NE-5, NE-8 (имя) |
  | **WATERDEEP** | Piltover & Zaun | `piltover` | 49200–49220 | NE-6, NE-7, NE-8 (имя) |
  | **AVERNUS** | Noxus | `noxus` | 49500–49524 | NE-9 (правила), NE-10 (арты) |
  | **ICEWIND DALE** | Freljord | `freljord` | 49600–49620, 49634–49636 | NE-11 (правила), NE-12 (арты, UI), NE-12b (PROTOCOL 25), NE-17 (Gragas/Aurora/Olaf) |

  Плюс две фанатские колоды Tyrants другой сессии — **SIEGE** (49300–49319) и **MERCENARIES** (49400–49419), см. раздел в конце.
- Всё закоммичено и запушено на GitHub (`main`). Последний деплой — сборка 1792009359 (2026-10-15, после NE-20, **PROTOCOL 27**): все колоды New Era в обычном пуле.
- Тесты на 2026-10-14 (после NE-17): `пройдено: 1772, провалено: 0`, сеть `136 / 0`. В тесте карт 285 (… + 25 Avernus + 23 Icewind Dale). Сетевой `[server4] без лимита времени доска легла в сетку` (этап Stock-2) примерно в половине прогонов падает по времени и до правок — повторный прогон проходит.
- **NE-20 (2026-10-15):** все 7 колод (Celestial, Ravenloft, Waterdeep, Avernus, Icewind Dale, Siege, Mercenaries) без `wip` — в обычном пуле (STANDARD/RANDOM, онлайн-поиск), 13 полуколод. Вкладка CARDS: второй ряд вкладок New Era, карты по возрастанию цены, жетоны и вторые стороны — кнопкой под большой картой (`CollectionPage.TOKENS`). Простой автоигрок тестов с New Era может зациклиться (Black Pudding повышает всю колоду) и проигрывать рашу Ravenloft — тесты взяли другие сиды / классические пары.
- **Bilgewater владелец велел пропустить (2026-10-14)** — следующая колода по mapping-файлу после Freljord: **Shurima** (Devotion, картинки PDF с 144: 144 Azir, 145 Xerath…). Или живая проверка AVERNUS / ICEWIND DALE.
- Не в git и не моё: `scenes/ui/card_fx.gd`, `tests/ui_shot.gd` — правки владельца (отладочный флаг), не трогать и не коммитить.
- **Владелец ещё не проверял New Era-колоды живьём.** Чек-листы — в конце разделов ниже.

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
- **Полуколода:** `celestial` в `data/cards/half_decks.json`, 40 карт (20 уникальных; NE-13 по выбору владельца убрал Priest 49001, Pegasus 49008, Sphinx of Lore 49011 — карты остались в cards.json, +1 копия Warrior Infantry, Sphinx of Wonder, Hippogriff; PROTOCOL 26), флаг `"wip": true`, поэтому её нет в обычном пуле случайного выбора. Иначе бы поменялись сиды и журналы старых партий.
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
**NE-14:** по выбору владельца 40 карт / 20 уникальных — убраны Lemure 49110, Will-o'-Wisp 49111, Spirit Naga 49112 (в cards.json остались), все обычные карты по 3 копии (Death Dog, Gargoyle, Vampire Familiar, Shambling Mound, Bearded Devil, Specter, Awakened Tree, Grick, Sea Hag, Swarm), 10 карт по 1; PROTOCOL 27. Проверка сети «[server4] без лимита времени доска легла в сетку» иногда падает и до правки (случайный сид доски).
Тесты 1258/0, сеть 108/0. Всё по колоде — в `Claude outputs/new_era_shadow_isles.md` (таблица id → существо → карта мода, толкования).
- Карты 49100–49124, тип `RAVENLOFT` (до NE-8 — SHADOW), полуколода `shadow` (wip), эффекты `core/cards/shadow_cards.gd`, тест `test_shadow_isles`.
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
- Число копий карты = белые кружки внизу карты в PDF. Обычно выходит 45 карт (у Waterdeep — 42, больше карт в моде нет; так и оставлено).
- **Колоде — D&D-название по составу существ**, не имя региона LoL (владелец, 2026-10-11): Shadow Isles → Ravenloft, Piltover & Zaun → Waterdeep.
- **Имена карт уникальны во всей игре.** Если имя занято, меняется существо в New Era-колоде (так Waterdeep Hydra стала Harpy).
- Extra Champions (Vayne, Sona, Xin Zhao, Sylas, Lucian и др.) пока не берём.
- Работа маленькими этапами: «Stage NE-N: …», после каждого — тесты, коммит и короткий чек-лист на русском.

## Как делать следующую колоду (конвейер)
0. **Скрипты-помощники** лежат в `engine/godot/tools/new_era/` (запуск: `Godot --headless --script "<полный путь к .gd>"`, параметры — переменными окружения, пути — в стиле `C:/...`):
   - `extract_pdf.gd` — `OUT_DIR=<папка>`: все 479 JPEG-картинок PDF мода в `<папка>/0000.jpg…` (~1 мин). Read-инструмент PDF больше 100 МБ не открывает, Python здесь не работает — только так.
   - `pdf_sheets.gd` — `PDF_DIR=<папка> FROM=74 TO=97`: листы 2x2 карт для чтения текста, кладутся рядом с папкой как `sheet_NNNN.jpg`. Картинки 1731x2327, по одной смотреть дорого.
   - `art_contact.gd` — `DIR=<папка артов> OUT=<файл.jpg>`: все арты на пурпурной подложке (видно прозрачный фон) и в консоли их порядок.
   - `art_grid.gd` — `DIR NAMES="a.png b.jpeg" COLS=4 [CELL=600] OUT`: арты с сеткой через 100 px исходника — по ней выбирается окно `Rect2i` для `SINGLE_ART`.
   - `card_art_grid.gd` — `FROM=49200 TO=49211 OUT`: окна арта готовых карт x3 с сеткой 10 px — для проверки кадра и `MINI_FACE`.
   - `mini_strip.gd` — `IDS="49203 49205" OUT=<файл.png>`: мини-карты x4 полосой.
1. **Читать карты.** Извлечь картинки (`extract_pdf.gd`) во временную папку и смотреть листами (`pdf_sheets.gd`). Порядок карт в PDF (номера картинок):

   | Регион | Картинки |
   |---|---|
   | Demacia | 0–28 (0 Cursed Wanderer, 1–5 стартовые мода, 6–27 Демасия, 28 Shyvana) |
   | Shadow Isles | 29–52 (+ 321 Sapling, 326 Spider Elise) |
   | Piltover & Zaun | 53–73 (в 58 и 67 по две карты; Ferros Elite — только в 67) |
   | Noxus | 74–96 (+ 451–453 Blade Fragment, 454 Blade of Exile) |
   | Bilgewater | с 97 (97 Shellshocker, 98 Prowling Cutthroat, Hired Gun, 100 Mystifying Magician, 101 Watchful Idol…) |
   | Freljord | 121–143 (127 — Troll Scout + Rimetusk Shaman; жетоны 324 Eggnivia, 441–450 предметы Ornn) |
   | Shurima | с 144 (144 Azir, 145 Xerath, 146 Renekton, 147 Nasus…) |
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
   Жетоны и вторые формы чемпионов лежат отдельно: ~318–330 (Hextech, Shimmer, Sapling, Tibbers, Valor, Eggnivia, Dragon Shyvana, Spider Elise, Cougar Nidalee, Mega Gnar…), 438–454 предметы (Aphelios, Ornn, осколки Riven), дальше Poro. Быстро найти — контакт-лист кусками по 40 картинок (`art_contact.gd` на папку с копиями).
   Сколько копий: белые кружки внизу карты; у карт стоимостью 6+ (чемпионы) всегда 1. Обычно 13 обычных + 10 чемпионов = 45.
2. **Найти арты.** Во встроенном браузере открыть dndbeyond.com/monsters/… и через javascript_tool сделать fetch(`/monsters?filter-search=Имя`). Затем fetch страницы монстра (каждую в своём try/catch: закрытая страница роняет fetch) и взять src из `<img ... class="monster-image">` — общая регулярка по `avatars/` ловит картинки оформления сайта. Скрипт запускать фоном (`window.R = …`), результат забирать через 40 с: у javascript_tool лимит 45 с. Скачивать curl'ом с `-A "Mozilla/5.0"`. Монстры из платных книг отдают `locked` — брать других. jpeg почти всегда с фоном, png бывает и с фоном, и без. Проверять контакт-листом с пурпурной подложкой (прозрачное видно сразу). Почти всегда лучше версии **2024 года** (id `5195xxx`/`4904xxx`): у них чаще сцена с фоном, у 2014 года — вырезанные фигуры. **Но и у 2024 года много вырезанных фигур** (на AVERNUS 8 из 23: Imp, Quasit, Dretch, Pit Fiend, Gladiator, Hobgoblin Warrior…), поэтому имена существ закладывать в код только ПОСЛЕ контакт-листа артов — иначе потом переименовывать. Узкие картинки (например, 377x1000) часто без фигуры в кадре. Перед выбором проверить, что имени нет в `cards.json` (у всех колод, включая Siege/Mercenaries). Свободные монстры с фоном, ещё не занятые (на 2026-10-14, после NE-17): Gorgon, Cockatrice, Ankheg, Dryad, Dragon Turtle, Giant Toad (2024 jpeg), Sprite (узкий), Zombie, Stone Giant (2024, сцена), Goblin Minion, Steam/Magma/Dust Mephit, Hyena, Goat, Tough (узкий), Cultist (узкий), Commoner (сцена без героя). Великаны, Werewolf, Guard, Bulette, Centaur Trooper, Cultist Fanatic теперь заняты Icewind Dale. Кандидаты Icewind Dale — `cards/freljord/cand*` (не в git). Скачанные кандидаты лежат в `cards/avernus/cand*` (не в git).
3. **Положить данные.** Арты — в `cards/<колода>/`. Новые карты дописать в конец `cards.json` (следующий диапазон id, например 49100+), полуколоду — в `half_decks.json` с `"wip": true`, тип — для подписи. В `tools/pixel_cards.gd` добавить:
   - в `SINGLE_ART` — `id: ["папка/файл", Rect2i(окно арта)]`, пропорция 164:100;
   - в `MINI_FACE` — левый верхний угол выреза 52x53 в арте 164x100;
   - в `set_name()` — подпись для `card_id/100`.
4. **Сгенерировать карты:** `Godot --headless --path engine/godot --script res://tools/pixel_cards.gd` (~2,5 мин). `-- mini` перерисует только мини-карты, `-- measure` покажет высоты текстов: текст новой карты не должен превышать 85 px, иначе раздуется рамка всего набора. После генерации — `--import`.
5. **Кадры** удобнее подбирать по сетке 10 px на окне арта (вырезать `(6,34,164,100)` из `assets/cards_pixel/<id>.png`, увеличить x3, сетка). Оценки «на глаз» по общему листу дважды ошиблись.
6. **Эффекты** — в новом файле `core/cards/<deck>_cards.gd` по образцу celestial_cards.gd, подключить в `CardLibrary._build_effect`. Добавить названия вариантов в `option_card.gd` и тест колоды. Чтобы колода появилась в переключателе NEW ERA: ключ — в `GameSetup.NEW_ERA_DECKS`, надпись кнопки — в `SetupScreen.NEW_ERA_TITLES`, цвет фона — в `UnderdarkBg.DECK_COLOURS`. Число карт в `test_card_library_smoke_all_cards` поднять. Перед коммитом — несколько партий ботов: `tests/balance_run.gd -- name=x players=4 "mode=newera:celestial,<ключ>" games=24 procs=6` (итог в `Claude outputs/balance/`, пробные файлы потом удалить).
   - Флаги хода — в `state.turn_flags`; простые флаги ставят `ShadowCards._SetFlag` / `_AddFlag`.
   - Если одно и то же дерево эффекта нужно применить ещё раз, его надо пересобрать: эффекты хранят ответы внутри себя (см. `FocusEffect._fresh_copy`).
   - Снимок войск до/после действия («если поставил рядом с чужим», «если убил белое») — `PiltoverCards._AfterTroops`.
7. **Тесты:** `run_tests.gd` и `net_loopback.gd`. После новых `class_name` сначала выполнить `--import`, иначе «Identifier not declared».
8. **Мелочи, на которых спотыкались (NE-9/10):**
   - Карты в `cards.json` дописывать так: фрагмент JSON записать инструментом Write в scratchpad, потом склеить (`head -c -2` + `,\n` + фрагмент). Heredoc в Bash ломается на апострофах (`player's`).
   - `pixel_cards.gd` при полной генерации иногда меняет `assets/cards_pixel/48512.png` — это не наше, откатывать `git checkout`.
   - Если текст новой карты длиннее 85 px (`-- measure`), сокращать текст, а не рамку.
   - Перед выкладкой: новая колода или правка правил → поднять `NetSession.PROTOCOL` (сейчас 24), потом `bash server/deploy.sh` (собирает из рабочей папки, грузит на VPS, перезапускает; проверка — `curl http://129.101.123.70/tyrants/version.txt`).

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
  - Execute (бывший Devour) / Might — сделано в AVERNUS;
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
- AVERNUS: в интерфейсе нет счётчика пожираний за ход; бот не знает о Might; кадр Minotaur of Baphomet можно доработать.

## Готово: Noxus → AVERNUS (NE-9 `5db51a7`, NE-10 `441c853`, PROTOCOL 24 `8051fb4`)
**NE-16:** по выбору владельца 40 карт / 20 уникальных — убраны Pseudodragon 49504, Wereboar 49501, Bugbear Warrior 49508 (в cards.json остались), Mummy, Goblin Boss, Hobgoblin Captain, Minotaur of Baphomet — по 3.
Всё по колоде — в `Claude outputs/new_era_noxus.md` (таблица id → существо → карта мода, все толкования).
- Карты 49500–49522 (45 копий) + жетоны 49523 Blade Fragment (запас 3 у доски, если в рынке есть Half-Dragon) и 49524 Blade of Exile. Тип `AVERNUS`, ключ `noxus` (wip), эффекты `core/cards/noxus_cards.gd`, тест `test_avernus_deck`, цвет фона тёмно-красный.
- Название колоды и все существа выбраны мной, **владелец их ещё не видел**. Состав: Bandit, Wereboar, Goblin Boss, Hell Hound, Pseudodragon, Medusa, Bugbear Stalker, Guard Captain, Bugbear Warrior, Mummy, Ogre, Minotaur of Baphomet, Hobgoblin Captain; чемпионы Weretiger (Katarina), Lamia (Leblanc), Horned Devil (Mordekaiser), Efreeti (Vladimir), Azer Sentinel (Draven), Ice Devil (Swain), Troll (Sion), Fire Giant (Darius), Half-Dragon (Riven), Wyvern (Samira).
- Execute = Devour; **Might** — `NoxusCards.Might(index, factory)`: срабатывает, если текущий игрок сожрал в этот ход ≥ index карт. Все пути пожирания (DevourCard, Carrion Crawler, Ulitharid, Green Hag, карты Avernus) зовут `NoxusCards.on_devour` — новые карты с Devour тоже должны его звать.
- Новое в движке: `GameState.deployable_slots(pid)` — все проверки постановки войск идут через него (Weretiger закрывает локацию); `GameState.instant_winner` + `Scoring.winners` (Horned Devil «you win»); скидка на слот рынка `turn_discounts["slot:N"]` (снимается при покупке); `turn_flags["devours"]`, `turn_flags["trophy_start"]` (ставится в `start_turn`).
- Чек-лист живой проверки: (1) NEW ERA → CELESTIAL + AVERNUS, на рынке карты с артами, фон красно-золотой; (2) Mummy без пожирания +2 Influence, Ogre (сожрать карту), снова Mummy +3; (3) Bandit — замена сожранной карты рынка из 3 верхних; (4) Bugbear Stalker — новая карта в слоте на 3 дешевле (цена зелёная); (5) Half-Dragon — в сброс приходит Blade Fragment.

## Готово: Freljord → ICEWIND DALE (NE-11 `551d69a`, NE-12 `aebd453`, NE-12b `6b6417c`, NE-17)
**NE-18:** по выбору владельца 40 карт / 20 уникальных — убраны Guard 49600, Giant Owl 49610, Giant Hyena 49612 (в cards.json остались), Giant Goat и Winter Wolf — по 3.
**NE-19:** владелец заменил животных: Giant Goat → Magmin, Giant Badger → Ettercap, Giant Elk → Invisible Stalker, Boar → Xorn, Cultist Fanatic → Skeleton (id и правила те же; константы в freljord_cards.gd переименованы).
Всё по колоде — в `Claude outputs/new_era_freljord.md` (таблица, толкования).
- Карты 49600–49618, 49620 и 49634–49636 (45 копий). Тип `ICEWIND`, ключ `freljord` (wip), эффекты `core/cards/freljord_cards.gd`, тест `test_icewind_deck`, фон ледяной голубой. **NE-17:** по решению владельца убраны Roc, Stone Giant, Giant Ape и всё, что с ними связано (Roc Egg, 10 предметов Masterwork, знаки на доске `state.wards`, стопка FRONT, `state.front`, `state.masterwork`; id 49619, 49621–49633 удалены). Вместо них Extra Champions мода: Gragas → Pirate Captain (49634), Aurora → Blink Dog (49635), Olaf → Young White Dragon (49636).
- **Frostbite** — `FreljordCards.on_discard` из всех путей сброса (DiscardCardEffect, ForceDiscard.VictimDiscard, ScryCards, _CycleHand, _DiscardDrawn, RemoveSelfFromPlay). Решение владельца: сброс руки в конце хода Frostbite не вызывает. Новые карты со сбросом из руки тоже должны звать on_discard.
- **Hill Giant** (Braum) — `FreljordCards.guard(victim, causer, what, inner)`: им обёрнуты все принудительные сбросы (ForceDiscard._guarded) и Insane Outcast от соперника (GiveInsaneOutcast._give).
- **Счётчики хода NE-17:** `turn_flags.gained` (Pirate Captain; ставит `FreljordCards.note_gain` во всех путях получения карты), `turn_flags.olaf` и `olaf_locked` (Young White Dragon: `on_card_deploy` в DeployTroop, `locked_power` в Actions.deploy, GameState, StateView, бот, Chimera; `spent_power` при убийстве и возврате шпиона). MoveTroop получил `dest_near_site` (Blink Dog).
- UI: стопка FRONT и рисование знаков на доске убраны вместе с картами (NE-17); новое событие журнала `card_on_top` (Pirate Captain).
- Существа выбраны мной, владелец их не видел: Guard, Cultist Fanatic, Werewolf, Giant Goat, Centaur Trooper, Bulette, Ice Mephit, Giant Elk, Giant Badger, Boar, Giant Owl, Winter Wolf, Giant Hyena; чемпионы Owlbear (Nunu), Hill Giant (Braum), Cloud Giant (Lissandra), Remorhaz (Ashe), Mammoth (Sejuani), Storm Giant (Volibear), Frost Giant (Tryndamere), Pirate Captain (Gragas), Blink Dog (Aurora), Young White Dragon (Olaf).
- Чек-лист живой проверки: (1) NEW ERA → CELESTIAL + ICEWIND DALE, фон ледяной; (2) соперник с Giant Goat в руке, сыграть Werewolf — он сбрасывает Goat и берёт карту (Frostbite), у тебя +3 Power; (3) Hill Giant в руке соперника — ему предлагают раскрыть и не сбрасывать; (4) Pirate Captain без покупок — в конце хода вопрос, карта приходит в новую руку; (5) Young White Dragon — +3 Power, базовое действие Deploy на эту Power не даётся; (6) Blink Dog — выбрать локацию со своим войском и переставить оттуда чужие войска рядом.

## Bilgewater (владелец велел пропустить, 2026-10-14)
- Картинки PDF с 97: 97 Shellshocker, 98 Prowling Cutthroat, 99 Hired Gun, 100 Mystifying Magician, 101 Watchful Idol, дальше смотреть листами `pdf_sheets.gd FROM=97 TO=125`. Жетоны (если есть) — в районе 318–330 и 438–454.
- Механики: **Voyage** — карта срабатывает сейчас и ещё раз в начале следующего хода (нужен отложенный эффект на начало хода и чтобы карта не уходила в сброс в конце хода); **кубики D4/D6** с перебросами (Shellshocker: «бросаешь кубик — бросай два, выбирай»), броски — через `state.rng`, чтобы реплеи и сеть сходились; Hired Gun — возврат в руку, когда другой игрок покупает карту за 6+ (реакция в чужой ход, по образцу `PiltoverCards.after_buy` / `MercenaryCards.after_buy`).
- Черновик существ в mapping: сахуагины, куо-тоа, морские существа. D&D-название придумать по составу (например, SEA OF SWORDS / NELANTHER / SAHUAGIN), проверять занятость имён и фон артов ДО кода.

## Piltover & Zaun — правила (NE-6) и арты (NE-7)
Всё по колоде — в `Claude outputs/new_era_piltover.md` (таблица id → существо → карта мода, толкования).
- Карты 49200–49220, тип `WATERDEEP` (до NE-8 — PILTOVER), полуколода `piltover` (wip, **40 карт / 20 уникальных** с NE-15: владелец убрал Rust Monster 49203, Clay Golem 2, Gelatinous Cube 4, Tough Boss 4, Spy 3), эффекты `core/cards/piltover_cards.gd`, тест `test_piltover_zaun`. Цвет фона — розовый (`UnderdarkBg.DECK_COLOURS["piltover"]`).
- Новое в движке:
  - `FocusEffect` с `need = 2` — Double Focus; `FocusEffect.support()` — сколько других карт аспекта (сыграно + в руке); флаг `focus_extra` повторяет Focus (копия эффекта пересобирается из карты по номеру Focus, `FocusEffect.registry`).
  - `ChooseEffect`: флаг `choose_all` — вариант «All of them».
  - `PlaceSpy`: флаг `spy_move` — после шпиона вопрос «Move a troop?».
  - Лишний ход: `GameState.extra_turn_for / in_extra_turn`, `GameEnd.advance_turn`, `turn_flags["card_limit"]`, `TurnEngine.can_play_card` (бот это учитывает), в view — `extra_turn`, `cards_left`.
  - Harpy (бывшая Hydra): `PiltoverCards.after_buy` из GameServer после покупки.
  - Режимы: `GameSetup.is_new_era / is_mode / new_era_pair / new_era_mode`, `SetupScreen.mode_title`.
- **NE-7 (арты):** 21 арт в `cards/pz/`, окна и мини-лица в `pixel_cards.gd`; возможная доводка кадров — Spy (лицо в тени), Rust Monster и Iron Golem (тёмные). Кандидаты `cards/pz/cand*` не в git.
- В интерфейсе пока нет отдельной надписи «лишний ход, осталось N карт» — сервер просто не даёт сыграть четвёртую карту.
- Чек-лист для живой проверки: (1) NEW ERA → кнопки колод, выбрать CELESTIAL + PILTOVER, фон розово-золотой; (2) Homunculus «choose all», потом Wererat — есть вариант «All of them»; (3) Basilisk с двумя Malice в руке — лишний ход, четвёртая карта не играется; (4) Assassin показывает 2 верхние карты каждого; (5) Harpy с двумя Ambition — после покупки предлагает карту дешевле.

## Siege и Mercenaries (2026-10-13)
Фанатские полуколоды Tyrants (не Runeterra): `cards/Siege_Deck.pdf`, `cards/Mercenaries_-_Full_deck.pdf`. Подробности — `Claude outputs/siege_mercenaries.md`.
- Карты 49300–49319 (тип SIEGE), 49400–49419 (тип MERCENARY), по 40 карт, `wip`; кнопки SIEGE и MERCENARIES в переключателе NEW ERA.
- Эффекты: `core/cards/siege_cards.gd`, `core/cards/mercenary_cards.gd`; тесты `test_siege_deck`, `test_mercenaries_deck`.
- Арты вырезаны из самих PDF: `cards/siege/`, `cards/mercenaries/`.
- Имя Hydra перешло к карте Siege, карта Waterdeep 49220 теперь **Harpy** (арт 2024 года с D&D Beyond, `cards/pz/harpy.png`).
