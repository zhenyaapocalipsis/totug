# Подбор анимаций Hearthstone для уникальных карт

150 уникальных карт проекта (по одной копии в полуколоде, `data/cards/half_decks.json`) и
для каждой — легендарка Hearthstone, чей эффект розыгрыша (CustomSummon) берём за основу.
Подбор по смыслу и виду (дракон — драконом, нежить — нежитью, море — морским, огонь —
огнём), без повторов: у всех 150 разные легендарки и разные префабы эффектов. Все есть в
файлах игры (`data/hs_legendary_summons.tsv`). Как делать — `GUIDE.md`.

Правила подбора (владелец, подробно — `GUIDE.md` §1): легендарки из всех наборов HS
(правило «только свежие 2024+» снято 2026-10-26); эпичность по стоимости карты по одной
шкале на всю игру (9–10 — весь экран, 7–8 — большие, 5–6 — крупные у места карты, до 4 —
скромные); дарк фэнтези.

Это черновик для владельца: любую строку можно заменить. Перед работой над картой:
`hsx extract` по id из таблицы, посмотреть эффект (пробные кадры), убедиться, что он
подходит смыслу карты (кто источник, кто цель) и не повторяет макет HS (герой, рамка).
Названия полуколод — внутренние (`drow`, `noxus` = Avernus, `freljord` = Icewind,
`shurima` = Calimshan, `ionia` = Kara-Tur, `piltover` = Waterdeep, `shadow` = Ravenloft,
`bandle` = Feywild, `void` = Far Realm, `ixtal` = Chult).

Готово: строки «СДЕЛАНО» в таблицах (вся колода dragons, drow, demons, elementals, aberrations). Остальные — по очереди, по слову владельца.

В оставшихся 12 колодах почти все легендарки — из старых наборов (в каждой колоде свежих
0–4): перед работой над колодой подобрать свежие замены (правило выше), сначала из запаса.

### Запас: свежие эффекты, уже опробованные, но свободные (2026-10-25)

Пробы лежат на этом ПК: рецепт `hs_unity/render/cand/<имя>.json` (только слой эффекта,
жетон HS спрятан) и лист `hs_unity/render/cand/<имя>_sheet.png` (кадры 0.17–3.7 с).
Владелец их видел, когда выбирал для демонов. Брать в первую очередь — по смыслу и цене.

| Эффект (id) | Проба | Что видно | Куда подойдёт |
|---|---|---|---|
| Ragnaros the Great Fire (CATA_150) | `ragnaros` | огненные языки с краёв экрана, огромный горящий рогатый череп | 9–10 / 7–8: Imix (elementals, принц огня) |
| Vulcanos (CATA_488) | `vulcanos` | огненный валун падает и взрывается | земля/огонь, 5–6 |
| Sinestra (CATA_154) | `sinestra` | огненное солнце раскрывается в пылающие крылья | огонь/дракон/феникс, 6–7 |
| Drest'agath (BE_703) | `drestagath` | огненный глаз в пурпурном пламени, короткий | глаз, скромно (≤ 5) |
| Talgath (GDB_472) | `talgath` | две зелёные глефы Скверны бьют крестом, дым | клинки, воин, 5–6 |
| Broxigar (TIME_020) | `broxigar` | зелёная сфера Скверны раскалывается | 5–6 |
| Magtheridon, Unreleased (TOY_647) | `magtoy` | когтистая лапа рвёт землю из трещин | чудовище, 6 |
| G'huun (BE_287) | `ghuun` | щупальца стягиваются в красный кровавый взрыв | aberrations / кровь, 6–7 |
| Zakajz the Corruptor (BE_728) | `zakajz` | фиолетовая клешня-раковина из разлома (владельцу не понравилась для Glabrezu) | void / aberrations |
| Kith'ix (BE_090) | `kithix` | фиолетовые молнии; экран темнеет фиолетовым — затемнение убирать | void, 7–8 |
| Nexus-Prince Shaffar (GDB_143) | `shaffar` | ленты и вспышка синих молний на весь экран | 7–8, магия/буря |
| Aviana, Elune's Chosen (EDR_895) | `aviana` | огромные крылья с луной на весь экран, удар | celestial / птица, 7–8 |
| Harpy Queen Aviana (TOY_806) | `harpy` | зелёный ветер, птицы не видно | ветер, скромно |
| Q'onzu (EDR_517) | `qonzu` | синий вихрь ветра и вспышка | воздух, ≤ 5 |
| Lady Azshara (TIME_211) | `azshara_time` | синий водоворот, всплеск | вода/море, 5–6 |
| Victor Nefarius (CATA_470) | `nefarius` | зелёный магический вихрь | магия, 5–6 |
| Summoner Darkmarrow (VAC_503) | `darkmarrow` | фиолетовый разлом с костями и молниями | undead / некромант, 6 |
| Kronn the Impaler (BE_732) | `kronn` | маленькое синее ледяное копьё | лёд, ≤ 4 |
| Murmur (GDB_448) | `murmur` | бирюзовые звуковые кольца | звук/магия, 5 |
| Husk, Eternal Reaper (TIME_618) | `husk` | золотой знак-печать из песка | shurima (Calimshan), 6 |
| King Tide (VAC_524) | `kingtide` | бирюзовая волна прилетает слева, брызги (полёт прибивать `pin`) | вода/море, 6 |
| Morchok (CATA_570) | `morchok` | розовый удар из угла, фиолетовый взрыв, голубая искра (полёт — `pin`) | камень/магия, 5–6 |
| Therazane (BE_337) | `therazane` (рецепт был recipes/therazane.json, коммит dabd4c66) | радужные самоцветы и бирюзовый кристалл — для дарк фэнтези слишком ярко | земля, 6 || Mirrex (DINO_407) | `mirrex` | синее облако, розовые кристаллы — для дарк фэнтези слишком ярко | кристаллы, 5 |

### drow

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Council Member (48315) | Wilfred Fizzlebang (AT_027) | `ATFX_WilfredFizzlebang_CustomSummon.prefab` | СДЕЛАНО (HsFx-61; владелец выбрал в HsBrowser 2026-10-27 вместо Lady Prestor); фиолетовые кольца призыва, по FSM без Timeline; выжигание фиолетовое |
| Deathblade (48316) | Blade of The Black Empire (BE_227) | `05_BEFX_BladeoftheBlackEmpire_CustomSummon.prefab` | СДЕЛАНО (HsFx-57; владелец выбрал в HsBrowser 2026-10-27 вместо Zayle); два фиолетовых разреза крестом, вихрь пустоты; выжигание фиолетовое |
| Inquisitor (48325) | K'ara, the Dark Star (GDB_127) | `GDBFX_Kara_CustomSummon.prefab` | СДЕЛАНО (HsFx-60; владелец выбрал в HsBrowser 2026-10-27 вместо Benedictus, кадры того удалены); K'ara перепечена с контуром этой карты; выжигание фиолетовое |
| Masters of Sorcere (48328) | Zayle, Shadow Cloak (DAL_800) | `DALFX_ZayleShadowCloak_CustomSummon.prefab` | СДЕЛАНО (HsFx-58; владелец выбрал в HsBrowser 2026-10-27 вместо Kael'thas, тот уходит к Efreeti); кадры Zayle перепечены с контуром этой карты; выжигание фиолетовое |
| Matron Mother (48329) | Renferal, the Malignant (EDR_526) | `EDRFX_RenferalTheMalignant_CustomSummon.prefab` | СДЕЛАНО (HsFx-62; владелец выбрал в HsBrowser 2026-10-27 вместо Queen Azshara); багровая паутина; выжигание багровое |
| Weaponmaster (48339) | Exarch Akama (GDB_235) | `GDBFX_ExarchAkama_CustomSummon.prefab` | СДЕЛАНО (HsFx-63; владелец выбрал в HsBrowser 2026-10-27 вместо Samuro); пыль и камни у места карты (`move`), огненный крест клинков; выжигание оранжевое |

### dragons

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Black Dragon (48400) | Victor Nefarius (CATA_470) | `CATAFX_VictorNefarius_CustomSummon.prefab` | СДЕЛАНО (HsFx-64..68; владелец выбрал в HsBrowser 2026-10-27 вместо Onyxia); зелёный серп и сфера; выжигание чёрное (правило владельца для Black Dragon) |
| Blue Dragon (48403) | Murozond, Unbounded (TIME_024) | `TIMEFX_MurozondUnbounded_Customsummon.prefab` | СДЕЛАНО (HsFx-64..68; владелец выбрал в HsBrowser 2026-10-27 вместо Malygos); синие молнии через экран, шар; выжигание голубое |
| Green Dragon (48419) | Y'Shaarj (LT23_028H_03) | `DMFFX_Y_ShaarjDefiler_CustomSummon.prefab` | СДЕЛАНО (HsFx-64..68; владелец выбрал в HsBrowser 2026-10-27 вместо Ysera); лента порчи слева, воронка, клякса; трещины спрятаны; выжигание зелёное |
| Rath Modar (48425) | Rhonin (AT_009) | `Rhonin_CustomSpawn.prefab` | БЕЗ АНИМАЦИИ (владелец 2026-10-27, HsFx-56: кадры и звуки удалены; рецепт оставлен); было — (HsFx-20) |
| Red Dragon (48426) | Deathwing, Worldbreaker (CATA_190h) | `CATAFX_Deathwing_CustomSummon_Super.prefab` | СДЕЛАНО (HsFx-1..12) |
| Severin Silrajin (48429) | High Cultist Herenn (TLC_810) | `TLCFX_HighCultistHerenn_CustomSummon.prefab` | СДЕЛАНО (HsFx-64..68; владелец выбрал в HsBrowser 2026-10-27 вместо Cho'gall (тот уходит к Chain Devil)); огненное кольцо ритуала, фиолетовый луч; выжигание фиолетовое |
| White Dragon (48433) | Vyranoth (CATA_213) | `CATAFX_Vyranoth_CustomSummon.prefab` | СДЕЛАНО (HsFx-64..68; владелец выбрал в HsBrowser 2026-10-27 вместо Frost Queen Sindragosa); ледяные кристаллы, морозный взрыв; выжигание голубое |

### demons

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Balor (48500) | Ragnaros, the Great Fire (CATA_150) | `CATAFX_Ragnaros_CustomSummon.prefab` | СДЕЛАНО (HsFx-69..75; владелец выбрал в HsBrowser 2026-10-27 вместо Magtheridon); огненные струи, рогатый огненный лик; выжигание оранжевое |
| Demogorgon (48501) | Kil'jaeden (GDB_145) | `GDBFX_Kiljaeden_CustomSummon.prefab` | СДЕЛАНО (HsFx-30); стоимость 8 — вихрь Скверны на весь экран, выжигание жёлто-зелёное (2026-10-25) |
| Glabrezu (48513) | Nightmare Lord Xavius (EDR_856) | `EDRFX_Xavius_CustomSummon.prefab` | СДЕЛАНО (HsFx-69..75; владелец выбрал в HsBrowser 2026-10-27 вместо Razidir (тот уходит к Guardian Naga)); алые когти, огненный взрыв; выжигание алое |
| Graz'zt (48514) | Endbringer Umbra (TLC_106) | `06_TLCFX_EndbringerUmbra_CustomSummon.prefab` | СДЕЛАНО (HsFx-59; владелец выбрал в HsBrowser 2026-10-27 вместо K'ara, та уходит к Inquisitor); фиолетовые щупальца тьмы сходятся в точку, взрыв; выжигание фиолетовое |
| Orcus (48535) | Archimonde (GDB_128) | `GDBFX_Archimonde_CustomSummon.prefab` | СДЕЛАНО (HsFx-31); стоимость 8 — метеоры Скверны на весь экран, выжигание жёлто-зелёное (2026-10-25) |
| Vrock (48538) | Nythendra (EDR_818) | `EDRFX_Nythendra_CustomSummon.prefab` | СДЕЛАНО (HsFx-34); вместо Anetheron (SW_092, старый набор); пробы Sasquawk, Q'onzu, Owlonius, Aviana, Ohn'ahra, Harpy Queen Aviana владелец смотрел — выбрал Nythendra: врок разносит споры (2026-10-25) |
| Zuggtmoy (48539) | Spore Empress Moldara (GDB_234) | `GDBFX_SporeEmpressMoldara_CustomSummon.prefab` | СДЕЛАНО (HsFx-32); выжигание жёлтое в цвет вспышки спор (владелец 2026-10-25) |

### elementals

Все стоят 5–6. Выбор владельца по пробам 2026-10-25 (старые Ysiel, Naz'jar, Ragnaros EX1,
S'theno, Neptulon TID, Neeru, Al'Akir NEW1 заменены свежими).

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Aerisi Kalinoth (48600) | Inara Stormcrash (DMF_708) | `DMFFX_InaraStormcrash_CustomSummon.prefab` | СДЕЛАНО (HsFx-69..75; владелец выбрал в HsBrowser 2026-10-27 вместо Ohn'ahra); молния слева, сфера бури; трещины спрятаны; выжигание голубое |
| Gar Shatterkeel (48626) | Mutanus the Devourer (WC_030) | `BARFX_MutanusTheDevourer_CustomSummon.prefab` | СДЕЛАНО (HsFx-69..75; владелец выбрал в HsBrowser 2026-10-27 вместо Neptulon); тёмный водоворот, всплеск; затемнение доски не берём; выжигание бирюзовое |
| Imix (48629) | Commander Geddon (CATA_591) | `CATAFX_CommanderGeddon_CustomSummon.prefab` | БЕЗ АНИМАЦИИ (владелец 2026-10-27, HsFx-56: кадры и звуки удалены; рецепт оставлен); было — (HsFx-39); принц огня; огненный вихрь, шар магмы взрывается; овал жетона в кольце спрятан; выжигание оранжевое |
| Marlos Urnrayle (48630) | Y'Shaarj, Titan Bane (BE_784) | `BEFX_YShaarjtheTitanBane_CustomSummon.prefab` | СДЕЛАНО (HsFx-47); медуза — ядовитые змеиные глаза в пурпурной тьме; выжигание ядовито-зелёное. Mirrex (HsFx-43) владелец снял 2026-10-26: розовые кристаллы не для дарк фэнтези; смотрел и отверг Nespirah, Wallow, Renferal, Unknowable One, Black Blood, Herenn, Eliza |
| Ogrémoch (48631) | Ravitz (BE_230) | `BE_230_Ravitz_CustomSummon.prefab` | СДЕЛАНО (HsFx-69..75; владелец выбрал в HsBrowser 2026-10-27 вместо Nespirah); зелёные кристаллы скверны; трещины спрятаны; выжигание зелёное |
| Olhydra (48632) | Azshara, Ocean Lord (CATA_151) | `CATAFX_LadyAzshara_CustomSummon.prefab` | СДЕЛАНО (HsFx-37); принцесса воды, волна снизу обрушивается на место карты; выжигание морской зелени |
| Vanifer (48633) | Incindius (VAC_321) | `VACFX_Incindius_CustomSummon.prefab` | БЕЗ АНИМАЦИИ (владелец 2026-10-27, HsFx-56: кадры и звуки удалены; рецепт оставлен); было — (HsFx-42, HsFx-45); огненная жрица; лавовый взрыв, огненная звезда; оболочка жетона `M_MinionShell_Goo` (жёлтая капсула) спрятана; выжигание красно-оранжевое |
| Yan-C-Bin (48639) | Al'Akir, Lord of Storms (CATA_153) | `CATAFX_Al'Akir_CustomSummon.prefab` | БЕЗ АНИМАЦИИ (владелец 2026-10-27, HsFx-56: кадры и звуки удалены; рецепт оставлен); было — (HsFx-38, HsFx-44); принц воздуха; смерч с молниями прилетает справа, как в HS (прибитый `pin` владелец отверг: «появляется из ниоткуда сразу гигантским»); выжигание фиолетовое |

### aberrations

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Elder Brain (48700) | Kith'ix (BE_090) | `BEFX_Kithix_CustomSummon.prefab` | СДЕЛАНО (HsFx-50); древний разум — фиолетовые молнии с неба, вспышка-мозг (BrainBlast); затемнение и дым на весь экран убраны; выжигание фиолетовое; вместо N'Zoth, God of the Deep (DMF_002, старый набор); пробы Umbra, N'Zoth Dream's End, Mastermind Yogg-Saron владелец смотрел (2026-10-26) |
| Ulitharid (48701) | Azalina Soulsever (JAIL_430) | `JAIL_430_AzalinaSoulsever_FAB_CustomSummon_FX.prefab` | СДЕЛАНО (HsFx-69..75; владелец выбрал в HsBrowser 2026-10-27 вместо Irida (та уходит к Oni)); фиолетовая сфера, щупальца тьмы; трещины спрятаны; выжигание фиолетовое |
| Aboleth (48705) | The Black Blood (CATA_300) | `CATA_300_TheBlackBlood_CustomSummon.prefab` | СДЕЛАНО (HsFx-51); древняя слизистая тварь из глубин, купол ShieldFX спрятан, выжигание фиолетовое; вместо Soggoth (OG_340, старый набор); пробы Maladaar, Uluu владелец смотрел (2026-10-26) |
| Neogi (48710) | Magmaw (CATA_550) | `CATAFX_Magmaw_CustomSummon.prefab` | СДЕЛАНО (HsFx-54); владелец выбрал сам из HsBrowser (2026-10-27): бурый дым по верху экрана, лавовый червь вырывается справа снизу (полёт как в HS), огненный взрыв; выжигание огненно-оранжевое. Wallow (HsFx-52) снят — не понравился; смотрел и отверг: Anub'Rekhan (без жетона только дым), Broodqueen Sha'kar, Kerrigan, Renferal, Omen |
| Death Tyrant (48713) | Shadowcrafter Scabbs (AV_203) | `AVFX_ShadowcrafterScabbs_CustomSummon_Super.prefab` (спелл `..._Spell`) | СДЕЛАНО (HsFx-55); владелец выбрал сам из HsBrowser (2026-10-27): чёрный дым, алая лента влетает сверху, взрыв чёрного дыма — на тёмной доске тихо, владелец берёт всё равно; тень портрета героя спрятана; выжигание алое. G'huun (HsFx-53) снят — не понравился; смотрел и отверг: C'Thun the Shattered, C'Thun Eye of the Empire, Kel'Thuzad, Bonelord Frostwhisper |
| Beholder (48715) | Staff of the Endbringer (TLC_EVENT_402) | `TLCFX_StaffEndbringer_CustomSummon.prefab` | СДЕЛАНО (HsFx-69..75; владелец выбрал в HsBrowser 2026-10-27 вместо Iso'rath (тот уходит к Roper)); зелёно-фиолетовый вихрь, сфера-око; выжигание синее |

### undead

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Death Knight (48721) | The Lich King (ICC_314) | `LichKing_CustomSummon.prefab` | рыцарь смерти |
| Mummy Lord (48725) | Dark Pharaoh Tekahn (ULD_168) | `DarkPharaohTekahn_CustomSummon.prefab` | владыка-мумия |
| Vampire (48728) | Tichondrius (CORE_CATA_001) | `CORE_CATAFX_Tichondrius_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Lich (48732) | Broxigar (TIME_020) | `TIME_020_Broxigar_Fab_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| High Priest of Myrkul (48733) | Bwonsamdi, the Dead (TRL_260) | `Bwonsamdi_CustomSummon.prefab` | жрец бога смерти |
| Revenant (48738) | Sylvanas, the Accused (CORE_MAW_033) | `MAWFX_SylvanasTheAccused_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |

### celestial

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Sphinx of Valor (49003) | Genn, Worgen King (CATA_615t) | `CATAFX_GennWorgenKing_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Djinni (49716) | Velen, Leader of the Exiled (GDB_131) | `GDBFX_VelenLeader_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Solar (49015) | Medivh the Hallowed (TIME_890) | `TIMEFX_MedivhtheHallowed_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Erinyes (49521) | Fyrakk the Blazing (FIR_959) | `FIRFX_FyrakkTheBlazing_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Warrior Veteran (49017) | Commander Beatrix (JAIL_397) | `JAIL_397_HighCommanderBeatrix_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Berserker Commander (49607) | Korrak the Bloodrager (AV_143) | `AVFX_Korrak_CustomSummon.prefab` | берсерк |
| Scout (49019) | Tyrande (EDR_464) | `EDRFX_Tyrande_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| ~~Silver Dragon~~ (—, существо убрано из игры NE-38; на 49020 теперь другое существо) | Azure Queen Sindragosa (TIME_852) | `TIMEFX_AzureQueenSindragosa_CustomSummon.prefab` | анимация свободна |
| Shield Guardian (49218) | Omen (EDR_421) | `EDRFX_Omen_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Adult Gold Dragon (49022) | Ursol (EDR_259) | `EDRFX_Ursol_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |

### shadow

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| ~~Rakshasa~~ (—, существо убрано из игры NE-37; на 49113/49115/49118 теперь Strahd / Relentless Slasher / Zombie Plague Spreader) | Argus, the Emerald Star (TTN_862) | `TTNFX_ArgusTheEmeraldStar_CustomSummon.prefab` | анимация свободна |
| Nightmare (49114) | Thunderbringer (WW_440) | `WWFX_Thunderbringer_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| ~~Chain Devil~~ (—, существо убрано из игры NE-42; на 49513 теперь Arcanaloth) | Cho'gall, Twilight Chieftain (YOG_530) | `YOGFX_Cho'gallTwilightChieftain_CustomSummon.prefab` | анимация свободна (кадры chogall запечены) |
| Barbed Devil (49517) | Wrathion (Story_06_Wrathion) | `Wrathion_CustomSummon.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| Ghast (49117) | Blood Doctor Thal'ena (JAIL_446) | `JAIL_446_BloodDoctorThal_ena_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Treant (49811) | Greybough (DMF_734) | `DMFFX_GreyBough_CustomSummon.prefab` | ожившее дерево |
| Bone Devil (49516) | G'huun (BE_287) | `BE_287_GhuunTheCataStrophic_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Drider (49120) | Blightfang (RLK_225) | `RLK_225_BlightFang_Spawn.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Green Hag (49920; до NE-45 — 49121 в Ravenloft, NE-45 — 49900) | Jace Darkweaver (SW_044) | `SWFX_JaceDarkweaver_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Shadow (49122) | The Jailer (CORE_MAW_034) | `MAWFX_TheJailer_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |

### piltover

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Stone Golem (49211) | Chronogor (TIME_032) | `TIMEFX_Chronogor_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Assassin (49707; NE-49 убран из Waterdeep, NE-50 вернулся в Calimshan) | Garona Halforcen (TIME_875) | `TIME_875_Garona_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Iron Golem (49213) | Mathias Shaw (CAP_005) | `CAP_005_MathiasShaw_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| ~~Manticore~~ (—, существо убрано из игры NE-49; на 49214 теперь Elise) | Lo'Gosh, Blood Fighter (TIME_850) | `TIME_LoGosh_CustomSummon.prefab` | анимация свободна |
| Homunculus (49215) | Norgannon (TTN_075) | `TTNFX_Norgannon_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Chimera (49216) | Dave Berard (CRED_215) | `AVFX_BrukanElements_CustomSummon_Super.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| Archmage (49217) | Khadgar (DAL_575) | `Khadgar_CustomSummon.prefab` | архимаг |
| ~~Basilisk~~ (—, существо убрано из игры NE-37; на 49113/49115/49118 теперь Strahd / Relentless Slasher / Zombie Plague Spreader) | Overseer Frigidara (LEG_RLK_224) | `RLKFX_Frigidara_CustomSummon.prefab` | анимация свободна |
| Behir (49219) | Mastermind Yogg-Saron (BE_009) | `BEFX_YoggSarontheMastermind_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Harpy (49220) | Serena Bloodfeather (BAR_315) | `BARFX_SerenaBloodFeather_CustomSummon.prefab` | гарпия |

### siege

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Avatar of Lolth (49300) | Chillin' Vol'jin (VAC_957) | `VACFX_ChillinVoljin_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Converter (49301) | Morchie (END_036) | `ENDFX_Morchie_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Relentless Siege (49302) | Warmaster Blackhorn (CATA_720) | `CATA_720_WarmasterBlackhorn_CustomSummon.prefab` | осада, бомбардировка |
| Beast Tamer (49303) | Beastmaster Leoroxx (BT_214) | `BeastmasterLeoroxx_CustomSummon.prefab` | укротитель зверей |
| Warlord (49304) | Remornia, Living Blade (CORE_REV_316) | `REVFX_RemorniaLivingBlade_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Siege Beast (49305) | King Krush (EX1_543) | `KingKrush_CustomSummon.prefab` | огромный осадный зверь |

### mercenaries

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Artemis Entreri (49402) | Lady Darkvein (CORE_REV_373) | `REVFX_LadyDarkvein_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Nihiloor (49407) | Karov the Broken (JAIL_448) | `JAIL_448_KarovTheBroken_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Nar'l Xibrindas (49412) | Staff of Trickery (JAIL_875) | `JAILFX_StaffofTrickery_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Jarlaxle (49413) | Heistbaron Togwaggle (DAL_417) | `HeistbaronTogwaggle_CustomSummon.prefab` | авантюрист, крадёт карту |
| Sylgar (49416) | Drest'agath (BE_703) | `BE_703_Drestagath_CustomSummon_FX.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Ahmaergo (49417) | Brann Bronzebeard (LOE_077) | `Brann_CustomSummon.prefab` | дварф |
| Xanathar Zushaxx (49418) | N'Zoth, Dream's End (BE_017) | `BE_017_NzothDreamsEnd_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |

### noxus

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| ~~Weretiger~~ (—, существо убрано из игры NE-37; на 49113/49115/49118 теперь Strahd / Relentless Slasher / Zombie Plague Spreader) | Beaststalker Tavish (AV_113) | `AVFX_TavishBeastStalker_CustomSummon_Super.prefab` | анимация свободна |
| Lamia (49514) | Amitut, Keeper of Amitus (BE_143) | `BE_143_Amitut_Keeper_CustomSummon_FX.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Horned Devil (49515) | Arch-Villain Rafaam (CORE_DAL_422) | `ArchVillianRafaam_CustomSummon.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| Efreeti (49715) | Kael'thas Sunstrider (BT_255) | `KaelthasSunstrider_CustomSummon.prefab` | СДЕЛАНО (HsFx-76; владелец выбрал в HsBrowser 2026-10-27; готовый эффект другой карты перепечён с контуром этой) |
| Azer Sentinel (49801) | Mug'Zee (JAIL_800) | `JAILFX_MugZee_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Ice Devil (49518) | Moroes (KAR_044) | `Moroes_CustomSummon.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| Troll (49519) | Shudderblock (TOY_501t) | `TOYFX_Shudderblock_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Fire Giant (49636) | Neeru Fireblade (LETL_823H) | `BARFX_NeeruFireblade_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| ~~Half-Dragon~~ (—, существо убрано из игры NE-39; на 49018 теперь другое существо) | Sire Denathrius (REV_906t) | `REVFX_SireDenathrius_Infused_CustomSummon.prefab` | анимация свободна |
| Wyvern (49522) | Captain Crowley (CAP_106) | `CAPFX_CaptainCrowley_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |

### freljord

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Doomwake Giant (49613) | — | — | NE-51: creature replaced; Kel'Thuzad animation is available, new assignment pending |
| Hill Giant (49614) | Bearon Gla'shear (AV_257) | `AVFX_BearonGlashear_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Cloud Giant (49615) | Hodir, Father of Giants (TTN_752) | `TTNFX_HodirFatherGiants_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Remorhaz (49616) | Ras Frostwhisper (SCH_273) | `SCHFX_RasFrostwhisperer_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Mammoth (49617) | Icehowl (AT_125) | `IceHowl_CustomSpawn.prefab` | ледяной зверь |
| Storm Giant (49618) | Thaddius, Monstrosity (NX2_033) | `NX2FX_ThaddiusFleshTitan_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Frost Giant (49620) | The Lich King (CORE_ICC_314) | `LichKing_CustomSummon.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| ~~Pirate Captain~~ (—, существо убрано из игры NE-50; на 49714 теперь Abveku) | Eliza Goreblade (VAC_426) | `VAC_ElizaGoreBlade_CustomSummon.prefab` | анимация свободна |
| Blink Dog (49635) | Zer'Ontu (BE_790) | `BE_790_ZerOntu_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| ~~Young White Dragon~~ (—, существо убрано из игры NE-38; на 49014 теперь другое существо) | Bonelord Frostwhisper (RLK_591) | `RLKFX_BonelordFrostwhisper_CustomSummon.prefab` | анимация свободна |

### shurima

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| ~~Roper~~ (—, существо убрано из игры NE-50; на 49711 теперь Marid) | Iso'rath (CATA_481) | `CATAFX_Iso'rath_CustomSummon.prefab` | анимация свободна |
| ~~Ancient Brass Dragon~~ (—, существо убрано из игры NE-38; на 49016 теперь другое существо) | Mister Clocksworth (TIME_038t3) | `TIMEFX_MisterClocksWorth_CustomSummon.prefab` | анимация свободна |
| Purple Worm (49713) | Arisen Onyxia (CATA_155) | `CATA_155_ArisenOnyxia_Fab_CustomSummon_FX.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Ras Nsi (50101) | — | — | NE-52: новое существо; анимация пока не назначена. Guardian Naga перенесена на обычную карту 50115; прежний Razidir освобождён |
| ~~Adult Brass Dragon~~ (—, существо убрано из игры NE-38; на 49021 теперь другое существо) | Anachronos (CORE_RLK_919) | `RLKFX_Anachronos_CustomSummon.prefab` | анимация свободна |
| Stone Giant (49606) | Toy Captain Tarim (TOY_813t) | `TOYFX_ToyCaptainTarim_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Gorgon (49717) | Gorgonzormu (VAC_955) | `VACFX_Gorgonzormu_CustomSummon.prefab` | горгона (по имени; при желании — заменить) |
| Ankheg (49718) | Gorm the Worldeater (GDB_842) | `GDBFX_GormtheWorldeater_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Dust Mephit (49719) | Time Adm'ral Hooktail (TIME_713) | `TIMEFX_Timecap_nHooktail_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Deva (49004) | Sunsapper Lynessa (VAC_507) | `VACFX_SunsapperLynessa_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |

### ionia

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Biha Babir (49800) | Aranna, Thrill Seeker (VAC_501) | `VACFX_ArannatheExtreme_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Oni (49634) | Irida Sinseeker (JAIL_719) | `JAIL_719_IridaSinseeker_CustomSummon_FX.prefab` | СДЕЛАНО (HsFx-76; владелец выбрал в HsBrowser 2026-10-27; готовый эффект другой карты перепечён с контуром этой) |
| Murder Comet (49803) | Aya, Lotus Kingpin (JAIL_504) | `JAILFX_AyaLotusKingpin_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Nafas (49712) | Titanographer Osk (TLC_452t35) | `TLCFX_Titangrapher_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Elemental Cataclysm (49807) | Endtime Murozond (END_037) | `ENDFX_EndtimeMurozond_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Tarrasque (50104) | Maruut Stonebinder (DEEP_037) | `DEEPFX_MaruutStonebinder_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Brackish Trudge (49815) | Nozdormu, Bronze Aspect (CATA_473) | `CATAFX_NozdormuBronzeAspect_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Khargra (49820) | Elise, Badlands Savior (WW_392) | `WWFX_EliseBadlandsSavior_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Gulthias Blight (49821) | Ultraxion (CATA_497) | `CATAFX_Ultraxion_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Kraken (50107) | Ozumat (TID_711) | `TIDFX_Ozumat_CustomSummon.prefab` | морское чудище |

### bandle

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| ~~Satyr Thornbearer~~ (—, существо убрано из игры NE-45; на 49900 теперь Green Hag) | Nightmare Lord Xavius (EDR_856) | `EDRFX_Xavius_CustomSummon.prefab` | анимация свободна |
| ~~High Fae Kindguard~~ (—, существо убрано из игры NE-45; на 49901 теперь Yarnspinner) | Prince Malchezaar (LT24_821H) | `Malchezaar_CustomSummon.prefab` | анимация свободна |
| ~~High Fae Noble~~ (—, существо убрано из игры NE-45; на 49902 теперь Incarnation of Transience) | Glugg the Gulper (TSC_639) | `TSCFX_GluggTheGulper_CustomSummon.prefab` | анимация свободна |
| Lorehold Apprentice (49212; NE-45 убран из Feywild, NE-49 вернулся в Waterdeep) | Farseer Wo (TIME_013) | `TIME_FarseerWo_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Silverquill Apprentice (49220; NE-45 убран из Feywild, NE-49 вернулся в Waterdeep) | Farseer Nobundo (GDB_447) | `GDBFX_FarsserNobundo_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| ~~Faerie Pathlighter~~ (—, существо убрано из игры NE-45; на 49905 теперь Lampad) | Soulburner Varia (YOG_520) | `YOGFX_SoulburnerVaria_CustomSummon.prefab` | анимация свободна |
| Faerie Dragon Youth (49906) | Eternus (TIME_435) | `TIME_Eternus_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| ~~Witherbloom Apprentice~~ (—, существо убрано из игры NE-45; на 49908 теперь The Gardener) | Altruis the Outcast (TOY_401t2) | `Altruis_CustomSummon.prefab` | анимация свободна |
| Witchkite (49909) | Nablya, the Watcher (TLC_624) | `TLCFX_NablyatheWatcher_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |

### void

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Githyanki Knight (50000) | Lothraxion the Redeemed (DMF_240) | `DMFFX_Lothraxion_CustomSummon.prefab` | астральный рыцарь |
| Greater Star Spawn Emissary (50001) | Sargeras, the Destroyer (TTN_960) | `TTNFX_SargerasTheDestroyer_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Froghemoth Elder (50002) | The Exodar (GDB_120) | `GDBFX_TheExodar_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Githzerai Zerth (50003) | The Eternal Hold (TIME_446) | `TIME_EternalHold_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Thri-kreen Marauder (50004) | Grand Empress Shek'zara (DMF_516) | `DMFFX_GrandEmpressShakzara_CustomSummon.prefab` | богомол-воин |
| Red Slaad (50005) | Blood-Queen Lana'thel (CORE_ICC_841) | `BloodQueenLanathel_CustomSummon.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| Inquisitor of the Mind Fire (50006) | Archwitch Willow (CORE_SCH_181) | `SCHFX_ArchwitchWillow_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Groundling Stalker (50007) | Overlord Drakuru (RLK_913) | `RLKFX_Drakuru_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Eye Monger (50008) | The 8 Hands From Beyond (GDB_477) | `GDBFX_8HandsFromBeyond_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |

### ixtal

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Hythonia (50100) | — | — | NE-52: новое существо; анимация пока не назначена. Прежнее назначение Yuan-ti Infiltrator освобождено |
| Galeb Duhr (49822) | Krog, Crater King (TLC_480) | `TLCFX_KrogCraterKing_Custom_Summon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Sarrukh Tyrant (50102) | Timethief Rafaam (TIME_005) | `TIMEFX_TimetheifRafaam_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Ironscale Hydra (50103) | — | — | NE-52: новое существо; анимация пока не назначена. Прежнее назначение Lizardfolk Sovereign освобождено |
| Chwinga (49806) | Baroness Vashj (REV_788) | `REVFX_BaronessVashj_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Troglodyte (50105) | The Unknowable One (BE_725) | `BEFX_UnknowableOne_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Snapping Hydra (50106) | — | — | NE-52: новое существо; анимация пока не назначена. Прежнее назначение Lizardfolk Geomancer освобождено |
| Dao (49720) | Dreamplanner Zephrys (WORK_027) | `WORKFX_ZephrysOverworked_CustomSummon.prefab` | земляной джинн |
| Euryale (50108) | — | — | NE-52: новое существо; анимация пока не назначена. Прежнее назначение Knight of Eldraine освобождено |
