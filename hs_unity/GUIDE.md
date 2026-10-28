# Анимации розыгрыша карт из Hearthstone — рабочий документ

Как делать анимации уникальных карт: что хочет владелец, как устроен конвейер, команды,
проверки и ловушки. Собрано по работе над Red Dragon (Deathwing, Worldbreaker, этапы
HsFx-0..12, октябрь 2026), дополнено на остальных картах (HsFx-14..35, 2026-10-24/25).
Какая легендарка HS идёт к какой карте — `CARD_MAP.md` (там же «Готово» и запас проб).

## Перенос назначений владельца (с 2026-10-28) — НОВЫЙ ЧАТ НАЧИНАТЬ ОТСЮДА

Владелец сам выбрал эффекты для 131 карты в HsBrowser (`data/hs_assign.tsv`, «назначение
важнее CARD_MAP») и сказал «начинай переносить утверждённые анимации в проект». Эффект
владелец уже видел вживую — пробы кандидатов не нужны; адаптация как раньше (§0 п.2–10:
жетон и контуры HS в `hide`, всё в `under`, `pin`/полёт по §1, выжигание в тон эффекта,
эпичность по цене — если эффект явно мал/велик для цены, спросить). Одна карта = один
коммит «Stage HsFx-N». Номер следующего — смотреть `git log --oneline | grep HsFx | head -1`.
Пакетный Unity можно запускать из копии проекта в scratchpad, если у владельца открыт
HsBrowser (память «Unity: edit in copy»).

- **HsFx-56 (сделано):** «Без анимации» — Rath Modar, Imix, Vanifer, Yan-C-Bin: убраны
  из `RECIPES`/`SCRIPTS`, кадры и звуки удалены, рецепты оставлены.
- **HsFx-69..75 (сделано):** Balor → Ragnaros the Great Fire, Glabrezu → Xavius, Aerisi → Inara,
  Gar → Mutanus, Ogrémoch → Ravitz, Ulitharid → Azalina, Beholder → Staff of the Endbringer;
  `magtheridon`, `nespirah`, `neptulon`, `ohnahra` удалены. Все замены у готовых колод сделаны.
- **HsFx-64..68 (сделано):** dragons — Black → Victor Nefarius (выжигание чёрное), Blue → Murozond
  Unbounded, Green → Y'Shaarj LT23 (`yshaarj_lt`, звуки в соседних папках выгрузки), Severin →
  Herenn, White → Vyranoth; `onyxia`, `malygos`, `ysera`, `sindragosa` удалены; `chogall` ждёт Chain Devil.
  Ловушка: `port.sh` правится во время пакетного запуска — bash читает скрипт на ходу и падает;
  для пачек запускать копию (`cp port.sh /tmp/port_run.sh`).
- **HsFx-61..63 (сделано):** Council Member → Wilfred Fizzlebang (FSM без Timeline: `noTimeline`,
  `clips`, `stopAt`), Matron Mother → Renferal, Weaponmaster → Exarch Akama (старт сдвинут `move`);
  `prestor`, `azshara`, `samuro` удалены. Колода drow перенесена. Помощник — `tools/port.sh`
  (recipe / bake / rebake / sounds / check, описание в шапке).
- **HsFx-57..60 (сделано):** Graz'zt → Endbringer Umbra (`umbra`); Inquisitor → K'ara
  (перепечена с `echo_48325`, `benedictus` удалён); Deathblade → Blade of The Black Empire (`blackempire`); Masters
  of Sorcere → Zayle (кадры `zayle` перепечены с `echo_48328`). Кадры и скрипт `kaelthas`
  без карты — не удалять, перепечь для Efreeti (`echo_49516`). Готовый рецепт для другой
  карты: поменять `echo_<cid>` в рецепте, запечь в `render/<имя>_bake`, скопировать png и
  `meta.json` поверх старых (`.import` остаются), `--import`.
- **Без изменений (11):** Red Dragon, Demogorgon, Orcus, Vrock, Zuggtmoy, Marlos, Olhydra,
  Elder Brain, Aboleth, Neogi, Death Tyrant (TB_World007 = тот же префаб, что AV_203).
- **Заменить у готовых (19), старые кадры удалять после замены:** Council Member → Wilfred
  Fizzlebang (было prestor), Deathblade → Blade of The Black Empire (zayle), Inquisitor →
  K'ara (benedictus; рецепт `kara` есть), Masters of Sorcere → Zayle (kaelthas; рецепт
  `zayle` есть), Matron Mother → Renferal (azshara), Weaponmaster → Exarch Akama (samuro),
  Black → Victor Nefarius (onyxia), Blue → Murozond Unbounded (malygos), Green → Y'Shaarj
  LT23 (ysera), Severin → High Cultist Herenn (chogall), White → Vyranoth (sindragosa),
  Balor → Ragnaros the Great Fire (magtheridon), Glabrezu → Nightmare Lord Xavius
  (razidir), Graz'zt → Endbringer Umbra (kara), Aerisi → Inara Stormcrash (ohnahra), Gar →
  Mutanus (neptulon), Ogrémoch → Ravitz (nespirah), Ulitharid → Azalina Soulsever
  (irida), Beholder → Staff of the Endbringer (isorath).
- **Готовые рецепты пригодятся новым картам:** Kael'thas → Efreeti, Cho'gall → Chain
  Devil, Razidir → Guardian Naga, Irida → Oni, Iso'rath → Roper (перепечь с контуром и
  тоном новой карты: `echo_<cid>.png`, `tintHue`).
- **Новые (~100):** все остальные строки `hs_assign.tsv` (undead … ixtal).
- **Без назначения (19, не трогать):** Death Knight, Mummy Lord, High Priest of Myrkul,
  Berserker, Treant, Archmage, Harpy, Relentless Siege, Beast Tamer, Siege Beast,
  Jarlaxle, Ahmaergo, Mammoth, Gorgon, Kraken, Satyr Thornbearer, Githyanki Knight,
  Thri-kreen Marauder, Yuan-ti Infiltrator.
- **Chrono-Lord Deios (TIME_064)** назначен двум картам — владелец 2026-10-28: «перевыберу
  сам» одной из них; Dao и Lizardfolk Geomancer делать по новому `hs_assign.tsv`.

## Где остановились (2026-10-27)

**Новый чат — начать отсюда.** Задеплоено 4 колоды, 29 карт (сборка 1792957293). Потом
сделана и закоммичена 5-я колода — **aberrations** (HsFx-48..55, ниже), **не запушено и
не задеплоено** (push + `bash server/deploy.sh` — по слову владельца). Следующий этап —
**HsFx-56**; следующую колоду называет владелец — спросить вопросом с вариантами (undead,
celestial, shadow…). Перед пробами: §1 (все наборы HS, эпичность по цене, **дарк фэнтези**), арт и
текст карт колоды (`engine/godot/data/cards/cards.json`), `CARD_MAP.md` (запас проб).
Пробы пачкой — `hs_unity/tools/cand.sh` (ниже, «Порядок для новой колоды», шаг 2).

- **Готово и задеплоено — 4 колоды, 29 карт.** dragons (Red, Black, Blue, Green, White
  Dragon, Rath Modar, Severin), drow (Council Member, Deathblade, Inquisitor, Masters of
  Sorcere, Matron Mother, Weaponmaster), demons (Balor — Magtheridon, Demogorgon —
  Kil'jaeden, Orcus — Archimonde, Zuggtmoy — Moldara, Graz'zt — K'ara, Vrock — Nythendra,
  Glabrezu — Razidir), elementals (ниже). Скрипты — `SCRIPTS` в `hs_play.gd`, рецепты —
  `recipes/`.
- **elementals (HsFx-36..47, всё задеплоено, сборка 1792957293)**: Ogrémoch — Nespirah (HsFx-46, вместо Therazane), Olhydra —
  Azshara Ocean Lord, Yan-C-Bin — Al'Akir CATA (смерч прилетает справа, как в HS — HsFx-44),
  Imix — Geddon (`PS_TokenGlow` в кольце спрятан), Gar Shatterkeel — Neptulon BE,
  Aerisi — Ohn'ahra (молния с левого края через левую панель — как в HS, владелец),
  Vanifer — Incindius, Marlos — Y'Shaarj (HsFx-47, вместо Mirrex). Therazane и Mirrex
  владелец снял 2026-10-26 как слишком яркие для дарк фэнтези (§1); их кадры удалены,
  пробы — в запасе. Смотреть арт карты: Огремоч — «скала с изумрудами», Марлос — медуза.
  Y'Shaarj — 56 МБ кадров (глаза на пол-экрана), самый тяжёлый набор после Worldbreaker.
- **aberrations (HsFx-48..55, 2026-10-26..27, не задеплоено)**: Beholder — Iso'rath, Ulitharid —
  Irida Sinseeker (JAIL, старый набор, но владелец назвал сам), Elder Brain — Kith'ix (дым
  `FX_Smoke*` и `Vignette_Backing*` на весь экран убраны), Aboleth — The Black Blood (купол
  `ShieldFX` спрятан), Neogi — Magmaw (HsFx-54), Death Tyrant — Shadowcrafter Scabbs (HsFx-55):
  обе владелец выбрал сам в HsBrowser вместо Wallow и G'huun. Scabbs — обёртка `_Super`
  эффекта карты-героя: `spell` + клип аниматора `clips` + частицы Timeline в `controls` (FSM
  ведёт и аниматор, и Timeline), тень портрета `SocketShadowRoot` спрятана. Чего владелец не захотел у
  Ulitharid: C'Thun Eye of the Empire без глаза, с перекрашенной текстурой щупалец
  (`textures` + `recolor`) и разведёнными по углам (`move`) — «каша». Если владелец просит
  «щупальца» — искать по узлам/текстурам `tentacle|tendril` в выгрузках (так найден C'Thun).
- **`cand.sh`** раньше не находил узлы со скобками (`FX_Impact (1)`) для `controls` —
  исправлено; у старых проб из запаса удар мог потеряться — проверять `controls` по Timeline.
- **`pin` — не для всего, что летит** (владелец 2026-10-25): прибитый смерч Al'Akir
  «появляется из ниоткуда сразу гигантского размера» — вернули полёт как в HS. Прибивать
  только жетон/разлом, который формируется на месте (Razidir); крупный объект, который в HS
  прилетает и сжимается, оставлять с полётом. При сомнении — пробы обоих вариантов.
- **Дальше:** следующую колоду называет владелец (undead, celestial, shadow…). Легендарки
  из старых наборов в `CARD_MAP.md` — нормальные кандидаты (§1, правило «только свежие»
  снято 2026-10-26). Следующий номер — **HsFx-56**.
- **Ловушки этой колоды:** `deps_*.txt` из запаса (`render/cand/`) — только эффект, без
  Choice_Reveal: перед запеканием слить с `deps_worldbreaker.txt` (`awk '!seen[$0]++'`),
  иначе «prefab not found b5e71dd8…» и 0 кадров. `hs_hue.gd` / `bake_sheet.gd` с
  несуществующим кадром виснут (Godot не выходит) — номера кадров проб проверять `ls`.
  Пока Unity печёт одно, можно готовить следующее (рецепт, звуки) и импортировать готовое —
  Unity строго по одному. **Если владелец держит открытым HsBrowser** (тот же проект
  `hs_unity` в редакторе), пакетный Unity не стартует («Multiple Unity instances») —
  попросить закрыть окно Unity перед пробами и запеканием.
- **Порядок для новой колоды** (так сделаны демоны):
  1. Стоимости карт колоды (`engine/godot/data/cards/cards.json`, `cost`) → уровень
     эпичности (§1). Строки колоды в `CARD_MAP.md` — первый кандидат; ещё 2–3 по смыслу
     из любых наборов (сначала избранное `data/hs_favorites.tsv` и **запас** в `CARD_MAP.md`,
     пробы уже есть; иначе `data/hs_legendary_summons.tsv`, нет в
     `CARD_MAP.md`: `grep -F <prefab> CARD_MAP.md`).
  2. Пробы кандидатов пачкой — `hs_unity/tools/cand.sh` (рабочая папка = scratchpad с
     `hsx`, §0 п.1): `bash hs_unity/tools/cand.sh <SP> make BE_784:yshaarj CATA_527:nespirah
     …` (выгрузка, пути узлов, deps с Choice_Reveal, рецепт-проба в `hs_unity/render/cand/`:
     жетон и контуры HS в `hide`, корень в `under`, ControlRandomizedTrack в `controls`),
     затем в фоне `bash hs_unity/tools/cand.sh <SP> render yshaarj nespirah …` (Unity по
     одному, лист `<имя>_sheet.png` и полоса `<имя>_strip.png` — 4 кадра у места карты,
     удобно отсеивать). Смотреть полосы, отобрать 3–4 мрачных, владельцу — листы
     (SendUserFile) и вопрос с вариантами. Ссылки на выгрузку — в выводе `make`.
  3. Выбранное — по §0 (выжигание крупно, запекание, звуки, HsPlay, проверка в партии,
     тесты, коммит «Stage HsFx-N»). Следующий номер — **HsFx-56**.
- **Демоны — что решил владелец:** у Balor (единственная старая, BT — оставлена) кольцо
  оков перекрашено в огонь (`tintHue` на `Binding_Root`), карта держится до конца оков
  (`hold` 2.4) — если эффект после удара долго идёт вокруг карты, спрашивать. У Orcus
  виньетка и туман на весь экран убраны (пятна в пиксель-арте), хвосты метеоров
  оставлены. Glabrezu: владелец сам выбрал Razidir и попросил «адаптацию» — разлом не
  летит из угла (`pin`), контур и овал жетона убраны.
- **Не путать ответы владельца:** «другие варианты, мне нравится эта клешня вообще»
  значило «НЕ нравится» — при сомнении переспросить одним вопросом.
- **Контуры жетона HS прятать всегда** (владелец замечает): `TokenGlow`,
  `MinionEdgeGlow*`, `Mesh_TokenGlow*`, `*Top_Nightmare`, `M_MinionShell*` (оболочка жетона, у Incindius — жёлтая капсула) — овал жетона миньона и
  контур легендарной рамки (у K'ara — овальная обводка, у Razidir — «крыло» сверху).
  Перед запеканием `grep -iE "glow|edge|token" paths.txt` и пробы без них.
- **Полёт жетона HS из-за края** (Razidir): в рецепте `pin` [{node, pos}] — узел
  каждый кадр в точке посадки (pos = последнее значение кривой position в клипе).
- **Пробы замен до работы:** владелец может попросить «какие ещё есть варианты» — 3–4
  свободные легендарки по смыслу, пробы всех (рецепты-пробы в `hs_unity/render/cand/`,
  только слой эффекта; путь `textures/...` в рецепте — от папки рецепта), листы рядом,
  выбор вопросом. Что владелец смотрел и отверг — в `CARD_MAP.md` у карты.
- **Как владелец ведёт работу:** «делай дальше X, деплой потом» — коммит на каждую карту,
  push + `bash server/deploy.sh` только по слову. Пробы (лист + выжигание крупно) до
  полного запекания; спорное — вопросом с вариантами (AskUserQuestion). Тон выжигания
  почти всегда **в цвет анимации** (не арта): мерить `tools/hs_hue.gd` по кадру пробы.
- **Если эффект HS плохой** (только полёт миньона, слабая дымка, «выглядит странно»):
  найти 2–3 замены по смыслу в `data/hs_legendary_summons.tsv`, которых нет в
  `CARD_MAP.md` (`grep -F <prefab> CARD_MAP.md`), сделать пробы всех и дать выбрать;
  строку в `CARD_MAP.md` заменить с причиной. Так заменены Valeera → Zayle и
  Whitemane → Benedictus.
- **Почти всегда весь эффект — в `under`** (корневые узлы префаба): иначе после удара
  он закрывает карту. Жетон HS, свечение миньона и трещины — в `hide`.

## Просмотр всех легендарок HS — HsBrowser (2026-10-26)

Владелец сам выбирает анимации в Unity, без запекания: `hs_unity/hs-browser.bat` (или в
открытом проекте меню **Tyrants → HS Legendaries**). Слева все 1291 эффект розыгрыша
(CustomSummon/Spawn, золотые и алмазные отдельно), поиск, фильтр по дополнению и «Свежие
2024+», сортировка по выходу дополнений (порядок — по номеру карты в базе HS), «Не
смотрел»; справа эффект играет вживую с камеры доски HS в точке посадки (490, 365),
жетон HS спрятан (переключатель). ↑↓ — листать, Пробел/F — ★, R — заново.
- **Избранное владельца** — `hs_unity/data/hs_favorites.tsv` (card_id, name, kind, set): отсюда
  брать кандидатов для колод. Просмотренные — `hs_unity/render/hs_seen.txt`. Фильтр «★: все /
  только избранное / без избранного» (владелец 2026-10-27). Кнопка «Скрыть занятые» убирает из
  списка эффекты, уже стоящие на картах Tyrants (CARD_MAP + hs_assign.tsv); после назначения в
  панели эффект пропадает сразу, «Показать эффект» снимает фильтр (владелец 2026-10-27).
- **Панель карт — HsCards** (владелец 2026-10-27; справа внутри окна HsBrowser, кнопка «Карты
  Tyrants» прячет; отдельное окно не годится: на экране 300% с двумя мониторами Unity ставил его
  за край): 150 уникальных карт по колодам (одна
  копия в полуколоде), полная карта `cards_pixel` и миниатюра `cards_mini`, строка CARD_MAP.
  «Назначить» (Enter) кладёт эффект, выбранный в HsBrowser, на карту →
  **`hs_unity/data/hs_assign.tsv`** (card_id, card, deck, hs_id, hs_name, kind, date). **Назначение
  важнее CARD_MAP**: такие карты запекать по нему (новый рецепт, строку CARD_MAP обновить).
  «Без анимации» (только у сделанных) — строка с hs_id `-`: у карты убрать запечённый эффект
  (запись в SCRIPTS HsPlay, кадры, строку CARD_MAP), в списке ✗. «Отменить» — убрать строку.
  ● — назначено, ✓ — сделано; в HsBrowser «→ карта» у занятых эффектов, предупреждение о
  повторе. Проверка: `HsCards.Dump -hsc-out <txt>`, снимок окна `HsCards.Shot` (см. код).
- Список — `hs_unity/render/hs_gallery.tsv` (не в git, после патча HS пересобрать):
  `<SP>/hsx/hsx.exe gallery C:/Games/Hearthstone/Data/Win <SP>/hsx/cabmap.tsv
  hs_unity/data/hs_legendary_summons.tsv hs_unity/render/hs_gallery.tsv` (~15 с).
- Это предпросмотр: без звука и без шейдера пиксель-арта. Окончательно — пробы по §0.
- **ControlRandomizedTrack теперь играет сам** (2026-10-26): в `Assets/HsBake/HsTimeline/`
  заглушки `Hearthstone.Timeline.ControlRandomizedTrack` / `ControlRandomizedPlayableAsset`
  (наследники `ControlTrack` / `ControlPlayableAsset`, поля те же) — Unity связывает их с
  префабами HS, частицы новых наборов идут по Timeline. Для новых рецептов `controls` по
  этим дорожкам больше не нужны (Timeline и `controls` вместе гоняют одни частицы — при
  совпадении отрезков то же самое; старые запечённые карты не тронуты).
- Что окно делает само: прятать жетон — только его сетки (`Card_InPlay`, `TokenGlow`…),
  не узлы `OnToken`/`Token_Root` (у старых карт там весь эффект); всё выключено (спелл по
  FSM, Onyxia) — включает узлы-контейнеры; обёртка (`*_Super`, героев `*_FX`; у рыцарей
  смерти ICC в ней только лиана) — играет корневой префаб из её зависимостей, если в нём
  рендереров больше (63 карты; строка состояния «обёртка → спелл»). Составные (Zul'jin:
  закрутка, след, удар по FSM) — только крупнейшая часть. Бандлы не закрываются до
  закрытия окна: новая карта набора — несколько секунд, дальше быстро.
- **Повторы убраны** (владелец): один спелл — одна строка, самая поздняя карта (CORE_EX1_298,
  а не EX1_298; DRG_600t3); 871 эффект из 1291 строки, остальные id — «Тот же эффект» и поиск.
- Полная проверка 2026-10-26 (`all`): все 1291 видны, почти пустые — CFM_341, BOT_243.
- **Пока у владельца открыт Unity с `hs_unity`, запекание (`-batchmode`) не запустится** —
  проект один; попросить закрыть Unity.
- Проверка без окна: `-executeMethod HsBrowser.Test -hsb-cards ID,ID -hsb-out <папка>`
  (кадры 0.5/1.5/2.5 с и где рендереры; `all` с `-hsb-from/-hsb-to` — доля экрана с
  эффектом и лучший кадр каждой карты, `progress.txt`). В настоящем окне —
  `HsBrowser.Smoke` (Unity без `-batchmode`, сам закрывается). Пока владелец держит
  `hs_unity` открытым — гонять на копии проекта (Assets, Packages, ProjectSettings,
  Library, `render/hs_gallery.tsv`) в scratchpad.

## 0. Быстрый старт: новая карта по шагам

Так сделаны все карты из «Где остановились». Пути `<R>` = `C:/tyrants of the underdark godot`,
`<SP>` = scratchpad сессии, `G` = `C:\godot\Godot_v4.7.2-stable_win64_console.exe`,
`U` = `C:\Program Files\Unity\Hub\Editor\6000.6.6f1\Editor\Unity.exe`.

1. **hsx:** `dotnet build hs_unity/tools/hsx -c Release -o <SP>/hsx` (dotnet в Program
   Files есть; или скопировать готовую папку `hsx` с `cabmap.tsv` из scratchpad прошлой
   сессии: `ls /c/Users/JEKADI~1/AppData/Local/Temp/claude/*/*/scratchpad/hsx/cabmap.tsv`). `hsx extract C:/Games/Hearthstone/Data/Win <SP>/x <CARD_ID>` — первый
   запуск строит `cabmap.tsv` (несколько минут), потом быстро. Смотреть `index.txt`
   (m_CustomSummonSpellPath — основной эффект; m_PlayEffectDef.m_SpellPath — дымка или
   что-то у героя), в папке префаба: `fsm_*.txt` (тайминги, звуки, тряска),
   `timeline_*.txt`, `hierarchy.txt` (`grep "^ *GO '"` — узлы; `grep Card_InPlay` —
   меши карты HS, прятать), `anim/*.json` (какие узлы двигаются, `m_IsActive`).
2. **Логика:** понять, что эффект делает с миньоном HS, и адаптировать (§1): всё в
   точке посадки, без полёта через экран; что повторяет макет HS — в `hide`; что
   рисуется поверх места карты после удара — в `under`.
3. **deps:** `hsx deps <Win> <SP>/hsx/cabmap.tsv <SP>/d.txt CAB-<из первой строки
   hierarchy.txt>`, затем слить с Choice_Reveal: `awk '!seen[$0]++' <SP>/d.txt
   hs_unity/deps_worldbreaker.txt > hs_unity/deps_<имя>.txt`.
4. **Контур карты и тон:** `G --headless --path . --script res://tools/hs_bake_prep.gd --
   --card=<cid> --frac=0.519,0.761 --out=<R>/hs_unity/recipes/textures/echo_<cid>.png`;
   `res://tools/card_tone.gd -- --cards=<cid> --debug` (тон арта; владелец обычно
   берёт цвет эффекта — `res://tools/hs_hue.gd -- <кадр пробы>`).
5. **Рецепт** `hs_unity/recipes/<имя>.json` по образцу `onyxia.json` / `malygos.json` /
   `ysera.json`: слой эффекта (`pos [-7.59, 0, -7.01]` — посадка в (490, 365)) + слой
   Choice_Reveal (`at` = удар + ~0.02, тон `tintHue/Sat/Val`).
6. **Пробы:** `U -batchmode -quit -projectPath <R>/hs_unity -executeMethod HsRender.Run
   -hsr-win C:/Games/Hearthstone/Data/Win -hsr-recipe <R>/hs_unity/recipes/<имя>.json
   -hsr-out <R>/hs_unity/render/<проба> -hsr-frames 10,30,... -logFile ...` (пути
   абсолютные; `hs_unity/render/` в .gitignore), лист `tools/bake_sheet.gd` поверх
   `hs_unity/render/clean_bg.png` (снимок `ui_shot --scenario=hs_play --card=<cid>
   --wait=1`), выжигание крупно `--crop=400,280,180,170 --scale=2 --card=<cid>
   --card-at=461,323 --card-from=<кадр>`. **Показать владельцу и спросить спорное.**
7. **Запекание** в `<R>/engine/godot/assets/hs_fx/baked/<имя>` в фоне (~10 мин на
   300 кадров), удалить `hsr_log.txt` оттуда; `G --headless --path . --import`; в
   `.import` кадров `sed -i 's/^compress\/mode=0/compress\/mode=1/;
   s/^compress\/lossy_quality=0.7/compress\/lossy_quality=0.9/;
   s/^process\/fix_alpha_border=true/process\/fix_alpha_border=false/'`; ещё `--import`.
8. **Звуки:** `.fsb` → wav: `hs_unity/tools/vgmstream/vgmstream-cli.exe -o out.wav
   in.fsb` (Windows-сборка vgmstream, только на этом ПК, в .gitignore) в
   `engine/godot/assets/hs_fx/<имя>/`; громкость — m_Volume FSM × AudioSource;
   стингеры и VO не брать. vgmstream пишет «not found» на длинных путях scratchpad —
   скопировать `.fsb` в короткий путь (`<SP>/a.fsb`) и конвертировать оттуда.
9. **HsPlay:** `RECIPES[cid]`, `SCRIPTS[<имя>]` (card.reveal = слой Choice_Reveal +
   0.45; кадров должно хватить до reveal + 1.95 с), `cues`, `shakers`.
10. **Проверка в партии** (не только листы!): `tests/ui_shot.gd -- --scenario=hs_play
    --card=<cid> --gif=110 --out=../../hs_unity/render/x.png` (путь от res://),
    `--wait=N` снимок через N кадров, не секунд (пиксель-арт виден только здесь), `--strip=...` соседние кадры;
    `tools/hs_smoothness.gd -- --card=<cid>` (не headless); тесты; коммит
    «Stage HsFx-N: …»; `CARD_MAP.md` — «СДЕЛАНО».

## 1. Правила владельца (не нарушать)

- **Из всех наборов HS** (владелец 2026-10-26 снял правило «только свежие 2024+» от
  2026-10-25): кандидатов брать из всех легендарок — старых и новых — по смыслу, цене и
  дарк фэнтези. Строку `CARD_MAP.md` со старой легендаркой не менять только из-за набора.
  Избранное владельца из HsBrowser — `data/hs_favorites.tsv`, смотреть первым.
- **Эпичность по стоимости, одна шкала на всю игру** (владелец 2026-10-25): чем дороже
  карта, тем больше, дольше и мощнее эффект. 9–10 — на весь экран, самые долгие, сильная
  тряска (уровень Deathwing Worldbreaker); 7–8 — большие, далеко за место карты, заметная
  тряска; 5–6 — крупные, вокруг места карты (Balor, Samuro); до 4 — скромные, короткие,
  локальные. Стоимость — `engine/godot/data/cards/cards.json` (`cost`).

- **Тон — дарк фэнтези** (владелец 2026-10-25): кандидатов подбирать серьёзных, тёмных и
  тяжёлых (тень, кровь, скверна, некротика, буря, лава, глубокая вода), в глубоких или
  приглушённых цветах. Не предлагать игривое: игрушки (TOY), вечеринки и кабаре (VAC),
  радужные самоцветы, милых птиц. В вопросе владельцу коротко писать, чем кандидат мрачен.
- **Как в Hearthstone, максимально близко к оригиналу.** Не перерисовывать и не
  «портировать» шейдеры руками — эффект **запекается** из оригинальных префабов HS в
  Unity (ручной порт был тусклым и «не тем», владелец его отверг).
- **Без витрины и без затемнения.** Нажал карту — она сразу исчезает из руки, идёт эффект.
- **Карта после эффекта:** в месте удара проявляется **миниатюра в своём размере (1×)**
  — «горящее» выжигание контура по макету нашей мини-карты (Choice_Reveal HS), **без
  огня-частиц** на ней; стоит ~1 с, гаснет. Полноформатная карта — не нужна.
- **Место удара / появления карты** (Red Dragon): над счётчиком POWER/INFLUENCE,
  зазор от текста счётчика до миниатюры = зазору от счётчика до руки (15 px); центр
  миниатюры (490, 365) на экране 960x540. Пролёт/начало эффекта — где в HS, не двигать;
  двигать только посадку/удар (рецепт `move`).
- **У нас не HS — адаптировать логику:** миньон HS не прилетает из-за края экрана;
  эффект с нажатия формируется в точке, куда карта «приземляется» (Onyxia: полёт
  Token_Root из клипа выключен, `"clip": "none"`, — сгусток растёт на месте посадки).
- **Выжигание карты — в основном тоне карты** (владелец 2026-10-24), не оранжевое
  Deathwing для всех. Тон — по арту миниатюры (`tools/card_tone.gd`), владелец может
  выбрать другой (Black Dragon — чёрный: насыщенность 0, яркость ×0.25; Blue —
  синий 0.605; Red — исходный оранжевый). Рецепт слоя Choice_Reveal: `tintHue`,
  `tintSat`, `tintVal`, `tintNodes` (см. §3.2). Перед запеканием показать пробные кадры
  выжигания крупно (`bake_sheet --crop`).
- **Действия карты** (вытеснение, возврат шпиона, VP…) — **стандартные анимации игры**,
  эффекты HS на них не ставить (владелец убрал Raze/Topple 2026-10-21). Механизм
  `actions` в HsPlay оставлен на случай, если владелец попросит для другой карты.
- **Эффект розыгрыша карты (m_PlayEffectDef, у Worldbreaker — дымка YoggFogg)** висит
  **до конца розыгрыша** карты (пока у неё есть вопросы / не сменился ход), не трясётся.
- **Тряска:** трясутся доска и эффекты на ней вместе (тряска камеры HS), дымка стоит.
- **60 к/с**, как игра (20 к/с — «дёргано»).
- **Пиксель-арт обязателен:** шейдер кадров — крупный пиксель 2×2, яркость 6 ступенями
  с сохранением оттенка, прозрачность 8 ступенями, без дизеринга (см. §6).
- **Не нужны:** стингеры карт (m_PlayEffectDef SoundSpellPaths `*_Stinger`), реплики
  (VO), трещины гнезда героя, портрет/кольцо героя, рамка карты HS — всё, что повторяет
  макет HS, заменять своим или прятать.
- Смотреть анимацию в игре: **Esc → CARD ANIMATIONS** (список всех карт с HsPlay).
- Общие: шаг → тесты → коммит «Stage HsFx-N: …» → короткий чеклист владельцу по-русски;
  по просьбе — `git push` и `bash server/deploy.sh` (сервер + автообновление игрокам).

## 2. Где что лежит

| Что | Где |
|---|---|
| Игрок эффектов | `engine/godot/scenes/ui/hs_fx/hs_play.gd` (RECIPES, SCRIPTS, FOGS, шейдер кадров) |
| Связь с партией | `engine/godot/scenes/ui/game_screen.gd`: `_on_result` / `_hs_start` / `_hs_flush` (эффект держит ответ сервера), `_hs_actions` (дымка до конца розыгрыша, действия), меню `CARD ANIMATIONS` |
| Тряска доски | `board_panel.gd`: `camera_offset` (от HsPlay) |
| Запечённые кадры | `engine/godot/assets/hs_fx/baked/<имя>/f###.png`, `u###.png`, `meta.json` |
| Звуки эффекта | `engine/godot/assets/hs_fx/<имя>/*.wav` |
| Свои замены текстур HS | `engine/godot/assets/hs_fx/own/` (`tools/hs_own_textures.gd`), контур карты — `hs_unity/recipes/textures/echo_<cid>.png` (`tools/hs_bake_prep.gd`) |
| Unity-проект запекания | `hs_unity/` (Unity 6000.6.6f1, URP, Timeline); скрипт `Assets/Editor/HsRender.cs`, время шейдеров `Assets/HsBake/HsTimeFeature.cs` |
| Рецепты | `hs_unity/recipes/<имя>.json` |
| Списки бандлов | `hs_unity/deps_*.txt` (`hsx deps`) |
| Утилита выгрузки | `hs_unity/tools/hsx/` (C#, AssetsTools.NET) |
| Список легендарок HS с эффектами | `hs_unity/data/hs_legendary_summons.tsv` (card_id, name, kind, prefab, bundle) |
| Hearthstone | `C:\Games\Hearthstone` (`Data\Win` — бандлы, `Hearthstone_Data\Managed` — сборки C#) |

## 3. Конвейер для новой карты

### 3.1 Выгрузка и разбор (hsx)

Сборка утилиты (нужен .NET 8 SDK; в прошлый раз ставился в папку scratchpad):
`dotnet build hs_unity/tools/hsx -c Release -o <bin>`.

- `hsx extract C:/Games/Hearthstone/Data/Win <out> <CARD_ID>` — все эффекты карты:
  `index.txt` (какой префаб откуда: m_PlayEffectDef, m_CustomSummonSpellPath,
  m_CustomChoiceRevealSpellPath, m_SubSpellEffectDefs…), на префаб — `hierarchy.txt`
  (узлы, guid, CAB), `fsm_*.txt` (PlayMaker: состояния, Wait, переменные —
  например WaitToShowCards, позиции actorPosition), `timeline_*.txt` (дорожки:
  Control = когда включены частицы, CameraShaker2 = тряска, Sound = звуки,
  CameraOverlay — проверить muted), `anim/*.json` (клипы), `audio/*.fsb`, `textures/`.
- `.fsb` → wav: `vgmstream-cli -o out.wav in.fsb` (vgmstream, Windows-сборка).
- `hsx deps <Win> <cabmap.tsv> <out.txt> CAB-...` — все бандлы, нужные префабу (для
  рецепта). `cabmap.tsv` строится при первом `extract`.
- Также: `hsx shaders`, `hsx variant` (дизассемблер шейдеров), `hsx fields <dll>
  <подстрока>` и `hsx il <dll> <Тип>` (код игры: так нашли алгоритм тряски
  ShakerHelper и устройство свечения ScreenEffectsPass).

Что выписать из выгрузки: guid префабов (из `hierarchy.txt` первой строки), имя корня
спелла (если префаб — обёртка `*_Super`), тайминги Timeline (клипы, частицы, тряска,
звуки с громкостями из AudioSource `m_Volume`), где «удар» (по FSM / анимации), есть ли
дорожки `ControlRandomizedTrack` (их Timeline без кода игры не играет — в рецепт
`controls`), узлы героя/карты/доски HS, которые надо спрятать или заменить.

### 3.2 Рецепт (`hs_unity/recipes/<имя>.json`)

```
deps, fps 60, len, space "gamma", ldr true,
layers: [{ prefab (guid), spell (корень внутри обёртки), at (с),
           pos/usePos (корень эффекта в мире HS), move [{node, by}] (сдвиг узлов: посадка),
           pin [{node, pos}] (анимированный узел держать в локальной точке: без полёта),
           only + place/usePlace + scale (одно поддерево, напр. Burst0_New у Choice_Reveal),
           hide [пути] (не рисовать), hidePS [пути] (без частиц, сетки остаются),
           under [пути] (дорожка «под картой» u###), clip / clips [{name, at}] (клипы аниматора по FSM; clip "none" — без клипов, "timeline" — аниматоры ведёт Timeline),
           stopAt (частицы перестают рождаться), controls [{node, start, end}],
           show [пути] (узлы, которые включает FSM: ActivateGameObject),
           noTimeline (не играть Timeline префаба — всё по FSM: clip и controls),
           tintHue/tintSat/tintVal + tintNodes [пути] + tintProps (по умолчанию
           _WhiteColor, _MidColor, _LastColor): перекраска цветов градиента материалов
           поддерева — оттенок заменить, насыщенность заменить (если ≥ 0), яркость ×;
           цвета, которые пишет анимация HS (блок свойств), перекрашиваются каждый кадр,
           mats [{node, prop, value|color}] (правка свойств материала), measure [пути] }],
textures: [{name (текстура HS), file (своя PNG)}],
hueFrom [от, до] + hueTo + hueKeep (0.25): перекраска готового кадра — оттенки полосы
  сдвигаются к hueTo (частицы и текстуры, до которых tintProps не достаёт; проба Zakajz
  в красный: hueFrom [0.62, 0.98], hueTo 0)
```

Камера — камера доски HS (BoardCameras/Main Camera: pos (-7.795, 19.598, -5.965),
FOV 34.87). Мир → экран 960x540: x ≈ 480 + (X+7.8)·44.1, y по z ≈ 247 + (−4.659 − Z)·54.9
(у уровня карты y=3.802). Точно — `measure`: в логе прямоугольник/точка узла на экране.

### 3.3 Запекание

```
"C:\Program Files\Unity\Hub\Editor\6000.6.6f1\Editor\Unity.exe" -batchmode -quit -projectPath hs_unity
  -executeMethod HsRender.Run -hsr-win C:/Games/Hearthstone/Data/Win
  -hsr-recipe hs_unity/recipes/<имя>.json -hsr-out engine/godot/assets/hs_fx/baked/<имя>
  [-hsr-frames 6,20,40] [-hsr-from N] [-hsr-mode probe]
```

- Пути `-hsr-recipe`/`-hsr-out` давать **абсолютными** (относительные Unity считает от
  `hs_unity/`, то есть `hs_unity/hs_unity/...`).
- Сначала `-hsr-mode probe` (список узлов, материалов, поддержка шейдеров) и пробные
  кадры `-hsr-frames` в отдельную папку (`hs_unity/render/...`, не в игру).
- Лист кадров поверх снимка игры: `tools/bake_sheet.gd -- --dir=… --frames=… --bg=<снимок
  960x540> [--card=ID --card-at=x,y --card-from=N] [--crop=x,y,w,h --scale=2] --out=…`
  (снимок: `tests/ui_shot.gd -- --out=../../hs_unity/render/x.png` — путь от res://;
  миниатюра в центре (490, 365) — `--card-at=461,323`).
- Полное запекание ~10 мин на 280 кадров; запускать в фоне. Упал (нехватка памяти
  Unity) — дозапечь `-hsr-from N`.
- После: `--import`, затем в `.import` кадров `process/fix_alpha_border=false`,
  `compress/mode=1`, `compress/lossy_quality=0.9` (WebP), ещё раз `--import`.

### 3.4 Игра

- `HsPlay.RECIPES[cid] = "<имя>"`, `SCRIPTS["<имя>"]`: `frames`, `sounds`, `card` (face
  "mini", reveal/sweep/hold/out, center), `cues` [[с, файл, громкость]], `shakers`
  (из CameraShaker2 Timeline: [с, по, амплитуда, кривая, интервал]), `fog`
  [имя, секунда], при надобности `actions`. Дымка — запись в `FOGS` (loop, fade, end…).
- Проверка: `tests/ui_shot.gd -- --scenario=hs_play --card=ID --gif=110` (розыгрыш),
  `--scenario=hs_dragon` (Red Dragon целиком с ответами на вопросы — образец для своих
  сценариев), `--scenario=fx_menu --play=1`; крупно — `--wait=N` снимок; `--strip=x,y,w,h`
  — кусок экрана из каждого кадра (ловить мерцание).
- Плавность: `tools/hs_smoothness.gd` (не headless): макс ≤ ~15 мс, 0 пропусков.
- Якорь действия на цель: `tools/bake_centroid.gd -- <папка> from to` (центр огня).

## 4. Проверки перед показом владельцу

1. Соседние кадры подряд крупно — нет ряби/мерцания (если есть — время шейдеров).
2. Кадры в партии поверх настоящего экрана, а не на пустом фоне.
3. Ничего от макета HS: портрет/гнездо героя, рамка карты, кольца, трещины гнезда.
4. Позиция удара и карты — по правилам владельца (§1), без пустых кругов.
5. 60 к/с, плавность (`hs_smoothness`), размер набора (WebP).
6. Звуки: громкости из AudioSource, без стингеров и VO.
7. Пиксель-арт включён (шейдер), смотреть кадр в игре крупно.
8. Тесты `run_tests.gd` и `net_loopback.gd` зелёные.

## 5. Ловушки (на чём уже обжигались)

- **Ручной порт шейдеров/частиц** — тускло, мимо оригинала. Только запекание Unity.
- **Цветовое пространство:** проект Unity в **Gamma** и 8-битный буфер (`ldr`), как HS
  — в Linear всё бледно, в HDR-float NaN тени заливают кадр чёрным.
- **NaN в материалах:** `_MiddlePointPos = 0` (тень Deathwing) — деление на ноль; править
  через `mats` (0.5, цвета рампы, `_ColorMul` 0 — тень только затемняет).
- **Рябь огня/мерцание интерфейса под эффектом:** шейдеры HS крутят текстуры по `_Time`,
  Unity в редакторе подставлял реальное время → `HsTimeFeature` ставит время кадра.
  Всегда смотреть соседние кадры.
- **ControlRandomizedTrack** не играется Timeline без кода HS → `controls` в рецепте.
- **Обёртки `*_Super`** — сам спелл грузится отдельно: `spell` = имя корня.
- **Прозрачность:** кадр рисуется дважды (чёрный/белый фон) → premultiplied цвет и
  альфа; чисто аддитивные пиксели получают альфу 1/255 (иначе WebP-шум и шейдер их режут).
- **WebP с потерями** шумит в пустых местах → шейдер не рисует альфу 0; `fix_alpha_border`
  выключать. BC7 — в 4 раза больше места.
- **Unity падает** на долгом запекании при `Texture2D.Apply` на каждый кадр — не выгружать
  кадры в видеопамять; `-hsr-from` дозапекает.
- **Спелл по FSM, а не по Timeline** (Onyxia): корень `Root` выключен, его включает
  FSM, частицы запускает FSM (ParticlePlayAction) — в рецепт `show`, `noTimeline`,
  `clip` и `controls` по секундам FSM (Wait); частицы из `controls` идут только по ним.
  Тряска FSM (CameraShakerAction, CameraShakeMgr) — случайная точка каждый кадр, длина
  = время последнего ключа кривой: в HsPlay интервал 1/60, амплитуда ×0.8.
- **Анимация только в Timeline** (Malygos: клип `Recorded` есть лишь на дорожке
  Animation, у контроллера аниматора клипов нет): такой аниматор HsRender оставляет
  включённым, иначе дорожка ничего не двигает. Проверять по `measure`: узел движется?
- **Чужие контроллеры аниматоров** (Lady Prestor: на AnimRoot контроллер Kurtrus, на
  крыльях — Il'gynoth): HsRender по умолчанию проигрывает самый длинный клип
  контроллера — жетон летит не туда, крыльев нет. В лог `animator X: <клипы>` смотреть:
  клипы не этой карты → в рецепт `"clip": "timeline"` (все аниматоры ведёт Timeline).
- **Старая анимация Unity** (компонент `Animation`, клип legacy; FSM
  `AnimationPlaythroughAction`, Whitemane): HsRender (с 2026-10-24) проигрывает её клип
  с начала слоя — клип по умолчанию, первое состояние или `clip` рецепта. События клипа
  (`SendEvent` playFX…) — в дампе клипа `m_Events` (time): по ним `controls` частиц.
- **MainCameraShakerAction** (m_Amount, m_Time, m_Delay) = CameraShakeMgr.Shake с
  кривой Linear(0, 1, time, 0): в HsPlay `[[0, 1], [1, 0]]`. Высота тона звука FSM
  (m_Pitch) — 4-е число в `cues`.
- **Слабая дымка на весь экран** в пиксель-арте (8 ступеней прозрачности) распадается
  на полосы с резкими краями — в пробах `bake_sheet` (без шейдера) этого не видно,
  смотреть снимок из партии (`ui_shot --wait=N`) и пиксели углов кадров (f и u
  отдельно — так видно, какая дорожка). У Ysera это было затемнение краёв Vignette.
- **`hide` против анимации:** клип HS с кривой `m_IsActive` включает узел обратно
  (Ysera: Vignette, цветы рамки героя) — HsRender прячет узлы `hide` заново после
  анимации каждый кадр (до 2026-10-24 не прятал).
- **Карта должна читаться:** если эффект после удара продолжает рисоваться поверх места
  карты (Ysera: цветы, портал), эти узлы — в `under` (дорожка под картой).
- **Привязки старых дорожек** в `m_SceneBindings` директора (Camera Shaker 2 Track и
  т. п.) — не значит, что дорожка есть; верить только дампу `timeline_*.txt`.
- **Эффект розыгрыша (m_PlayEffectDef) бывает не дымкой**, а действием у героя HS
  (Ysera: Hero_Impact — цветы у рамки героя): такой не брать (макет HS).
- **Меши жетона миньона HS** (`Card_InPlay_Ally_*_mesh`: овальный портрет, рамка
  элитного дракона) в эффекте — макет HS, прятать (Ysera: Token_FX — владелец заметил
  овал в портале). Перед запеканием искать в `hierarchy.txt`: `grep Card_InPlay`.
- **Жетон HS из осколков** (Sindragosa: `Sindragosa_TokenRoot/TokenPieces`, меши
  `Kun_*` — рамка и портрет миньона, разбитые на куски) собирается в овал жетона HS —
  макет HS, владелец убрал (2026-10-24). Всё, что после удара стелется по столу (крылья,
  трещины, туман), — в `under`, иначе карту не видно.
- **Свечение миньона HS** (`Mesh_FlashGlow`, GenFX_AllyInPlay_MinionGlow) и трещины под
  миньоном (`Mesh_Crack`) — макет HS, прятать.
- **Якорь не по точке префаба**, а по видимому огню (`bake_centroid`).
- **Камера:** тряска — по коду HS `ShakerHelper` (30 точек, интервал, двойной косинус,
  кривая силы), сдвигает доску (`camera_offset`) и эффекты, не дымку.
- **Свечение HS** (ScreenEffectsPass, проходы GlowTransparent и т. п.) — только для
  объектов на слоях эффектов; у Worldbreaker не использовалось. Проверять по слоям узлов
  (19 IgnoreFullScreenEffects, 21 Effects, 23 ScreenEffects).
- **Первые кадры окна дёргаются всегда** — плавность мерить после прогрева.
- **Godot зависает на запуске**, если в `assets/` лежат свежезапечённые неимпортированные
  кадры (сотни PNG): любой `--script` (даже `hs_hue.gd`) встаёт на импорт. Сначала
  `--import`, а все вызовы Godot оборачивать в `timeout 900` — убить зависший процесс
  нельзя (Stop-Process запрещён), только остановить свою фоновую задачу (TaskStop).
- **Цвета частиц и текстур** перекраской `tintProps` не меняются (Zakajz в красный —
  только часть): для этого `hueFrom/hueTo` рецепта — перекраска готового кадра.
- **Жетон HS бывает не в `OnToken`**: `TokenGlow`, `MinionEdgeGlow_2`,
  `MinionEdgeGlow_Top_Nightmare`, `Mesh_TokenGlow_*` — овал и контур легендарной
  рамки; владелец замечает сразу (K'ara, Razidir). Искать `grep -iE "glow|edge|token"`.
- **Эффект, затемняющий весь экран** (Kith'ix, Archimonde Vignette, CameraOverlay)
  в пиксель-арте рвётся на пятна — прятать узел или не брать.
- **python** здесь — заглушка Store: правки JSON — скриптом Godot или Edit.
- **PowerShell-скрипты с кириллицей** ломаются — править через Edit.

## 6. Пиксель-арт (шейдер кадров в HsPlay)

`PIXEL_BLOCK 2` (крупный пиксель 2×2 пикселя игры), `PIXEL_LEVELS 6` (ступени яркости
max(r,g,b) с сохранением оттенка — поканальные давали оливковую грязь), `PIXEL_ALPHA 8`
(4 — дымка слишком плотная), без дизеринга (решётка Байера рябила поверх интерфейса).
Ступени — в premultiplied-виде, чистый свет остаётся светом. Менять только по слову
владельца; сравнивать крупными вырезками до/после.

## 7. Размеры (Red Dragon)

Розыгрыш 277 кадров (16 МБ WebP), дымка 481 кадр (46 МБ). Игра (game.pck) ~105 МБ.
Дымку делать короче, если карт с ней будет много (петля 3 с вместо 4.5).
