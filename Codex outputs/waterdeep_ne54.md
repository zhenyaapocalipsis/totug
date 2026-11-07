# Stage NE-54: Waterdeep constructs and their creators

Eight owner-approved D&D Beyond illustrations (gallery choices 2, 3, 4, 5, 7, 9, 10, 12). No modrons. Card mechanics, aspects, prices, VP and deck copy counts are unchanged. Original scenes are framed close to the subject; no backgrounds were generated.

| Card ID | Previous creature | New creature | Russian name |
|---|---|---|---|
| 49204 | Animated Chained Library | Loading Rig | Погрузочный механизм |
| 49201 | Cogwork Archivist | Ruin Grinder | Разрушитель руин |
| 49202 | Caldron Magen | Helmed Horror | Шлемоносный ужас |
| 49209 | Terran Magen | Nimblewright Guard | Страж-нимблрайт |
| 49206 | Virvos Magen | Warforged Titan | Кованый титан |
| 49212 | Lorehold Apprentice | Viktra Mordenheim | Виктра Морденхейм |
| 49217 | Conjurer Archmage | Manshoon | Мэншун |
| 49220 | Silverquill Apprentice | Trobriand | Тробрианд |

Trobriand is CONSTRUCT, matching the illustrated iron-golem body. Viktra Mordenheim and Manshoon remain HUMAN.

Sources and crop coordinates: waterdeep_ne54_changes.json. Full card faces and miniatures: waterdeep_ne54_en.png and waterdeep_ne54_ru.png.

HS assignments for Lorehold Apprentice (Farseer Wo) and Silverquill Apprentice (Farseer Nobundo) are freed. The previous planned Archmage binding is freed too. New creatures have no assigned HS animation; baked effects remain available.

The owner’s unrelated mini-face coordinates are preserved. Previously untracked hs_unity/data/hs_assign.tsv and Claude outputs/new_era_creatures.md are updated locally and left out of the commit.

## Validation

- Rules-data invariant check: all card fields except approved names/race unchanged; half-deck copies unchanged; Russian ability text unchanged.
- Unrelated mini-face coordinates preserved.
- Core tests with isolated workspace APPDATA: 2270 passed, 0 failed.
- Complete localization catalog: 23998 checks, 0 failed.
- Final localization check for all eight changed cards: localized catalog translated: 2600 checks, failed 0.
- English/Russian full faces and final miniatures visually reviewed.
- Executable rules code unchanged (only creature names in comments).
