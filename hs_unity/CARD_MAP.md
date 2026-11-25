# Анимации Hearthstone для уникальных карт

В списке 150 карт из 18 полуколод. Уникальная карта встречается в своей полуколоде
в одном экземпляре по `engine/godot/data/cards/half_decks.json`. Названия карт берутся
из `engine/godot/data/cards/cards.json`.

«СДЕЛАНО» означает, что эффект уже подключён в Godot. Остальные эффекты в таблице —
ранее подобранные кандидаты. Назначение владельца в `data/hs_assign.tsv` имеет
приоритет. Порядок работы и критерии подбора описаны в `GUIDE.md`.

Ключи полуколод в данных игры (`shadow` — Ravenloft, `piltover` — Waterdeep,
`noxus` — Avernus, `freljord` — Icewind Dale, `shurima` — Calimshan,
`ionia` — Kara-Tur, `bandle` — Feywild, `void` — Far Realm, `ixtal` — Chult).

## Уникальные карты

### drow

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Статус |
|---|---|---|---|
| Council Member (48315) | Wilfred Fizzlebang (AT_027) | `ATFX_WilfredFizzlebang_CustomSummon.prefab` | СДЕЛАНО (HsFx-61; владелец выбрал в HsBrowser 2026-10-27 вместо Lady Prestor); фиолетовые кольца призыва, по FSM без Timeline; выжигание фиолетовое |
| Deathblade (48316) | Blade of The Black Empire (BE_227) | `05_BEFX_BladeoftheBlackEmpire_CustomSummon.prefab` | СДЕЛАНО (HsFx-57; владелец выбрал в HsBrowser 2026-10-27 вместо Zayle); два фиолетовых разреза крестом, вихрь пустоты; выжигание фиолетовое |
| Inquisitor (48325) | K'ara, the Dark Star (GDB_127) | `GDBFX_Kara_CustomSummon.prefab` | СДЕЛАНО (HsFx-60; владелец выбрал в HsBrowser 2026-10-27 вместо Benedictus, кадры того удалены); K'ara перепечена с контуром этой карты; выжигание фиолетовое |
| Masters of Sorcere (48328) | Zayle, Shadow Cloak (DAL_800) | `DALFX_ZayleShadowCloak_CustomSummon.prefab` | СДЕЛАНО (HsFx-58; владелец выбрал в HsBrowser 2026-10-27 вместо Kael'thas, тот уходит к Efreeti); кадры Zayle перепечены с контуром этой карты; выжигание фиолетовое |
| Matron Mother (48329) | Renferal, the Malignant (EDR_526) | `EDRFX_RenferalTheMalignant_CustomSummon.prefab` | СДЕЛАНО (HsFx-62; владелец выбрал в HsBrowser 2026-10-27 вместо Queen Azshara); багровая паутина; выжигание багровое |
| Weaponmaster (48339) | Exarch Akama (GDB_235) | `GDBFX_ExarchAkama_CustomSummon.prefab` | СДЕЛАНО (HsFx-63; владелец выбрал в HsBrowser 2026-10-27 вместо Samuro); пыль и камни у места карты (`move`), огненный крест клинков; выжигание оранжевое |

### dragons

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Статус |
|---|---|---|---|
| Black Dragon (48400) | Victor Nefarius (CATA_470) | `CATAFX_VictorNefarius_CustomSummon.prefab` | СДЕЛАНО (HsFx-64..68; владелец выбрал в HsBrowser 2026-10-27 вместо Onyxia); зелёный серп и сфера; выжигание чёрное (правило владельца для Black Dragon) |
| Blue Dragon (48403) | Murozond, Unbounded (TIME_024) | `TIMEFX_MurozondUnbounded_Customsummon.prefab` | СДЕЛАНО (HsFx-64..68; владелец выбрал в HsBrowser 2026-10-27 вместо Malygos); синие молнии через экран, шар; выжигание голубое |
| Green Dragon (48419) | Y'Shaarj (LT23_028H_03) | `DMFFX_Y_ShaarjDefiler_CustomSummon.prefab` | СДЕЛАНО (HsFx-64..68; владелец выбрал в HsBrowser 2026-10-27 вместо Ysera); лента порчи слева, воронка, клякса; трещины спрятаны; выжигание зелёное |
| Rath Modar (48425) | Farseer Wo (TIME_013) | `TIME_FarseerWo_CustomSummon.prefab` | СДЕЛАНО (HsFx-99, 2026-11-24), показ владельцу перед переносом остальных назначений |
| Red Dragon (48426) | Deathwing, Worldbreaker (CATA_190h) | `CATAFX_Deathwing_CustomSummon_Super.prefab` | СДЕЛАНО (HsFx-1..12) |
| Severin Silrajin (48429) | High Cultist Herenn (TLC_810) | `TLCFX_HighCultistHerenn_CustomSummon.prefab` | СДЕЛАНО (HsFx-64..68; владелец выбрал в HsBrowser 2026-10-27 вместо Cho'gall (тот уходит к Chain Devil)); огненное кольцо ритуала, фиолетовый луч; выжигание фиолетовое |
| White Dragon (48433) | Vyranoth (CATA_213) | `CATAFX_Vyranoth_CustomSummon.prefab` | СДЕЛАНО (HsFx-64..68; владелец выбрал в HsBrowser 2026-10-27 вместо Frost Queen Sindragosa); ледяные кристаллы, морозный взрыв; выжигание голубое |

### demons

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Статус |
|---|---|---|---|
| Balor (48500) | Ragnaros, the Great Fire (CATA_150) | `CATAFX_Ragnaros_CustomSummon.prefab` | СДЕЛАНО (HsFx-69..75; владелец выбрал в HsBrowser 2026-10-27 вместо Magtheridon); огненные струи, рогатый огненный лик; выжигание оранжевое |
| Demogorgon (48501) | Kil'jaeden (GDB_145) | `GDBFX_Kiljaeden_CustomSummon.prefab` | СДЕЛАНО (HsFx-30); стоимость 8 — вихрь Скверны на весь экран, выжигание жёлто-зелёное (2026-10-25) |
| Glabrezu (48513) | Nightmare Lord Xavius (EDR_856) | `EDRFX_Xavius_CustomSummon.prefab` | СДЕЛАНО (HsFx-69..75; владелец выбрал в HsBrowser 2026-10-27 вместо Razidir (тот уходит к Guardian Naga)); алые когти, огненный взрыв; выжигание алое |
| Graz'zt (48514) | Endbringer Umbra (TLC_106) | `06_TLCFX_EndbringerUmbra_CustomSummon.prefab` | СДЕЛАНО (HsFx-59; владелец выбрал в HsBrowser 2026-10-27 вместо K'ara, та уходит к Inquisitor); фиолетовые щупальца тьмы сходятся в точку, взрыв; выжигание фиолетовое |
| Orcus (48535) | Archimonde (GDB_128) | `GDBFX_Archimonde_CustomSummon.prefab` | СДЕЛАНО (HsFx-31); стоимость 8 — метеоры Скверны на весь экран, выжигание жёлто-зелёное (2026-10-25) |
| Vrock (48538) | Nythendra (EDR_818) | `EDRFX_Nythendra_CustomSummon.prefab` | СДЕЛАНО (HsFx-34); вместо Anetheron (SW_092, старый набор); пробы Sasquawk, Q'onzu, Owlonius, Aviana, Ohn'ahra, Harpy Queen Aviana владелец смотрел — выбрал Nythendra: врок разносит споры (2026-10-25) |
| Zuggtmoy (48539) | Spore Empress Moldara (GDB_234) | `GDBFX_SporeEmpressMoldara_CustomSummon.prefab` | СДЕЛАНО (HsFx-32); выжигание жёлтое в цвет вспышки спор (владелец 2026-10-25) |

### elementals

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Статус |
|---|---|---|---|
| Aerisi Kalinoth (48600) | Inara Stormcrash (DMF_708) | `DMFFX_InaraStormcrash_CustomSummon.prefab` | СДЕЛАНО (HsFx-69..75; владелец выбрал в HsBrowser 2026-10-27 вместо Ohn'ahra); молния слева, сфера бури; трещины спрятаны; выжигание голубое |
| Gar Shatterkeel (48626) | Mutanus the Devourer (WC_030) | `BARFX_MutanusTheDevourer_CustomSummon.prefab` | СДЕЛАНО (HsFx-69..75; владелец выбрал в HsBrowser 2026-10-27 вместо Neptulon); тёмный водоворот, всплеск; затемнение доски не берём; выжигание бирюзовое |
| Imix (48629) | Ignis, the Eternal Flame (TTN_751) | `11_TTNFX_Ignis_CustomSummon.prefab` | СДЕЛАНО (HsFx-103; владелец выбрал в HsBrowser 2026-11-23); эффект Ignis, the Eternal Flame; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Marlos Urnrayle (48630) | Y'Shaarj, Titan Bane (BE_784) | `BEFX_YShaarjtheTitanBane_CustomSummon.prefab` | СДЕЛАНО (HsFx-47); медуза — ядовитые змеиные глаза в пурпурной тьме; выжигание ядовито-зелёное. Mirrex (HsFx-43) владелец снял 2026-10-26: розовые кристаллы не для дарк фэнтези; смотрел и отверг Nespirah, Wallow, Renferal, Unknowable One, Black Blood, Herenn, Eliza |
| Ogrémoch (48631) | Ravitz (BE_230) | `BE_230_Ravitz_CustomSummon.prefab` | СДЕЛАНО (HsFx-69..75; владелец выбрал в HsBrowser 2026-10-27 вместо Nespirah); зелёные кристаллы скверны; трещины спрятаны; выжигание зелёное |
| Olhydra (48632) | Azshara, Ocean Lord (CATA_151) | `CATAFX_LadyAzshara_CustomSummon.prefab` | СДЕЛАНО (HsFx-37); принцесса воды, волна снизу обрушивается на место карты; выжигание морской зелени |
| Vanifer (48633) | Grand Magister Rommath (RLK_803) | `10_RLKFX_GrandMagisterRommath_CustomSummon.prefab` | СДЕЛАНО (HsFx-104; владелец выбрал в HsBrowser 2026-11-23); эффект Grand Magister Rommath; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Yan-C-Bin (48639) | Al'Akir, the Winds of Time (WON_092h) | `06_WONFX_AlAkir_Hero_CustomSummon_Spell.prefab` | СДЕЛАНО (HsFx-105; владелец выбрал в HsBrowser 2026-11-24); эффект Al'Akir, the Winds of Time; жетон HS спрятан сетками; выжигание в цвет эффекта |

### aberrations

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Статус |
|---|---|---|---|
| Elder Brain (48700) | Kith'ix (BE_090) | `BEFX_Kithix_CustomSummon.prefab` | СДЕЛАНО (HsFx-50); древний разум — фиолетовые молнии с неба, вспышка-мозг (BrainBlast); затемнение и дым на весь экран убраны; выжигание фиолетовое; вместо N'Zoth, God of the Deep (DMF_002, старый набор); пробы Umbra, N'Zoth Dream's End, Mastermind Yogg-Saron владелец смотрел (2026-10-26) |
| Ulitharid (48701) | Azalina Soulsever (JAIL_430) | `JAIL_430_AzalinaSoulsever_FAB_CustomSummon_FX.prefab` | СДЕЛАНО (HsFx-69..75; владелец выбрал в HsBrowser 2026-10-27 вместо Irida (та уходит к Oni)); фиолетовая сфера, щупальца тьмы; трещины спрятаны; выжигание фиолетовое |
| Aboleth (48705) | The Black Blood (CATA_300) | `CATA_300_TheBlackBlood_CustomSummon.prefab` | СДЕЛАНО (HsFx-51); древняя слизистая тварь из глубин, купол ShieldFX спрятан, выжигание фиолетовое; вместо Soggoth (OG_340, старый набор); пробы Maladaar, Uluu владелец смотрел (2026-10-26) |
| Neogi (48710) | Magmaw (CATA_550) | `CATAFX_Magmaw_CustomSummon.prefab` | СДЕЛАНО (HsFx-54); владелец выбрал сам из HsBrowser (2026-10-27): бурый дым по верху экрана, лавовый червь вырывается справа снизу (полёт как в HS), огненный взрыв; выжигание огненно-оранжевое. Wallow (HsFx-52) снят — не понравился; смотрел и отверг: Anub'Rekhan (без жетона только дым), Broodqueen Sha'kar, Kerrigan, Renferal, Omen |
| Death Tyrant (48713) | Shadowcrafter Scabbs (TB_World007) | `AVFX_ShadowcrafterScabbs_CustomSummon_Super.prefab` (спелл `..._Spell`) | СДЕЛАНО (HsFx-55); владелец выбрал сам из HsBrowser (2026-10-27): чёрный дым, алая лента влетает сверху, взрыв чёрного дыма — на тёмной доске тихо, владелец берёт всё равно; тень портрета героя спрятана; выжигание алое. G'huun (HsFx-53) снят — не понравился; смотрел и отверг: C'Thun the Shattered, C'Thun Eye of the Empire, Kel'Thuzad, Bonelord Frostwhisper |
| Beholder (48715) | Staff of the Endbringer (TLC_EVENT_402) | `TLCFX_StaffEndbringer_CustomSummon.prefab` | СДЕЛАНО (HsFx-69..75; владелец выбрал в HsBrowser 2026-10-27 вместо Iso'rath (тот уходит к Roper)); зелёно-фиолетовый вихрь, сфера-око; выжигание синее |

### undead

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Статус |
|---|---|---|---|
| Death Knight (48721) | Eliza Goreblade (VAC_426) | `VAC_ElizaGoreBlade_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |
| Mummy Lord (48725) | Nexus-Prince Shaffar (GDB_143) | `10_GDBFX_NexusPrinceShaffar_CustomSummon.prefab` | СДЕЛАНО (HsFx-106; владелец выбрал в HsBrowser 2026-11-23); эффект Nexus-Prince Shaffar; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Vampire (48728) | Tichondrius (CORE_CATA_001) | `CORE_CATAFX_Tichondrius_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Lich (48732) | Broxigar (TIME_020) | `TIME_020_Broxigar_Fab_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| High Priest of Myrkul (48733) | Soulburner Varia (YOG_520) | `YOGFX_SoulburnerVaria_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |
| Revenant (48738) | Sylvanas, the Accused (CORE_MAW_033) | `MAWFX_SylvanasTheAccused_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |

### celestial

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Статус |
|---|---|---|---|
| Sphinx of Valor (49003) | Genn, Worgen King (CATA_615t) | `CATAFX_GennWorgenKing_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Deva (49004) | Sunsapper Lynessa (VAC_507) | `VACFX_SunsapperLynessa_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Solar (49015) | Medivh the Hallowed (TIME_890) | `TIMEFX_MedivhtheHallowed_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Sphinx of Secrets (49016) | Kologarn (TTN_330) | `07_TTNFX_Kologarn_CustomSummon.prefab` | СДЕЛАНО (HsFx-110; владелец выбрал в HsBrowser 2026-11-24); эффект Kologarn; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Warrior Veteran (49017) | Commander Beatrix (JAIL_397) | `JAIL_397_HighCommanderBeatrix_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Archaic (49018) | Thorim, Stormlord (TTN_835) | `06_TTNFX_ThorimStormlord_CustomSummon.prefab` | СДЕЛАНО (HsFx-107; владелец выбрал в HsBrowser 2026-11-24); эффект Thorim, Stormlord; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Scout (49019) | Tyrande (EDR_464) | `EDRFX_Tyrande_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Empyrean (49020) | Lumia (GDB_144) | `06_GDB_144_Lumia_CustomSummon.prefab` | СДЕЛАНО (HsFx-109; владелец выбрал в HsBrowser 2026-11-23); эффект Lumia; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Archon of Boundaries (49021) | Ebyssian (CATA_553t) | `09_CATAFX_533t_Ebyssian_CustomSummon.prefab` | СДЕЛАНО (HsFx-108; владелец выбрал в HsBrowser 2026-11-23); эффект Ebyssian; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Adult Gold Dragon (49022) | Ursol (EDR_259) | `EDRFX_Ursol_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |

### shadow

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Статус |
|---|---|---|---|
| Dracolich (49113) | Azure Queen Sindragosa (TIME_852) | `TIMEFX_AzureQueenSindragosa_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |
| Nightmare (49114) | Thunderbringer (WW_440) | `WWFX_Thunderbringer_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Ramya Vasavadan (49115) | Tenwu of the Red Smoke (DMF_071) | `09_DMF_TenwuOfTheRedSmoke_CustomSummon.prefab` | СДЕЛАНО (HsFx-112; владелец выбрал в HsBrowser 2026-11-23); эффект Tenwu of the Red Smoke; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Saidra d'Honaire (49116) | Godfrey the Betrayer (JAIL_509) | `10_JAILFX_Godfrey_CustomSummon.prefab` | СДЕЛАНО (HsFx-113; владелец выбрал в HsBrowser 2026-11-23); эффект Godfrey the Betrayer; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Ghast (49117) | Blood Doctor Thal'ena (JAIL_446) | `JAIL_446_BloodDoctorThal_ena_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Strahd von Zarovich (49118) | Sire Denathrius (REV_906t) | `REVFX_SireDenathrius_Infused_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |
| Dullahan (49119) | Vexallus (RLK_541) | `05_RLKFX_Vexallus_CustomSummon.prefab` | СДЕЛАНО (HsFx-111; владелец выбрал в HsBrowser 2026-11-24); эффект Vexallus; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Drider (49120) | Blightfang (RLK_225) | `RLK_225_BlightFang_Spawn.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Azalin Rex (49121) | The Jailer (CORE_MAW_034) | `MAWFX_TheJailer_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |
| Ankhtepot (49122) | Chrono-Lord Epoch (TIME_714) | `TIMEFX_ChronoLordEpoch_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |

### piltover

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Статус |
|---|---|---|---|
| Stone Golem (49211) | Chronogor (TIME_032) | `TIMEFX_Chronogor_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Koboldzilla (49212) | Aya, Lotus Kingpin (JAIL_504) | `JAILFX_AyaLotusKingpin_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |
| Iron Golem (49213) | Mathias Shaw (CAP_005) | `CAP_005_MathiasShaw_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Ivan Dilisnya (49214) | Kazakus, Golem Shaper (BAR_079) | `09_BARFX_KazakusGolemShaper_CustomSummon.prefab` | СДЕЛАНО (HsFx-114; владелец выбрал в HsBrowser 2026-11-24); эффект Kazakus, Golem Shaper; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Homunculus (49215) | Norgannon (TTN_075) | `TTNFX_Norgannon_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Chimera (49216) | Dave Berard (CRED_215) | `AVFX_BrukanElements_CustomSummon_Super.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| Manshoon (49217) | Xor'toth, Breaker of Stars (GDB_118) | `10_GDBFX_Xortoth_CustomSummon.prefab` | СДЕЛАНО (HsFx-115; владелец выбрал в HsBrowser 2026-11-24); эффект Xor'toth, Breaker of Stars; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Shield Guardian (49218) | Omen (EDR_421) | `EDRFX_Omen_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Behir (49219) | Mastermind Yogg-Saron (BE_009) | `BEFX_YoggSarontheMastermind_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Trobriand (49220) | Endtime Murozond (END_037) | `ENDFX_EndtimeMurozond_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |

### siege

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Статус |
|---|---|---|---|
| Avatar of Lolth (49300) | Chillin' Vol'jin (VAC_957) | `VACFX_ChillinVoljin_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Converter (49301) | Morchie (END_036) | `ENDFX_Morchie_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Relentless Siege (49302) | Darkbishop Benedictus (CORE_SW_448) | `SWFX_DarkBishopBenedictus_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): клип восстановлен из Git, показ актуальной миниатюры |
| Beast Tamer (49303) | Exarch Maladaar (GDB_470) | `08_GDBFX_ExarchMaladaar_CustomSummon.prefab` | СДЕЛАНО (HsFx-116; владелец выбрал в HsBrowser 2026-11-24); эффект Exarch Maladaar; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Warlord (49304) | Remornia, Living Blade (CORE_REV_316) | `REVFX_RemorniaLivingBlade_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Siege Beast (49305) | Bonelord Frostwhisper (RLK_591) | `RLKFX_BonelordFrostwhisper_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |

### mercenaries

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Статус |
|---|---|---|---|
| Artemis Entreri (49402) | Lady Darkvein (CORE_REV_373) | `REVFX_LadyDarkvein_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Nihiloor (49407) | Karov the Broken (JAIL_448) | `JAIL_448_KarovTheBroken_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Nar'l Xibrindas (49412) | Staff of Trickery (JAIL_875) | `JAILFX_StaffofTrickery_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Jarlaxle (49413) | Altruis the Outcast (TOY_401t2) | `Altruis_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |
| Sylgar (49416) | Drest'agath (BE_703) | `BE_703_Drestagath_CustomSummon_FX.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Ahmaergo (49417) | Lo'Gosh, Blood Fighter (TIME_850) | `TIME_LoGosh_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |
| Xanathar Zushaxx (49418) | N'Zoth, Dream's End (BE_017) | `BE_017_NzothDreamsEnd_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |

### noxus

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Статус |
|---|---|---|---|
| Arcanaloth (49513) | Archmage Kalec (CATA_458) | `07_CATA_ArchmageKalec_CustomSummon.prefab` | СДЕЛАНО (HsFx-117; владелец выбрал в HsBrowser 2026-11-23); эффект Archmage Kalec; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Lamia (49514) | Amitut, Keeper of Amitus (BE_143) | `BE_143_Amitut_Keeper_CustomSummon_FX.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Horned Devil (49515) | Arch-Villain Rafaam (CORE_DAL_422) | `ArchVillianRafaam_CustomSummon.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| Bone Devil (49516) | G'huun (BE_287) | `BE_287_GhuunTheCataStrophic_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Barbed Devil (49517) | Wrathion (Story_06_Wrathion) | `Wrathion_CustomSummon.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| Ice Devil (49518) | Moroes (KAR_044) | `Moroes_CustomSummon.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| Sewer King (49519) | Uluu, the Everdrifter (GDB_854) | `06_GDBFX_UluuTheEverdrifter_CustomSummon.prefab` | СДЕЛАНО (HsFx-118; владелец выбрал в HsBrowser 2026-11-24); эффект Uluu, the Everdrifter; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Daemogoth Titan (49520) | Blood-Queen Lana'thel (CORE_ICC_841) | `BloodQueenLanathel_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |
| Erinyes (49521) | Fyrakk the Blazing (FIR_959) | `FIRFX_FyrakkTheBlazing_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Wyvern (49522) | Captain Crowley (CAP_106) | `CAPFX_CaptainCrowley_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |

### freljord

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Статус |
|---|---|---|---|
| Doomwake Giant (49613) | Overlord Drakuru (RLK_913) | `RLKFX_Drakuru_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |
| Hill Giant (49614) | Bearon Gla'shear (AV_257) | `AVFX_BearonGlashear_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Cloud Giant (49615) | Hodir, Father of Giants (TTN_752) | `TTNFX_HodirFatherGiants_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Remorhaz (49616) | Ras Frostwhisper (SCH_273) | `SCHFX_RasFrostwhisperer_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Mammoth (49617) | Kel'Thuzad (FP1_013) | `Kelthuzad_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |
| Storm Giant (49618) | Thaddius, Monstrosity (NX2_033) | `NX2FX_ThaddiusFleshTitan_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Frost Giant (49620) | The Lich King (CORE_ICC_314) | `LichKing_CustomSummon.prefab` | СДЕЛАНО (HsFx-78; владелец выбрал в HsBrowser 2026-10-27) |
| Oni (49634) | Irida Sinseeker (JAIL_719) | `JAIL_719_IridaSinseeker_CustomSummon_FX.prefab` | СДЕЛАНО (HsFx-76; владелец выбрал в HsBrowser 2026-10-27; готовый эффект другой карты перепечён с контуром этой) |
| Blink Dog (49635) | Zer'Ontu (BE_790) | `BE_790_ZerOntu_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Fire Giant (49636) | Neeru Fireblade (LETL_823H) | `BARFX_NeeruFireblade_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |

### shurima

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Статус |
|---|---|---|---|
| Marid (49711) | Ozumat (TID_711) | `07_TIDFX_Ozumat_CustomSummon.prefab` | СДЕЛАНО (HsFx-120; владелец выбрал в HsBrowser 2026-11-24); эффект Ozumat; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Nafas (49712) | Titanographer Osk (TLC_452t35) | `TLCFX_Titangrapher_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Purple Worm (49713) | Arisen Onyxia (CATA_155) | `CATA_155_ArisenOnyxia_Fab_CustomSummon_FX.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Abveku (49714) | Ultraxion (CATA_497) | `CATAFX_Ultraxion_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |
| Efreeti (49715) | Kael'thas Sunstrider (BT_255) | `KaelthasSunstrider_CustomSummon.prefab` | СДЕЛАНО (HsFx-76; владелец выбрал в HsBrowser 2026-10-27; готовый эффект другой карты перепечён с контуром этой) |
| Djinni (49716) | Velen, Leader of the Exiled (GDB_131) | `GDBFX_VelenLeader_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Gorgon (49717) | The Eternal Hold (TIME_446) | `TIME_EternalHold_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |
| Ankheg (49718) | Gorm the Worldeater (GDB_842) | `GDBFX_GormtheWorldeater_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Dust Mephit (49719) | Time Adm'ral Hooktail (TIME_713) | `TIMEFX_Timecap_nHooktail_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Dao (49720) | Chrono-Lord Deios (TIME_064) | `05_TIMEFX_ChronoLordDeios_CustomSummon.prefab` | СДЕЛАНО (HsFx-119; владелец выбрал в HsBrowser 2026-10-27); эффект Chrono-Lord Deios; жетон HS спрятан сетками; выжигание в цвет эффекта |

### ionia

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Статус |
|---|---|---|---|
| Biha Babir (49800) | Aranna, Thrill Seeker (VAC_501) | `VACFX_ArannatheExtreme_CustomSummon.prefab` | СДЕЛАНО (HsFx-77; владелец выбрал в HsBrowser 2026-10-27) |
| Ancient of War (49801) | Chronikar (END_006) | `ENDFX_Chronikar_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |
| Elemental Cataclysm (49803) | Mug'Zee (JAIL_800) | `JAILFX_MugZee_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |
| Chwinga (49806) | Baroness Vashj (REV_788) | `REVFX_BaronessVashj_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Groff (49807) | Ulfar (CORE_CATA_006) | `09_CORE_CATA_006_Ulfar_CustomSummon.prefab` | СДЕЛАНО (HsFx-121; владелец выбрал в HsBrowser 2026-11-23); эффект Ulfar; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Zaratan (49811) | Anachronos (CORE_RLK_919) | `RLKFX_Anachronos_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |
| Leviathan (49815) | Overseer Frigidara (LEG_RLK_224) | `RLKFX_Frigidara_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |
| Spore of Moander (49820) | The Living Plague (JAIL_443) | `06_JAIL_443_TheLivingPlague_CustomSummon.prefab` | СДЕЛАНО (HsFx-122; владелец выбрал в HsBrowser 2026-11-24); эффект The Living Plague; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Ivana Boritsi (49821) | Archwitch Willow (CORE_SCH_181) | `SCHFX_ArchwitchWillow_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |
| Galeb Duhr (49822) | Krog, Crater King (TLC_480) | `TLCFX_KrogCraterKing_Custom_Summon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |

### bandle

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Статус |
|---|---|---|---|
| Mother Lorinda (49900) | Jace Darkweaver (SW_044) | `SWFX_JaceDarkweaver_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |
| Yarnspinner (49901) | Elder Nadox (RLK_658) | `06_RLKFX_ElderNadox_CustomSummon.prefab` | СДЕЛАНО (HsFx-125; владелец выбрал в HsBrowser 2026-11-23); эффект Elder Nadox; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Incarnation of Transience (49902) | Morchok (CATA_570) | `07_CATAFX_Morchok_CustomSummon.prefab` | СДЕЛАНО (HsFx-123; владелец выбрал в HsBrowser 2026-11-24); эффект Morchok; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Trostani (49903) | Argus, the Emerald Star (TTN_862) | `TTNFX_ArgusTheEmeraldStar_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |
| Swanmay (49904) | Prince Malchezaar (LT24_821H) | `Malchezaar_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |
| Lampad (49905) | Sathrovarr (DRG_402) | `10_Sathrovarr_CustomSummon.prefab` | СДЕЛАНО (HsFx-124; владелец выбрал в HsBrowser 2026-11-24); эффект Sathrovarr; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Faerie Dragon Youth (49906) | Eternus (TIME_435) | `TIME_Eternus_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| The Gardener (49908) | Ysera, Emerald Aspect (EDR_000) | `EDRFX_YseraEmeraldAspect_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): клип восстановлен из Git, показ актуальной миниатюры |
| Witchkite (49909) | Nablya, the Watcher (TLC_624) | `TLCFX_NablyatheWatcher_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |

### void

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Статус |
|---|---|---|---|
| Elder Thing (50000) | Cho'gall, Mastermind (CATA_726) | `09_CATAFX_ChogallMastermind_CustomSummon.prefab` | СДЕЛАНО (HsFx-127; владелец выбрал в HsBrowser 2026-11-24); эффект Cho'gall, Mastermind; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Zargon the Returner (50001) | Sargeras, the Destroyer (TTN_960) | `TTNFX_SargerasTheDestroyer_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |
| Froghemoth Elder (50002) | The Exodar (GDB_120) | `GDBFX_TheExodar_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Feyr (50003) | Iso'rath (CATA_481) | `CATAFX_Iso'rath_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |
| Cthulhu (50004) | Malygos the Spellweaver (LEG_CS3_034) | `06_EX1FX_Malygos_CustomSummon.prefab` | СДЕЛАНО (HsFx-126; владелец выбрал в HsBrowser 2026-11-24); эффект Malygos the Spellweaver; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Shoggoth (50005) | Galakrond, Azeroth's End (DRG_660t3) | `07_Hero_Galakrond_Priest_CustomSummon_FX.prefab` | СДЕЛАНО (HsFx-129; владелец выбрал в HsBrowser 2026-11-23); эффект Galakrond, Azeroth's End; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Qunbraxel (50006) | Tras'tath, Soul Parasite (JAIL_721) | `10_JAIL_721_TrastathSoulParasite_CustomSummon.prefab` | СДЕЛАНО (HsFx-128; владелец выбрал в HsBrowser 2026-11-23); эффект Tras'tath, Soul Parasite; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Hazlik (50007) | Nozdormu, Bronze Aspect (CATA_473) | `CATAFX_NozdormuBronzeAspect_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |
| Eye Monger (50008) | The 8 Hands From Beyond (GDB_477) | `GDBFX_8HandsFromBeyond_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |

### ixtal

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Статус |
|---|---|---|---|
| Hythonia (50100) | Razidir (TLC_463) | `TLC463_Nazidir_CustomSummon.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |
| Displacer Beast (50101) | Beaststalker Tavish (AV_113) | `AVFX_TavishBeastStalker_CustomSummon_Super.prefab` | СДЕЛАНО (HsFx-101): сохранённый клип с актуальной миниатюрой |
| Sarrukh Tyrant (50102) | Timethief Rafaam (TIME_005) | `TIMEFX_TimetheifRafaam_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Ironscale Hydra (50103) | Dirdra, Rebel Captain (GDB_117) | `09_GCBFX_Dirada_CustomSummon.prefab` | СДЕЛАНО (HsFx-130; владелец выбрал в HsBrowser 2026-11-24); эффект Dirdra, Rebel Captain; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Tarrasque (50104) | Maruut Stonebinder (DEEP_037) | `DEEPFX_MaruutStonebinder_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Troglodyte (50105) | The Unknowable One (BE_725) | `BEFX_UnknowableOne_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |
| Snapping Hydra (50106) | Kingsbane (LOOT_542) | `02_Kingsbane_CustomSpawn.prefab` | СДЕЛАНО (HsFx-132; владелец выбрал в HsBrowser 2026-11-24); эффект Kingsbane; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Kraken (50107) | Golganneth, the Thunderer (TTN_800) | `10_TTNFX_Golganneth_CustomSummon.prefab` | СДЕЛАНО (HsFx-131; владелец выбрал в HsBrowser 2026-11-24); эффект Golganneth, the Thunderer; жетон HS спрятан сетками; выжигание в цвет эффекта |
| Troll (50108) | Shudderblock (TOY_501t) | `TOYFX_Shudderblock_CustomSummon.prefab` | СДЕЛАНО (HsFx-79; владелец выбрал в HsBrowser 2026-10-27) |

## Освобождённые эффекты

У этих карт несколько копий. Рецепты и запечённые кадры снятых эффектов сохранены для повторного использования.

| Карта | Полуколода | Копий | Легендарка HS (id) | Префаб эффекта | Прежний статус |
|---|---|---|---|---|---|
| Shadow | shadow | 3 | The Jailer (CORE_MAW_034) | `MAWFX_TheJailer_CustomSummon.prefab` | Был в игре |
| Stone Giant | freljord | 3 | Toy Captain Tarim (TOY_813t) | `TOYFX_ToyCaptainTarim_CustomSummon.prefab` | Был в игре |
| Berserker Commander | freljord | 2 | Korrak the Bloodrager (AV_143) | `AVFX_Korrak_CustomSummon.prefab` | Был предложен |
| Assassin | shurima | 3 | Garona Halforcen (TIME_875) | `TIME_875_Garona_CustomSummon.prefab` | Был в игре |
| Green Hag | bandle | 2 | Jace Darkweaver (SW_044) | `SWFX_JaceDarkweaver_CustomSummon.prefab` | Был в игре |
| Red Slaad | void | 3 | Blood-Queen Lana'thel (CORE_ICC_841) | `BloodQueenLanathel_CustomSummon.prefab` | Был в игре |
| Githyanki Knight | void | 2 | Lothraxion the Redeemed (DMF_240) | `DMFFX_Lothraxion_CustomSummon.prefab` | Был предложен |

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

### Прежние назначения заменённых существ

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Статус |
|---|---|---|---|
| ~~Silver Dragon~~ (—, существо убрано из игры NE-38; на 49020 теперь другое существо) | Azure Queen Sindragosa (TIME_852) | `TIMEFX_AzureQueenSindragosa_CustomSummon.prefab` | анимация свободна |
| ~~Rakshasa~~ (—, существо убрано из игры NE-37; на 49113/49115/49118 теперь Strahd / Relentless Slasher / Zombie Plague Spreader) | Argus, the Emerald Star (TTN_862) | `TTNFX_ArgusTheEmeraldStar_CustomSummon.prefab` | анимация свободна |
| ~~Chain Devil~~ (—, существо убрано из игры NE-42; на 49513 теперь Arcanaloth) | Cho'gall, Twilight Chieftain (YOG_530) | `YOGFX_Cho'gallTwilightChieftain_CustomSummon.prefab` | анимация свободна (кадры chogall запечены) |
| ~~Manticore~~ (—, существо убрано из игры NE-49; на 49214 теперь Ivan Dilisnya) | Lo'Gosh, Blood Fighter (TIME_850) | `TIME_LoGosh_CustomSummon.prefab` | анимация свободна |
| ~~Basilisk~~ (—, существо убрано из игры NE-37; на 49113/49115/49118 теперь Strahd / Relentless Slasher / Zombie Plague Spreader) | Overseer Frigidara (LEG_RLK_224) | `RLKFX_Frigidara_CustomSummon.prefab` | анимация свободна |
| ~~Weretiger~~ (—, существо убрано из игры NE-37; на 49113/49115/49118 теперь Strahd / Relentless Slasher / Zombie Plague Spreader) | Beaststalker Tavish (AV_113) | `AVFX_TavishBeastStalker_CustomSummon_Super.prefab` | анимация свободна |
| ~~Half-Dragon~~ (—, существо убрано из игры NE-39; на 49018 теперь другое существо) | Sire Denathrius (REV_906t) | `REVFX_SireDenathrius_Infused_CustomSummon.prefab` | анимация свободна |
| ~~Pirate Captain~~ (—, существо убрано из игры NE-50; на 49714 теперь Abveku) | Eliza Goreblade (VAC_426) | `VAC_ElizaGoreBlade_CustomSummon.prefab` | анимация свободна |
| ~~Young White Dragon~~ (—, существо убрано из игры NE-38; на 49014 теперь другое существо) | Bonelord Frostwhisper (RLK_591) | `RLKFX_BonelordFrostwhisper_CustomSummon.prefab` | анимация свободна |
| ~~Roper~~ (—, существо убрано из игры NE-50; на 49711 теперь Marid) | Iso'rath (CATA_481) | `CATAFX_Iso'rath_CustomSummon.prefab` | анимация свободна |
| ~~Ancient Brass Dragon~~ (—, существо убрано из игры NE-38; на 49016 теперь другое существо) | Mister Clocksworth (TIME_038t3) | `TIMEFX_MisterClocksWorth_CustomSummon.prefab` | анимация свободна |
| ~~Adult Brass Dragon~~ (—, существо убрано из игры NE-38; на 49021 теперь другое существо) | Anachronos (CORE_RLK_919) | `RLKFX_Anachronos_CustomSummon.prefab` | анимация свободна |
| ~~Satyr Thornbearer~~ (—, существо убрано из игры NE-45; на 49900 теперь Green Hag) | Nightmare Lord Xavius (EDR_856) | `EDRFX_Xavius_CustomSummon.prefab` | анимация свободна |
| ~~High Fae Kindguard~~ (—, существо убрано из игры NE-45; на 49901 теперь Yarnspinner) | Prince Malchezaar (LT24_821H) | `Malchezaar_CustomSummon.prefab` | анимация свободна |
| ~~High Fae Noble~~ (—, существо убрано из игры NE-45; на 49902 теперь Incarnation of Transience) | Glugg the Gulper (TSC_639) | `TSCFX_GluggTheGulper_CustomSummon.prefab` | анимация свободна |
| ~~Faerie Pathlighter~~ (—, существо убрано из игры NE-45; на 49905 теперь Lampad) | Soulburner Varia (YOG_520) | `YOGFX_SoulburnerVaria_CustomSummon.prefab` | анимация свободна |
| ~~Witherbloom Apprentice~~ (—, существо убрано из игры NE-45; на 49908 теперь The Gardener) | Altruis the Outcast (TOY_401t2) | `Altruis_CustomSummon.prefab` | анимация свободна |
