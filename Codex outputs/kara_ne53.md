# Stage NE-53: Kara-Tur elementals

Eleven owner-approved creature replacements. Prices, aspects, rules text, VP and deck copies are unchanged. All new races are ELEMENTAL.

| Card ID | Previous creature | New creature |
|---|---|---|
| 49803 | Murder Comet | Elder Tempest |
| 49808 | Awakened Tree | Phoenix |
| 49811 | Treant | Zaratan |
| 49812 | Bodytaker Podling | Dust Hulk |
| 49813 | Gas Spore Fungus | Water Weird |
| 49815 | Brackish Trudge | Leviathan |
| 49816 | Bodytaker Plant | Blistercoil Weird |
| 49817 | Shambling Mound | Cinder Hulk |
| 49818 | Tempest Hart | Lightning Hulk |
| 49819 | Shrieker Fungus | Mist Hulk |
| 49821 | Gulthias Blight | Auril |

Seven original D&D Beyond cutouts received painted backgrounds with the built-in image_gen tool. The owner approved close-up framing with minimal visible background. Final source images are in cards/ionia; crop coordinates are in tools/pixel_cards.gd. Prompts: Codex outputs/kara_ne53_prompts.json. Sources and coordinates: Codex outputs/kara_ne53_changes.json.

Previous HS bindings for Murder Comet, Brackish Trudge and Gulthias Blight are freed. Treant’s planned binding is freed too. New creatures have no assigned HS animation. Existing baked effects remain available.

Unrelated owner edits to mini-face coordinates are preserved; only the eleven target entries are staged.

Review: Codex outputs/kara_ne53_en.png and kara_ne53_ru.png.

## Local files

The owner’s previously untracked hs_unity/data/hs_assign.tsv and Claude outputs/new_era_creatures.md were updated locally and left out of this commit. CARD_MAP.md records the freed effects; the complete replacement list is above.

## Validation

- Rules data invariant check: unchanged cost, aspect, text, VP, deck copies; unrelated cards and owner mini-face edits preserved.
- Localized catalog: 23360 checks, failed 0.
- Full English and Russian card faces and miniatures visually inspected.
- Core tests with workspace-isolated APPDATA: 2270 passed, 0 failed (engine/godot/kara-ne53-tests-isolated-engine.log). The initial default-user-data run could not write profile/replay fixtures under the sandbox; the isolated rerun passed.
