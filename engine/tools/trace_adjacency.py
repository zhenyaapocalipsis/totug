#!/usr/bin/env python3
"""
Смежность троп-слотов, прослеженная ПО ПЕЧАТНЫМ ТУННЕЛЯМ.

Зачем: смежность решает, где у игрока есть Присутствие, а значит — куда можно
ставить войска, кого убивать, кого supplant'ить. Выводить её из расстояний между
слотами — гадание: кольцо между двумя сайтами по расстоянию «принадлежит»
ближайшему, хотя на рисунке туннель идёт к обоим (проверено на C7: среднее
кольцо ведёт и к Spiderhome, и к Thanatos Gate). Каждое такое неверное
срабатывание — баг в правилах.

Как устроен арт (выяснено разбором, а не предположено):
  * фон ВНЕ гексагона — чисто белый, такой же, как туннели. Туннели доходят до
    края тайла и там сливаются с фоном, поэтому анализ обрезается телом тайла:
    иначе все туннели гекса оказываются связаны «через улицу».
  * карточка сайта — белый прямоугольник с ЧЁРНОЙ ОБВОДКОЙ. Обводка отделяет
    тело карточки от подходящих туннелей, так что «общая белая компонента»
    связать туннель с сайтом не может: их приходится сшивать через небольшое
    расширение отрезка туннеля.
  * троп-слоты сайта нарисованы кругами ВНУТРИ карточки.

Алгоритм:
  1. маска белого, обрезанная телом тайла;
  2. вырезаются диски ТОЛЬКО маршрутных слотов — так туннельная сеть рвётся
     ровно в точках, где стоят фишки, а карточки остаются целыми;
  3. компоненты: крупные — тела карточек, остальные — отрезки туннелей;
  4. отрезок туннеля даёт смежность между всеми маршрутными слотами, которых
     он касается, и всеми сайтами, к карточкам которых он подходит.

Внутрисайтовая смежность берётся не отсюда, а из принадлежности слота сайту:
на арте она и так очевидна, а по рисунку определялась бы хуже.

Выход: data/board/art_adjacency.json
    {гекс: {"slot_slot": [[id, id]...], "slot_site": [[id_слота, id_сайта]...]}}

Запуск:
    python3 tools/trace_adjacency.py "путь/к/board hexes"
"""

import json
import sys
from pathlib import Path

import cv2
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data" / "board"

# Порог «белого». Туннели и карточки — почти чистый белый, арт под ними темнее.
WHITE_MIN = 205
# Радиус выреза вокруг маршрутного слота, в единицах арта (печатное кольцо ~0.42-0.52).
PUNCH_RADIUS_UNITS = 0.60
# На сколько расширяем вырез, проверяя касание слота к отрезку туннеля.
TOUCH_MARGIN_UNITS = 0.16
# Компонента крупнее этого (в единицах арта в квадрате) считается телом карточки.
CARD_MIN_AREA_UNITS2 = 1.5
# Отрезок туннеля считается подходящим к карточке, если после расширения на
# столько единиц он её задевает — столько занимает чёрная обводка карточки.
CARD_GAP_UNITS = 0.10
# Отрезок мельче этого — шум арта, а не туннель.
SEGMENT_MIN_AREA_UNITS2 = 0.04


def load(name):
    return json.loads((DATA / f"{name}.json").read_text(encoding="utf-8"))


def tile_mask(img):
    """Тело шестиугольника: крупнейшая область не-белого, затянутая выпуклой оболочкой."""
    h, w = img.shape[:2]
    art = np.any(img < WHITE_MIN, axis=2).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(art, 8)
    if count < 2:
        return np.ones((h, w), np.uint8)
    biggest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    blob = (labels == biggest).astype(np.uint8)
    contours, _ = cv2.findContours(blob, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    hull = cv2.convexHull(max(contours, key=cv2.contourArea))
    mask = np.zeros((h, w), np.uint8)
    cv2.fillPoly(mask, [hull], 1)
    inset = max(3, int(0.012 * w))
    return cv2.erode(mask, np.ones((inset, inset), np.uint8))


def trace(img, site_slots, route_slots, scale, centre):
    """
    site_slots:  [(slot_id, x, z, site_id)]
    route_slots: [(slot_id, x, z)]
    """
    h, w = img.shape[:2]

    def to_px(x, z):
        return int(round(centre[0] + x * scale)), int(round(centre[1] - z * scale))

    white = np.all(img >= WHITE_MIN, axis=2).astype(np.uint8) & tile_mask(img)

    # шаг 2: вырезаем ТОЛЬКО маршрутные слоты — карточки должны остаться целыми
    carved = white.copy()
    punch_r = int(round(PUNCH_RADIUS_UNITS * scale))
    touch_r = int(round((PUNCH_RADIUS_UNITS + TOUCH_MARGIN_UNITS) * scale))
    route_px = {}
    for sid, x, z in route_slots:
        p = to_px(x, z)
        route_px[sid] = p
        cv2.circle(carved, p, punch_r, 0, -1)

    count, labels, stats, _ = cv2.connectedComponentsWithStats(carved, 8)

    # шаг 3: крупные компоненты — карточки; сопоставляем их сайтам по слотам внутри
    card_area = CARD_MIN_AREA_UNITS2 * scale * scale
    segment_area = SEGMENT_MIN_AREA_UNITS2 * scale * scale
    site_of_component = {}
    for sid, x, z, site_id in site_slots:
        px, py = to_px(x, z)
        if 0 <= py < h and 0 <= px < w:
            comp = int(labels[py, px])
            if comp != 0 and stats[comp, cv2.CC_STAT_AREA] >= card_area:
                site_of_component[comp] = site_id
    # слот мог попасть в вырезанный круг или на тёмный значок — добираем поиском
    # ближайшей крупной компоненты в небольшом окне вокруг слота
    for sid, x, z, site_id in site_slots:
        px, py = to_px(x, z)
        window = labels[max(0, py - punch_r):py + punch_r, max(0, px - punch_r):px + punch_r]
        for comp in np.unique(window):
            comp = int(comp)
            if comp != 0 and stats[comp, cv2.CC_STAT_AREA] >= card_area:
                site_of_component.setdefault(comp, site_id)

    gap = max(2, int(round(CARD_GAP_UNITS * scale)))
    kernel = np.ones((gap * 2 + 1, gap * 2 + 1), np.uint8)

    slot_slot, slot_site = set(), set()

    for comp in range(1, count):
        area = int(stats[comp, cv2.CC_STAT_AREA])
        if comp in site_of_component or area < segment_area:
            continue  # это карточка или шум, а не отрезок туннеля

        segment = (labels == comp).astype(np.uint8)

        # какие маршрутные слоты этот отрезок задевает
        touched_routes = []
        for sid, p in route_px.items():
            ring = np.zeros((h, w), np.uint8)
            cv2.circle(ring, p, touch_r, 1, -1)
            cv2.circle(ring, p, punch_r, 0, -1)
            if int((ring & segment).sum()) > 0.2 * scale:
                touched_routes.append(sid)

        # к каким карточкам подходит — через расширение на толщину обводки
        grown = cv2.dilate(segment, kernel)
        touched_sites = set()
        for card_comp, site_id in site_of_component.items():
            if int((grown & (labels == card_comp).astype(np.uint8)).sum()) > 0.2 * scale:
                touched_sites.add(site_id)

        for i, a in enumerate(touched_routes):
            for b in touched_routes[i + 1:]:
                slot_slot.add(tuple(sorted((a, b))))
            for site_id in touched_sites:
                slot_site.add((a, site_id))

    # Кольца, подходящие к одному и тому же сайту, НЕ смежны друг другу:
    # они соединены через сам сайт. На тайлах-хабах (B1, B3-B6, A1) вокруг
    # названия сайта нарисован соединительный контур со стрелками, к которому
    # сходятся все туннели, — из-за него все кольца попадали в одну компоненту
    # и получалась ложная смежность «каждое с каждым».
    sites_of_slot = {}
    for slot_id, site_id in slot_site:
        sites_of_slot.setdefault(slot_id, set()).add(site_id)
    slot_slot = {
        (a, b) for (a, b) in slot_slot
        if not (sites_of_slot.get(a, set()) & sites_of_slot.get(b, set()))
    }

    return sorted(slot_slot), sorted(slot_site)


def main():
    hex_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("hexes")
    sites, routes, snap = load("site_data"), load("route_slots"), load("snap_report")

    result = {}
    print(f"{'гекс':5} {'маршр.':>7} {'сайтов':>7} {'кольцо-кольцо':>14} {'кольцо-сайт':>12}  "
          f"кольца без связей")
    print("-" * 82)
    for hex_id in sorted(set(list(sites.keys()) + list(routes.keys()))):
        img_path = hex_dir / f"hex_{hex_id}.png"
        if not img_path.exists() or hex_id not in snap:
            continue
        img = cv2.imread(str(img_path))
        site_slots = [
            (c["id"], c["x"], c["z"], s["id"])
            for s in sites.get(hex_id, []) for c in s["troop_slots"]
        ]
        route_slots = [(s["id"], s["x"], s["z"]) for s in routes.get(hex_id, [])]
        cal = snap[hex_id]
        ss, st = trace(img, site_slots, route_slots,
                       cal["scale_px_per_unit"], cal["centre_px"])
        result[hex_id] = {"slot_slot": [list(p) for p in ss],
                          "slot_site": [list(p) for p in st]}

        linked = {a for a, _ in ss} | {b for _, b in ss} | {a for a, _ in st}
        orphans = [s[0] for s in route_slots if s[0] not in linked]
        print(f"{hex_id:5} {len(route_slots):7} {len(sites.get(hex_id, [])):7} "
              f"{len(ss):14} {len(st):12}  {', '.join(orphans) if orphans else ''}")

    (DATA / "art_adjacency.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    tot_ss = sum(len(v["slot_slot"]) for v in result.values())
    tot_st = sum(len(v["slot_site"]) for v in result.values())
    print("-" * 82)
    print(f"связей кольцо-кольцо: {tot_ss}, кольцо-сайт: {tot_st}")
    print(f"сохранено: {DATA / 'art_adjacency.json'}")


if __name__ == "__main__":
    main()
