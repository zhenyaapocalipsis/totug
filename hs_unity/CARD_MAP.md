# Подбор анимаций Hearthstone для уникальных карт

150 уникальных карт проекта (по одной копии в полуколоде, `data/cards/half_decks.json`) и
для каждой — легендарка Hearthstone, чей эффект розыгрыша (CustomSummon) берём за основу.
Подбор по смыслу и виду (дракон — драконом, нежить — нежитью, море — морским, огонь —
огнём), без повторов: у всех 150 разные легендарки и разные префабы эффектов. Все есть в
файлах игры (`data/hs_legendary_summons.tsv`). Как делать — `GUIDE.md`.

Это черновик для владельца: любую строку можно заменить. Перед работой над картой:
`hsx extract` по id из таблицы, посмотреть эффект (пробные кадры), убедиться, что он
подходит смыслу карты (кто источник, кто цель) и не повторяет макет HS (герой, рамка).
Названия полуколод — внутренние (`drow`, `noxus` = Avernus, `freljord` = Icewind,
`shurima` = Calimshan, `ionia` = Kara-Tur, `piltover` = Waterdeep, `shadow` = Ravenloft,
`bandle` = Feywild, `void` = Far Realm, `ixtal` = Chult).

Готово: Red Dragon (Deathwing, Worldbreaker), Black Dragon (Onyxia the Broodmother), Blue Dragon (Malygos), Green Dragon (Ysera). Остальные — по очереди, по слову владельца.

### drow

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Council Member (48315) | Lady Prestor (SW_078) | `SWFX_LadyPrestor_CustomSummon.prefab` | интриганка при дворе, тайно дракон — политика и влияние |
| Deathblade (48316) | Valeera the Hollow (ICC_827) | `DK_Valeera_CustomSummon_FX.prefab` | убийца-разбойница из теней |
| Inquisitor (48325) | High Inquisitor Whitemane (EX1_190) | `HighInquisitorWhitemane_CustomSummon.prefab` | инквизитор, суд и казнь |
| Masters of Sorcere (48328) | Kael'thas Sunstrider (BT_255) | `KaelthasSunstrider_CustomSummon.prefab` | верховный маг-эльф, магическая школа |
| Matron Mother (48329) | Queen Azshara (TSC_641) | `TSCFX_Azshara_CustomSummon.prefab` | властная королева-матриарх |
| Weaponmaster (48339) | Blademaster Samuro (BAR_078) | `BARFX_Samuro_CustomSummon.prefab` | мастер клинка |

### dragons

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Black Dragon (48400) | Onyxia the Broodmother (CS3_032) | `ds1FX_Onyxia_CustomSummon.prefab` | СДЕЛАНО (HsFx-14) |
| Blue Dragon (48403) | Malygos, Aspect of Magic (DRG_270) | `MalygosAspectOfMagic_CustomSummon.prefab` | СДЕЛАНО (HsFx-16) |
| Green Dragon (48419) | Ysera, Emerald Aspect (EDR_000) | `EDRFX_YseraEmeraldAspect_CustomSummon.prefab` | СДЕЛАНО (HsFx-18) |
| Rath Modar (48425) | Rhonin (AT_009) | `Rhonin_CustomSpawn.prefab` | красный волшебник |
| Red Dragon (48426) | Deathwing, Worldbreaker (CATA_190h) | `CATAFX_Deathwing_CustomSummon_Super.prefab` | СДЕЛАНО (HsFx-1..12) |
| Severin Silrajin (48429) | Cho'gall, Twilight Chieftain (YOG_530) | `YOGFX_Cho'gallTwilightChieftain_CustomSummon.prefab` | глава культа драконов, тёмный культист |
| White Dragon (48433) | Frost Queen Sindragosa (NX2_037) | `NX2FX_FrostQueenSindragosa_CustomSummon.prefab` | белая (ледяная) драконица |

### demons

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Balor (48500) | Magtheridon (BT_850) | `Magtheridon_CustomSummon.prefab` | огненный повелитель демонов с плетью |
| Demogorgon (48501) | Kil'jaeden (GDB_145) | `GDBFX_Kiljaeden_CustomSummon.prefab` | принц демонов, разлом и вторжение |
| Glabrezu (48513) | Fel Lord Betrug (DAL_607) | `FelLordBetrug_CustomSummon.prefab` | демон-громила |
| Graz'zt (48514) | Prince Malchezaar (KAR_096) | `Malchezaar_CustomSummon.prefab` | обольстительный принц демонов |
| Orcus (48535) | Archimonde (GDB_128) | `GDBFX_Archimonde_CustomSummon.prefab` | принц демонов, смерть и разрушение |
| Vrock (48538) | Anetheron (SW_092) | `SWFX_Anetheron_CustomSummon.prefab` | демон, налетающий стаей |
| Zuggtmoy (48539) | Spore Empress Moldara (GDB_234) | `GDBFX_SporeEmpressMoldara_CustomSummon.prefab` | королева грибов и спор |

### elementals

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Aerisi Kalinoth (48600) | Ysiel Windsinger (BT_131) | `YsielWindsinger_CustomSummon.prefab` | пророчица ветра |
| Gar Shatterkeel (48626) | Lady Naz'jar (TID_709) | `TIDFX_LadyNazjar_CustomSummon.prefab` | пророк воды, морская буря |
| Imix (48629) | Ragnaros the Firelord (EX1_298) | `Ragnaros_CustomSummon.prefab` | принц огня |
| Marlos Urnrayle (48630) | Lady S'theno (TSC_218) | `TSCFX_LadyStheno_CustomSummon.prefab` | медуза-змея, окаменение |
| Ogrémoch (48631) | Therazane the Earthmother (BE_337) | `BEFX_TherazaneEarthMother_CustomSummon.prefab` | принц земли |
| Olhydra (48632) | Neptulon the Tidehunter (TID_712) | `TIDFX_NeptulonTidehunter_CustomSummon.prefab` | принцесса воды, прилив |
| Vanifer (48633) | Neeru Fireblade (BAR_919) | `BARFX_NeeruFireblade_CustomSummon.prefab` | огненная жрица |
| Yan-C-Bin (48639) | Al'Akir the Windlord (NEW1_010) | `AlAkir_CustomSummon.prefab` | принц воздуха |

### aberrations

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Elder Brain (48700) | N'Zoth, God of the Deep (DMF_002) | `DMFFX_NZothGodofTheDeep_CustomSummon.prefab` | древний разум из глубин |
| Ulitharid (48701) | Mindflayer Kaahrj (DRG_308) | `MindflayerKaahrj_CustomSummon.prefab` | иллитид, пожиратель разума |
| Aboleth (48705) | Soggoth the Slitherer (OG_340) | `Soggoth_CustomSummon.prefab` | древнее существо с щупальцами из воды |
| Neogi (48710) | Anub'Rekhan (RLK_659) | `RLKFX_AnubRekhan_CustomSummon.prefab` | паукообразный рабовладелец |
| Death Tyrant (48713) | C'Thun, the Shattered (DMF_254) | `DMFFX_CthunTheShattered_CustomSummon.prefab` | мёртвый бехолдер — разбитый глаз |
| Beholder (48715) | Iso'rath (CATA_481) | `CATAFX_Iso'rath_CustomSummon.prefab` | бехолдер — гигантский глаз-пожиратель |

### undead

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Death Knight (48721) | The Lich King (ICC_314) | `LichKing_CustomSummon.prefab` | рыцарь смерти |
| Mummy Lord (48725) | Dark Pharaoh Tekahn (ULD_168) | `DarkPharaohTekahn_CustomSummon.prefab` | владыка-мумия |
| Vampire (48728) | Blood-Queen Lana'thel (ICC_841) | `BloodQueenLanathel_CustomSummon.prefab` | вампир |
| Lich (48732) | Kel'Thuzad, the Inevitable (REV_514) | `REVFX_KelThuzadTheInevitable_CustomSummon.prefab` | лич |
| High Priest of Myrkul (48733) | Bwonsamdi, the Dead (TRL_260) | `Bwonsamdi_CustomSummon.prefab` | жрец бога смерти |
| Revenant (48738) | Sylvanas, the Accused (MAW_033) | `MAWFX_SylvanasTheAccused_CustomSummon.prefab` | мститель, восставший из мёртвых |

### celestial

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Sphinx of Valor (49003) | King Phaoris (ULD_304) | `KingPharois_CustomSummon.prefab` | сфинкс, древний царь пустыни |
| Djinni (49004) | Zephrys the Great (ULD_003) | `Zephrys_CustomSummon.prefab` | джинн |
| Solar (49015) | Ragnaros, Lightlord (OG_229) | `RagnarosLightlord_CustomSummon.prefab` | ангел света и пламени |
| Erinyes (49016) | Aggramar, the Avenger (TTN_092) | `TTNFX_AggramarTheAvenger_CustomSummon.prefab` | крылатая мстительница |
| Warrior Veteran (49017) | Varian, King of Stormwind (SW_081) | `SWFX_KingVarian_CustomSummon.prefab` | воин-ветеран |
| Berserker (49018) | Korrak the Bloodrager (AV_143) | `AVFX_Korrak_CustomSummon.prefab` | берсерк |
| Scout (49019) | Vereesa Windrunner (DAL_379) | `VereesaWindrunner_CustomSummon.prefab` | разведчица-лучница |
| Silver Dragon (49020) | Alexstrasza, Guardian of Life (CATA_307) | `CATAFX_AlexstraszaGaurdianofLife_CustomSummon.prefab` | добрая драконица-хранительница |
| Shield Guardian (49021) | Kologarn (TTN_330) | `TTNFX_Kologarn_CustomSummon.prefab` | каменный страж-голем |
| Gold Dragon (49022) | Nozdormu the Timeless (DRG_309) | `NozdormuTheTimeless_CustomSummon.prefab` | золотой дракон |

### shadow

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Rakshasa (49113) | Shirvallah, the Tiger (TRL_300) | `Shirvallah_CustomSummon.prefab` | демон-тигр |
| Nightmare (49114) | The Headless Horseman (TOY_829) | `TOYFX_HeadlessHorseman_CustomSummon_Super.prefab` | огненный конь кошмаров |
| Chain Devil (49115) | Raza the Chained (CFM_020) | `Raza_CustomSummon.prefab` | дьявол в цепях |
| Barbed Devil (49116) | Kurtrus Ashfallen (BAR_333) | `BARFX_Kurtrus_CustomSummon.prefab` | колючий дьявол, клинки |
| Ghast (49117) | Rotface (ICC_405) | `RotFace_CustomSummon.prefab` | гниющий упырь |
| Treant (49118) | Greybough (DMF_734) | `DMFFX_GreyBough_CustomSummon.prefab` | ожившее дерево |
| Bone Devil (49119) | Lord Marrowgar (RLK_085) | `RLKFX_LordMarrowgar_CustomSummon.prefab` | костяной дьявол |
| Drider (49120) | Hadronox (ICC_835) | `Hadronox_CustomSummon.prefab` | паук-дроу |
| Green Hag (49121) | Hagatha the Witch (GIL_504) | `Hagatha_CustomSummon_FX.prefab` | болотная ведьма |
| Shadow (49122) | Teron Gorefiend (BT_126) | `TeronGorefiend_CustomSummon.prefab` | живая тень |

### piltover

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Stone Golem (49211) | The Stonewright (REV_921) | `REVFX_TheStonewright_CustomSummon.prefab` | каменный голем |
| Assassin (49212) | Garona Halforcen (TIME_875) | `TIME_875_Garona_CustomSummon.prefab` | наёмная убийца |
| Iron Golem (49213) | Mimiron, the Mastermind (TTN_920) | `ETCFX_MimironTheMastermind_CustomSummon_Friendly.prefab` | железный голем, механизм |
| Manticore (49214) | Zixor, Apex Predator (BT_210) | `Zixor_CustomSummon.prefab` | хищное чудовище |
| Homunculus (49215) | Kazakus, Golem Shaper (BAR_079) | `BARFX_KazakusGolemShaper_CustomSummon.prefab` | алхимическое создание |
| Chimera (49216) | Chromaggus (BRM_031) | `Chromaggus_CustomSummon.prefab` | многоголовое чудовище |
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
| Sylgar (49416) | Sir Finley Mrrgglton (LOE_076) | `SirMrrgglton_CustomSummon.prefab` | рыбка Занатара |
| Ahmaergo (49417) | Brann Bronzebeard (LOE_077) | `Brann_CustomSummon.prefab` | дварф |
| Xanathar Zushaxx (49418) | King of the Underbelly (JAIL_831) | `JAILFX_TunnelKing_CustomSummon.prefab` | бехолдер — король преступного мира |

### noxus

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Weretiger (49513) | Halazzi, the Lynx (TRL_900) | `HalazziTheLynx_CustomSummon.prefab` | оборотень-кошка |
| Lamia (49514) | Lady Anacondra (WC_006) | `BARFX_LadyAnacondra_CustomSummon.prefab` | змеедева |
| Horned Devil (49515) | Lord Jaraxxus (EX1_323) | `EX1_Hero_Jaraxxus_Warlock_CustomSummon_FX.prefab` | рогатый дьявол |
| Efreeti (49516) | Pyros (UNG_027) | `Pyros_CustomSummon.prefab` | огненный джинн |
| Azer Sentinel (49517) | Emperor Thaurissan (BRM_028) | `ThaurissanMinion_CustomSummon.prefab` | огненный дварф |
| Ice Devil (49518) | Ras Frostwhisper (SCH_273) | `SCHFX_RasFrostwhisperer_CustomSummon.prefab` | ледяной дьявол |
| Troll (49519) | Zul'jin (TRL_065) | `ZulJin_CustomSummon_FX.prefab` | тролль |
| Fire Giant (49520) | Magmaw (CATA_550) | `CATAFX_Magmaw_CustomSummon.prefab` | огненный великан, лава |
| Half-Dragon (49521) | Wrathion (CFM_806) | `Wrathion_CustomSummon.prefab` | полудракон |
| Wyvern (49522) | Flightmaster Dungar (SW_079) | `SWFX_FlightmasterDungar_CustomSummon.prefab` | виверна, полёт |

### freljord

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Owlbear (49613) | Ursoc (EDR_819) | `EDRFX_Ursoc_CustomSummon.prefab` | медведь |
| Hill Giant (49614) | Hodir, Father of Giants (TTN_752) | `TTNFX_HodirFatherGiants_CustomSummon.prefab` | великан |
| Cloud Giant (49615) | Aman'Thul (TTN_429) | `TTNFX_Amanthul_CustomSummon.prefab` | небесный великан |
| Remorhaz (49616) | Mutanus the Devourer (WC_030) | `BARFX_MutanusTheDevourer_CustomSummon.prefab` | пожирающий червь |
| Mammoth (49617) | Icehowl (AT_125) | `IceHowl_CustomSpawn.prefab` | ледяной зверь |
| Storm Giant (49618) | Golganneth, the Thunderer (TTN_800) | `TTNFX_Golganneth_CustomSummon.prefab` | великан бури |
| Frost Giant (49620) | Lokholar the Ice Lord (AV_141t) | `AVFX_Lokholar_CustomSummon.prefab` | ледяной великан |
| Pirate Captain (49634) | Captain Hooktusk (TRL_126) | `CaptainHooktusk_CustomSummon.prefab` | капитан пиратов |
| Blink Dog (49635) | Goldrinn (EDR_480) | `EDR_Goldrinn_CustomSummon.prefab` | волшебный пёс-волк |
| Young White Dragon (49636) | Azure Queen Sindragosa (TIME_852) | `TIMEFX_AzureQueenSindragosa_CustomSummon.prefab` | молодая ледяная драконица |

### shurima

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Roper (49711) | Il'gynoth (DMF_230) | `DMFFX_Ilgynoth_CustomSummon.prefab` | чудовище-глаз с щупальцами |
| Ancient Brass Dragon (49712) | Fyrakk the Blazing (FIR_959) | `FIRFX_FyrakkTheBlazing_CustomSummon.prefab` | древний дракон пустыни, пламя |
| Purple Worm (49713) | Gorm the Worldeater (GDB_842) | `GDBFX_GormtheWorldeater_CustomSummon.prefab` | гигантский червь |
| Guardian Naga (49714) | Lady Vashj (BT_109) | `LadyVashj_CustomSummon.prefab` | нага |
| Adult Brass Dragon (49715) | Dragonqueen Alexstrasza (DRG_089) | `DragonqueenAlexstrasza_CustomSummon.prefab` | дракон пустыни |
| Stone Giant (49716) | Ozruk (UNG_907) | `Ozruk_CustomSummon.prefab` | каменный великан |
| Gorgon (49717) | Gorgonzormu (VAC_955) | `VACFX_Gorgonzormu_CustomSummon.prefab` | горгона (по имени; при желании — заменить) |
| Ankheg (49718) | Princess Huhuran (OG_309) | `PrincessHuhuran_CustomSummon.prefab` | гигантское роющее насекомое |
| Dust Mephit (49719) | Raylla, Sand Sculptor (VAC_424) | `VACFX_RayllaSandSculptor_CustomSummon.prefab` | пыльный элементаль |
| Deva (49720) | Lyra the Sunshard (UNG_963) | `Aurelia_CustomSummon.prefab` | ангел-посланник |

### ionia

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Ancient Green Dragon (49800) | Ysera, Unleashed (DRG_320) | `YseraUnleashed_CustomSummon.prefab` | древняя зелёная драконица |
| Oni (49801) | Tenwu of the Red Smoke (DMF_071) | `DMF_TenwuOfTheRedSmoke_CustomSummon.prefab` | демон-огр Востока |
| Ancient Black Dragon (49803) | Deathwing, Mad Aspect (DRG_026) | `DeathwingMadAspect_CustomSummon_GroundBurst.prefab` | древний чёрный дракон |
| Ancient Copper Dragon (49806) | Chromatus (CATA_432) | `CATAFX_Chromatus_CustomSummon.prefab` | древний дракон |
| Ancient Blue Dragon (49807) | Malygos the Spellweaver (CS3_034) | `EX1FX_Malygos_CustomSummon.prefab` | древний синий дракон |
| Tarrasque (49811) | Oondasta (TRL_542) | `Oondasta_CustomSummon.prefab` | непобедимое чудище |
| Ancient Bronze Dragon (49815) | Nozdormu, Bronze Aspect (CATA_473) | `CATAFX_NozdormuBronzeAspect_CustomSummon.prefab` | бронзовый дракон |
| Adult Gold Dragon (49820) | Rheastrasza (WW_824) | `WWFX_Rheastrasza_CustomSummon.prefab` | золотой дракон |
| Ancient Silver Dragon (49821) | Kalecgos (DAL_609) | `Kalecgos_CustomSummon.prefab` | древний серебряный дракон |
| Kraken (49822) | Ozumat (TID_711) | `TIDFX_Ozumat_CustomSummon.prefab` | морское чудище |

### bandle

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Satyr Thornbearer (49900) | Nightmare Lord Xavius (EDR_856) | `EDRFX_Xavius_CustomSummon.prefab` | сатир |
| High Fae Kindguard (49901) | Tyrande (EDR_464) | `EDRFX_Tyrande_CustomSummon.prefab` | страж-эльфийка |
| High Fae Noble (49902) | Sesselie of the Fae Court (REV_319) | `REVFX_SesselieFaeCourt_CustomSummon.prefab` | феи-аристократы |
| Lorehold Apprentice (49903) | Star Student Stelina (SCH_603) | `SCHFX_StarStudentStelina_CustomSummon.prefab` | ученица-маг |
| Silverquill Apprentice (49904) | Inkmaster Solia (CFM_687) | `Irelia_CustomSummon.prefab` | ученица — чернила и слово |
| Faerie Pathlighter (49905) | Kiri, Chosen of Elune (DMF_733) | `DMFFX_KiriChosenofElune_CustomSummon.prefab` | фея-проводник со светом |
| Faerie Dragon Youth (49906) | Ysondre (EDR_465) | `EDRFX_Ysondre_CustomSummon_FIX.prefab` | дракончик фей |
| Witherbloom Apprentice (49908) | Archwitch Willow (SCH_181) | `SCHFX_ArchwitchWillow_CustomSummon.prefab` | ведьма-травница |
| Witchkite (49909) | Glinda Crowskin (GIL_618) | `GlindaCrowskin_CustomSummon.prefab` | ведьма-птица |

### void

| Карта (id) | Легендарка HS (id) | Префаб эффекта | Почему |
|---|---|---|---|
| Githyanki Knight (50000) | Lothraxion the Redeemed (DMF_240) | `DMFFX_Lothraxion_CustomSummon.prefab` | астральный рыцарь |
| Greater Star Spawn Emissary (50001) | Xor'toth, Breaker of Stars (GDB_118) | `GDBFX_Xortoth_CustomSummon.prefab` | порождение звёзд |
| Froghemoth Elder (50002) | Krag'wa, the Frog (TRL_345) | `Kragwa_CustomSummon.prefab` | гигантская лягушка |
| Githzerai Zerth (50003) | Akama (BT_713) | `Akama_CustomSummon.prefab` | монах-аскет |
| Thri-kreen Marauder (50004) | Grand Empress Shek'zara (DMF_516) | `DMFFX_GrandEmpressShakzara_CustomSummon.prefab` | богомол-воин |
| Red Slaad (50005) | Kryxis the Voracious (REV_510) | `REVFX_Kryxis_CustomSummon.prefab` | хаотичный жабий демон |
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
