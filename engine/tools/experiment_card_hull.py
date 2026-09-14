#!/usr/bin/env python3
"""
Эксперимент: оболочка слотов используется, чтобы ОПОЗНАТЬ компоненты карточки,
а не чтобы вырезать её из маски.

История попыток (каждая проваливалась по своей причине):
  * общая связная компонента — у карточки чёрная обводка, туннель её не касается;
  * расширение всей маски — склеивает разные сайты (у A2 три сайта в один);
  * порог по площади — не видит мелкие карточки (у A3 карточка на один слот);
  * поиск компоненты шагом наружу от слота — ломает тайлы-хабы;
  * разделение по толщине — тело карточки изрезано печатными кружками слотов;
  * ВЫЧИТАНИЕ геометрической оболочки — оболочка меньше настоящей карточки,
    и её остаток остаётся в маске отдельной крупной компонентой. Цепочка
    получалась «кольцо -> отрезок -> остаток карточки -> карточка», а связь
    искалась только на прямом касании, поэтому рвалась посередине.

Рабочая идея: координаты слотов известны точно и уже сверены с артом. Значит
любая белая компонента, накрывающая оболочку слотов сайта, — это часть его
карточки. Всё остальное белое — туннели. Тогда отрезок туннеля соединяет
кольца, которых касается, с сайтами, чьих компонент касается.
"""

import sys
from pathlib import Path

import cv2
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from trace_adjacency import tile_mask, WHITE_MIN, load  # noqa: E402

BASE = "/mnt/user-data/uploads/tyrants of the underdark godot/board hexes/"

# Размечено вручную по печатному арту (tools/render_labelled_hex.py).
EXPECT = {
    "C4": {"r0": {"Red Gate", "Caer Sidi"}, "r1": {"Kulggen", "Caer Sidi"},
           "r2": {"Caer Sidi"}, "r3": {"Caer Sidi"}},
    "C1": {"r0": {"The Twilight", "Spiral Desert"},
           "r1": {"Spiral Desert", "Magma Gate"},
           "r2": {"Spiral Desert"},
           "r3": {"The Twilight", "Magma Gate"}},
    "C7": {"r0": {"Spiderhome", "Thanatos Gate"}},
}


def slot_hull(site, to_px, shape, pad_px):
    mask = np.zeros(shape, np.uint8)
    pts = np.array([to_px(c["x"], c["z"]) for c in site["troop_slots"]], np.int32)
    if len(pts) >= 3:
        cv2.fillPoly(mask, [cv2.convexHull(pts)], 1)
    elif len(pts) == 2:
        cv2.line(mask, tuple(pts[0]), tuple(pts[1]), 1, 3)
    else:
        cv2.circle(mask, tuple(pts[0]), 2, 1, -1)
    return cv2.dilate(mask, np.ones((2 * pad_px + 1,) * 2, np.uint8))


def links(hx, pad_units, snap, sites, routes, min_seg=0.03):
    img = cv2.imread(BASE + f"hex_{hx}.png")
    h, w = img.shape[:2]
    cal = snap[hx]
    scale, centre = cal["scale_px_per_unit"], cal["centre_px"]

    def to_px(x, z):
        return int(round(centre[0] + x * scale)), int(round(centre[1] - z * scale))

    white = np.all(img >= WHITE_MIN, axis=2).astype(np.uint8) & tile_mask(img)

    punch = int(0.60 * scale)
    touch = int(0.78 * scale)
    ring_px = {}
    carved = white.copy()
    for slot in routes.get(hx, []):
        p = to_px(slot["x"], slot["z"])
        ring_px[slot["id"]] = p
        cv2.circle(carved, p, punch, 0, -1)

    count, labels, stats, _ = cv2.connectedComponentsWithStats(carved, 8)

    # компонента карточки = та, что накрывает оболочку слотов сайта
    site_components = {}
    for site in sites.get(hx, []):
        hull = slot_hull(site, to_px, (h, w), int(pad_units * scale))
        found = set()
        for comp in np.unique(labels[hull.astype(bool)]):
            comp = int(comp)
            if comp != 0:
                found.add(comp)
        site_components[site["name"]] = found

    owned = set()
    for comps in site_components.values():
        owned |= comps

    result = {}
    for comp in range(1, count):
        if comp in owned or stats[comp, cv2.CC_STAT_AREA] < min_seg * scale * scale:
            continue
        segment = (labels == comp).astype(np.uint8)
        rings = []
        for rid, p in ring_px.items():
            probe = np.zeros((h, w), np.uint8)
            cv2.circle(probe, p, touch, 1, -1)
            cv2.circle(probe, p, punch, 0, -1)
            if (probe & segment).sum() > 0.15 * scale:
                rings.append(rid)
        if not rings:
            continue
        grown = cv2.dilate(segment, np.ones((9, 9), np.uint8))
        hit = set()
        for name, comps in site_components.items():
            for other in comps:
                if (grown & (labels == other).astype(np.uint8)).sum() > 0.15 * scale:
                    hit.add(name)
                    break
        for rid in rings:
            result.setdefault(rid, set()).update(hit)
    return result


def main():
    snap, sites, routes = load("snap_report"), load("site_data"), load("route_slots")
    for pad in (0.30, 0.45, 0.60, 0.75):
        ok = total = 0
        report = []
        for hx, expect in EXPECT.items():
            got = links(hx, pad, snap, sites, routes)
            marks = []
            for ring, want in expect.items():
                have = got.get(f"{hx}_route{ring[1:]}", set())
                good = have == want
                ok += good
                total += 1
                marks.append(f"{ring}{'+' if good else '-'}")
            report.append(f"{hx}[{' '.join(marks)}]")
        print(f"запас {pad:.2f} ед.:  верно {ok}/{total}   " + "  ".join(report))


if __name__ == "__main__":
    main()
