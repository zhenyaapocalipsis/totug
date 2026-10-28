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
| Sphinx of Valor (49003) | King Phaoris (ULD_304) | `KingPharois_CustomSummon.prefab` | сфинкс, древний царь пустыни |
| Djinni (49004) | Zephrys the Great (ULD_003) | `Zephrys_CustomSummon.prefab` | джинн |
| Solar (49015) | Medivh the Hallowed (TIME_890) | `TIMEFX_MedivhtheHallowed_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Erinyes (49016) | Aggramar, the Avenger (TTN_092) | `TTNFX_AggramarTheAvenger_CustomSummon.prefab` | крылатая мстительница |
| Warrior Veteran (49017) | Varian, King of Stormwind (SW_081) | `SWFX_KingVarian_CustomSummon.prefab` | воин-ветеран |
| Berserker (49018) | Korrak the Bloodrager (AV_143) | `AVFX_Korrak_CustomSummon.prefab` | берсерк |
| Scout (49019) | Vereesa Windrunner (DAL_379) | `VereesaWindrunner_CustomSummon.prefab` | разведчица-лучница |
| Silver Dragon (49020) | Azure Queen Sindragosa (TIME_852) | `TIMEFX_AzureQueenSindragosa_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Shield Guardian (49021) | Omen (EDR_421) | `EDRFX_Omen_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Gold Dragon (49022) | Nozdormu the Timeless (DRG_309) | `NozdormuTheTimeless_CustomSummon.prefab` | золотой дракон |

### shadow

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Rakshasa (49113) | Shirvallah, the Tiger (TRL_300) | `Shirvallah_CustomSummon.prefab` | демон-тигр |
| Nightmare (49114) | Thunderbringer (WW_440) | `WWFX_Thunderbringer_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Chain Devil (49115) | Cho'gall, Twilight Chieftain (YOG_530) | `YOGFX_Cho'gallTwilightChieftain_CustomSummon.prefab` | СДЕЛАНО (HsFx-76; владелец выбрал в HsBrowser 2026-10-27; готовый эффект другой карты перепечён с контуром этой) |
| Barbed Devil (49116) | Wrathion (Story_06_Wrathion) | `Wrathion_CustomSummon.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| Ghast (49117) | Rotface (ICC_405) | `RotFace_CustomSummon.prefab` | гниющий упырь |
| Treant (49118) | Greybough (DMF_734) | `DMFFX_GreyBough_CustomSummon.prefab` | ожившее дерево |
| Bone Devil (49119) | Lord Marrowgar (RLK_085) | `RLKFX_LordMarrowgar_CustomSummon.prefab` | костяной дьявол |
| Drider (49120) | Hadronox (ICC_835) | `Hadronox_CustomSummon.prefab` | паук-дроу |
| Green Hag (49121) | Jace Darkweaver (SW_044) | `SWFX_JaceDarkweaver_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Shadow (49122) | Teron Gorefiend (BT_126) | `TeronGorefiend_CustomSummon.prefab` | живая тень |

### piltover

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Stone Golem (49211) | The Stonewright (REV_921) | `REVFX_TheStonewright_CustomSummon.prefab` | каменный голем |
| Assassin (49212) | Garona Halforcen (TIME_875) | `TIME_875_Garona_CustomSummon.prefab` | наёмная убийца |
| Iron Golem (49213) | Mimiron, the Mastermind (TTN_920) | `ETCFX_MimironTheMastermind_CustomSummon_Friendly.prefab` | железный голем, механизм |
| Manticore (49214) | Zixor, Apex Predator (BT_210) | `Zixor_CustomSummon.prefab` | хищное чудовище |
| Homunculus (49215) | Kazakus, Golem Shaper (BAR_079) | `BARFX_KazakusGolemShaper_CustomSummon.prefab` | алхимическое создание |
| Chimera (49216) | Dave Berard (CRED_215) | `AVFX_BrukanElements_CustomSummon_Super.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| Archmage (49217) | Khadgar (DAL_575) | `Khadgar_CustomSummon.prefab` | архимаг |
| Basilisk (49218) | Gonk, the Raptor (TRL_241) | `Gonk_CustomSummon.prefab` | ящер |
| Behir (49219) | Thorim, Stormlord (TTN_835) | `TTNFX_ThorimStormlord_CustomSummon.prefab` | змей-молния |
| Harpy (49220) | Serena Bloodfeather (BAR_315) | `BARFX_SerenaBloodFeather_CustomSummon.prefab` | гарпия |

### siege

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Avatar of Lolth (49300) | Broodqueen Sha'kar (BE_565) | `BEFX_ShakartheSupreme_CustomSummon.prefab` | паучья богиня, королева выводка |
| Converter (49301) | Cho'gall, Mastermind (CATA_726) | `CATAFX_ChogallMastermind_CustomSummon.prefab` | обращает врагов на свою сторону |
| Relentless Siege (49302) | Warmaster Blackhorn (CATA_720) | `CATA_720_WarmasterBlackhorn_CustomSummon.prefab` | осада, бомбардировка |
| Beast Tamer (49303) | Beastmaster Leoroxx (BT_214) | `BeastmasterLeoroxx_CustomSummon.prefab` | укротитель зверей |
| Warlord (49304) | Overlord Saurfang (BAR_334) | `BARFX_OverlordSaurfang_CustomSummon.prefab` | полководец |
| Siege Beast (49305) | King Krush (EX1_543) | `KingKrush_CustomSummon.prefab` | огромный осадный зверь |

### mercenaries

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Artemis Entreri (49402) | Edwin, Defias Kingpin (DED_510) | `DEDFX_EdwinDefiasKingpin_CustomSummon.prefab` | король убийц |
| Nihiloor (49407) | Za'qul (TSC_959) | `TSCFX_Zaqul_CustomSummon.prefab` | иллитид, кошмар разума |
| Nar'l Xibrindas (49412) | Archmage Arugal (GIL_691) | `ArchmageArugal_CustomSummon.prefab` | маг-дроу |
| Jarlaxle (49413) | Heistbaron Togwaggle (DAL_417) | `HeistbaronTogwaggle_CustomSummon.prefab` | авантюрист, крадёт карту |
| Sylgar (49416) | Drest'agath (BE_703) | `BE_703_Drestagath_CustomSummon_FX.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Ahmaergo (49417) | Brann Bronzebeard (LOE_077) | `Brann_CustomSummon.prefab` | дварф |
| Xanathar Zushaxx (49418) | N'Zoth, Dream's End (BE_017) | `BE_017_NzothDreamsEnd_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |

### noxus

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Weretiger (49513) | Beaststalker Tavish (AV_113) | `AVFX_TavishBeastStalker_CustomSummon_Super.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| Lamia (49514) | Lady Anacondra (WC_006) | `BARFX_LadyAnacondra_CustomSummon.prefab` | змеедева |
| Horned Devil (49515) | Arch-Villain Rafaam (CORE_DAL_422) | `ArchVillianRafaam_CustomSummon.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| Efreeti (49516) | Kael'thas Sunstrider (BT_255) | `KaelthasSunstrider_CustomSummon.prefab` | СДЕЛАНО (HsFx-76; владелец выбрал в HsBrowser 2026-10-27; готовый эффект другой карты перепечён с контуром этой) |
| Azer Sentinel (49517) | Emperor Thaurissan (BRM_028) | `ThaurissanMinion_CustomSummon.prefab` | огненный дварф |
| Ice Devil (49518) | Moroes (KAR_044) | `Moroes_CustomSummon.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| Troll (49519) | Zul'jin (TRL_065) | `ZulJin_CustomSummon_FX.prefab` | тролль |
| Fire Giant (49520) | Magmaw (CATA_550) | `CATAFX_Magmaw_CustomSummon.prefab` | огненный великан, лава |
| Half-Dragon (49521) | Wrathion (CFM_806) | `Wrathion_CustomSummon.prefab` | полудракон |
| Wyvern (49522) | Flightmaster Dungar (SW_079) | `SWFX_FlightmasterDungar_CustomSummon.prefab` | виверна, полёт |

### freljord

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Owlbear (49613) | Kel'Thuzad (FP1_013) | `Kelthuzad_CustomSummon.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| Hill Giant (49614) | Hodir, Father of Giants (TTN_752) | `TTNFX_HodirFatherGiants_CustomSummon.prefab` | великан |
| Cloud Giant (49615) | Hodir, Father of Giants (TTN_752) | `TTNFX_HodirFatherGiants_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Remorhaz (49616) | Mutanus the Devourer (WC_030) | `BARFX_MutanusTheDevourer_CustomSummon.prefab` | пожирающий червь |
| Mammoth (49617) | Icehowl (AT_125) | `IceHowl_CustomSpawn.prefab` | ледяной зверь |
| Storm Giant (49618) | Golganneth, the Thunderer (TTN_800) | `TTNFX_Golganneth_CustomSummon.prefab` | великан бури |
| Frost Giant (49620) | The Lich King (CORE_ICC_314) | `LichKing_CustomSummon.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| Pirate Captain (49634) | Eliza Goreblade (VAC_426) | `VAC_ElizaGoreBlade_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Blink Dog (49635) | Zer'Ontu (BE_790) | `BE_790_ZerOntu_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Young White Dragon (49636) | Bonelord Frostwhisper (RLK_591) | `RLKFX_BonelordFrostwhisper_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |

### shurima

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Roper (49711) | Iso'rath (CATA_481) | `CATAFX_Iso'rath_CustomSummon.prefab` | СДЕЛАНО (HsFx-76; владелец выбрал в HsBrowser 2026-10-27; готовый эффект другой карты перепечён с контуром этой) |
| Ancient Brass Dragon (49712) | Mister Clocksworth (TIME_038t3) | `TIMEFX_MisterClocksWorth_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Purple Worm (49713) | Gorm the Worldeater (GDB_842) | `GDBFX_GormtheWorldeater_CustomSummon.prefab` | гигантский червь |
| Guardian Naga (49714) | Razidir (TLC_463) | `TLC463_Nazidir_CustomSummon.prefab` | СДЕЛАНО (HsFx-76; владелец выбрал в HsBrowser 2026-10-27; готовый эффект другой карты перепечён с контуром этой) |
| Adult Brass Dragon (49715) | Anachronos (CORE_RLK_919) | `RLKFX_Anachronos_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Stone Giant (49716) | Toy Captain Tarim (TOY_813t) | `TOYFX_ToyCaptainTarim_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Gorgon (49717) | Gorgonzormu (VAC_955) | `VACFX_Gorgonzormu_CustomSummon.prefab` | горгона (по имени; при желании — заменить) |
| Ankheg (49718) | Gorm the Worldeater (GDB_842) | `GDBFX_GormtheWorldeater_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Dust Mephit (49719) | Time Adm'ral Hooktail (TIME_713) | `TIMEFX_Timecap_nHooktail_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Deva (49720) | Sunsapper Lynessa (VAC_507) | `VACFX_SunsapperLynessa_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |

### ionia

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Ancient Green Dragon (49800) | Aranna, Thrill Seeker (VAC_501) | `VACFX_ArannatheExtreme_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Oni (49801) | Irida Sinseeker (JAIL_719) | `JAIL_719_IridaSinseeker_CustomSummon_FX.prefab` | СДЕЛАНО (HsFx-76; владелец выбрал в HsBrowser 2026-10-27; готовый эффект другой карты перепечён с контуром этой) |
| Ancient Black Dragon (49803) | Aya, Lotus Kingpin (JAIL_504) | `JAILFX_AyaLotusKingpin_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Ancient Copper Dragon (49806) | Titanographer Osk (TLC_452t35) | `TLCFX_Titangrapher_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Ancient Blue Dragon (49807) | Endtime Murozond (END_037) | `ENDFX_EndtimeMurozond_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Tarrasque (49811) | Oondasta (TRL_542) | `Oondasta_CustomSummon.prefab` | непобедимое чудище |
| Ancient Bronze Dragon (49815) | Nozdormu, Bronze Aspect (CATA_473) | `CATAFX_NozdormuBronzeAspect_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Adult Gold Dragon (49820) | Elise, Badlands Savior (WW_392) | `WWFX_EliseBadlandsSavior_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Ancient Silver Dragon (49821) | Ultraxion (CATA_497) | `CATAFX_Ultraxion_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Kraken (49822) | Ozumat (TID_711) | `TIDFX_Ozumat_CustomSummon.prefab` | морское чудище |

### bandle

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Satyr Thornbearer (49900) | Nightmare Lord Xavius (EDR_856) | `EDRFX_Xavius_CustomSummon.prefab` | сатир |
| High Fae Kindguard (49901) | Prince Malchezaar (LT24_821H) | `Malchezaar_CustomSummon.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| High Fae Noble (49902) | Sesselie of the Fae Court (REV_319) | `REVFX_SesselieFaeCourt_CustomSummon.prefab` | феи-аристократы |
| Lorehold Apprentice (49903) | Star Student Stelina (SCH_603) | `SCHFX_StarStudentStelina_CustomSummon.prefab` | ученица-маг |
| Silverquill Apprentice (49904) | Inkmaster Solia (CFM_687) | `Irelia_CustomSummon.prefab` | ученица — чернила и слово |
| Faerie Pathlighter (49905) | Kiri, Chosen of Elune (DMF_733) | `DMFFX_KiriChosenofElune_CustomSummon.prefab` | фея-проводник со светом |
| Faerie Dragon Youth (49906) | Ysondre (EDR_465) | `EDRFX_Ysondre_CustomSummon_FIX.prefab` | дракончик фей |
| Witherbloom Apprentice (49908) | Altruis the Outcast (TOY_401t2) | `Altruis_CustomSummon.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| Witchkite (49909) | Glinda Crowskin (GIL_618) | `GlindaCrowskin_CustomSummon.prefab` | ведьма-птица |

### void

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Githyanki Knight (50000) | Lothraxion the Redeemed (DMF_240) | `DMFFX_Lothraxion_CustomSummon.prefab` | астральный рыцарь |
| Greater Star Spawn Emissary (50001) | Xor'toth, Breaker of Stars (GDB_118) | `GDBFX_Xortoth_CustomSummon.prefab` | порождение звёзд |
| Froghemoth Elder (50002) | Krag'wa, the Frog (TRL_345) | `Kragwa_CustomSummon.prefab` | гигантская лягушка |
| Githzerai Zerth (50003) | Akama (BT_713) | `Akama_CustomSummon.prefab` | монах-аскет |
| Thri-kreen Marauder (50004) | Grand Empress Shek'zara (DMF_516) | `DMFFX_GrandEmpressShakzara_CustomSummon.prefab` | богомол-воин |
| Red Slaad (50005) | Blood-Queen Lana'thel (CORE_ICC_841) | `BloodQueenLanathel_CustomSummon.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| Inquisitor of the Mind Fire (50006) | Mindrender Illucia (SCH_159) | `SCHFX_MindrenderIllucia_CustomSummon.prefab` | огонь разума |
| Groundling Stalker (50007) | Opu the Unseen (TLC_522) | `TLCFX_OputheUnseen_CustomSummon.prefab` | невидимый охотник |
| Eye Monger (50008) | C'Thun, Eye of the Empire (BE_013) | `BEFX_CthunEyeoftheEmpire_CustomSummon.prefab` | существо-глаз |

### ixtal

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Yuan-ti Infiltrator (50100) | Infiltrator Lilian (SCH_426) | `InfiltratorLillian_CustomSummon.prefab` | змеелюд-лазутчик |
| Galeb Duhr (50101) | Archaedas (BE_055) | `BEFX_Archeadas_CustomSummon.prefab` | ожившая скала |
| Sarrukh Tyrant (50102) | Hakkar, the Soulflayer (TRL_541) | `Hakkar_CustomSummon.prefab` | змеиный тиран |
| Lizardfolk Sovereign (50103) | Tyrantus (UNG_852) | `Tyrantus_CustomSummon.prefab` | король ящеров |
| Chwinga (50104) | Pip the Potent (WW_394) | `WWFX_PipThePotent_CustomSummon.prefab` | крошечный дух |
| Troglodyte (50105) | Krog, Crater King (TLC_480) | `TLCFX_KrogCraterKing_Custom_Summon.prefab` | пещерный ящер |
| Lizardfolk Geomancer (50106) | Niri of the Crater (TLC_836) | `TLCFX_NirioftheCrater_CustomSummon.prefab` | геомант-ящер |
| Dao (50107) | Dreamplanner Zephrys (WORK_027) | `WORKFX_ZephrysOverworked_CustomSummon.prefab` | земляной джинн |
| Knight of Eldraine (50108) | The Glass Knight (GIL_817) | `GlassKnight_CustomSummon.prefab` | сказочный рыцарь |
