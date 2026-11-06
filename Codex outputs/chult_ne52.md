# Stage NE-52: Chult creature replacements

Approved by the owner on 2026-11-07. Card IDs, effects, costs, aspects, VP and deck copies are preserved. Yuan-ti Abomination (50112) stays.

| ID | Previous creature | New creature | Source |
|---|---|---|---|
| 50100 | Yuan-ti Infiltrator | Hythonia | https://www.dndbeyond.com/monsters/909488-hythonia |
| 50103 | Lizardfolk Sovereign | Ironscale Hydra | https://www.dndbeyond.com/monsters/909489-ironscale-hydra |
| 50106 | Lizardfolk Geomancer | Snapping Hydra | https://www.dndbeyond.com/monsters/3852146-snapping-hydra |
| 50108 | Knight of Eldraine | Euryale | https://www.dndbeyond.com/monsters/3960607-euryale |
| 50113 | Performer Maestro | Yuan-ti Infiltrator | existing approved source |
| 50118 | Kenku | Ssurran Defiler | https://www.dndbeyond.com/monsters/2821202-ssurran-defiler |
| 50119 | Aarakocra Aeromancer | Yuan-ti Malison | https://www.dndbeyond.com/monsters/5195292-yuan-ti-malison-type-3 |
| 50101 | Guardian Naga | Ras Nsi | https://www.dndbeyond.com/monsters/33253-ras-nsi |
| 50115 | Living Gust of Wind | Guardian Naga | https://www.dndbeyond.com/monsters/5195066-guardian-naga |

## Animation assignments

Removed obsolete assignments; baked resources retained for later reuse. The new unique creatures have no assigned HS effect. Guardian Naga is now an ordinary 3-copy, cost-3 card.

```tsv
50108	Knight of Eldraine	ixtal	END_006	Chronikar	CustomSummon	2026-10-27
50106	Lizardfolk Geomancer	ixtal	TIME_064	Chrono-Lord Deios	CustomSummon	2026-10-27
50103	Lizardfolk Sovereign	ixtal	TIME_714	Chrono-Lord Epoch	CustomSummon	2026-10-27
50101	Guardian Naga	shurima	TLC_463	Razidir	CustomSummon	2026-10-27
```

## Ras Nsi background

Built-in imagegen edit, original character from D&D Beyond; owner explicitly requested adding background. Original kept at cards/ixtal/more/ras_nsi.png; final cards/ixtal/ras_nsi_temple.png.

Prompt: Use case: precise-object-edit. Edit target: the supplied original D&D Beyond Ras Nsi illustration. Primary request: add a complete painted environment behind the existing character. Preserve Ras Nsi's recognizable exact appearance, pose, bandage-wrapped head and torso, crossed arms, gold collar and bracelets, sword extending to lower left, and huge coiled rusty brown snake tail. Keep the original character illustration as unchanged as possible; do not redesign or replace him. Replace all transparency and the pale decorative backdrop with a coherent full dark-fantasy scene: an ancient moss-covered serpent temple in the jungles of Chult, carved stone pillars with snake reliefs, worn stone floor beneath his coils, distant dense jungle greenery and subtle humid haze. Match the original painterly tabletop fantasy illustration style and natural lighting; subdued green and aged-gold environment, the character remains clearly separated and readable. Landscape composition around 3:2 with full foreground character, his head clearly readable near upper center, surroundings filled edge to edge so a wide 164:100 card crop around upper body and snake coils has real background. No white margins, no transparency, no text, no borders, no extra characters, no extra limbs. Output an opaque complete illustration.


## Verification

- === пройдено: 2270, провалено: 0 ===
- Localized catalog: 23357 checks, failed 0.
- All nine cards keep their original cost, aspect, rules text and VP; deck copies unchanged.
- English rasters regenerated only for the nine selected IDs; Russian faces are presentation overlays.
- Unrelated owner edits to mini-face entries are preserved; only the nine target entries are staged.
- Review sheets: Codex outputs/chult_ne52_en.png and chult_ne52_ru.png.
