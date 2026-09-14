#!/usr/bin/env python3
"""
Извлекает данные доски Demonweb из Lua-скрипта мода TTS в JSON.

Источник: main_lua_script.lua (мод Tabletop Simulator "Tyrants of the Underdark [SCRIPTED]")
Выход:    data/board/*.json  — потребляется ядром правил в Godot.

Извлекаются:
  - site_data.json      сайты по гексам: имя, VP, троп-слоты (локальные координаты), стартовые белые войска
  - route_slots.json    троп-слоты на маршрутах (туннельные "кольца" между сайтами)
  - hex_edges.json      какие из 6 рёбер каждого гекса имеют туннельный выход (в неповёрнутой ориентации)
  - layouts.json        раскладки слотов на 2/3/4 игроков + адъяценция слотов
  - markers.json        данные маркеров контроля для 7 именованных сайтов
"""

import json
import math
import re
from pathlib import Path

SRC = Path(__file__).resolve().parent.parent / "main_lua_script.lua"
OUT = Path(__file__).resolve().parent.parent / "data" / "board"

# константы из Lua
HEX_SCALE = 8.5          # demonwebHexScale
ART_REF_SCALE = 7.0      # demonwebHexArtReferenceScale
R = HEX_SCALE
SQRT3 = math.sqrt(3)

DIR_CYCLE = ["N", "NE", "SE", "S", "SW", "NW"]


def read_source() -> str:
    return SRC.read_text(encoding="utf-8")


def strip_comments(s: str) -> str:
    """Убирает однострочные Lua-комментарии, не трогая содержимое строк."""
    out = []
    for line in s.split("\n"):
        res, i, in_str, quote = [], 0, False, ""
        while i < len(line):
            c = line[i]
            if in_str:
                if c == "\\":
                    res.append(line[i:i + 2]); i += 2; continue
                if c == quote:
                    in_str = False
                res.append(c); i += 1; continue
            if c in ("'", '"'):
                in_str, quote = True, c
                res.append(c); i += 1; continue
            if c == "-" and i + 1 < len(line) and line[i + 1] == "-":
                break
            res.append(c); i += 1
        out.append("".join(res))
    return "\n".join(out)


def extract_block(src: str, name: str) -> str:
    """Возвращает текст Lua-таблицы `name = { ... }` со сбалансированными скобками."""
    m = re.search(rf"^{re.escape(name)}\s*=\s*\{{", src, re.M)
    if not m:
        raise KeyError(f"не найдена таблица {name}")
    start = m.end() - 1
    depth, i, in_str, quote = 0, start, False, ""
    while i < len(src):
        c = src[i]
        if in_str:
            if c == "\\":
                i += 2; continue
            if c == quote:
                in_str = False
        elif c in ("'", '"'):
            in_str, quote = True, c
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return src[start:i + 1]
        i += 1
    raise ValueError(f"незакрытая таблица {name}")


def lua_to_py(block: str):
    """
    Конвертирует Lua-табличный литерал в структуру Python.
    Поддерживает: вложенные таблицы, key=value, позиционные элементы,
    числа, строки, true/false, и арифметику с R/SQRT3 (для раскладок слотов).
    """
    toks = re.findall(
        r"""\{|\}|,|=|'[^']*'|"[^"]*"|[A-Za-z_][A-Za-z0-9_]*|-?\d+\.?\d*(?:[eE][-+]?\d+)?|\*|/|\+|-|\(|\)""",
        block,
    )
    pos = 0

    def peek():
        return toks[pos] if pos < len(toks) else None

    def eat(expected=None):
        nonlocal pos
        t = toks[pos]
        if expected and t != expected:
            raise ValueError(f"ожидалось {expected}, получено {t}")
        pos += 1
        return t

    def parse_expr():
        """Арифметическое выражение: числа, R, SQRT3, * / + -."""
        nonlocal pos
        depth = 0
        start = pos
        while pos < len(toks):
            t = toks[pos]
            if t == "(":
                depth += 1
            elif t == ")":
                if depth == 0:
                    break
                depth -= 1
            elif depth == 0 and t in (",", "}", "="):
                break
            pos += 1
        expr = " ".join(toks[start:pos])
        return eval(expr, {"__builtins__": {}}, {"R": R, "SQRT3": SQRT3, "math": math})

    def parse_value():
        nonlocal pos
        t = peek()
        if t == "{":
            return parse_table()
        if t in ("true", "false"):
            eat()
            return t == "true"
        if t == "nil":
            eat()
            return None
        if t and (t[0] in ("'", '"')):
            eat()
            return t[1:-1]
        return parse_expr()

    def parse_table():
        nonlocal pos
        eat("{")
        result_dict, result_list = {}, []
        while True:
            t = peek()
            if t == "}":
                eat("}")
                break
            if t == ",":
                eat(","); continue
            # key = value ?
            if (
                t is not None
                and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", t)
                and pos + 1 < len(toks)
                and toks[pos + 1] == "="
            ):
                key = eat(); eat("=")
                result_dict[key] = parse_value()
            elif t == "[":
                raise NotImplementedError("[key] = value не встречается в целевых таблицах")
            else:
                result_list.append(parse_value())
        return result_dict if result_dict else result_list

    return parse_table()


def scale_local(v: float) -> float:
    """
    Все локальные координаты (круги сайтов, кольца маршрутов, шпионские смещения,
    позиции маркеров) замерены в ОДНОЙ системе — при ART_REF_SCALE.

    Комментарий в Lua у demonwebConnectorRingsByTile ("Values are already in world
    units (not scaled)") противоречит коду: demonwebSpawnSites применяет
    hexArtScale = demonwebHexScale / demonwebHexArtReferenceScale и к кольцам,
    и к кругам сайтов одинаково. Верен код, а не комментарий.

    Для вывода топологии абсолютный масштаб не важен вообще — важны только
    относительные расстояния и направления, — поэтому координаты хранятся
    как измерены, а коэффициент отдаётся отдельно (см. meta.json) для отрисовки.
    """
    return v


def build_site_data(src: str) -> dict:
    raw = lua_to_py(extract_block(src, "demonwebSiteData"))
    out = {}
    for hex_id, sites in raw.items():
        if isinstance(sites, dict):      # одиночный сайт без обёртки в список
            sites = [sites]
        out[hex_id] = []
        for idx, s in enumerate(sites):
            circles = [
                {"id": f"{hex_id}_{idx}_{i}", "x": scale_local(c[0]), "z": scale_local(c[1])}
                for i, c in enumerate(s.get("circles", []))
            ]
            out[hex_id].append({
                "id": f"{hex_id}_site{idx}",
                "name": s["name"],
                "vp": s["points"],
                "troop_slots": circles,
                "initial_white_troops": s.get("initialTroops", 0),
                "spy_offsets": [scale_local(x) for x in s.get("spyOffsets", [])],
                "spy_z_offset": scale_local(s.get("spyZOffset", 0.0)),
            })
    return out


# ---------------------------------------------------------------------------
# Расхождения данных мода TTS с печатным артом, найденные сверкой по картинкам
# (tools/calibrate_hexes.py + tools/snap_slots_to_art.py). Оцифровка в Lua
# делалась человеком на глаз, и в двух местах она расходится с рисунком.
#
# A7: в Lua ему приписан общий с A4-A8 список из 7 колец — комментарий там
#     гласит "A4-A8 ... shared across all five since they use the same template".
#     Для A4/A5/A6/A8 это верно (проверено численно: совпадение до 0.01 единицы),
#     но у A7 на арте ОДНО кольцо в центре и 6 туннелей прямо к рёбрам.
#     Лишние 6 троп-слотов — это лишние места под войска, то есть прямое
#     влияние на правила (deploy, Presence, маршруты). Оставляем только центр.
#
# Ошибка положения кольца B1 (север, было {-0.47, 4.400} вместо ~{-0.05, 4.40})
# здесь НЕ правится: её снимает tools/snap_slots_to_art.py, подтягивая слот
# в центр найденного печатного круга. Здесь только то, что снапом не лечится —
# лишние или недостающие слоты.
# A2: оба «кольца» из Lua — фантомные. Они стоят ВНУТРИ блока с правилами
#     региона (Fogtown/Gallenghast/Darkflame), поверх букв слов CONTROL и TOTAL.
#     Это не троп-слоты вообще. Проверено увеличением арта: tools/render_labelled_hex.py
#     ставит их на текст, а не на печатные кружки туннелей. Три локации A2
#     соединены между собой напрямую, без промежуточных мест под войска.
ROUTE_SLOT_OVERRIDES = {
    # оставить только кольца с этими индексами из списка Lua
    "A7": {"keep_indices": [3]},   # индекс 3 = {0.092, -0.066}, центральный хаб
    "A2": {"keep_indices": []},    # оба фантомные, см. комментарий выше
}
# ---------------------------------------------------------------------------


def build_route_slots(src: str) -> dict:
    """
    Туннельные "кольца" вдоль маршрутов = троп-слоты на маршрутах.
    Координаты в Lua уже в мировых единицах (не масштабируются), см. комментарий
    "Values are already in world units (not scaled)".
    Для каждого слота считаем угол от центра гекса — по нему определяется,
    к какому из 6 рёбер он тяготеет (нужно для сшивания графа между гексами).
    """
    raw = lua_to_py(extract_block(src, "demonwebConnectorRingsByTile"))
    # мировое направление -> угол (пойнти-топ гексы, рёбра через 60 градусов)
    dir_angles = {"N": 90, "NE": 30, "SE": -30, "S": -90, "SW": -150, "NW": 150}
    out = {}
    for hex_id, rings in raw.items():
        override = ROUTE_SLOT_OVERRIDES.get(hex_id)
        if override and "keep_indices" in override:
            keep = set(override["keep_indices"])
            rings = [r for i, r in enumerate(rings) if i in keep]
        slots = []
        for i, (x, z) in enumerate(rings):
            radius = math.hypot(x, z)
            angle = math.degrees(math.atan2(z, x))
            # ближайшее ребро по углу
            best_dir, best_delta = None, 999.0
            for d, a in dir_angles.items():
                delta = abs((angle - a + 180) % 360 - 180)
                if delta < best_delta:
                    best_dir, best_delta = d, delta
            slots.append({
                "id": f"{hex_id}_route{i}",
                "x": x,
                "z": z,
                "radius": radius,
                # слот считается граничным (кандидат на сшивание с соседним гексом),
                # если лежит достаточно далеко от центра гекса
                "edge_dir": best_dir,
                "edge_angle_delta": best_delta,
            })
        out[hex_id] = slots
    return out


# Правки таблицы demonwebEdgeConnByTile по печатному арту.
#
# Исходная таблица в моде размечена вручную и неполна: у 21 тайла из 27 просто
# проставлено «открыты все шесть рёбер», а «false» автор расставил только там,
# где заметил. Каждая правка ниже проверена инструментом tools/verify_hex_edges.py
# (белый штрих туннеля на самой границе шестиугольника) и глазами по увеличенным
# фрагментам арта.
#
# Первым расхождение заметил владелец игры: на картинке доски ребро C5-C3 было
# красным (не сомкнулось), хотя на арте туннель C5 доходит до края.
HEX_EDGE_OVERRIDES = {
    # у пяти B-тайлов на южном ребре стоит карточка локации, туннеля туда нет
    # (у B2 это единственное ребро, которое автор таблицы отметил верно)
    "B1": {"S": False},
    "B3": {"S": False},
    "B4": {"S": False},
    "B5": {"S": False},
    "B6": {"S": False},
    "C5": {"SE": True},    # туннель от Ath-Qua выходит на юго-восточное ребро
    "C8": {"N": False},    # на северном ребре карточка Enzithir, туннеля нет
    "X3": {"SE": True, "SW": True},
    "X4": {"N": False},
}


def build_hex_edges(src: str) -> dict:
    raw = lua_to_py(extract_block(src, "demonwebEdgeConnByTile"))
    result = {}
    for hex_id, edges in raw.items():
        fixed = {d: bool(edges.get(d)) for d in DIR_CYCLE}
        fixed.update(HEX_EDGE_OVERRIDES.get(hex_id, {}))
        result[hex_id] = [d for d in DIR_CYCLE if fixed[d]]
    return result


def build_layouts(src: str) -> dict:
    layouts = {}
    for n in (2, 3, 4):
        slots = lua_to_py(extract_block(src, f"demonweb{n}PlayerSlots"))
        adj = lua_to_py(extract_block(src, f"demonweb{n}PlayerAdjacency"))
        layouts[str(n)] = {
            "slots": {
                name: {"x": v[0], "z": v[1], "base_rotation": v[2]}
                for name, v in slots.items()
            },
            "adjacency": [{"a": e["a"], "b": e["b"], "dir": e["dir"]} for e in adj],
        }
    return layouts


def build_markers(src: str) -> dict:
    raw = lua_to_py(extract_block(src, "demonwebMarkerData"))
    out = {}
    for hex_id, m in raw.items():
        out[hex_id] = {
            "site_name": m.get("siteName"),
            "marker_pos": [scale_local(x) for x in m.get("markerPos", [])],
            "total_control_variants": [
                {"vp": v.get("vp", 0)} for v in m.get("variants", [])
            ],
        }
    return out


def main():
    src = strip_comments(read_source())
    OUT.mkdir(parents=True, exist_ok=True)

    artifacts = {
        "site_data.json": build_site_data(src),
        "route_slots.json": build_route_slots(src),
        "hex_edges.json": build_hex_edges(src),
        "layouts.json": build_layouts(src),
        "markers.json": build_markers(src),
        "meta.json": {
            "hex_scale": HEX_SCALE,
            "art_reference_scale": ART_REF_SCALE,
            "art_to_world": HEX_SCALE / ART_REF_SCALE,
            "note": (
                "Локальные координаты хранятся как измерены (в системе арта гекса). "
                "Для мировых позиций умножать на art_to_world. Топология от масштаба "
                "не зависит."
            ),
        },
    }
    for fname, data in artifacts.items():
        (OUT / fname).write_text(
            json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        print(f"  {fname:20s} ok")

    sites = artifacts["site_data.json"]
    total_sites = sum(len(v) for v in sites.values())
    total_slots = sum(len(s["troop_slots"]) for v in sites.values() for s in v)
    total_white = sum(s["initial_white_troops"] for v in sites.values() for s in v)
    print(f"\nгексов с сайтами: {len(sites)}")
    print(f"сайтов:           {total_sites}")
    print(f"троп-слотов:      {total_slots}")
    print(f"белых войск:      {total_white}")
    print(f"гексов с рёбрами: {len(artifacts['hex_edges.json'])}")
    routes = artifacts["route_slots.json"]
    print(f"слотов маршрутов: {sum(len(v) for v in routes.values())} на {len(routes)} гексах")
    radii = sorted(s["radius"] for v in routes.values() for s in v)
    print(f"  радиусы слотов: min={radii[0]:.2f} медиана={radii[len(radii)//2]:.2f} max={radii[-1]:.2f}")


if __name__ == "__main__":
    main()
