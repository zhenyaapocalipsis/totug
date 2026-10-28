class_name HsPlay
extends Control

## Розыгрыш карты как в Hearthstone (решения владельца 2026-10-19/20): без витрины и
## без затемнения; нажатую карту рука прячет сразу, и идёт эффект Hearthstone, затем в
## центре доски на секунду проявляется миниатюра карты и гаснет — и только потом игра
## показывает действия карты (released). Действия карты (вытеснение, возврат шпиона, VP)
## тоже играют эффекты HS — на месте цели (action). Всё время розыгрыша, пока карта не
## отыграла все действия, по краям экрана висит дымка эффекта розыгрыша (fog_on/fog_off).
##
## Эффекты — запечённые кадры (assets/hs_fx/baked/<имя>/): Unity рисует оригинальные
## префабы Hearthstone из файлов игры его же шейдерами, частицами и Timeline, с камеры
## доски HS, и пишет кадры 960x540 с premultiplied-альфой (hs_unity, HsRender; рецепт —
## hs_unity/recipes/<имя>.json). Дорожка f### рисуется над картой, u### — под ней
## (подложка и горящий контур появления карты). Текстуры HS под его макет (рамка карты,
## портрет героя) при запекании заменены своими.

## Акт появления закончился, карта погасла: можно показывать действия и вопросы.
signal released
## Сдвиг «камеры» (тряска камеры Hearthstone) в пикселях экрана: доска сдвигается так же,
## как кадры эффектов (BoardPanel.camera_offset); дымка по краям экрана стоит.
signal camera_offset(offset: Vector2)

const BAKED := "res://assets/hs_fx/baked/"
const SOUNDS := "res://assets/hs_fx/"
## Расчётный экран: кадры запечены под него.
const DESIGN := Vector2(960, 540)
## Сколько кадров вперёд подгружать в фоне (кадры идут 60 в секунду, WebP распаковывается
## несколько миллисекунд).
const AHEAD := 12
## Сколько первых кадров должно быть готово до старта часов эффекта.
const WARM := 8
## Пикселей экрана 960x540 на единицу мира HS на уровне доски (камера доски HS: высота
## 19.6, вертикальный угол обзора 34.87).
const PX_PER_UNIT := 44.1

## Карта -> сценарий.
const RECIPES := {"48426": "worldbreaker", "48400": "nefarius", "48403": "murozond", "48419": "yshaarj_lt", "48433": "vyranoth", "48429": "herenn", "48315": "fizzlebang", "48316": "blackempire", "48325": "kara", "48328": "zayle", "48329": "renferal", "48339": "akama", "48500": "ragnaros_gf", "48501": "kiljaeden", "48535": "archimonde", "48539": "moldara", "48514": "umbra", "48538": "nythendra", "48513": "xavius", "48631": "ravitz", "48632": "azshara_ocean", "48626": "mutanus", "48600": "inara", "48630": "yshaarj", "48715": "staff_endbringer", "48701": "azalina", "48700": "kithix", "48705": "blackblood", "48710": "magmaw", "48713": "scabbs", "49516": "kaelthas", "49115": "chogall", "49714": "razidir", "49801": "irida", "49711": "isorath", "48732": "broxigar", "48738": "sylvanastheaccused", "48728": "tichondrius", "49021": "omen", "49020": "azurequeensindrago", "49015": "medivhthehallowed", "49121": "jacedarkweaver", "49114": "thunderbringer", "49416": "drestagath", "49418": "nzothdreamsend", "49635": "zerontu", "49615": "hodirfatherofgiant", "49634": "elizagoreblade", "49636": "bonelordfrostwhisp", "49715": "anachronos", "49712": "misterclocksworth", "49718": "gormtheworldeater", "49720": "sunsapperlynessa", "49719": "timeadmralhooktail", "49716": "toycaptaintarim", "49820": "elisebadlandssavio", "49803": "ayalotuskingpin", "49807": "endtimemurozond", "49815": "nozdormubronzeaspe", "49806": "titanographerosk", "49800": "arannathrillseeker", "49821": "ultraxion", "49620": "thelichking", "49613": "kelthuzad", "49901": "princemalchezaar", "49908": "altruistheoutcast", "50005": "bloodqueenlanathel", "49116": "wrathion", "49518": "moroes", "49515": "archvillainrafaam", "49216": "daveberard", "49513": "beaststalkertavish"}
## Сценарий: frames — папка кадров розыгрыша; sounds — папка звуков; card — появление
## карты в своём размере: face (full — полноформатная, mini — миниатюра; горящий контур
## в кадрах запечён под неё), reveal (секунда), sweep (проявляется снизу вверх), hold
## (стоит), out (гаснет), center (центр на экране 960x540 — центр квада Quad_CardGlow);
## cues — звуки [секунда, файл, громкость 0..1, высота тона (1)]; shakers — тряска камеры HS (дорожка
## CameraShaker2 в Timeline спелла): [с, по, амплитуда (единицы мира HS), кривая силы
## [[доля клипа, сила], ...], интервал смены точки, с]; fog — дымка розыгрыша (FOGS) и
## секунда её появления; actions — эффекты действий карты: событие -> frames, anchor
## (точка удара в кадрах на экране 960x540 — по центру огня в кадрах), follow (xy — кадр сдвигается в точку цели,
## y — только по высоте), cues, shakers, lead (через сколько секунд может начаться
## следующее действие).
const SCRIPTS := {
	# Deathwing, Worldbreaker (CATA_190h): CATAFX_Deathwing_CustomSummon_Spell (тень
	# дракона с огненным шлейфом проносится над доской, пике в центр доски (1.13 с),
	# огненная волна, вспышка, дым, угли) и сразу за ударом CATAFX_Deathwing_Choice_Reveal
	# (одна карта вместо четырёх, с 1.15 с; сама карта — через 0.45 с, WaitToShowCards;
	# огонь появления убран, осталось выжигание — владелец 2026-10-20). Действия карты
	# (вытеснение, возврат шпиона, VP) — обычные анимации игры (владелец 2026-10-21:
	# эффекты Raze/Topple HS убраны); дымка YoggFogg висит до конца розыгрыша карты.
	"worldbreaker": {"frames": "worldbreaker", "sounds": "worldbreaker",
		"card": {"face": "mini", "reveal": 1.6, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# громкости — AudioSource префабов HS; стингеры карт (m_PlayEffectDef) не нужны (владелец)
		"cues": [[0.0, "CATA_190h_Enter_01", 0.7], [0.0, "CATA_190h_Enter_Dragon_01", 0.7], [0.85, "CATA_190h_Enter_02", 0.7],
			[1.0, "CATA_190h_Enter_Dragon_02", 0.7], [1.15, "CATA_190h_CardReveal_01", 0.8]],
		"shakers": [[0.0, 1.133, 0.08, [[0.0, 0.5], [0.3, 0.99], [0.51, 0.23], [1.0, 0.0]], 0.075],
			[1.133, 2.533, 0.12, [[0.0, 0.5], [0.1, 0.99], [0.21, 0.98], [0.67, 0.15], [1.0, 0.0]], 0.075]],
		"fog": ["worldbreaker_fog", 0.1]},
	# Victor Nefarius (CATA_470) — Black Dragon (вместо Onyxia — владелец выбрал в HsBrowser
	# 2026-10-27): CATAFX_VictorNefarius_CustomSummon (Timeline): над точкой посадки клубится
	# зелёная мгла, закручивается зелёно-золотой серп, на 1.2 с вспышка — сфера, угли гаснут.
	# Весь эффект под картой. Выжигание чёрное (владелец 2026-10-24 для Black Dragon).
	"nefarius": {"frames": "nefarius", "sounds": "nefarius",
		"card": {"face": "mini", "reveal": 1.67, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline: AudioSource 0.8 с начала, удар 0.5 с 1.2 с
		"cues": [[0.0, "CATA_470_VictorNefarius_CustomSummon_Sound", 0.8], [1.2, "CATA_470_VictorNefarius_CustomSummon_Impact_Sound", 0.5]],
		# CameraShaker2: дрожь нарастает до удара, в ударе 0.07 и спад
		"shakers": [[0.198, 1.1, 0.05, [[0.0, 0.0], [1.0, 1.0]], 0.075],
			[1.1, 3.15, 0.07, [[0.0, 0.26], [0.13, 0.67], [0.37, 0.11], [0.68, 0.02], [1.0, 0.0]], 0.075]]},
	# Murozond, Unbounded (TIME_024) — Blue Dragon (вместо Malygos — владелец выбрал в
	# HsBrowser 2026-10-27): TIMEFX_MurozondUnbounded_Customsummon (Timeline): синие молнии
	# бьют через весь экран, сходятся в точке посадки, на 1.5 с удар — вспышка, синий шар,
	# руна гаснет. Жетон HS спрятан, весь эффект под картой. Выжигание голубое в цвет молний.
	"murozond": {"frames": "murozond", "sounds": "murozond",
		"card": {"face": "mini", "reveal": 1.97, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline: AudioSource 0.7 с начала, удар 0.7 с 1.5 с
		"cues": [[0.0, "TIMEFX_MurozondUnbounded_Customsummon_Sound", 0.7], [1.5, "TIMEFX_MurozondUnbounded_Customsummon_Impact_Sound", 0.7]],
		# CameraShaker2: молнии нарастают 0.4, спад 0.3, удар 0.2
		"shakers": [[0.0, 0.683, 0.4, [[0.0, 0.0], [1.0, 1.0]], 0.0433], [0.683, 1.133, 0.3, [[0.0, 1.0], [1.0, 0.0]], 0.0329],
			[1.5, 2.283, 0.2, [[0.0, 1.0], [1.0, 0.0]], 0.0314]]},
	# Y'Shaarj (LT23_028H_03, эффект DMFFX_Y_ShaarjDefiler) — Green Dragon (вместо Ysera —
	# владелец выбрал в HsBrowser 2026-10-27): ядовито-зелёная лента порчи прилетает слева
	# снизу (как в HS) и закручивается в воронку у точки посадки, на 1.07 с белая вспышка,
	# зелёное облако и жёлтая клякса порчи. Трещины в земле (`mesh_Cracks*`, макет HS)
	# спрятаны, весь эффект под картой. Выжигание ядовито-зелёное.
	"yshaarj_lt": {"frames": "yshaarj_lt", "sounds": "yshaarj_lt",
		"card": {"face": "mini", "reveal": 1.54, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# AudioPlayClipAction FSM: 0.8 с начала, удар 0.7 с 1.1 с
		"cues": [[0.0, "Y_ShaarjTheDefiler_CustomSummon_Sound", 0.8], [1.1, "Y_ShaarjTheDefiler_CustomSummon_Impact_Sound", 0.7]],
		# CameraShakerAction FSM: 0.06 с 0.3 с, удар 0.1 с 1.07 с
		"shakers": [[0.3, 1.3, 0.06, [[0.0, 1.0], [0.63, 0.6], [0.75, 0.0], [1.0, 0.0]], 0.075],
			[1.07, 1.57, 0.1, [[0.0, 1.0], [0.25, 0.0], [1.0, 0.0]], 0.075]]},
	# High Cultist Herenn (TLC_810) — Severin Silrajin (вместо Cho'gall — владелец выбрал в
	# HsBrowser 2026-10-27; Cho'gall уходит к Chain Devil): TLCFX_HighCultistHerenn_CustomSummon
	# (Timeline): в точке посадки разгорается огненное кольцо ритуала, сверху бьёт фиолетовый
	# луч, на 1.45 с удар — фиолетово-огненная вспышка, круг тлеет. Весь эффект под картой.
	# Выжигание фиолетовое.
	"herenn": {"frames": "herenn", "sounds": "herenn",
		"card": {"face": "mini", "reveal": 1.92, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline: AudioSource 0.5 с начала
		"cues": [[0.0, "TLCFX_HighCultistHerenn_CustomSummon_Sound", 0.5]],
		# CameraShaker2: дрожь 0.05 нарастает, удар 0.2 с 1.45 с
		"shakers": [[0.0, 2.183, 0.05, [[0.0, 0.0], [0.27, 0.58], [0.95, 1.0], [1.0, 1.0]], 0.15],
			[1.45, 2.367, 0.2, [[0.0, 1.0], [1.0, 0.0]], 0.075]]},
	# Vyranoth (CATA_213) — White Dragon (вместо Frost Queen Sindragosa — владелец выбрал в
	# HsBrowser 2026-10-27): CATAFX_Vyranoth_CustomSummon (Timeline): из точки посадки
	# вырастают ледяные кристаллы, морозный туман, к ~1.2 с ледяной взрыв, осколки тают.
	# Весь эффект под картой. Выжигание ледяное голубое.
	"vyranoth": {"frames": "vyranoth", "sounds": "vyranoth",
		"card": {"face": "mini", "reveal": 1.67, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline: AudioSource 0.8 с начала
		"cues": [[0.0, "Vyranoth_CustomSummon_Sound", 0.8]],
		# CameraShaker2: 0.08, пик к 1.3 с
		"shakers": [[0.0, 3.117, 0.08, [[0.0, 0.0], [0.26, 0.3], [0.42, 0.77], [0.54, 0.49], [1.0, 0.0]], 0.075]]},
	# Cho'gall, Twilight Chieftain (YOG_530) — Chain Devil (владелец в HsBrowser 2026-10-27; кадры
	# перепечены с её контуром; до HsFx-64..68 — Severin Silrajin):
	# YOGFX_Cho'gallTwilightChieftain_CustomSummon (Timeline): две цепи бьют крестом в точку
	# посадки, сверху падает фиолетовый луч, на 0.95 с удар — кольцо, всплеск сумерек и
	# осколки цепей. Весь эффект под картой (всплеск закрывал её). Убраны миньон HS, его
	# свечение и трещины; затемнение доски в фиолетовый (SetAmbientColor FSM) не берём.
	# Выжигание фиолетовое в цвет эффекта (владелец 2026-10-24). Дымки нет.
	"chogall": {"frames": "chogall", "sounds": "chogall",
		"card": {"face": "mini", "reveal": 1.42, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		"cues": [[0.0, "ChoGallTwilightChieftain_CustomSummon_Sound", 1.0]],
		# CameraShaker2: 0.2 по осям, сила линейно 1 -> 0
		"shakers": [[0.933, 2.0, 0.2, [[0.0, 1.0], [1.0, 0.0]], 0.075]]},
	# Wilfred Fizzlebang (AT_027) — Council Member (вместо Lady Prestor — владелец выбрал в
	# HsBrowser 2026-10-27): ATFX_WilfredFizzlebang_CustomSummon (по FSM, без Timeline): в точке
	# посадки загораются фиолетовые кольца призыва чернокнижника, тьма втягивается в центр,
	# на 1.0 с появляется миньон HS, кольца гаснут (клип Fizzlebang_RingsFade). Весь эффект под
	# картой. Выжигание фиолетовое в цвет колец. Тряски нет.
	"fizzlebang": {"frames": "fizzlebang", "sounds": "fizzlebang",
		"card": {"face": "mini", "reveal": 1.47, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# AudioPlaythroughAction FSM с начала: AudioSource 1 x 0.7
		"cues": [[0.0, "WilfredFizzlebang_CustomSummon_Sound", 0.7]]},
	# Renferal, the Malignant (EDR_526) — Matron Mother (вместо Queen Azshara — владелец выбрал
	# в HsBrowser 2026-10-27): EDRFX_RenferalTheMalignant_CustomSummon (Timeline): над точкой
	# посадки сгущается тьма, на 0.67 с вспыхивает багровая паутина (паучья матрона Ллос),
	# паутина тлеет и гаснет. Жетон HS спрятан, весь эффект под картой. Выжигание багровое.
	"renferal": {"frames": "renferal", "sounds": "renferal",
		"card": {"face": "mini", "reveal": 1.14, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline: AudioSource 0.7 с начала
		"cues": [[0.0, "RenferalTheMalignant_CustomSummon_Sound", 0.7]],
		# CameraShaker2: (0.03, 0.05, 0.05) в ударе, сила линейно 1 -> 0
		"shakers": [[0.667, 1.267, 0.05, [[0.0, 1.0], [1.0, 0.0]], 0.075]]},
	# Exarch Akama (GDB_235) — Weaponmaster (вместо Blademaster Samuro — владелец выбрал в
	# HsBrowser 2026-10-27): GDBFX_ExarchAkama_CustomSummon (Timeline): в точке посадки
	# поднимается пыль и камни (в HS — ниже, у героя; сдвинуты `move` к месту карты), на 1.27 с
	# удар — огненный крест двух клинков и облако пыли. Жетон HS спрятан, весь эффект под
	# картой. Выжигание оранжевое в цвет клинков.
	"akama": {"frames": "akama", "sounds": "akama",
		"card": {"face": "mini", "reveal": 1.74, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline: AudioSource 0.5 — замах с начала, удар с 1.283 с
		"cues": [[0.0, "ExarchAkama_CustomSummon_Cast_Sound", 0.5], [1.283, "ExarchAkama_CustomSummon_Impact_Sound", 0.5]],
		# CameraShaker2: рывок в начале 0.2, дрожь 0.1 нарастает перед ударом, удар 0.2
		"shakers": [[0.0, 0.35, 0.2, [[0.0, 1.0], [1.0, 0.0]], 0.075], [0.533, 0.872, 0.1, [[0.0, 0.0], [1.0, 1.0]], 0.25],
			[1.267, 1.617, 0.2, [[0.0, 1.0], [1.0, 0.0]], 0.075]]},
	# Zayle, Shadow Cloak (DAL_800) — Masters of Sorcere (владелец в HsBrowser 2026-10-27; до
	# HsFx-58 стоял на Deathblade вместо Valeera the Hollow: у неё только
	# полёт миньона HS на лиане — владелец 2026-10-24): DALFX_ZayleShadowCloak_CustomSummon
	# (по FSM: все частицы с нажатия): в точке посадки фиолетовый разлом-молния, дым, знак
	# глаза в треугольнике, на 1.0 с появляется миньон HS. Весь эффект под картой (молния
	# шла поверх). Выжигание фиолетовое — тон арта совпал с цветом эффекта. Тряски нет.
	"zayle": {"frames": "zayle", "sounds": "zayle",
		"card": {"face": "mini", "reveal": 1.47, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		"cues": [[0.0, "ZayleMasterCloak_CustomSummon", 1.0]]},
	# Blade of The Black Empire (BE_227) — Deathblade (вместо Zayle — владелец выбрал в
	# HsBrowser 2026-10-27): BEFX_BladeoftheBlackEmpire_CustomSummon (Timeline): два
	# фиолетовых разреза клинка крестом над точкой посадки, на 0.53 с удар — вихрь пустоты,
	# всплеск и угли. Жетона HS в эффекте нет, весь эффект под картой. Выжигание фиолетовое.
	"blackempire": {"frames": "blackempire", "sounds": "blackempire",
		"card": {"face": "mini", "reveal": 1.0, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline: AudioSource 0.7 с начала, удар 0.7 с 0.533 с
		"cues": [[0.0, "BE_227_BladeofTheBlackEmpire_CustomSummon_Sound", 0.7],
			[0.533, "BE_227_BladeofTheBlackEmpire_CustomSummon_ImpactSound", 0.7]],
		# CameraShaker2: три рывка разреза и удара, сила линейно 1 -> 0
		"shakers": [[0.15, 0.3, 0.02, [[0.0, 1.0], [1.0, 0.0]], 0.036], [0.35, 0.5, 0.07, [[0.0, 1.0], [1.0, 0.0]], 0.036],
			[0.567, 0.717, 0.09, [[0.0, 1.0], [1.0, 0.0]], 0.036]]},
	# Kael'thas Sunstrider (BT_255) — Efreeti (владелец в HsBrowser 2026-10-27; кадры перепечены
	# перепечены с её контуром; до HsFx-58 — Masters of Sorcere): BTFX_KaelthasSunstrider_CustomSummon
	# (Timeline): в точке посадки огненная спираль, вокруг кружат три зелёные сферы Скверны
	# с огненными шлейфами, растёт солнечный шар, на 1.5 с удар — зелёная вспышка и пламя.
	# Весь эффект под картой; трещины в земле (макет HS) убраны. Выжигание зелёное в цвет
	# Скверны (владелец 2026-10-25).
	"kaelthas": {"frames": "kaelthas", "sounds": "kaelthas",
		"card": {"face": "mini", "reveal": 1.97, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# AudioPlayClipAction FSM: 0.5 с начала, удар 0.6 на 1.5 с
		"cues": [[0.0, "Kael_thasSunstrider_CustomSummon_Sound", 0.5], [1.5, "Kael_thasSunstrider_CustomSummon_Impact_Sound", 0.6]],
		# CameraShakerAction FSM: 0.15 по осям через 0.1 с после удара, 0.63 с
		"shakers": [[1.6, 2.23, 0.12, [[0.0, 1.0], [1.0, 0.0]], 0.0167]]},
	# Ragnaros, the Great Fire (CATA_150) — Balor (вместо Magtheridon — владелец выбрал в
	# HsBrowser 2026-10-27): CATAFX_Ragnaros_CustomSummon (Timeline + FSM): огненные струи со
	# всех сторон сходятся в точку посадки, из пламени встаёт рогатый огненный лик, на 1.4 с он
	# рассыпается огнём. Жетон HS и его свечение спрятаны, весь эффект под картой.
	# Выжигание огненно-оранжевое.
	"ragnaros_gf": {"frames": "ragnaros_gf", "sounds": "ragnaros_gf",
		"card": {"face": "mini", "reveal": 1.87, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# AudioPlayClipAction FSM 0.85 с начала
		"cues": [[0.0, "CATAFX_Ragnaros_CustomSummon_Sound", 0.85]],
		# CameraShaker2: дрожь 0.05 нарастает до 1.4 с, потом 0.07 рывком и спад
		"shakers": [[0.0, 1.4, 0.05, [[0.0, 0.0], [1.0, 1.0]], 0.075],
			[1.4, 3.933, 0.07, [[0.0, 0.26], [0.12, 0.96], [0.21, 0.22], [1.0, 0.0]], 0.075]]},
	# Kil'jaeden (GDB_145) — Demogorgon (стоимость 8 — большой эффект на весь экран, правило
	# владельца 2026-10-25): GDBFX_Kiljaeden_CustomSummon (Timeline): ленты Скверны со всего
	# экрана закручиваются в вихрь с красным кольцом, открывается зелёный портал, на 1.5 с он
	# схлопывается вспышкой, по столу расходятся трещины. Жетон HS и его свечение спрятаны,
	# весь эффект под картой. Выжигание жёлто-зелёное в цвет Скверны. Эффект розыгрыша
	# (портал в колоду HS) не берём.
	"kiljaeden": {"frames": "kiljaeden", "sounds": "kiljaeden",
		"card": {"face": "mini", "reveal": 1.97, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline: AudioSource 0.7, удар на 1.5 с
		"cues": [[0.0, "Kiljaeden_CustomSummon_Cast_Sound", 0.7], [1.5, "Kiljaeden_CustomSummon_Impact_Sound", 0.7]],
		# CameraShaker2: 0.2 по осям, сила линейно 1 -> 0
		"shakers": [[0.0, 0.65, 0.2, [[0.0, 1.0], [1.0, 0.0]], 0.075], [1.5, 1.983, 0.2, [[0.0, 1.0], [1.0, 0.0]], 0.075]]},
	# Archimonde (GDB_128) — Orcus (стоимость 8 — эффект на весь экран): GDBFX_Archimonde_CustomSummon
	# (Timeline): с краёв экрана падают метеоры Скверны, в точке посадки загорается треугольник
	# рун, на 1.68 с удар — вспышка Скверны. Виньетка и зелёный туман на весь экран убраны: в
	# пиксель-арте рвались на пятна по краям (как у Ysera). Копия эффекта для стороны соперника
	# (Root_Opponent), жетон HS и его свечение спрятаны; ScreenFX сдвинут в центр экрана HS, как ставит FSM;
	# перекраску доски (SetAmbientColor FSM) не берём. Выжигание жёлто-зелёное в цвет Скверны.
	"archimonde": {"frames": "archimonde", "sounds": "archimonde",
		"card": {"face": "mini", "reveal": 2.15, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline: AudioSource 0.7 (каст, удар на 1.683 с), метеоры 0.4 с 0.583 с
		"cues": [[0.0, "Archimonde_CustomSummon_Cast_Sound", 0.7], [0.583, "Archimonde_CustomSpawn_Missiles_Sound", 0.4],
			[1.683, "Archimonde_CustomSummon_Impact_Sound", 0.7]],
		# CameraShaker2: дрожь 0.06 нарастает до удара, в ударе (0.25, 0.05, 0.15) — у нас круг 0.2
		"shakers": [[0.4, 1.683, 0.06, [[0.0, 0.0], [0.73, 1.0], [1.0, 1.0]], 0.159],
			[1.683, 2.517, 0.2, [[0.0, 0.0], [0.1, 1.0], [0.31, 0.93], [0.51, 0.36], [0.71, 0.14], [1.0, 0.0]], 0.075]]},
	# Spore Empress Moldara (GDB_234) — Zuggtmoy (стоимость 6 — крупный эффект у места карты):
	# GDBFX_SporeEmpressMoldara_CustomSummon (Timeline): зелёный шлейф спор закручивается к точке
	# посадки, на 1.35 с вспышка жёлтых спор с трещинами, облако спор держится вокруг карты.
	# Жетон HS и его свечение спрятаны, весь эффект под картой. Выжигание жёлтое в цвет
	# вспышки спор (владелец 2026-10-25).
	"moldara": {"frames": "moldara", "sounds": "moldara",
		"card": {"face": "mini", "reveal": 1.82, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline: AudioSource 0.8 с начала, удар 0.6 на 1.35 с
		"cues": [[0.0, "GDBFX_SporeEmpressMoldara_CustomSummon_Sound", 0.8], [1.35, "FX_MinionSummonLarge_Drop", 0.6]],
		# CameraShaker2: 0.1 нарастает до 0.767 с, в ударе 0.2 и спад
		"shakers": [[0.0, 0.767, 0.1, [[0.0, 0.0], [1.0, 1.0]], 0.075], [1.35, 2.1, 0.2, [[0.0, 1.0], [1.0, 0.0]], 0.075]]},
	# K'ara, the Dark Star (GDB_127) — Inquisitor (владелец в HsBrowser 2026-10-27, вместо
	# Benedictus; до HsFx-60 стояла на Graz'zt вместо Prince Malchezaar, KAR — владелец
	# 2026-10-25: только свежие анимации; пробы Sinestra, Shaffar, Carress, Darkmarrow,
	# Nefarius, Lady Azshara): GDBFX_Kara_CustomSummon (Timeline): в точке посадки
	# фиолетовый демонический силуэт, на 1.27 с он схлопывается в тёмную звезду-портал с
	# кольцом искр, портал гаснет к 3.7 с. Жетон HS и его овальный контур (TokenGlow —
	# владелец заметил 2026-10-25) спрятаны, весь эффект под картой.
	# Выжигание фиолетовое в цвет эффекта. Тряски в HS нет.
	"kara": {"frames": "kara", "sounds": "kara",
		"card": {"face": "mini", "reveal": 1.74, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline: AudioSource 0.35
		"cues": [[0.0, "Kara_CustomSummon_Sound", 0.35]]},
	# Endbringer Umbra (TLC_106) — Graz'zt (вместо K'ara — владелец выбрал в HsBrowser
	# 2026-10-27): TLCFX_EndbringerUmbra_CustomSummon (Timeline): фиолетовые щупальца тьмы
	# тянутся сверху и сходятся в точке посадки, на 1.0 с удар — вспышка, сфера тёмной
	# энергии, ударная волна. Жетон HS спрятан, весь эффект под картой; фиолетовое
	# затемнение доски (CameraOverlay) не берём. Выжигание фиолетовое в цвет щупалец.
	"umbra": {"frames": "umbra", "sounds": "umbra",
		"card": {"face": "mini", "reveal": 1.47, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline: AudioSource 0.6 с начала
		"cues": [[0.0, "EndbringerUmbra_CustomSummon_Sound", 0.6]],
		# CameraShaker2: дрожь нарастает 0.04 до удара, в ударе 0.2, сила линейно 1 -> 0
		"shakers": [[0.0, 1.0, 0.04, [[0.0, 0.0], [1.0, 1.0]], 0.075], [1.0, 1.75, 0.2, [[0.0, 1.0], [1.0, 0.0]], 0.075]]},
	# Nythendra (EDR_818) — Vrock (вместо Anetheron, SW — владелец 2026-10-25: только
	# свежие; врок разносит споры): EDRFX_Nythendra_CustomSummon (Timeline): жёлтая чумная
	# мошкара вихрем стягивается к точке посадки, на 1.38 с вспышка — рой разлетается и
	# гаснет. Жетон HS, его свечение и осколки жетона спрятаны, весь эффект под картой.
	# Выжигание жёлтое в цвет роя.
	"nythendra": {"frames": "nythendra", "sounds": "nythendra",
		"card": {"face": "mini", "reveal": 1.85, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline: каст AudioSource 0.6, удар 0.5 на 1.383 с
		"cues": [[0.0, "EDRFX_Nythendra_CustomSummon_Cast_Sound", 0.6], [1.383, "EDRFX_Nythendra_CustomSummon_Impact_Sound", 0.5]],
		# CameraShaker2: 0.05 до удара, в ударе 0.2, сила линейно 1 -> 0
		"shakers": [[0.0, 1.383, 0.05, [[0.0, 1.0], [1.0, 0.0]], 0.075], [1.383, 1.85, 0.2, [[0.0, 1.0], [1.0, 0.0]], 0.075]]},
	# Nightmare Lord Xavius (EDR_856) — Glabrezu (вместо Razidir — владелец выбрал в HsBrowser
	# 2026-10-27; Razidir уходит к Guardian Naga): EDRFX_Xavius_CustomSummon (Timeline): алые
	# когти рвут воздух над точкой посадки, на 1.15 с огненный взрыв, багровые разрывы тлеют.
	# Жетон HS спрятан, весь эффект под картой. Выжигание алое.
	"xavius": {"frames": "xavius", "sounds": "xavius",
		"card": {"face": "mini", "reveal": 1.62, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline: AudioSource 0.6 — замах с начала, удар с 1.167 с
		"cues": [[0.0, "EDRFX_Xavius_CustomSummon_Cast_Sound", 0.6], [1.167, "EDRFX_Xavius_CustomSummon_Impact_Sound", 0.6]],
		# CameraShaker2: 0.1 в начале и в ударе
		"shakers": [[0.0, 0.783, 0.1, [[0.0, 0.5], [0.13, 1.0], [0.4, 0.2], [1.0, 0.0]], 0.075],
			[1.15, 2.333, 0.1, [[0.0, 0.5], [0.13, 1.0], [0.4, 0.2], [1.0, 0.0]], 0.075]]},
	# Razidir (TLC_463) — Guardian Naga (владелец в HsBrowser 2026-10-27, перепечён;
	# до HsFx-69..75 — Glabrezu, (вместо Fel Lord Betrug, DAL — владелец 2026-10-25: только
	# свежие; пробы Zakajz, Talgath, Kronn, G'huun, Vulcanos, Drest'agath, Broxigar,
	# Magtheridon Unreleased и др.): TLC463_Nazidir_CustomSummon (Timeline). Адаптация
	# (владелец): в HS разлом-жетон летит из угла экрана — здесь он с нажатия формируется в
	# точке посадки (рецепт pin), на 0.98 с удар — зелёные когти полосуют стол, всплеск
	# слизи, трещины. Жетон HS, его свечение-овал и контур легендарной рамки (владелец
	# 2026-10-25) и копия для соперника спрятаны, весь эффект под картой.
	# Выжигание пурпурное в цвет разлома.
	"razidir": {"frames": "razidir", "sounds": "razidir",
		"card": {"face": "mini", "reveal": 1.45, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# AudioPlayClipAction FSM 0.85
		"cues": [[0.0, "Razidir_CustomSummon_Sound", 0.85]],
		# CameraShaker2: 0.1 по осям, рывок в ударе
		"shakers": [[0.95, 1.85, 0.08, [[0.0, 0.0], [0.04, 0.75], [0.5, 0.0], [1.0, 0.0]], 0.0219]]},
	# Inara Stormcrash (DMF_708) — Aerisi Kalinoth (вместо Ohn'ahra — владелец выбрал в
	# HsBrowser 2026-10-27): DMFFX_InaraStormcrash_CustomSummon (Timeline + FSM): синяя молния
	# прилетает слева (как в HS), бьёт в точку посадки, на 1.35 с вспыхивает и висит сфера бури
	# с разрядами. Жетон HS и трещины в земле (макет HS) спрятаны, весь эффект под картой.
	# Выжигание голубое в цвет молний.
	"inara": {"frames": "inara", "sounds": "inara",
		"card": {"face": "mini", "reveal": 1.82, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# AudioPlayClipAction FSM 0.7 с задержкой 0.8 с
		"cues": [[0.8, "InaraStormcrash_CustomSummon_Sound", 0.7]],
		# CameraShakerAction FSM: 0.04 с 0.2 с, 0.03 с 1.0 с, рывок и спад
		"shakers": [[0.2, 1.2, 0.04, [[0.0, 1.0], [0.25, 0.0], [1.0, 0.0]], 0.075], [1.0, 2.0, 0.03, [[0.0, 1.0], [0.25, 0.0], [1.0, 0.0]], 0.075]]},
	# Mutanus the Devourer (WC_030) — Gar Shatterkeel (вместо Neptulon — владелец выбрал в
	# HsBrowser 2026-10-27): BARFX_MutanusTheDevourer_CustomSummon (FSM запускает Timeline):
	# в точке посадки закручивается тёмный водоворот, пузыри и блики воды, на 1.25 с всплеск
	# кольцом. Жетон HS (с миньоном) спрятан, весь эффект под картой; затемнение доски
	# (SetAmbientColor FSM) не берём. Выжигание бирюзовое.
	"mutanus": {"frames": "mutanus", "sounds": "mutanus",
		"card": {"face": "mini", "reveal": 1.72, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# AudioPlayClipAction FSM 0.7: с начала и удар с 1.25 с
		"cues": [[0.0, "MutanusTheDevourer_CustomSummon", 0.7], [1.25, "MutanusTheDevourer_CustomSummon_Impact", 0.7]],
		# MainCameraShakerAction FSM: 0.03, 0.6 с
		"shakers": [[1.25, 1.85, 0.03, [[0.0, 1.0], [1.0, 0.0]], 0.0167]]},
	# Ravitz (BE_230) — Ogrémoch (вместо Nespirah — владелец выбрал в HsBrowser 2026-10-27):
	# BEFX_Ravitz_CustomSummon (Timeline): из точки посадки прорастают зелёные кристаллы скверны,
	# на 1.1 с они взрываются зелёной вспышкой, оседает пыль. Жетон HS и трещины в земле
	# (`GroundCracks_*`) спрятаны, весь эффект под картой. Выжигание ядовито-зелёное.
	"ravitz": {"frames": "ravitz", "sounds": "ravitz",
		"card": {"face": "mini", "reveal": 1.57, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline: AudioSource 0.5 с начала, удар 0.6 с 1.1 с
		"cues": [[0.0, "BE_230_Ravitz_CustomSummon_Sound", 0.5], [1.1, "BE_230_Ravitz_CustomSummon_Impact_Sound", 0.6]],
		# CameraShaker2: два рывка 0.2 при росте кристаллов, удар 0.3
		"shakers": [[0.0, 0.296, 0.2, [[0.0, 1.0], [0.64, 0.84], [1.0, 0.0]], 0.075], [0.533, 0.83, 0.2, [[0.0, 1.0], [0.64, 0.84], [1.0, 0.0]], 0.075],
			[1.133, 1.4, 0.3, [[0.0, 1.0], [1.0, 0.0]], 0.075]]},
	# Azshara, Ocean Lord (CATA_151) — Olhydra (вместо Neptulon the Tidehunter, TID — владелец
	# 2026-10-25: только свежие; пробы Neptulon BE, King Tide, Lady Azshara TIME):
	# CATAFX_LadyAzshara_CustomSummon (Timeline): в точке посадки фиолетовая вспышка с
	# молниями, снизу поднимается бирюзовая волна и на 1.2 с обрушивается на место карты —
	# всплеск брызг и пены. Жетон HS (с ним шлейф брызг) и копия для соперника спрятаны, весь
	# эффект под картой. Выжигание морской зелени в цвет волны.
	"azshara_ocean": {"frames": "azshara_ocean", "sounds": "azshara_ocean",
		"card": {"face": "mini", "reveal": 1.7, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline: AudioSource 0.7 с начала, удар 0.7 с 1.217 с
		"cues": [[0.0, "CATAFX_LadyAzshara_CustomSummon_Sound", 0.7], [1.217, "CATAFX_LadyAzshara_CustomSummon_Impact_Sound", 0.7]],
		# CameraShaker2: (0.2, 0.3, 0.1) — у нас 0.25, рывок в ударе
		"shakers": [[1.233, 1.9, 0.25, [[0.0, 0.0], [0.04, 0.75], [0.5, 0.0], [1.0, 0.0]], 0.0219]]},
	# Y'Shaarj, Titan Bane (BE_784) — Marlos Urnrayle, медуза (вместо Mirrex — владелец
	# 2026-10-26: дарк фэнтези, розовые кристаллы не подходят; пробы Nespirah, Wallow, Renferal,
	# The Unknowable One, The Black Blood, Herenn, Eliza Goreblade и др.):
	# BEFX_YShaarjtheTitanBane_CustomSummon (Timeline): в пурпурной тьме собирается ядовитое
	# облако, на 0.55 с раскрываются ядовито-зелёные змеиные глаза (взгляд медузы), молнии,
	# яд расползается и гаснет. Жетон HS и его контур спрятаны, весь эффект под картой.
	# Выжигание ядовито-зелёное в цвет глаз.
	"yshaarj": {"frames": "yshaarj", "sounds": "yshaarj",
		"card": {"face": "mini", "reveal": 1.1, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline: AudioSource 0.7 с начала, удар 0.7 с 0.55 с
		"cues": [[0.0, "BEFX_YShaarjtheTitanBane_CustomSummon_Sound", 0.7], [0.55, "BEFX_YShaarjtheTitanBane_CustomSummon_Impact_Sound", 0.7]],
		# CameraShaker2: 0.07 в ударе, сила линейно 1 -> 0
		"shakers": [[0.583, 2.081, 0.07, [[0.0, 0.99], [1.0, 0.0]], 0.075]]},
	# Azalina Soulsever (JAIL_430) — Ulitharid (вместо Irida — владелец выбрал в HsBrowser
	# 2026-10-27; Irida уходит к Oni): JAIL_430_AzalinaSoulsever_FAB_CustomSummon_FX (Timeline):
	# в точке посадки пульсирует фиолетовая сфера, из неё вырываются щупальца тьмы, на 1.45 с
	# сфера схлопывается и взрывается. Жетон HS и трещины в земле спрятаны, весь эффект под
	# картой. Выжигание фиолетовое.
	"azalina": {"frames": "azalina", "sounds": "azalina",
		"card": {"face": "mini", "reveal": 1.92, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline: AudioSource 0.7 с начала, удар 0.7 с 1.45 с
		"cues": [[0.0, "JAIL_430_AzalinaSoulsever_FAB_CustomSummon_FX_Sound", 0.7], [1.45, "JAIL_430_AzalinaSoulsever_FAB_CustomSummon_FX_Impact_Sound", 0.7]],
		# CameraShaker2: рывок 0.2 в начале, удар 0.1
		"shakers": [[0.0, 0.35, 0.2, [[0.0, 1.0], [1.0, 0.0]], 0.075], [1.483, 1.95, 0.1, [[0.0, 1.0], [1.0, 0.0]], 0.075]]},
	# Staff of the Endbringer (TLC_EVENT_402) — Beholder (вместо Iso'rath — владелец выбрал в
	# HsBrowser 2026-10-27; Iso'rath уходит к Roper): TLCFX_StaffEndbringer_CustomSummon (FSM +
	# Timeline): зелёные и фиолетовые сгустки закручиваются вихрем в точке посадки, к ~1.2 с
	# собираются в сияющую сферу-око, она гаснет. Весь эффект под картой. Выжигание синее.
	"staff_endbringer": {"frames": "staff_endbringer", "sounds": "staff_endbringer",
		"card": {"face": "mini", "reveal": 1.67, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# AudioPlayClipAction FSM с начала: 0.7 и 0.9
		"cues": [[0.0, "SphereOfSapience_SocketIn_Sound", 0.7], [0.0, "Aessina_CustomSummon_Cast_Sound", 0.9]]},
	# Iso'rath (CATA_481) — Roper (владелец в HsBrowser 2026-10-27, перепечён; до
	# HsFx-69..75 — Beholder), глаз-пожиратель (цена 5 — скромно, у места карты):
	# CATAFX_Iso'rath_CustomSummon (Timeline): фиолетовая воронка раскрывается, на 0.67 с
	# удар — пасть-цветок в светящейся сфере, щупальца тьмы кружат и гаснут к 2.5 с. Жетон HS
	# и его свечение спрятаны, весь эффект под картой. Выжигание фиолетовое в цвет портала.
	"isorath": {"frames": "isorath", "sounds": "isorath",
		"card": {"face": "mini", "reveal": 1.14, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline: AudioSource 0.8 с начала; тряски камеры в Timeline нет
		"cues": [[0.0, "CATAFX_IsoRath_CustomSummon_Sound", 0.8]]},
	# Irida Sinseeker (JAIL_719) — Oni (владелец в HsBrowser 2026-10-27, перепечена; до
	# HsFx-69..75 — Ulitharid), иллитид (выбор владельца 2026-10-26 вместо
	# Mindflayer Kaahrj; пробы C'Thun Eye of the Empire без глаза, с лиловыми и разведёнными
	# щупальцами, 8 Hands, G'huun, Zer'Ontu, Herenn — не то): JAIL_719_IridaSinseeker_CustomSummon_FX
	# (Timeline): тёмный разрез рассекает пространство по диагонали, раскрывается синий портал,
	# на 1.48 с удар — ударная волна и синяя вспышка с трещинами. Жетон HS спрятан, весь эффект
	# под картой. Выжигание сине-фиолетовое в цвет портала.
	"irida": {"frames": "irida", "sounds": "irida",
		"card": {"face": "mini", "reveal": 1.95, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# AudioPlayClipAction FSM: начало 0.6, удар 0.7 в 1.5 с (AudioSource 1)
		"cues": [[0.0, "JAIL_719_IridaSinseeker_FAB_CustomSummon_FX_Sound", 0.6], [1.5, "JAIL_719_IridaSinseeker_FAB_CustomSummon_FX_Impact_Sound", 0.7]],
		# CameraShaker2: 0.2 по осям в разрезе, 0.1 в ударе, сила линейно 1 -> 0
		"shakers": [[0.0, 0.817, 0.2, [[0.0, 1.0], [1.0, 0.0]], 0.075], [1.483, 1.917, 0.1, [[0.0, 1.0], [1.0, 0.0]], 0.075]]},
	# Kith'ix (BE_090) — Elder Brain, древний разум (вместо N'Zoth, God of the Deep; пробы
	# Umbra, N'Zoth Dream's End, Mastermind Yogg-Saron — владелец 2026-10-26): BEFX_Kithix_CustomSummon
	# (Timeline): по краям экрана сверкают фиолетовые молнии, на 0.6 с с неба бьёт столб молнии
	# в место карты, на 1.05 с удар — псионическая вспышка, ударная волна, дуги молний у земли.
	# Затемнение экрана (Vignette_Backing*) убрано, жетон HS спрятан, весь эффект под картой.
	# Выжигание фиолетовое в цвет молний.
	"kithix": {"frames": "kithix", "sounds": "kithix",
		"card": {"face": "mini", "reveal": 1.52, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline: начало с 0 с, удар с 0.967 с (AudioSource 1)
		"cues": [[0.0, "BE_090_Kithix_CustomSummon_Sound", 1.0], [0.967, "BE_090_Kithix_CustomSummon_ImpactSound", 1.0]],
		# CameraShaker2: дрожь 0.013 нарастает до удара, в ударе (0.2, 0.3) — у нас 0.25, рывок и спад
		"shakers": [[0.0, 1.05, 0.013, [[0.0, 0.0], [0.49, 0.99], [1.0, 0.99]], 0.0708],
			[1.05, 1.717, 0.25, [[0.0, 0.51], [0.5, 0.0], [1.0, 0.0]], 0.0708]]},
	# The Black Blood (CATA_300) — Aboleth, древняя слизистая тварь из глубин (вместо Soggoth;
	# пробы Maladaar, Uluu — владелец 2026-10-26): CATA_300_TheBlackBlood_CustomSummon (Timeline):
	# из лужи вскипает фиолетовый ком слизи, на 1.1 с всплеск и вспышка, слизь расплёскивается,
	# лужа остаётся под картой и дрожит. Жетон HS, свечение миньона и купол ShieldFX спрятаны,
	# весь эффект под картой. Выжигание фиолетовое в цвет слизи.
	"blackblood": {"frames": "blackblood", "sounds": "blackblood",
		"card": {"face": "mini", "reveal": 1.57, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline: начало с 0 с, удар с 1.267 с (AudioSource 0.7)
		"cues": [[0.0, "CATA_300_TheBlackBlood_CustomSummon_Sound", 0.7], [1.267, "Buttons_CustomSummon_Impact_Sound", 0.7]],
		# CameraShaker2: 0.05 нарастает до удара, в ударе 0.07 рывком и спад
		"shakers": [[0.198, 1.1, 0.05, [[0.0, 0.0], [1.0, 1.0]], 0.075],
			[1.1, 3.15, 0.07, [[0.0, 0.26], [0.13, 0.67], [0.37, 0.11], [0.68, 0.02], [1.0, 0.0]], 0.075]]},
	# Magmaw (CATA_550) — Neogi (выбор владельца 2026-10-27 из HsBrowser вместо Wallow; пробы
	# Anub'Rekhan, Broodqueen Sha'kar, Kerrigan, Renferal, Omen): CATAFX_Magmaw_CustomSummon
	# (Timeline): бурый дым ползёт по верху экрана, лавовый червь роет землю и вырывается справа
	# снизу, на 1.67 с взрыв огня и камней у места карты, дым и угли. Полёт червя — как в HS
	# (владелец). Жетон HS спрятан, весь эффект под картой. Выжигание огненно-оранжевое.
	"magmaw": {"frames": "magmaw", "sounds": "magmaw",
		"card": {"face": "mini", "reveal": 2.14, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline: начало с 0 с, удар с 0.95 с (AudioSource 1)
		"cues": [[0.0, "CATAFX_Magmaw_CustomSummon_Sound", 1.0], [0.95, "CATAFX_Magmaw_CustomSummon_ImpactSound", 1.0]],
		# CameraShaker2: толчки червя 0.05, 0.04, 0.1, в ударе 0.2, сила линейно 1 -> 0
		"shakers": [[0.117, 0.35, 0.05, [[0.0, 1.0], [1.0, 0.0]], 0.075], [0.35, 0.583, 0.05, [[0.0, 1.0], [1.0, 0.0]], 0.075],
			[1.0, 1.133, 0.04, [[0.0, 1.0], [1.0, 0.0]], 0.075], [1.367, 1.533, 0.1, [[0.0, 1.0], [1.0, 0.0]], 0.075],
			[1.683, 2.1, 0.2, [[0.0, 1.0], [1.0, 0.0]], 0.075]]},
	# Shadowcrafter Scabbs (AV_203) — Death Tyrant (выбор владельца 2026-10-27 из HsBrowser вместо
	# G'huun; пробы C'Thun the Shattered, C'Thun Eye of the Empire, Kel'Thuzad, Bonelord):
	# AVFX_ShadowcrafterScabbs_CustomSummon_Spell (обёртка _Super; эффект карты-героя по FSM —
	# клип аниматора CustomSummon и частицы Timeline через controls): чёрный дым собирается,
	# алая лента теней влетает сверху в место карты, на 1.8 с взрыв чёрного дыма, ударная волна.
	# Жетон и тень портрета героя (SocketShadowRoot) спрятаны. На тёмной доске эффект тихий —
	# владелец берёт всё равно. Выжигание алое.
	"scabbs": {"frames": "scabbs", "sounds": "scabbs",
		"card": {"face": "mini", "reveal": 2.3, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# AudioPlayClipAction FSM в начале (громкость в FSM не выгружена, AudioSource 1 — берём 0.8);
		# звук удара (TheAmazingReno) в FSM выключен
		"cues": [[0.0, "ShadowcrafterScabbs_CustomSummon_sound", 0.8]],
		# CameraShaker2: 0.05 нарастает до 1.08 с, в ударе 0.09, сила 1 -> 0
		"shakers": [[0.0, 1.083, 0.05, [[0.0, 0.0], [1.0, 1.0]], 0.075], [1.8, 3.683, 0.09, [[0.0, 1.0], [1.0, 0.0]], 0.075]]},
	# Broxigar (TIME_020) — Lich: TIME_020_Broxigar_Fab_CustomSummon (Timeline): в точке посадки
	# открывается ядовито-зелёный портал, на 1.0 с удар — зелёная вспышка и искры скверны. Жетон
	# HS и трещины спрятаны, весь эффект под картой. Выжигание зелёное. Владелец выбрал в
	# HsBrowser 2026-10-27.
	"broxigar": {"frames": "broxigar", "sounds": "broxigar",
		"card": {"face": "mini", "reveal": 1.47, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [[0, "TIME_020_Broxigar_Fab_CustomSummon_Sound", 0.8], [1, "TIME_020_Broxigar_Fab_CustomSummon_Impact_Sound", 0.8]],
		# CameraShaker2
		"shakers": [[1, 1.75, 0.5, [[0, 1], [1, 0]], 0.075], [0, 0.35, 0.2, [[0, 1], [1, 0]], 0.075]]},
	# Sylvanas, the Accused (CORE_MAW_033) — Revenant: MAWFX_SylvanasTheAccused_CustomSummon
	# (Timeline): тёмный плащ-дым и пряди крика банши стягиваются к точке посадки, на 1.67 с
	# удар — багровая дымка. Жетон HS спрятан, весь эффект под картой. Выжигание фиолетовое.
	# Владелец выбрал в HsBrowser 2026-10-27.
	"sylvanastheaccused": {"frames": "sylvanastheaccused", "sounds": "sylvanastheaccused",
		"card": {"face": "mini", "reveal": 2.14, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [[0, "SylvanasTheAccused_CustomSummon_Sound", 0.6], [1.67, "SylvanasTheAccused_CustomSummon_Impact_Sound", 0.6]],
		# CameraShaker2
		"shakers": [[1.667, 2.867, 0.1, [[0, 1], [1, 0]], 0.075], [0.767, 1.467, 0.05, [[0, 0], [0.47, 0.97], [0.88, 0.8], [1, 0]], 0.075]]},
	# Tichondrius (CORE_CATA_001) — Vampire: в точке посадки разгорается ядовито-зелёный шар
	# скверны, на 0.95 с вспышка, разлетаются летучие мыши. Жетон HS спрятан, весь эффект под
	# картой. Выжигание зелёное. Владелец выбрал в HsBrowser 2026-10-27.
	"tichondrius": {"frames": "tichondrius", "sounds": "tichondrius",
		"card": {"face": "mini", "reveal": 1.42, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [[0, "Tichondrias_CustomSummon_Sound", 0.9]],
		# CameraShaker2
		"shakers": [[0, 0.35, 0.2, [[0, 1], [1, 0]], 0.075], [0.917, 1.667, 0.5, [[0, 1], [1, 0]], 0.075]]},
	# Omen (EDR_421) — Shield Guardian: багровая лента прилетает слева (как в HS) и бьёт в точку
	# посадки, на 0.7 с алая сфера, искры гаснут. Жетон HS и трещины спрятаны, весь эффект под
	# картой. Выжигание алое. Владелец выбрал в HsBrowser 2026-10-27.
	"omen": {"frames": "omen", "sounds": "omen",
		"card": {"face": "mini", "reveal": 1.17, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [[0, "Omen_CustomSummon_Sound", 1]],
		# CameraShaker2
		"shakers": [[0.717, 1.3, 0.2, [[0, 1], [1, 0]], 0.075], [0.017, 0.367, 0.2, [[0, 1], [1, 0]], 0.075]]},
	# Azure Queen Sindragosa (TIME_852) — Silver Dragon: фиолетовый вихрь-крыло проносится к
	# точке посадки, на 0.95 с вспышка — белое сияние с фиолетовыми молниями и золотым светом.
	# Жетон HS и трещины спрятаны, весь эффект под картой. Выжигание фиолетовое. Владелец выбрал
	# в HsBrowser 2026-10-27.
	"azurequeensindrago": {"frames": "azurequeensindrago", "sounds": "azurequeensindrago",
		"card": {"face": "mini", "reveal": 1.42, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [[0, "TIMEFX_AzureQueenSindragosa_CustomSummon_Cast_Sound", 0.8], [0.967, "TIMEFX_AzureQueenSindragosa_CustomSummon_Impact_Sound", 0.8]],
		# CameraShaker2
		"shakers": [[0.667, 0.917, 0.4, [[0, 1], [1, 0]], 0.044], [0, 0.667, 0.1, [[0, 1], [1, 0]], 0.055], [0.933, 1.967, 0.3, [[0, 1], [1, 0]], 0.038]]},
	# Medivh the Hallowed (TIME_890) — Solar: у точки посадки встаёт витражная дверь портала в
	# языках пламени, на 1.4 с огненный взрыв. Жетон HS и виньетка спрятаны, весь эффект под
	# картой. Выжигание огненное. Владелец выбрал в HsBrowser 2026-10-27.
	"medivhthehallowed": {"frames": "medivhthehallowed", "sounds": "medivhthehallowed",
		"card": {"face": "mini", "reveal": 1.87, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [[0, "MedivhTheHallowed_CustomSummon_Cast_Sound", 0.8], [1.55, "MedivhTheHallowed_CustomSummon_Impact_Sound", 0.8]],
		# CameraShaker2
		"shakers": [[1.45, 1.917, 0.04, [[0, 1], [1, 0]], 0.075]]},
	# Jace Darkweaver (SW_044) — Green Hag: из точки посадки валит ядовито-зелёный дым скверны,
	# на 1.4 с вспышка, дым тает. Трещины в земле спрятаны, весь эффект под картой. Выжигание
	# зелёное. Владелец выбрал в HsBrowser 2026-10-27.
	"jacedarkweaver": {"frames": "jacedarkweaver", "sounds": "jacedarkweaver",
		"card": {"face": "mini", "reveal": 1.87, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [[1.4, "JaceDarkweaver_CustomSummon_Impact_Sound", 0.5]]},
	# Thunderbringer (WW_440) — Nightmare: над точкой посадки клубятся грозовые тучи, бьют синие
	# молнии, на 1.53 с удар — голубая вспышка. Жетон HS, виньетка бури и трещины спрятаны, весь
	# эффект под картой. Выжигание голубое. Владелец выбрал в HsBrowser 2026-10-27.
	"thunderbringer": {"frames": "thunderbringer", "sounds": "thunderbringer",
		"card": {"face": "mini", "reveal": 2.00, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [[0, "Thunderbringer_CustomSummon_Cast_Sound", 0.6], [1.53, "Thunderbringer_CustomSummon_Impact_Sound", 0.6]],
		# CameraShaker2
		"shakers": [[1.467, 2, 0.15, [[0, 1], [1, 0]], 0.075], [0.967, 1.467, 0.05, [[0, 0], [0.23, 0.5], [1, 0.5]], 0.075]]},
	# Drest'agath (BE_703) — Sylgar: в точке посадки открывается огненный глаз в кольце пламени
	# (скромно — карта стоит 1), на 1.17 с он гаснет искрами. Жетон HS спрятан, весь эффект под
	# картой. Выжигание алое. Владелец выбрал в HsBrowser 2026-10-27.
	"drestagath": {"frames": "drestagath", "sounds": "drestagath",
		"card": {"face": "mini", "reveal": 1.64, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [[0, "BE_703_Drestagath_CustomSummon_FX_Sound", 0.7], [1.2, "BE_703_Drestagath_CustomSummon_FX_Impact_Sound", 0.7]],
		# CameraShaker2
		"shakers": [[0, 0.167, 0.2, [[0, 1], [1, 0]], 0.075], [0.7, 1.167, 0.05, [[0, 0], [1, 1]], 0.075], [1.167, 1.633, 0.2, [[0, 1], [1, 0]], 0.075]]},
	# N'Zoth, Dream's End (BE_017) — Xanathar: пурпурные тучи бездны и золотой свет, на 1.45 с
	# огненное кольцо, раскалённые трещины гаснут. Жетон HS и трещины в земле спрятаны, весь
	# эффект под картой. Выжигание огненное. Владелец выбрал в HsBrowser 2026-10-27.
	"nzothdreamsend": {"frames": "nzothdreamsend", "sounds": "nzothdreamsend",
		"card": {"face": "mini", "reveal": 1.92, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [[0, "BE_017_NzothDreamsEnd_CustomSummon_Sound", 0.8], [1.43, "BE_017_NzothDreamsEnd_CustomSummon_ImpactSound", 0.8]],
		# CameraShaker2
		"shakers": [[1.567, 2.583, 0.2, [[0, 1], [1, 0]], 0.075], [0.517, 1.1, 0.075, [[0, 1], [0.99, 0.7]], 0.1]]},
	# Zer'Ontu (BE_790) — Blink Dog: слева мерцает фиолетовый разлом, синий вихрь переносится к
	# точке посадки, на 1.45 с вспышка, голубой дым. Жетон HS и трещины спрятаны, весь эффект
	# под картой. Выжигание голубое. Владелец выбрал в HsBrowser 2026-10-27.
	"zerontu": {"frames": "zerontu", "sounds": "zerontu",
		"card": {"face": "mini", "reveal": 1.92, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [[0, "BE_790_ZerOntu_CustomSummon_Sound", 1], [1.32, "BE_790_ZerOntu_CustomSummon_ImpactSound", 1]],
		# CameraShaker2
		"shakers": [[1.517, 2.533, 0.2, [[0, 1], [1, 0]], 0.075], [0.517, 1.1, 0.075, [[0, 1], [0.99, 0.7]], 0.1]]},
	# Hodir, Father of Giants (TTN_752) — Cloud Giant: ледяной вихрь кружит над точкой посадки и
	# сжимается, на 1.32 с голубая вспышка. Жетон HS и трещины спрятаны, весь эффект под картой.
	# Выжигание голубое. Владелец выбрал в HsBrowser 2026-10-27.
	"hodirfatherofgiant": {"frames": "hodirfatherofgiant", "sounds": "hodirfatherofgiant",
		"card": {"face": "mini", "reveal": 1.79, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [[0, "HodirFatherGiants_CustomSummon_Sound", 0.9], [1.32, "HodirFatherGiants_CustomSummon_Impact_Sound", 0.8]],
		# CameraShaker2
		"shakers": [[0.833, 1.267, 0.05, [[0, 0], [0.21, 0.51], [0.7, 1], [1, 0]], 0.174], [1.317, 1.783, 0.15, [[0, 1], [1, 0]], 0.131]]},
	# Eliza Goreblade (VAC_426) — Pirate Captain: два кровавых клинка бьют крестом в точку
	# посадки, на 1.08 с алая вспышка, кровавый знак гаснет. Трещины от клинков спрятаны, весь
	# эффект под картой. Выжигание алое. Владелец выбрал в HsBrowser 2026-10-27.
	"elizagoreblade": {"frames": "elizagoreblade", "sounds": "elizagoreblade",
		"card": {"face": "mini", "reveal": 1.55, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [],
		# CameraShaker2
		"shakers": [[0.1, 0.9, 0.05, [[0, 0], [0.5, 1], [0.99, 0]], 0.075], [1.083, 2.75, 0.07, [[0, 0.26], [0.22, 0.64], [0.37, 0.11], [0.68, 0.02], [1, 0]], 0.075]]},
	# Bonelord Frostwhisper (RLK_591) — Young White Dragon: снизу к точке посадки поднимается
	# ледяной луч, на 1.63 с морозный взрыв, иней оседает. Жетон HS спрятан, весь эффект под
	# картой. Выжигание голубое. Владелец выбрал в HsBrowser 2026-10-27.
	"bonelordfrostwhisp": {"frames": "bonelordfrostwhisp", "sounds": "bonelordfrostwhisp",
		"card": {"face": "mini", "reveal": 2.10, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [[0, "BonelordFrostwhisper_CustomSummon_Sound", 0.8], [1.63, "BonelordFrostwhisper_CustomSummon_Impact_Sound", 0.6]],
		# CameraShaker2
		"shakers": [[1.633, 3.149, 0.15, [[0, 0.35], [1, 0]], 0.059]]},
	# Anachronos (CORE_RLK_919) — Adult Brass Dragon: золотая лента времени прилетает слева
	# снизу, закручивается кольцом у точки посадки, на 0.8 с вспышка — пылающее золотое кольцо.
	# Жетон HS спрятан, весь эффект под картой. Выжигание золотое. Владелец выбрал в HsBrowser
	# 2026-10-27.
	"anachronos": {"frames": "anachronos", "sounds": "anachronos",
		"card": {"face": "mini", "reveal": 1.27, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [[0, "Anachronos_CustomSummon_Sound", 0.7], [0.8, "Anachronos_CustomSummon_Impact_Sound", 0.4]],
		# CameraShaker2
		"shakers": [[0.833, 2.183, 0.05, [[0, 1], [1, 0]], 0.075]]},
	# Mister Clocksworth (TIME_038t3) — Ancient Brass Dragon: золотая спираль времени с синим
	# светом закручивается в точке посадки, на 1.52 с взрыв голубого и золотого огня. Жетон HS
	# спрятан, весь эффект под картой. Выжигание голубое. Владелец выбрал в HsBrowser
	# 2026-10-27.
	"misterclocksworth": {"frames": "misterclocksworth", "sounds": "misterclocksworth",
		"card": {"face": "mini", "reveal": 1.99, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [[0, "TIMEFX_MisterClocksWorth_CustomSummon_Sound", 0.4], [1.52, "TIMEFX_MisterClocksWorth_CustomSummon_Impact_Sound", 0.4]],
		# CameraShaker2
		"shakers": [[0.4, 1.383, 0.07, [[0, 0.26], [0.25, 0.97], [0.4, 0.22], [0.68, 0.02], [1, 0]], 0.075], [1.383, 2.183, 0.07, [[0, 0.26], [0.25, 0.65], [0.4, 0.22], [0.68, 0.02], [1, 0]], 0.129]]},
	# Gorm the Worldeater (GDB_842) — Ankheg: из точки посадки бьёт песок и пыль, земля
	# разверзается, на 1.3 с выброс песка. Жетон HS и трещины спрятаны, весь эффект под картой.
	# Выжигание песочное. Владелец выбрал в HsBrowser 2026-10-27.
	"gormtheworldeater": {"frames": "gormtheworldeater", "sounds": "gormtheworldeater",
		"card": {"face": "mini", "reveal": 1.77, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [[0, "GormtheWorldeater_CustomSummon_Sound", 0.5]],
		# CameraShaker2
		"shakers": [[0, 0.583, 0.1, [[0, 1], [1, 0]], 0.075], [0.617, 1.2, 0.1, [[0, 1], [1, 0]], 0.075], [1.3, 2.167, 0.1, [[0, 1], [1, 0]], 0.075]]},
	# Sunsapper Lynessa (VAC_507) — Deva: в точке посадки разгорается солнце, вокруг извиваются
	# огненные змеи, на 1.27 с вспышка, жар гаснет. Жетон HS спрятан, весь эффект под картой.
	# Выжигание огненное. Владелец выбрал в HsBrowser 2026-10-27.
	"sunsapperlynessa": {"frames": "sunsapperlynessa", "sounds": "sunsapperlynessa",
		"card": {"face": "mini", "reveal": 1.74, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [[0, "SunsapperLynessa_CustomSummon_Cast_Sound_", 0.5], [1.27, "SunsapperLynessa_CustomSummon_Impact_Sound_", 0.5]],
		# CameraShaker2
		"shakers": [[1.233, 2.283, 0.07, [[0, 1], [1, 0]], 0.122], [0, 1.15, 0.07, [[0, 0], [1, 1]], 0.049]]},
	# Time Adm'ral Hooktail (TIME_713) — Dust Mephit: золотой вихрь песка прилетает слева (как в
	# HS), на 1.25 с сфера голубого времени. Жетон HS и трещины спрятаны, весь эффект под
	# картой. Выжигание золотое. Владелец выбрал в HsBrowser 2026-10-27.
	"timeadmralhooktail": {"frames": "timeadmralhooktail", "sounds": "timeadmralhooktail",
		"card": {"face": "mini", "reveal": 1.72, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [[0, "Timecap_nHooktail_CustomSummon_Trigger_Sound", 0.6], [1, "Timecap_nHooktail_CustomSummon_Impact_Sound", 0.8]],
		# CameraShaker2
		"shakers": [[1.25, 2.233, 0.3, [[0, 0], [0.04, 0.72], [0.5, 0]], 0.0219]]},
	# Toy Captain Tarim (TOY_813t) — Stone Giant: в точке посадки вспыхивают золотые искры и
	# камни, на 1.5 с золотой взрыв щита. Жетон HS и трещины спрятаны, весь эффект под картой.
	# Выжигание золотое. Владелец выбрал в HsBrowser 2026-10-27.
	"toycaptaintarim": {"frames": "toycaptaintarim", "sounds": "toycaptaintarim",
		"card": {"face": "mini", "reveal": 1.97, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [[0, "TOY_813_ToyCaptainTarim_CustomSummon_Sound", 0.4], [1.5, "TOY_813_ToyCaptainTarim_CustomSummon_Impact_Sound", 0.4]],
		# CameraShaker2
		"shakers": [[0.367, 1.35, 0.04, [[0, 0.26], [0.12, 0.96], [0.39, 0.52], [0.98, 0.43]], 0.208], [1.467, 2.933, 0.06, [[0, 0.26], [0.12, 0.96], [0.47, 0.15], [1, 0]], 0.075]]},
	# Elise, Badlands Savior (WW_392) — Adult Gold Dragon: золотые ленты света сходятся в точку
	# посадки, на 1.43 с вспышка. Жетон HS спрятан, весь эффект под картой. Выжигание золотое.
	# Владелец выбрал в HsBrowser 2026-10-27.
	"elisebadlandssavio": {"frames": "elisebadlandssavio", "sounds": "elisebadlandssavio",
		"card": {"face": "mini", "reveal": 1.90, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [[0, "EliseBadlandsSavior_CustomSummon_Sound", 0.6], [1.43, "EliseBadlandsSavior_CustomSummon_Impact_Sound", 0.6]],
		# CameraShaker2
		"shakers": [[1.417, 2.417, 0.03, [[0, 1], [1, 0]], 0.075]]},
	# Aya, Lotus Kingpin (JAIL_504) — Ancient Black Dragon: фиолетовая туча закрывает верх поля,
	# зелёный удар клинка бьёт в точку посадки, на 1.5 с вспышка. Жетон HS и трещины спрятаны,
	# весь эффект под картой. Выжигание фиолетовое. Владелец выбрал в HsBrowser 2026-10-27.
	"ayalotuskingpin": {"frames": "ayalotuskingpin", "sounds": "ayalotuskingpin",
		"card": {"face": "mini", "reveal": 1.97, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [[0, "AyaLotusKingpin_CustomSummon_Sound", 0.7], [1.5, "AyaLotusKingpin_CustomSummon_Impact_Sound", 0.7]],
		# CameraShaker2
		"shakers": [[1.483, 2.133, 0.06, [[0, 1], [1, 0]], 0.075]]},
	# Endtime Murozond (END_037) — Ancient Blue Dragon: в точке посадки рождается синяя сфера,
	# молнии бьют во все стороны, на 1.25 с удар. Жетон HS, виньетка-прожектор и трещины
	# спрятаны, весь эффект под картой. Выжигание синее. Владелец выбрал в HsBrowser 2026-10-27.
	"endtimemurozond": {"frames": "endtimemurozond", "sounds": "endtimemurozond",
		"card": {"face": "mini", "reveal": 1.72, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [[0, "ENDFX_EndtimeMurozond_CustomSummon_Sound", 0.7], [1.25, "ENDFX_EndtimeMurozond_CustomSummon_Impact_Sound", 0.9]],
		# CameraShaker2
		"shakers": [[1.25, 1.917, 0.5, [[0, 0], [0.04, 0.75], [0.5, 0]], 0.0219], [0.317, 0.983, 0.5, [[0, 0], [0.04, 0.75], [0.09, 0], [0.5, 0]], 0.0219]]},
	# Nozdormu, Bronze Aspect (CATA_473) — Ancient Bronze Dragon: бронзовые кольца времени
	# сходятся к точке посадки, на 1.53 с белая вспышка. Жетон HS и трещины спрятаны, весь
	# эффект под картой. Выжигание бронзовое. Владелец выбрал в HsBrowser 2026-10-27.
	"nozdormubronzeaspe": {"frames": "nozdormubronzeaspe", "sounds": "nozdormubronzeaspe",
		"card": {"face": "mini", "reveal": 2.00, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [[0, "NozdormuBronzeAspect_CustomSummon_Sound", 0.9]],
		# CameraShaker2
		"shakers": [[1.429, 2.267, 0.15, [[0, 1], [1, 0]], 0.0407], [0.483, 1.05, 0.1, [[0, 0], [1, 1]], 0.0124]]},
	# Titanographer Osk (TLC_452t35) — Ancient Copper Dragon: медно-синяя лента пролетает к
	# точке посадки, на 1.48 с огненная вспышка. Жетон HS и трещины спрятаны, весь эффект под
	# картой. Выжигание медное. Владелец выбрал в HsBrowser 2026-10-27.
	"titanographerosk": {"frames": "titanographerosk", "sounds": "titanographerosk",
		"card": {"face": "mini", "reveal": 1.95, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [[0, "TLCFX_Titangrapher_CustomSummon_Sound", 0.5], [1.48, "TLCFX_Titangrapher_CustomSummon_Impact_Sound", 0.5]],
		# CameraShaker2
		"shakers": [[1.233, 1.9, 0.1, [[0, 0], [0.04, 0.75], [0.5, 0]], 0.0219]]},
	# Aranna, Thrill Seeker (VAC_501) — Ancient Green Dragon: ядовито-зелёный рывок слева, на
	# 1.25 с зелёный взрыв скверны. Жетон HS и трещины спрятаны, весь эффект под картой.
	# Выжигание зелёное. Владелец выбрал в HsBrowser 2026-10-27.
	"arannathrillseeker": {"frames": "arannathrillseeker", "sounds": "arannathrillseeker",
		"card": {"face": "mini", "reveal": 1.72, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [[0, "ArannaTheExtreme_CustomSummon_Cast_Sound", 0.8], [1.25, "ArannaTheExtreme_CustomSummon_Impact_Sound", 0.8]],
		# CameraShaker2
		"shakers": [[1.25, 1.917, 0.2, [[0, 0], [0.04, 0.75], [0.5, 0]], 0.0219]]},
	# Ultraxion (CATA_497) — Ancient Silver Dragon: фиолетовый вихрь сумерек снизу, на 1.28 с
	# фиолетовая сфера с молниями. Жетон HS спрятан, весь эффект под картой. Выжигание
	# фиолетовое. Владелец выбрал в HsBrowser 2026-10-27.
	"ultraxion": {"frames": "ultraxion", "sounds": "ultraxion",
		"card": {"face": "mini", "reveal": 1.75, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [[0, "CATAFX_Ultraxion_CustomSummon_Sound", 0.7], [1.28, "CATAFX_Ultraxion_CustomSummon_Impact_Sound", 0.7]],
		# CameraShaker2
		"shakers": [[1.283, 1.75, 0.04, [[0, 1], [1, 0]], 0.075]]},
	# The Lich King (CORE_ICC_314) — Frost Giant: LichKing_CustomSummon (старый префаб, по FSM без
	# Timeline): падает снег, в точку посадки бьёт снежный вихрь, вспыхивает синее пламя, на 2.4 с
	# ледяной удар и ударная волна. Морозная доска на весь экран (RenderTexture_Ground,
	# Offscreen_Ground — без неё метель закрывала экран), души и сугробы доски, трещины спрятаны.
	# Выжигание ледяное голубое. Владелец выбрал в HsBrowser 2026-10-27.
	"thelichking": {"frames": "thelichking", "sounds": "thelichking",
		"card": {"face": "mini", "reveal": 2.87, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# AudioPlayClipAction FSM: ветер 0.7 с начала, удар 0.75 с 1.5 с
		"cues": [[0.0, "LichKing_CustomSummon_Wind_Sound", 0.7], [1.5, "LichKing_CustomSummon_Impact_Sound", 0.75]],
		# MainCameraShakerAction FSM: 0.5 (у нас 0.3) с 2.6 с, 1 с
		"shakers": [[2.6, 3.6, 0.3, [[0.0, 1.0], [1.0, 0.0]], 0.0167]]},
	# Kel'Thuzad (FP1_013) — Owlbear: Kelthuzad_CustomSummon (старый префаб, по FSM): над точкой
	# посадки клубится ледяной туман с аркановым кольцом, на 1.5 с туман оседает ударом. Свечение
	# портрета (GlowQuad, клип legacy) спрятано. Выжигание голубое. Владелец выбрал в HsBrowser
	# 2026-10-27.
	"kelthuzad": {"frames": "kelthuzad", "sounds": "kelthuzad",
		"card": {"face": "mini", "reveal": 1.97, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# AudioPlayClipAction FSM 1.0 с начала
		"cues": [[0.0, "KelThuzad_CustomSummon_Sound_01", 1.0]],
		# MainCameraShakerAction FSM: 0.12 с 1.5 с, 0.6 с
		"shakers": [[1.5, 2.1, 0.12, [[0.0, 1.0], [1.0, 0.0]], 0.0167]]},
	# Prince Malchezaar (LT24_821H) — High Fae Kindguard: Malchezaar_CustomSummon (по FSM): в точке
	# посадки открывается синий портал с кольцами и звёздами, на 1.5 с теневой удар. Свечение
	# миньона и осколки (mesh_ImpactShatter) спрятаны. Выжигание фиолетовое. Владелец выбрал в
	# HsBrowser 2026-10-27.
	"princemalchezaar": {"frames": "princemalchezaar", "sounds": "princemalchezaar",
		"card": {"face": "mini", "reveal": 1.97, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# AudioPlayClipAction FSM: портал 0.9 с начала, удар 0.7 с 1.5 с
		"cues": [[0.0, "MalchezaarReturns_CustomSummon_Emerge_Sound", 0.9], [1.5, "MalchezaarReturns_CustomSummon_Land_Sound", 0.7]]},
	# Altruis the Outcast (TOY_401t2) — Witherbloom Apprentice: Altruis_CustomSummon (по FSM,
	# аниматор CustomSummon): фиолетовые и зелёные вихри скверны кружат над точкой посадки, на
	# 0.95 с огненный выброс. Свечение миньона и трещины спрятаны. Выжигание фиолетовое. Владелец
	# выбрал в HsBrowser 2026-10-27.
	"altruistheoutcast": {"frames": "altruistheoutcast", "sounds": "altruistheoutcast",
		"card": {"face": "mini", "reveal": 1.42, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# AudioPlayClipAction FSM 0.7: с начала и удар с 0.95 с
		"cues": [[0.0, "Altruis_CustomSummon_Sound", 0.7], [0.95, "Altruis_CustomSummon_Impact_Sound", 0.7]],
		# MainCameraShakerAction FSM: 0.05, 0.25 с
		"shakers": [[0.95, 1.2, 0.05, [[0.0, 1.0], [1.0, 0.0]], 0.0167]]},
	# Blood-Queen Lana'thel (CORE_ICC_841) — Red Slaad: BloodQueenLanathel_CustomSummon (старый
	# префаб, по FSM): тьма втягивается в точку посадки, кружат кровавые лопасти, раскрываются
	# крылья сан'лейн, на 1.0 с багровый выброс дыма. Выжигание алое. Владелец выбрал в HsBrowser
	# 2026-10-27.
	"bloodqueenlanathel": {"frames": "bloodqueenlanathel", "sounds": "bloodqueenlanathel",
		"card": {"face": "mini", "reveal": 1.47, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# AudioPlaythroughAction FSM 0.7 x AudioSource 0.6; втягивание (AudioSource частиц) 0.5
		"cues": [[0.0, "BloodQueenLanathel_CustomSummon_Sound", 0.45], [0.0, "Warlock_SiphonSoul_CasterImpact_1", 0.5]],
		# MainCameraShakerAction FSM: 0.15 с 1.0 с, 0.25 с
		"shakers": [[1.0, 1.25, 0.15, [[0.0, 1.0], [1.0, 0.0]], 0.0167]]},
	# Wrathion (Story_06_Wrathion) — Barbed Devil: Wrathion_CustomSummon (по FSM, аниматор
	# FX_Wrathion_CIP с 0.6 с): над точкой посадки бьют красные молнии, тёмный дым, на 1.0 с
	# вспышка. Квад миньона (SummonMinion_quad) спрятан. Выжигание алое. Владелец выбрал в
	# HsBrowser 2026-10-27.
	"wrathion": {"frames": "wrathion", "sounds": "wrathion",
		"card": {"face": "mini", "reveal": 1.47, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# AudioPlaythroughAction FSM 1.0 x AudioSource 0.9
		"cues": [[0.0, "Wrathion_CustomSummon_Sound", 0.9]]},
	# Moroes (KAR_044) — Ice Devil: Moroes_CustomSummon (старый префаб, по FSM): в точке посадки
	# клубится тёмный дым, загораются свечи, на 1.2 с белая вспышка и искры. Выжигание
	# фиолетовое. Владелец выбрал в HsBrowser 2026-10-27.
	"moroes": {"frames": "moroes", "sounds": "moroes",
		"card": {"face": "mini", "reveal": 1.67, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# AudioPlaythroughAction FSM 0.8
		"cues": [[0.0, "Moroes_CustomSummon_Sound", 0.8]]},
	# Arch-Villain Rafaam (CORE_DAL_422) — Horned Devil: ArchVillianRafaam_CustomSummon (по FSM,
	# аниматор): багровые и фиолетовые ленты закручиваются у точки посадки, на 0.5 с молнии и
	# вспышка. Свечение рамки (evil_glow*, оранжевый щит) и трещины спрятаны. Выжигание
	# фиолетовое. Владелец выбрал в HsBrowser 2026-10-27.
	"archvillainrafaam": {"frames": "archvillainrafaam", "sounds": "archvillainrafaam",
		"card": {"face": "mini", "reveal": 0.97, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# AudioPlaythroughAction FSM 0.5
		"cues": [[0.0, "ArchVillianRafaam_CustomSummon", 0.5]],
		# CameraShakerAction FSM: 0.5 (у нас 0.3) с 0.5 с
		"shakers": [[0.5, 1.0, 0.3, [[0.0, 1.0], [1.0, 0.0]], 0.0167]]},
	# Dave Berard (CRED_215, эффект Stormcaller Bru'kan AVFX_BrukanElements, обёртка _Super: спелл
	# AVFX_BrukanElements_CustomSummon_Spell) — Chimera: струи огня, воды и пыли стягиваются к
	# точке посадки, на 1.05 с вспышка стихий, на 1.8 с огненное кольцо. Портрет героя HS и трещины
	# спрятаны. Выжигание огненное. Владелец выбрал в HsBrowser 2026-10-28.
	"daveberard": {"frames": "daveberard", "sounds": "daveberard",
		"card": {"face": "mini", "reveal": 2.27, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# звуки FSM: начало и удар с 1.8 с
		"cues": [[0.0, "AVFX_BrukanElements_CustomSummon_Start_Sound", 0.7], [1.8, "AVFX_BrukanElements_CustomSummon_Impact_Sound", 0.7]],
		# CameraShaker2
		"shakers": [[1.833, 3.717, 0.09, [[0, 1], [0.44, 0.12], [1, 0]], 0.075], [0, 1.083, 0.05, [[0, 0], [0.1, 0.08], [0.9, 0.08], [1, 0]], 0.075], [1.05, 1.733, 0.03, [[0, 0.31], [0.15, 0.8], [1, 0]], 0.075]]},
	# Beaststalker Tavish (AV_113, обёртка _Super: спелл AVFX_TavishBeastStalker_CustomSummon_Spell)
	# — Weretiger: огненный выстрел снизу, на 1.28 с удар — облако пыли. Портрет героя HS и
	# трещины спрятаны. Выжигание оранжевое. Владелец выбрал в HsBrowser 2026-10-27.
	"beaststalkertavish": {"frames": "beaststalkertavish", "sounds": "beaststalkertavish",
		"card": {"face": "mini", "reveal": 1.75, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# Sound Timeline (громкость — AudioSource)
		"cues": [[0, "BeaststalkerTavish_CustomSummon_Sound", 0.6], [0.85, "BeaststalkerTavish_CustomSummon_GunShot_Sound", 0.4], [1.28, "BeaststalkerTavish_CustomSummon_Impact_Sound", 0.4]],
		# CameraShaker2
		"shakers": [[1, 1.567, 0.1, [[0, 1], [1, 0]], 0.075], [1.317, 1.85, 0.1, [[0, 0.82], [0.36, 0.08], [0.44, 0.89], [0.84, 0.03]], 0.075]]},
}
## Дымка розыгрыша (YoggFogg — эффект розыгрыша карты в HS, m_PlayEffectDef): кадры
## запечены с появлением (Intro), долгим средним куском и уходом (End с секунды end).
## Средний кусок [loop[0], loop[1]] повторяется по кругу со сменой через fade секунд;
## уход — переход за end_fade в кадры с end. sound — петля [файл, появление, громкость,
## затухание], end_sound — звук ухода [файл, громкость].
const FOGS := {
	"worldbreaker_fog": {"sounds": "worldbreaker", "loop": [1.5, 4.5], "fade": 0.6, "end": 6.0, "end_fade": 0.3,
		"sound": ["CATA_190h_YoggFogg_Loop", 0.5, 0.8, 1.5], "end_sound": ["CATA_190h_YoggFogg_End", 0.3]},
}

## Для снимков: шаг времени за кадр (0 — настоящее время).
static var fixed_dt := 0.0

var board_area: Control
var _queue: Array[Dictionary] = []
## Розыгрыш (основной эффект): карта, сценарий, его кадры.
var _item: Dictionary = {}
var _script: Dictionary = {}
var _main: _Clip
var _released := false
## Эффекты действий: идут или ждут своей очереди.
var _actions: Array[_Clip] = []
## Часы HsPlay и время, раньше которого не начинается следующее действие.
var _clock := 0.0
var _action_free_at := 0.0
## Дымка.
var _fog: _Fog
var _fog_end_at := -1.0
var _fog_snd := AudioStreamPlayer.new()

var _fog_box := Control.new()
var _under_box := Control.new()
var _card := _CardLayer.new()
var _over_box := Control.new()


static func has(cid: String) -> bool:
	return RECIPES.has(cid)


## Есть ли у карты cid эффект для события kind (supplant, return_spy, vp_site).
static func has_action(cid: String, kind: String) -> bool:
	return has(cid) and (SCRIPTS[RECIPES[cid]].get("actions", {}) as Dictionary).has(kind)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c: Control in [_fog_box, _under_box, _card, _over_box]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(c)
	_fog_snd.bus = Sfx.BUS
	add_child(_fog_snd)
	visible = false
	set_process(false)


## Разыграть карту cid: face — её лицо, quiet — чужая (тише); preview — только
## посмотреть (меню CARD ANIMATIONS): действий не будет, дымка уходит после эффекта.
func play(cid: String, face: Texture2D, quiet: bool = false, preview: bool = false) -> void:
	if not has(cid):
		return
	_queue.append({"cid": cid, "face": face, "quiet": quiet, "preview": preview})
	if _item.is_empty():
		_next()


## Эффект действия карты cid (событие kind) с целью в точке at (глобальные координаты):
## действия идут по очереди, каждое начинается, когда прежнее дошло до своего удара.
func action(cid: String, kind: String, at: Vector2, quiet: bool = false) -> void:
	if not has_action(cid, kind):
		return
	var spec: Dictionary = SCRIPTS[RECIPES[cid]]["actions"][kind]
	var target := _design(at)
	var off := target - Vector2(spec["anchor"])
	if String(spec["follow"]) == "y":
		off.x = 0.0
	var c := _Clip.new(self, String(spec["frames"]), String(SCRIPTS[RECIPES[cid]]["sounds"]), quiet, false)
	c.offset = off
	c.cues = spec.get("cues", [])
	c.set_shakers(spec.get("shakers", []))
	c.delay = maxf(0.0, _action_free_at - _clock)
	_action_free_at = _clock + c.delay + float(spec["lead"])
	_actions.append(c)
	_wake()


## Дымка розыгрыша карты cid: появляется через delay секунд (если её ещё нет).
func fog_on(cid: String, delay: float = 0.0, quiet: bool = false) -> void:
	if not has(cid) or not SCRIPTS[RECIPES[cid]].has("fog"):
		return
	_fog_end_at = -1.0
	if _fog != null and not _fog.ending:
		return
	if _fog != null:
		_fog.free_layers()
	var f: Array = SCRIPTS[RECIPES[cid]]["fog"]
	_fog = _Fog.new(self, String(f[0]), quiet)
	_fog.delay = delay
	_wake()


## Карта отыграла действия: дымка уходит, когда закончится очередь действий.
func fog_off() -> void:
	if _fog == null or _fog.ending:
		return
	_fog_end_at = maxf(_clock, _action_free_at) + 0.6


## Идёт ли розыгрыш, который ещё держит действия карты.
func is_busy() -> bool:
	return not _item.is_empty() and not _released


## Готов ли розыгрыш (для снимков и превью).
func is_ready() -> bool:
	return not _item.is_empty()


func _wake() -> void:
	visible = true
	set_process(true)


## Точка из глобальных координат в координаты расчётного экрана 960x540.
func _design(at: Vector2) -> Vector2:
	return (get_global_transform().affine_inverse() * at) * DESIGN / size


func _next() -> void:
	if _main != null:
		_main.free_layers()
	_main = null
	_item = {}
	_card.show_card(null, Rect2(), 0.0, 1.0)
	if _queue.is_empty():
		return
	_item = _queue.pop_front()
	_script = SCRIPTS[RECIPES[_item["cid"]]]
	_main = _Clip.new(self, String(_script["frames"]), String(_script["sounds"]), bool(_item["quiet"]), true)
	_main.cues = _script["cues"]
	_main.set_shakers(_script.get("shakers", []))
	_released = false
	var f: Array = _script.get("fog", [])
	if not f.is_empty():
		fog_on(_item["cid"], float(f[1]), bool(_item["quiet"]))
	_wake()


func _process(delta: float) -> void:
	var dt := fixed_dt if fixed_dt > 0.0 else delta
	_clock += dt
	if _main != null:
		_main.step(dt)
		_render_card()
		var cs: Dictionary = _script["card"]
		if not _released and _main.t >= float(cs["reveal"]) + float(cs["sweep"]) + float(cs["hold"]) + float(cs["out"]):
			_released = true
			released.emit()
		if _main.finished():
			if bool(_item.get("preview", false)):
				fog_off()
			_next()
	for c in _actions.duplicate():
		c.step(dt)
		if c.finished():
			c.free_layers()
			_actions.erase(c)
	if _fog != null:
		if _fog_end_at >= 0.0 and _clock >= _fog_end_at and not _fog.ending:
			_fog.end()
			_fog_end_at = -1.0
		_fog.step(dt)
		if _fog.finished():
			_fog.free_layers()
			_fog = null
	_set_camera(_camera())
	if _main == null and _actions.is_empty() and _fog == null:
		visible = false
		set_process(false)


## Кадр розыгрыша в момент t (секунды от начала), без звуков — для снимков.
func debug_seek(t: float) -> void:
	if _main != null:
		_main.seek(t)
		_render_card()


## Сдвиг камеры от тряски всех идущих эффектов (дымка не трясётся).
func _camera() -> Vector2:
	var off := Vector2.ZERO
	if _main != null:
		off += _main.shake_offset()
	for c in _actions:
		off += c.shake_offset()
	return off * PX_PER_UNIT * size.y / DESIGN.y


func _set_camera(off: Vector2) -> void:
	off = off.round()
	for c: Control in [_under_box, _card, _over_box]:
		c.position = off
	camera_offset.emit(off)


## Карта: проявляется снизу вверх, стоит, гаснет.
func _render_card() -> void:
	var cs: Dictionary = _script["card"]
	var t0 := float(cs["reveal"])
	if _main.t < t0:
		_card.show_card(null, Rect2(), 0.0, 1.0)
		return
	var shown := clampf((_main.t - t0) / float(cs["sweep"]), 0.0, 1.0)
	var out_at := t0 + float(cs["sweep"]) + float(cs["hold"])
	var a := 1.0 - clampf((_main.t - out_at) / float(cs["out"]), 0.0, 1.0)
	_card.show_card(_item["face"], _card_rect(), a, shown)


## Лицо карты для розыгрыша cid: полноформатное или миниатюра — как в сценарии (под него
## запечён горящий контур появления).
static func face_of(cid: String, art: String = "") -> Texture2D:
	var cs: Dictionary = SCRIPTS[RECIPES[cid]]["card"]
	return CardView.mini_texture(cid, art) if String(cs.get("face", "full")) == "mini" else CardView.pixel_texture(cid, art)


## Где карта на экране: в своём размере, центр сценария (960x540) -> размер HsPlay.
func _card_rect() -> Rect2:
	var k := size / DESIGN
	var face: Texture2D = _item["face"]
	var s := (face.get_size() if face != null else CardView.PIXEL_SIZE) * k
	var c := Vector2(_script["card"]["center"]) * k
	return Rect2((c - s * 0.5).round(), s.round())


## Точки тряски, как ShakerHelper.Initialize в Hearthstone: 30 направлений, каждое
## следующее повёрнуто на 100..260 градусов от прежнего (камеру бросает туда-обратно),
## точка — на эллипсе амплитуды.
static func _shake_path(amount: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var a := randf_range(0.0, 6.283)
	for i in 30:
		if i > 0:
			a = randf_range(a + 1.745, a + 4.538)
		pts.append(Vector2(cos(a), sin(a)) * amount)
	return pts


## Кривая силы HS [[доля, сила], ...]: гладкая (кубическая Эрмита с наклонами,
## не дающими выбросов, как «auto» у Unity).
static func _curve(keys: Array, u: float) -> float:
	if u <= float(keys[0][0]):
		return float(keys[0][1])
	for j in range(1, keys.size()):
		var x0 := float(keys[j - 1][0])
		var x1 := float(keys[j][0])
		if u > x1:
			continue
		var y0 := float(keys[j - 1][1])
		var y1 := float(keys[j][1])
		var h := x1 - x0
		var m0 := _slope(keys, j - 1)
		var m1 := _slope(keys, j)
		var v := (u - x0) / h
		var v2 := v * v
		var v3 := v2 * v
		return (2 * v3 - 3 * v2 + 1) * y0 + (v3 - 2 * v2 + v) * h * m0 + (-2 * v3 + 3 * v2) * y1 + (v3 - v2) * h * m1
	return float(keys[-1][1])


static func _slope(keys: Array, j: int) -> float:
	if j == 0 or j == keys.size() - 1:
		return 0.0
	var d0 := (float(keys[j][1]) - float(keys[j - 1][1])) / (float(keys[j][0]) - float(keys[j - 1][0]))
	var d1 := (float(keys[j + 1][1]) - float(keys[j][1])) / (float(keys[j + 1][0]) - float(keys[j][0]))
	if d0 * d1 <= 0.0:
		return 0.0
	return 2.0 / (1.0 / d0 + 1.0 / d1)


## Набор запечённых кадров: meta, подгрузка в фоне, кадр по времени.
class _Frames:
	var dir: String
	var fps := 60.0
	var count := 0
	var under := {}
	var _cache := {}

	func _init(name: String) -> void:
		dir = BAKED + name + "/"
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "meta.json"))
		fps = float(meta["fps"])
		count = int(meta["frames"])
		for i in meta.get("under", []):
			under[int(i)] = true

	func length() -> float:
		return count / fps

	func index(t: float) -> int:
		return clampi(floori(t * fps), 0, count - 1)

	func path(track: String, i: int) -> String:
		return dir + "%s%03d.png" % [track, i]

	func request(track: String, i: int) -> void:
		if i < 0 or i >= count or (track == "u" and not under.has(i)):
			return
		var key := track + str(i)
		if _cache.has(key):
			return
		_cache[key] = null
		ResourceLoader.load_threaded_request(path(track, i), "Texture2D")

	func ready(i: int) -> bool:
		return ResourceLoader.load_threaded_get_status(path("f", i)) == ResourceLoader.THREAD_LOAD_LOADED

	func texture(track: String, i: int) -> Texture2D:
		if track == "u" and not under.has(i):
			return null
		var key := track + str(i)
		if _cache.has(key):
			var t: Texture2D = _cache[key]
			if t == null:
				t = ResourceLoader.load_threaded_get(path(track, i))
				_cache[key] = t
			return t
		var tex := load(path(track, i)) as Texture2D
		_cache[key] = tex
		return tex

	## Держать подгруженными кадры starts[j]..starts[j]+AHEAD (и подгрузить их в фоне),
	## остальные забыть.
	func keep(starts: Array) -> void:
		var need := {}
		for s: int in starts:
			for k in range(maxi(s, 0), mini(s + AHEAD, count)):
				need[k] = true
				request("f", k)
				request("u", k)
		for key: String in _cache.keys():
			if not need.has(int(key.substr(1))):
				_cache.erase(key)


## Один идущий эффект: кадры (над картой и под ней), сдвиг на экране, звуки, тряска.
class _Clip:
	var host: HsPlay
	var frames: _Frames
	var sounds: String
	var quiet := false
	var t := 0.0
	var delay := 0.0
	var offset := Vector2.ZERO
	var cues: Array = []
	var shakers: Array = []
	var shake_points: Array = []
	var over := _FrameLayer.new()
	var under_layer := _FrameLayer.new()
	var _cue_t := -1.0
	var _warm := WARM
	var _warm_asked := 0
	var _shown := -1

	func _init(h: HsPlay, name: String, sound_dir: String, q: bool, with_under: bool) -> void:
		host = h
		frames = _Frames.new(name)
		sounds = sound_dir
		quiet = q
		_warm = mini(WARM, frames.count)
		host._over_box.add_child(over)
		if with_under or not frames.under.is_empty():
			host._under_box.add_child(under_layer)

	func set_shakers(list: Array) -> void:
		shakers = list
		shake_points = []
		for sh: Array in list:
			shake_points.append(HsPlay._shake_path(float(sh[2])))

	func finished() -> bool:
		return _warm == 0 and delay <= 0.0 and t >= frames.length()

	func free_layers() -> void:
		over.queue_free()
		under_layer.queue_free()

	func step(dt: float) -> void:
		if delay > 0.0:
			delay -= dt
			_preload()
			return
		if not _preload():
			return
		t += dt
		_cues()
		_show()

	func seek(time: float) -> void:
		t = time
		_warm = 0
		_show()

	## Первые кадры распаковываются (по два за кадр игры: готовые уходят в видеокарту
	## понемногу); часы эффекта стоят, пока они не готовы.
	func _preload() -> bool:
		if _warm == 0:
			return true
		for k in range(_warm_asked, mini(_warm_asked + 2, _warm)):
			frames.request("f", k)
			frames.request("u", k)
		_warm_asked = mini(_warm_asked + 2, _warm)
		for k in _warm:
			if k >= _warm_asked or not frames.ready(k):
				return false
		_warm = 0
		return delay <= 0.0

	func _show() -> void:
		var i := frames.index(t)
		var k := host.size / DESIGN
		for l: _FrameLayer in [over, under_layer]:
			l.position = (offset * k).round()
			l.size = host.size
		if i != _shown:
			_shown = i
			over.show_frame(frames.texture("f", i))
			under_layer.show_frame(frames.texture("u", i))
			frames.keep([i])

	func _cues() -> void:
		for c: Array in cues:
			if _cue_t < float(c[0]) and t >= float(c[0]):
				var vol := float(c[2]) if c.size() > 2 else 1.0
				var pitch := float(c[3]) if c.size() > 3 else 1.0
				Sfx.play_file(SOUNDS + sounds + "/" + String(c[1]) + ".wav", quiet, linear_to_db(vol), pitch)
		_cue_t = t

	## Сдвиг камеры в момент t, как ShakerHelper.UpdateTarget: доля клипа -> номер точки
	## (каждые interval секунд — следующая), переход между точками с двойным косинусным
	## сглаживанием, умножение на кривую силы. В мире HS вверх экрана — +z, сдвиг камеры
	## вверх двигает картинку вниз. В единицах мира HS.
	func shake_offset() -> Vector2:
		var off := Vector2.ZERO
		if delay > 0.0 or _warm > 0:
			return off
		for n in shakers.size():
			var sh: Array = shakers[n]
			var t0 := float(sh[0])
			var t1 := float(sh[1])
			if t < t0 or t >= t1:
				continue
			var u := (t - t0) / (t1 - t0)
			var s := u * (t1 - t0) / float(sh[4])
			var i := floori(s)
			var w := 1.0 - (0.5 + 0.5 * cos((s - i) * PI))
			w = 1.0 - (0.5 + 0.5 * cos(w * PI))
			var pts: PackedVector2Array = shake_points[n]
			var p := pts[i % pts.size()].lerp(pts[(i + 1) % pts.size()], w) * HsPlay._curve(sh[3], u)
			off += Vector2(-p.x, p.y)
		return off


## Дымка: появление, средний кусок по кругу (смена через fade), уход по запросу; две
## дорожки кадров для плавных переходов. Не трясётся.
class _Fog:
	var host: HsPlay
	var frames: _Frames
	var spec: Dictionary
	var quiet := false
	var t := 0.0
	var delay := 0.0
	var ending := false
	var _end_t := 0.0
	var _end_phase := 0.0
	var _a := _FrameLayer.new()
	var _b := _FrameLayer.new()
	var _warm := WARM
	var _warm_asked := 0
	var _started := false

	func _init(h: HsPlay, name: String, q: bool) -> void:
		host = h
		frames = _Frames.new(name)
		spec = FOGS[name]
		quiet = q
		_warm = mini(WARM, frames.count)
		host._fog_box.add_child(_b)
		host._fog_box.add_child(_a)

	func free_layers() -> void:
		_a.queue_free()
		_b.queue_free()
		host._fog_snd.stop()

	var _dead := false

	func finished() -> bool:
		return _dead or (ending and float(spec["end"]) + (t - _end_t) >= frames.length())

	func end() -> void:
		if not _started:
			# дымка ещё не появилась — просто не показываем её
			ending = true
			_dead = true
			return
		ending = true
		_end_t = t
		_end_phase = _phase(t)
		var snd: Array = spec["end_sound"]
		Sfx.play_file(SOUNDS + String(spec["sounds"]) + "/" + String(snd[0]) + ".wav", quiet, linear_to_db(float(snd[1])))

	## Время в кадрах дымки до ухода: появление, затем средний кусок по кругу.
	func _phase(time: float) -> float:
		var a := float(spec["loop"][0])
		var b := float(spec["loop"][1])
		if time < b:
			return time
		return a + fmod(time - b, b - a)

	func step(dt: float) -> void:
		if delay > 0.0:
			delay -= dt
			_preload()
			return
		if not _preload():
			return
		if not _started:
			_started = true
			var snd: Array = spec["sound"]
			host._fog_snd.stream = load(SOUNDS + String(spec["sounds"]) + "/" + String(snd[0]) + ".wav")
			if Sfx.volume > 0.0:
				host._fog_snd.play()
		t += dt
		_sound()
		_show()

	func _preload() -> bool:
		if _warm == 0:
			return true
		for k in range(_warm_asked, mini(_warm_asked + 2, _warm)):
			frames.request("f", k)
		_warm_asked = mini(_warm_asked + 2, _warm)
		for k in _warm:
			if k >= _warm_asked or not frames.ready(k):
				return false
		_warm = 0
		return delay <= 0.0

	func _sound() -> void:
		var snd: Array = spec["sound"]
		var k := clampf(t / float(snd[1]), 0.0, 1.0)
		if ending:
			k *= 1.0 - clampf((t - _end_t) / float(snd[3]), 0.0, 1.0)
		host._fog_snd.volume_db = linear_to_db(maxf(k * float(snd[2]), 0.0001)) + (Sfx.OTHER_DB if quiet else 0.0)

	func _show() -> void:
		var main_t: float
		var side_t := -1.0
		var side_w := 0.0
		if ending:
			var d := t - _end_t
			main_t = float(spec["end"]) + d
			side_t = _end_phase + d
			side_w = 1.0 - clampf(d / float(spec["end_fade"]), 0.0, 1.0)
		else:
			main_t = _phase(t)
			var a := float(spec["loop"][0])
			var b := float(spec["loop"][1])
			if t >= b:
				# начало нового круга: прошлый круг продолжается за b и тает
				side_t = main_t + (b - a)
				side_w = 1.0 - clampf((main_t - a) / float(spec["fade"]), 0.0, 1.0)
		var i := frames.index(main_t)
		_a.size = host.size
		_b.size = host.size
		_a.show_frame(frames.texture("f", i), 1.0 - side_w if side_w > 0.0 else 1.0)
		var keep := [i]
		if side_w > 0.0:
			var j := frames.index(side_t)
			_b.show_frame(frames.texture("f", j), side_w)
			keep.append(j)
		else:
			_b.show_frame(null)
		# заранее в памяти: начало круга (переход с конца куска) и начало ухода
		if not ending:
			keep.append(frames.index(float(spec["loop"][0])))
			keep.append(frames.index(float(spec["end"])))
		frames.keep(keep)


## Кадр эффекта на весь экран: premultiplied-альфа (One, OneMinusSrcAlpha). Кадры сжаты
## WebP с потерями: цвет шумит, альфа точная — пиксель с нулевой альфой пустой, его шум
## не рисуется (у настоящих пикселей эффекта альфа не ниже 1/255). alpha — общая
## прозрачность кадра (переходы дымки).
## Пиксель-арт (владелец, 2026-10-21): кадр рисуется крупным пикселем PIXEL_BLOCK x
## PIXEL_BLOCK пикселей игры (без сглаживания), яркость — PIXEL_LEVELS ровными ступенями
## с сохранением оттенка (поканальные ступени давали грязные оливковые тона), прозрачность
## — PIXEL_ALPHA ступенями; без дизеринга (решётка Байера по дымке рябила поверх
## интерфейса). Ступени — в premultiplied-виде: чистый свет (альфа ~0) остаётся светом.
const PIXEL_LEVELS := 6.0
const PIXEL_ALPHA := 8.0
const PIXEL_BLOCK := 2.0
const FRAME_SHADER := "shader_type canvas_item;\nrender_mode blend_premul_alpha;\n" \
	+ "uniform float alpha = 1.0;\nuniform float levels = 7.0;\nuniform float alpha_levels = 4.0;\n" \
	+ "uniform float block = 1.0;\n" \
	+ "float step_to(float v, float n, float d) { return clamp(floor(v * n + d) / n, 0.0, 1.0); }\n" \
	+ "void fragment() {\n" \
	+ "\tvec2 tsz = vec2(textureSize(TEXTURE, 0));\n\tvec2 px = floor(UV * tsz / block) * block;\n" \
	+ "\tvec4 c = texture(TEXTURE, (px + 0.5 * block) / tsz);\n" \
	+ "\tif (c.a <= 0.0) { COLOR = vec4(0.0); } else {\n" \
	+ "\t\tfloat d = 0.5;\n" \
	+ "\t\tfloat v = max(c.r, max(c.g, c.b));\n" \
	+ "\t\tvec4 q = vec4(v > 0.0 ? c.rgb * (step_to(v, levels, d) / v) : vec3(0.0), step_to(c.a, alpha_levels, d));\n" \
	+ "\t\tCOLOR = q * alpha;\n\t}\n}\n"
static var _frame_shader: Shader


class _FrameLayer extends Control:
	var _tex: Texture2D
	var _mat := ShaderMaterial.new()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if HsPlay._frame_shader == null:
			HsPlay._frame_shader = Shader.new()
			HsPlay._frame_shader.code = FRAME_SHADER
		_mat.shader = HsPlay._frame_shader
		_mat.set_shader_parameter("levels", PIXEL_LEVELS)
		_mat.set_shader_parameter("alpha_levels", PIXEL_ALPHA)
		_mat.set_shader_parameter("block", PIXEL_BLOCK)
		material = _mat

	func show_frame(tex: Texture2D, alpha: float = 1.0) -> void:
		_mat.set_shader_parameter("alpha", alpha)
		if tex != _tex:
			_tex = tex
			queue_redraw()

	func _draw() -> void:
		if _tex != null:
			draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)


## Карта: видна нижняя часть shown (0..1) — огонь проявляет её снизу вверх.
class _CardLayer extends Control:
	var _face: Texture2D
	var _rect := Rect2()
	var _alpha := 0.0
	var _shown := 1.0

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func show_card(face: Texture2D, r: Rect2, a: float, shown: float) -> void:
		_face = face
		_rect = r
		_alpha = a
		_shown = shown
		queue_redraw()

	func _draw() -> void:
		if _face == null or _alpha <= 0.0 or _shown <= 0.0:
			return
		var h := roundf(_rect.size.y * _shown)
		var src := Rect2(0.0, float(_face.get_height()) * (1.0 - h / _rect.size.y), float(_face.get_width()),
			float(_face.get_height()) * h / _rect.size.y)
		draw_texture_rect_region(_face, Rect2(_rect.position.x, _rect.end.y - h, _rect.size.x, h), src, Color(1, 1, 1, _alpha))
