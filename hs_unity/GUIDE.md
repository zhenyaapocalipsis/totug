# Анимации розыгрыша карт из Hearthstone — рабочий документ

Как делать анимации уникальных карт: что хочет владелец, как устроен конвейер, команды,
проверки и ловушки. Собрано по работе над Red Dragon (Deathwing, Worldbreaker, этапы
HsFx-0..12, октябрь 2026). Какая легендарка HS идёт к какой карте — `CARD_MAP.md`.

## 1. Правила владельца (не нарушать)

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
           only + place/usePlace + scale (одно поддерево, напр. Burst0_New у Choice_Reveal),
           hide [пути] (не рисовать), hidePS [пути] (без частиц, сетки остаются),
           under [пути] (дорожка «под картой» u###), clip / clips [{name, at}] (клипы аниматора по FSM),
           stopAt (частицы перестают рождаться), controls [{node, start, end}],
           mats [{node, prop, value|color}] (правка свойств материала), measure [пути] }],
textures: [{name (текстура HS), file (своя PNG)}]
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

- Сначала `-hsr-mode probe` (список узлов, материалов, поддержка шейдеров) и пробные
  кадры `-hsr-frames` в отдельную папку (`hs_unity/render/...`, не в игру).
- Лист кадров поверх снимка игры: `tools/bake_sheet.gd -- --dir=… --frames=… --bg=<снимок
  960x540> [--card=ID --card-at=x,y --card-from=N] --out=…` (снимок: `tests/ui_shot.gd
  -- --out=x.png`).
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
- **Якорь не по точке префаба**, а по видимому огню (`bake_centroid`).
- **Камера:** тряска — по коду HS `ShakerHelper` (30 точек, интервал, двойной косинус,
  кривая силы), сдвигает доску (`camera_offset`) и эффекты, не дымку.
- **Свечение HS** (ScreenEffectsPass, проходы GlowTransparent и т. п.) — только для
  объектов на слоях эффектов; у Worldbreaker не использовалось. Проверять по слоям узлов
  (19 IgnoreFullScreenEffects, 21 Effects, 23 ScreenEffects).
- **Первые кадры окна дёргаются всегда** — плавность мерить после прогрева.
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
