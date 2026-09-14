#!/usr/bin/env python3
"""Разбор отрезков туннелей на одном гексе: что каждый задевает и почему."""

import sys
from pathlib import Path

import cv2
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from trace_adjacency import tile_mask, WHITE_MIN, load  # noqa: E402

BASE = "/mnt/user-data/uploads/tyrants of the underdark godot/board hexes/"


def main(hx, card_pad=0.85):
    snap, sites, routes = load("snap_report"), load("site_data"), load("route_slots")
    img = cv2.imread(BASE + f"hex_{hx}.png")
    h, w = img.shape[:2]
    cal = snap[hx]
    scale, centre = cal["scale_px_per_unit"], cal["centre_px"]

    def to_px(x, z):
        return int(round(centre[0] + x * scale)), int(round(centre[1] - z * scale))

    white = np.all(img >= WHITE_MIN, axis=2).astype(np.uint8) & tile_mask(img)

    card = {}
    for site in sites.get(hx, []):
        mask = np.zeros((h, w), np.uint8)
        pts = np.array([to_px(c["x"], c["z"]) for c in site["troop_slots"]], np.int32)
        if len(pts) >= 3:
            cv2.fillPoly(mask, [cv2.convexHull(pts)], 1)
        elif len(pts) == 2:
            cv2.line(mask, tuple(pts[0]), tuple(pts[1]), 1, 3)
        else:
            cv2.circle(mask, tuple(pts[0]), 2, 1, -1)
        pad = int(card_pad * scale)
        card[site["name"]] = cv2.dilate(mask, np.ones((2 * pad + 1,) * 2, np.uint8))

    occupied = np.zeros((h, w), np.uint8)
    for mask in card.values():
        occupied |= mask
    tunnels = white & (1 - occupied)

    punch = int(0.60 * scale)
    touch = int(0.78 * scale)
    ring_px = {}
    for slot in routes.get(hx, []):
        p = to_px(slot["x"], slot["z"])
        ring_px["r" + slot["id"].split("route")[-1]] = p
        cv2.circle(tunnels, p, punch, 0, -1)

    count, labels, stats, _ = cv2.connectedComponentsWithStats(tunnels, 8)
    print(f"=== {hx}, запас карточки {card_pad} ед., порог отрезка "
          f"{0.03 * scale * scale:.0f} px ===")
    print(f"отрезков всего: {count - 1}")
    for comp in range(1, count):
        area = int(stats[comp, cv2.CC_STAT_AREA])
        segment = (labels == comp).astype(np.uint8)
        rings = []
        for rid, p in ring_px.items():
            probe = np.zeros((h, w), np.uint8)
            cv2.circle(probe, p, touch, 1, -1)
            cv2.circle(probe, p, punch, 0, -1)
            overlap = int((probe & segment).sum())
            if overlap > 0:
                rings.append(f"{rid}({overlap}px)")
        grown = cv2.dilate(segment, np.ones((9, 9), np.uint8))
        hits = []
        for name, mask in card.items():
            overlap = int((grown & mask).sum())
            if overlap > 0:
                hits.append(f"{name}({overlap}px)")
        keep = "" if area >= 0.03 * scale * scale else "  ОТБРОШЕН по площади"
        if rings or hits:
            print(f"  area={area:6}  кольца: {', '.join(rings) or '-':30} "
                  f"сайты: {', '.join(hits) or '-'}{keep}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "C1",
         float(sys.argv[2]) if len(sys.argv) > 2 else 0.85)
