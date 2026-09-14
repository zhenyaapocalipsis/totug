#!/usr/bin/env python3
"""
Собирает картинку ВСЕЙ доски: раскладывает гексы по местам с их поворотами
и рисует поверх троп-слоты и связи графа.

Нужен для проверки глазами того, что текстовые тесты проверить не могут:
похоже ли собранное на настоящую доску, туда ли встали гексы, состыковались ли
туннели на границах, и не висит ли где-то кусок карты сам по себе.

Раскладка и повороты берутся из board_layout.json, который ВЫГРУЖАЕТ САМ ДВИЖОК
(godot/tests/diagnose_board.gd). Это принципиально: пока рендерер считал повороты
своей копией алгоритма, он расходился с движком — показывал 13 состыковавшихся
рёбер там, где движок собирал 12. Картинка обязана показывать то, что строит
игра, иначе проверять по ней нечего.

Запуск:
    godot --headless --path godot --script res://tests/diagnose_board.gd
    python3 tools/render_board.py "путь/к/board hexes" [выходной_файл]
"""

import json
import math
import sys
from pathlib import Path

import cv2
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data" / "board"

# Геометрия гексагона измеряется по самому арту (см. hex_geometry): хардкодить
# нельзя, первая версия брала высоту 1602 px из выпуклой оболочки, а это была
# оболочка, раздутая чёрными точками СНАРУЖИ тайла. Настоящая высота 1562 px,
# и отношение ширина/высота сходится с идеальным 2/sqrt(3) = 1.1547.

# Во сколько раз ужимаем итоговую картинку — иначе доска в 9 тайлов
# получается около 6000 px и весит десятки мегабайт.
OUTPUT_SCALE = 0.22


def load(name):
    return json.loads((DATA / f"{name}.json").read_text(encoding="utf-8"))


def _hex_metrics(img):
    """
    Центр и радиус шестиугольника тайла.

    Форма не угадывается по контуру, а вычисляется. Два подвоха в арте:

    1. Снаружи тайла, на серединах рёбер, напечатаны чёрные точки — концы
       туннелей. Выпуклая оболочка растягивается, чтобы их охватить, и
       затягивает внутрь белый фон (это была белая обводка вокруг тайлов),
       а approxPolyDP с достаточным допуском срезает настоящие углы
       (на B1 отрубался верхний правый угол).
    2. Белые туннели РАЗРЕЗАЮТ тёмный арт на несколько кусков. У A4-A8, A9, X2
       «крупнейшая связная область» — лишь часть тайла: у A7 шесть прямых
       туннелей режут его на секторы, и центр уезжал в (462, 1074) вместо
       (908, 908), а радиус выходил вдвое меньше настоящего.

    Поэтому связные области не используются вовсе. Берутся все не-белые
    пиксели (с чисткой одиночного шума), и по ним — крайние левый и правый
    столбцы. Это ровно левая и правая вершины шестиугольника: точки-концы
    туннелей сидят на серединах рёбер и в крайние столбцы не попадают.
    Обе вершины лежат на высоте центра, отсюда и центр, и радиус.
    """
    mask = np.any(img < 205, axis=2).astype(np.uint8)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    columns = np.flatnonzero(mask.sum(axis=0) > 0)
    x_min, x_max = int(columns[0]), int(columns[-1])

    def column_centre(x):
        band = mask[:, x:x + 3]
        ys = np.flatnonzero(band.sum(axis=1) > 0)
        return float(ys.mean())

    centre = np.array([(x_min + x_max) / 2.0,
                       (column_centre(x_min) + column_centre(max(0, x_max - 2))) / 2.0])
    return centre, (x_max - x_min) / 2.0


def hexagon_polygon(img, grow=0.0):
    """Правильный шестиугольник тайла: плоские верх и низ, вершины слева и справа.

    grow расширяет его на столько пикселей — соседние тайлы тогда перекрываются
    на волосок и между ними не остаётся щели от сглаженной кромки.
    """
    centre, radius = _hex_metrics(img)
    radius += grow
    vertices = [
        centre + radius * np.array([math.cos(math.radians(a)),
                                    math.sin(math.radians(a))])
        for a in (0, 60, 120, 180, 240, 300)
    ]
    return np.array(vertices, dtype=np.int32).reshape(-1, 1, 2)


def hex_centre_radius(img):
    """Геометрический центр шестиугольника и его радиус, в пикселях картинки.

    Не путать с centre_px из калибровки: тот — начало координат АРТА (по нему
    расставлены троп-слоты) и смещён от центра шестиугольника примерно на 13 px.
    Поворачивать тайл надо вокруг геометрического центра: при повороте вокруг
    центра арта шестиугольник уезжает в сторону на величину этого смещения,
    у разных тайлов в разные стороны, и соседи расходятся до 27 px — это и были
    зазоры между тайлами.
    """
    return _hex_metrics(img)


def rotate_pixel_offset(d, rot_deg):
    """Поворот пиксельного смещения тем же поворотом, что применяется к картинке."""
    rad = math.radians(rot_deg)
    return (d[0] * math.cos(rad) - d[1] * math.sin(rad),
            d[0] * math.sin(rad) + d[1] * math.cos(rad))


def hex_geometry(img):
    """(R, шаг до соседа) в пикселях. У правильного шестиугольника соседи
    стоят на расстоянии «плоскость-плоскость» = sqrt(3) * R."""
    _, r = _hex_metrics(img)
    return r, math.sqrt(3) * r


def rotate_point(p, rot_deg):
    """Та же конвенция, что BoardBuilder.rotate_local: по часовой — положительная."""
    rad = math.radians(rot_deg)
    return (p[0] * math.cos(rad) + p[1] * math.sin(rad),
            -p[0] * math.sin(rad) + p[1] * math.cos(rad))


def render(hex_dir, out_path):
    sites, routes = load("site_data"), load("route_slots")
    snap, layouts, hex_edges = load("snap_report"), load("layouts"), load("hex_edges")

    try:
        built = load("board_layout")
    except FileNotFoundError:
        print("нет board_layout.json — сначала выгрузи раскладку из движка:\n"
              "  godot --headless --path godot --script res://tests/diagnose_board.gd")
        return
    hex_by_slot = built["hex_by_slot"]
    rotations = {k: float(v) for k, v in built["rotations"].items()}
    layout = layouts[str(built["player_count"])]

    # Геометрия гексагона берётся с первого же тайла, а не из константы.
    probe = cv2.imread(str(Path(hex_dir) / f"hex_{next(iter(hex_by_slot.values()))}.png"))
    hex_r, neighbour_step = hex_geometry(probe)

    # Позиции слотов раскладки заданы в мировых единицах (шаг соседей = R*sqrt(3),
    # где R = 8.5). Переводим в пиксели через измеренный шаг между гексами.
    world_step = math.sqrt(3) * 8.5
    px_per_world = neighbour_step / world_step

    places = {}
    for name, s in layout["slots"].items():
        if name in hex_by_slot:
            places[name] = (s["x"] * px_per_world, -s["z"] * px_per_world)

    xs = [p[0] for p in places.values()]
    ys = [p[1] for p in places.values()]
    pad = hex_r * 1.15
    width = int(max(xs) - min(xs) + 2 * pad)
    height = int(max(ys) - min(ys) + 2 * pad)
    origin = (-min(xs) + pad, -min(ys) + pad)

    canvas = np.zeros((height, width, 3), np.uint8)
    canvas[:] = (18, 12, 20)

    slot_px = {}     # slot_id -> (x, y) на общем полотне
    slot_kind = {}

    for layout_slot, hex_id in hex_by_slot.items():
        img = cv2.imread(str(Path(hex_dir) / f"hex_{hex_id}.png"))
        if img is None:
            continue
        h, w = img.shape[:2]
        rot = rotations[layout_slot]
        cal = snap[hex_id]
        art_scale, art_centre = cal["scale_px_per_unit"], cal["centre_px"]

        hex_centre, hex_radius = hex_centre_radius(img)

        # Шестиугольник расширяется на 2 px: соседние тайлы перекрываются на
        # волосок, и между ними не остаётся щели от сглаженной кромки. Ужимать
        # маску, наоборот, нельзя — прошлая версия ела по 2 px с каждой стороны.
        mask = np.zeros((h, w), np.uint8)
        cv2.fillPoly(mask, [hexagon_polygon(img, grow=2.0)], 255)

        # В расширенное кольцо попадает кромка белого фона снаружи тайла —
        # на стыках она видна как светлая ниточка. В самом кольце (и только
        # в нём) выбрасываем почти-белые пиксели; настоящие белые туннели
        # лежат внутри и не задеты.
        inner = np.zeros((h, w), np.uint8)
        cv2.fillPoly(inner, [hexagon_polygon(img, grow=-3.0)], 255)
        rim = (mask > 0) & (inner == 0)
        mask[rim & np.all(img >= 235, axis=2)] = 0

        # ПАДДИНГ ПЕРЕД ПОВОРОТОМ: без него угол тайла уезжает за край собственной
        # картинки и срезается (на B1 при повороте 240 градусов срубался угол).
        need = int(math.ceil(hex_radius)) + 12
        side = need * 2
        pad_img = np.zeros((side, side, 3), np.uint8)
        pad_mask = np.zeros((side, side), np.uint8)
        ox, oy = int(round(need - hex_centre[0])), int(round(need - hex_centre[1]))
        pad_img[oy:oy + h, ox:ox + w] = img
        pad_mask[oy:oy + h, ox:ox + w] = mask

        # OpenCV крутит против часовой при положительном угле, у нас конвенция
        # обратная (см. BoardBuilder.rotate_local), поэтому знак минус
        M = cv2.getRotationMatrix2D((float(need), float(need)), -rot, 1.0)
        rimg = cv2.warpAffine(pad_img, M, (side, side), flags=cv2.INTER_AREA)
        rmask = cv2.warpAffine(pad_mask, M, (side, side), flags=cv2.INTER_NEAREST)

        # смещение начала координат арта от центра шестиугольника — понадобится,
        # чтобы разместить троп-слоты на повёрнутом тайле
        art_offset = (art_centre[0] - hex_centre[0], art_centre[1] - hex_centre[1])
        h, w = side, side
        anchor = [float(need), float(need)]

        cx, cy = places[layout_slot]
        top = int(round(origin[1] + cy - anchor[1]))
        left = int(round(origin[0] + cx - anchor[0]))
        y0, y1 = max(0, top), min(height, top + h)
        x0, x1 = max(0, left), min(width, left + w)
        sub = rmask[y0 - top:y1 - top, x0 - left:x1 - left].astype(bool)
        canvas[y0:y1, x0:x1][sub] = rimg[y0 - top:y1 - top, x0 - left:x1 - left][sub]

        # слоты этого тайла
        entries = [(c["id"], c["x"], c["z"], "site")
                   for s in sites.get(hex_id, []) for c in s["troop_slots"]]
        entries += [(s["id"], s["x"], s["z"], "route") for s in routes.get(hex_id, [])]
        for sid, x, z, kind in entries:
            # положение слота относительно ЦЕНТРА ШЕСТИУГОЛЬНИКА, в пикселях,
            # затем тот же поворот, что применён к картинке
            d = (art_offset[0] + x * art_scale, art_offset[1] - z * art_scale)
            dx, dy = rotate_pixel_offset(d, rot)
            px = origin[0] + cx + dx
            py = origin[1] + cy + dy
            key = f"{layout_slot}:{sid}"
            slot_px[key] = (px, py)
            slot_kind[key] = kind

    # связи между гексами — их и надо разглядывать: состыковались ли туннели
    dirs = ["N", "NE", "SE", "S", "SW", "NW"]
    opposite = {"N": "S", "NE": "SW", "SE": "NW", "S": "N", "SW": "NE", "NW": "SE"}
    joined = 0
    for e in layout["adjacency"]:
        a, b = e["a"], e["b"]
        if a not in hex_by_slot or b not in hex_by_slot:
            continue

        def open_edge(slot, world_dir):
            shift = int(round(rotations[slot] / 60.0)) % 6
            raw = dirs[(dirs.index(world_dir) - shift) % 6]
            return raw in hex_edges.get(hex_by_slot[slot], [])

        ok = open_edge(a, e["dir"]) and open_edge(b, opposite[e["dir"]])
        pa = (origin[0] + places[a][0], origin[1] + places[a][1])
        pb = (origin[0] + places[b][0], origin[1] + places[b][1])
        colour = (90, 230, 90) if ok else (70, 70, 220)
        cv2.line(canvas, tuple(map(int, pa)), tuple(map(int, pb)), colour,
                 10 if ok else 6, cv2.LINE_AA)
        joined += 1 if ok else 0

    for key, (px, py) in slot_px.items():
        colour = (90, 220, 40) if slot_kind[key] == "site" else (30, 150, 255)
        cv2.circle(canvas, (int(px), int(py)), 26, colour, -1, cv2.LINE_AA)
        cv2.circle(canvas, (int(px), int(py)), 26, (0, 0, 0), 5, cv2.LINE_AA)

    for name, hex_id in hex_by_slot.items():
        px = int(origin[0] + places[name][0])
        py = int(origin[1] + places[name][1])
        label = f"{hex_id} @{int(rotations[name])}"
        cv2.putText(canvas, label, (px - 150, py + 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 2.4, (0, 0, 0), 14, cv2.LINE_AA)
        cv2.putText(canvas, label, (px - 150, py + 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 2.4, (255, 255, 255), 5, cv2.LINE_AA)

    out = cv2.resize(canvas, None, fx=OUTPUT_SCALE, fy=OUTPUT_SCALE,
                     interpolation=cv2.INTER_AREA)
    cv2.imwrite(str(out_path), out, [cv2.IMWRITE_PNG_COMPRESSION, 6])
    print(f"сохранено: {out_path}  ({out.shape[1]}x{out.shape[0]} px)")
    print(f"гексов: {len(hex_by_slot)}, слотов: {len(slot_px)}, "
          f"сомкнувшихся рёбер: {joined} из {len(layout['adjacency'])}")
    print(f"геометрия тайла: R={hex_r:.1f} px, шаг между соседями={neighbour_step:.1f} px")


if __name__ == "__main__":
    hex_dir = sys.argv[1] if len(sys.argv) > 1 else str(ROOT / "hexes")
    out = sys.argv[2] if len(sys.argv) > 2 else str(ROOT / "board.png")
    render(hex_dir, out)
