# New Era: Piltover & Zaun → големы, слизи и жители города (этап NE-6, 2026-10-11)

Карты в PDF мода: картинки 53–73 (в 58 и 67 по две карты; Ferros Elite есть только в 67).
Карт с разными именами — 21, копий по кружкам — **42** (у Celestial и Shadow Isles по 45). Трёх карт до 45 в моде нет.

## Решения
- Режим NEW ERA: колоды выбираются переключателем в меню (любые две из Celestial, Shadow Isles, Piltover). Строка режима `newera:celestial,piltover`; старое `newera` = Celestial + Shadow Isles.
- Valor → MALICE, «neutral troop» → белое войско.
- **Double <X> Focus** — нужны ДВЕ другие карты этого аспекта: сыгранные в этот ход и/или в руке.
- Существа подобраны под свободный арт D&D Beyond с фоном (почти все модроны, Helmed Horror, Iron Cobra, Autognome — в платных книгах; Animated Armor, Flying Sword, Rug of Smothering — только вырезанные без фона). Pirate Captain оставлен для Bilgewater. Владелец состав пока не видел.

## Карты (id 49200–49220, тип PILTOVER)
| id | Существо | Карта мода | Цена | Аспект | VP | Копий |
|---|---|---|---|---|---|---|
| 49200 | Tough Boss | Officer Squad | 3 | CONQUEST | 2/4 | 3 |
| 49201 | Wererat | Zaun Diva | 3 | MALICE | 1/3 | 4 |
| 49202 | Bandit Captain | Midenstokke Henchmen | 4 | MALICE | 2/4 | 3 |
| 49203 | Rust Monster | Chief Mechanist | 2 | CONQUEST | 1/3 | 4 |
| 49204 | Black Pudding | Augmented Experimenter | 3 | AMBITION | 1/3 | 4 |
| 49205 | Spy | Chembaron | 3 | GUILE | 1/3 | 2 |
| 49206 | Otyugh | Chump Whump | 4 | CONQUEST | 2/4 | 2 |
| 49207 | Clay Golem | Plaza Guardian | 5 | MALICE | 2/5 | 3 |
| 49208 | Gelatinous Cube | Patrol Wardens | 2 | AMBITION | 1/2 | 3 |
| 49209 | Ochre Jelly | Dropboarder | 4 | GUILE | 2/4 | 2 |
| 49210 | Mimic | Ferros Elite | 4 | AMBITION | 2/4 | 2 |
| 49211 | Stone Golem | Vi | 6 | CONQUEST | 3/6 | 1 |
| 49212 | Assassin | Caitlyn | 6 | MALICE | 3/6 | 1 |
| 49213 | Iron Golem | Jayce | 6 | AMBITION | 3/6 | 1 |
| 49214 | Manticore | Jinx | 6 | GUILE | 3/6 | 1 |
| 49215 | Homunculus | Heimerdinger | 7 | AMBITION | 3/7 | 1 |
| 49216 | Chimera | Warwick | 7 | CONQUEST | 3/6 | 1 |
| 49217 | Archmage | Viktor | 7 | GUILE | 3/6 | 1 |
| 49218 | Basilisk | Ekko | 7 | MALICE | 3/6 | 1 |
| 49219 | Behir | Janna | 9 | MALICE | 4/9 | 1 |
| 49220 | Hydra | Seraphine | 7 | AMBITION | 3/6 | 1 |

Арты (NE-7) — `cards/pz/<существо>.png/jpeg`, версии 2024 года с фоном; окна — `SINGLE_ART`/`MINI_FACE` в `tools/pixel_cards.gd`, подпись PILTOVER & ZAUN (в шрифт карт добавлен знак &). Неиспользованные кандидаты — `cards/pz/cand`, `cand2` (не в git, можно удалить).

## Как истолкованы спорные места (можно поменять)
- «Next to another player's troop» (Tough Boss, Chimera): новое войско стоит в соседнем слоте или в той же локации, что и войско другого игрока (не белое).
- Homunculus: «choose all» — в каждом «Choose one» этого хода появляется вариант **All of them** (можно и не брать). «Focus triggers an additional time» — каждый Focus этого хода срабатывает ещё раз; две Homunculus — ещё два раза.
- Assassin (Caitlyn): смотрит 2 верхние карты каждого игрока, начиная с себя; сбросить можно **одну карту на всех**.
- Iron Golem (Jayce): «promote a card you played» — можно продвинуть и саму Iron Golem.
- Basilisk (Ekko): лишний ход сразу после своего, в нём не больше 3 карт. Из лишнего хода ещё один не берётся. Работает и в последнем круге.
- Hydra (Seraphine): «whenever you recruit a card with Influence» = каждая покупка за Influence (рынок и запас). После неё можно бесплатно взять карту рынка дешевле купленной.
- Behir (Janna): «Focus»-карта — карта, в тексте которой есть «Focus ►».
- Archmage (Viktor): «Gain a spy» — +1 шпион в запас, всего не больше 10.
- Chimera (Warwick): «deploy 2 troops per Power» — сколько угодно раз: платишь 1 Power, ставишь 2 войска.
