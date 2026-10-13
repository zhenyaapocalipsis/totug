# New Era — Noxus → AVERNUS (этап NE-9, правила)

Полуколода Noxus из мода Runeterra Reforged на существах Аверна (первый слой Девяти Преисподних, Кровавая война): дьяволы, хобгоблины, наёмники.
Ключ в коде — `noxus`, класс — `NoxusCards` (`core/cards/noxus_cards.gd`), тип карт — `AVERNUS`, id 49500–49524, 45 карт + 2 жетона.
Картинки PDF мода: 74–96 (колода), 451–453 (Blade Fragment), 454 (Blade of Exile).

## Таблица

| id | Существо | Карта мода | Цена | Аспект | VP | Копий |
|---|---|---|---|---|---|---|
| 49500 | Bandit | Armed Acquisitioner | 2 | Ambition | 1/2 | 3 |
| 49501 | Wereboar | Legion Marauder | 3 | Conquest | 1/3 | 3 |
| 49502 | Goblin Boss | Crimson Disciple | 3 | Guile | 2/4 | 2 |
| 49503 | Hell Hound | Thorn of the Rose | 4 | Malice | 2/4 | 3 |
| 49504 | Pseudodragon | Crimson Aristocrat | 2 | Guile | 1/3 | 4 |
| 49505 | Medusa | The Lady of Blood | 5 | Malice | 3/5 | 2 |
| 49506 | Bugbear Stalker | Black Rose Spy | 3 | Guile | 2/4 | 3 |
| 49507 | Guard Captain | Legion Veteran | 4 | Ambition | 2/5 | 3 |
| 49508 | Bugbear Warrior | Reckless Trifarian | 3 | Malice | 1/3 | 2 |
| 49509 | Mummy | Grave Physician | 2 | Ambition | 1/2 | 2 |
| 49510 | Ogre | Legion General | 3 | Conquest | 1/3 | 4 |
| 49511 | Minotaur of Baphomet | Minotaur Reckoner | 4 | Malice | 2/4 | 2 |
| 49512 | Hobgoblin Captain | Incisive Tactician | 3 | Conquest | 1/3 | 2 |
| 49513 | Weretiger | Katarina | 7 | Guile | 3/7 | 1 |
| 49514 | Lamia | Leblanc | 6 | Guile | 3/7 | 1 |
| 49515 | Horned Devil | Mordekaiser | 9 | Conquest | 5/9 | 1 |
| 49516 | Efreeti | Vladimir | 7 | Ambition | 3/7 | 1 |
| 49517 | Azer Sentinel | Draven | 6 | Malice | 3/6 | 1 |
| 49518 | Ice Devil | Swain | 7 | Ambition | 3/7 | 1 |
| 49519 | Troll | Sion | 9 | Conquest | 4/9 | 1 |
| 49520 | Fire Giant | Darius | 6 | Conquest | 3/7 | 1 |
| 49521 | Half-Dragon | Riven | 6 | Malice | 3/6 | 1 |
| 49522 | Wyvern | Samira | 6 | Ambition | 3/6 | 1 |
| 49523 | Blade Fragment | Blade Fragment (жетон, запас 3) | — | — | 0/0 | — |
| 49524 | Blade of Exile | Blade of Exile (жетон) | — | — | 0/0 | — |

У всех существ есть страница на D&D Beyond со свободным артом (проверено 2026-10-13; фон у артов проверяется на этапе артов). Имена не совпадают ни с одной картой игры.

## Толкования
- **Execute = Devour**, стопка Execute = `devoured_pile`. Учёт пожираний — `NoxusCards.on_devour`, его зовут все пути пожирания (DevourCard, Carrion Crawler, Ulitharid, Green Hag, карты Avernus). Пожирание картами Ravenloft и классическими тоже включает Might.
- **Might**: срабатывает, если текущий игрок в этот ход уже сожрал карту; вторая Might на карте требует второго пожирания. Проверяется в момент розыгрыша карты (сначала пожирание, потом карта с Might). Срабатывает автоматически, без вопроса.
- **Troll (Sion)**: «Might срабатывает ещё раз» — каждая Might дважды до конца хода, включая Might самого Troll.
- **Horned Devil (Mordekaiser)**: «Execute half the Market deck» — верхняя половина колоды рынка (с округлением вверх) уходит в сожранные, каждая считается пожиранием. Если колода рынка уже пуста — игрок побеждает, партия кончается после его хода (`GameState.instant_winner`). «Play up to 2 cards from the Execute pile» — любые карты из стопки, после розыгрыша они остаются вне игры.
- **Bandit**: сожранная карта рынка заменяется одной из 3 верхних карт колоды рынка, две другие — под низ колоды.
- **Bugbear Stalker**: скидка 3 лежит на слоте рынка до конца хода (снимается, когда карту из слота купили).
- **Mummy**: «recruit from the top card of the Execute pile» — как Ghost: до конца хода верхнюю сожранную карту можно купить.
- **Weretiger (Katarina)**: запрет «не ставить войска в эту локацию» действует, только если там кого-то убили, и только для игрока, сыгравшего карту (реакции соперников, например Shield Guardian, ставят как обычно). Проверка — `GameState.deployable_slots`.
- **Lamia (Leblanc)**: игрок раскладывает 5 верхних карт соперника на открытую и закрытую стопки, соперник одну кладёт обратно на верх колоды, эффекты другой разыгрывает игрок; сами карты потом идут в сброс соперника.
- **Efreeti (Vladimir)**: «Promote instead» — вопрос после каждого пожирания из руки/сброса в этот ход; такое пожирание всё равно считается для Might.
- **Azer Sentinel (Draven)**: VP в конце хода = сколько войск попало в трофеи за этот ход (`turn_flags["trophy_start"]`, ставится в начале каждого хода). Сюда входят убитые и до розыгрыша Azer Sentinel.
- **Fire Giant (Darius)**: «deployed at least 15/30 troops» = своих войск сейчас на доске.
- **Half-Dragon (Riven)**: при каждом розыгрыше — Blade Fragment из запаса (3 на партию). Если в одном ходу сыграны все 3 осколка и Half-Dragon — в конце хода осколки уходят из игры, в сброс приходит Blade of Exile.
- **Wyvern (Samira)**: «Assassinate 2 troops at a site» — обе в одной локации.
- Ice Devil (Swain): «10 шпионов» из правил мода не вводим.

## Не сделано
- Арты сделаны (NE-10): 23 арта 2024 года с D&D Beyond (все с фоном) в `cards/avernus/`, жетоны Blade Fragment / Blade of Exile — кропы из PDF мода (картинки 451, 454). Из-за артов без фона 8 существ заменены (Imp→Bandit, Hobgoblin Warrior→Wereboar, Cultist→Goblin Boss, Quasit→Pseudodragon, Dretch→Mummy, Pit Fiend→Horned Devil, Horned Devil→Troll, Gladiator→Azer Sentinel). Возможная доводка кадра — Minotaur of Baphomet (тёмная пёстрая сцена). `cards/avernus/cand*` — неиспользованные кандидаты, не в git.
- В интерфейсе нет счётчика пожираний за ход (видно только по Might).
- Бот не знает о Might — играет карты Avernus как обычные.
