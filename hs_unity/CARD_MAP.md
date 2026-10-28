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
| Djinni (49004) | Velen, Leader of the Exiled (GDB_131) | `GDBFX_VelenLeader_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Solar (49015) | Medivh the Hallowed (TIME_890) | `TIMEFX_MedivhtheHallowed_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Erinyes (49016) | Fyrakk the Blazing (FIR_959) | `FIRFX_FyrakkTheBlazing_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Warrior Veteran (49017) | Commander Beatrix (JAIL_397) | `JAIL_397_HighCommanderBeatrix_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Berserker (49018) | Korrak the Bloodrager (AV_143) | `AVFX_Korrak_CustomSummon.prefab` | берсерк |
| Scout (49019) | Tyrande (EDR_464) | `EDRFX_Tyrande_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Silver Dragon (49020) | Azure Queen Sindragosa (TIME_852) | `TIMEFX_AzureQueenSindragosa_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Shield Guardian (49021) | Omen (EDR_421) | `EDRFX_Omen_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Gold Dragon (49022) | Ursol (EDR_259) | `EDRFX_Ursol_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |

### shadow

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Rakshasa (49113) | Argus, the Emerald Star (TTN_862) | `TTNFX_ArgusTheEmeraldStar_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Nightmare (49114) | Thunderbringer (WW_440) | `WWFX_Thunderbringer_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Chain Devil (49115) | Cho'gall, Twilight Chieftain (YOG_530) | `YOGFX_Cho'gallTwilightChieftain_CustomSummon.prefab` | СДЕЛАНО (HsFx-76; владелец выбрал в HsBrowser 2026-10-27; готовый эффект другой карты перепечён с контуром этой) |
| Barbed Devil (49116) | Wrathion (Story_06_Wrathion) | `Wrathion_CustomSummon.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| Ghast (49117) | Blood Doctor Thal'ena (JAIL_446) | `JAIL_446_BloodDoctorThal_ena_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Treant (49118) | Greybough (DMF_734) | `DMFFX_GreyBough_CustomSummon.prefab` | ожившее дерево |
| Bone Devil (49119) | G'huun (BE_287) | `BE_287_GhuunTheCataStrophic_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Drider (49120) | Blightfang (RLK_225) | `RLK_225_BlightFang_Spawn.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Green Hag (49121) | Jace Darkweaver (SW_044) | `SWFX_JaceDarkweaver_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Shadow (49122) | The Jailer (CORE_MAW_034) | `MAWFX_TheJailer_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |

### piltover

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Stone Golem (49211) | Chronogor (TIME_032) | `TIMEFX_Chronogor_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Assassin (49212) | Garona Halforcen (TIME_875) | `TIME_875_Garona_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Iron Golem (49213) | Mathias Shaw (CAP_005) | `CAP_005_MathiasShaw_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Manticore (49214) | Lo'Gosh, Blood Fighter (TIME_850) | `TIME_LoGosh_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Homunculus (49215) | Norgannon (TTN_075) | `TTNFX_Norgannon_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Chimera (49216) | Dave Berard (CRED_215) | `AVFX_BrukanElements_CustomSummon_Super.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| Archmage (49217) | Khadgar (DAL_575) | `Khadgar_CustomSummon.prefab` | архимаг |
| Basilisk (49218) | Overseer Frigidara (LEG_RLK_224) | `RLKFX_Frigidara_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
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
| Weretiger (49513) | Beaststalker Tavish (AV_113) | `AVFX_TavishBeastStalker_CustomSummon_Super.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| Lamia (49514) | Amitut, Keeper of Amitus (BE_143) | `BE_143_Amitut_Keeper_CustomSummon_FX.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Horned Devil (49515) | Arch-Villain Rafaam (CORE_DAL_422) | `ArchVillianRafaam_CustomSummon.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| Efreeti (49516) | Kael'thas Sunstrider (BT_255) | `KaelthasSunstrider_CustomSummon.prefab` | СДЕЛАНО (HsFx-76; владелец выбрал в HsBrowser 2026-10-27; готовый эффект другой карты перепечён с контуром этой) |
| Azer Sentinel (49517) | Mug'Zee (JAIL_800) | `JAILFX_MugZee_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Ice Devil (49518) | Moroes (KAR_044) | `Moroes_CustomSummon.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| Troll (49519) | Shudderblock (TOY_501t) | `TOYFX_Shudderblock_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Fire Giant (49520) | Neeru Fireblade (LETL_823H) | `BARFX_NeeruFireblade_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Half-Dragon (49521) | Sire Denathrius (REV_906t) | `REVFX_SireDenathrius_Infused_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Wyvern (49522) | Captain Crowley (CAP_106) | `CAPFX_CaptainCrowley_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |

### freljord

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Owlbear (49613) | Kel'Thuzad (FP1_013) | `Kelthuzad_CustomSummon.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| Hill Giant (49614) | Bearon Gla'shear (AV_257) | `AVFX_BearonGlashear_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Cloud Giant (49615) | Hodir, Father of Giants (TTN_752) | `TTNFX_HodirFatherGiants_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Remorhaz (49616) | Ras Frostwhisper (SCH_273) | `SCHFX_RasFrostwhisperer_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Mammoth (49617) | Icehowl (AT_125) | `IceHowl_CustomSpawn.prefab` | ледяной зверь |
| Storm Giant (49618) | Thaddius, Monstrosity (NX2_033) | `NX2FX_ThaddiusFleshTitan_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Frost Giant (49620) | The Lich King (CORE_ICC_314) | `LichKing_CustomSummon.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| Pirate Captain (49634) | Eliza Goreblade (VAC_426) | `VAC_ElizaGoreBlade_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Blink Dog (49635) | Zer'Ontu (BE_790) | `BE_790_ZerOntu_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Young White Dragon (49636) | Bonelord Frostwhisper (RLK_591) | `RLKFX_BonelordFrostwhisper_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |

### shurima

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Roper (49711) | Iso'rath (CATA_481) | `CATAFX_Iso'rath_CustomSummon.prefab` | СДЕЛАНО (HsFx-76; владелец выбрал в HsBrowser 2026-10-27; готовый эффект другой карты перепечён с контуром этой) |
| Ancient Brass Dragon (49712) | Mister Clocksworth (TIME_038t3) | `TIMEFX_MisterClocksWorth_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Purple Worm (49713) | Arisen Onyxia (CATA_155) | `CATA_155_ArisenOnyxia_Fab_CustomSummon_FX.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
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
| Tarrasque (49811) | Maruut Stonebinder (DEEP_037) | `DEEPFX_MaruutStonebinder_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Ancient Bronze Dragon (49815) | Nozdormu, Bronze Aspect (CATA_473) | `CATAFX_NozdormuBronzeAspect_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Adult Gold Dragon (49820) | Elise, Badlands Savior (WW_392) | `WWFX_EliseBadlandsSavior_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Ancient Silver Dragon (49821) | Ultraxion (CATA_497) | `CATAFX_Ultraxion_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Kraken (49822) | Ozumat (TID_711) | `TIDFX_Ozumat_CustomSummon.prefab` | морское чудище |

### bandle

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Satyr Thornbearer (49900) | Nightmare Lord Xavius (EDR_856) | `EDRFX_Xavius_CustomSummon.prefab` | сатир |
| High Fae Kindguard (49901) | Prince Malchezaar (LT24_821H) | `Malchezaar_CustomSummon.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| High Fae Noble (49902) | Glugg the Gulper (TSC_639) | `TSCFX_GluggTheGulper_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Lorehold Apprentice (49903) | Farseer Wo (TIME_013) | `TIME_FarseerWo_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Silverquill Apprentice (49904) | Farseer Nobundo (GDB_447) | `GDBFX_FarsserNobundo_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Faerie Pathlighter (49905) | Soulburner Varia (YOG_520) | `YOGFX_SoulburnerVaria_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Faerie Dragon Youth (49906) | Eternus (TIME_435) | `TIME_Eternus_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Witherbloom Apprentice (49908) | Altruis the Outcast (TOY_401t2) | `Altruis_CustomSummon.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
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
| Yuan-ti Infiltrator (50100) | Infiltrator Lilian (SCH_426) | `InfiltratorLillian_CustomSummon.prefab` | змеелюд-лазутчик |
| Galeb Duhr (50101) | Krog, Crater King (TLC_480) | `TLCFX_KrogCraterKing_Custom_Summon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Sarrukh Tyrant (50102) | Timethief Rafaam (TIME_005) | `TIMEFX_TimetheifRafaam_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Lizardfolk Sovereign (50103) | Chrono-Lord Epoch (TIME_714) | `TIMEFX_ChronoLordEpoch_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Chwinga (50104) | Baroness Vashj (REV_788) | `REVFX_BaronessVashj_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Troglodyte (50105) | The Unknowable One (BE_725) | `BEFX_UnknowableOne_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Lizardfolk Geomancer (50106) | Niri of the Crater (TLC_836) | `TLCFX_NirioftheCrater_CustomSummon.prefab` | геомант-ящер |
| Dao (50107) | Dreamplanner Zephrys (WORK_027) | `WORKFX_ZephrysOverworked_CustomSummon.prefab` | земляной джинн |
| Knight of Eldraine (50108) | Chronikar (END_006) | `ENDFX_Chronikar_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
