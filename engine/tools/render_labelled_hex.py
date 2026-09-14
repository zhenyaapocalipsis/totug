#!/usr/bin/env python3
"""
Рисует гекс с ПОДПИСАННЫМИ маршрутными слотами — для ручной сверки смежности.

Автоматическая трассировка туннелей (tools/trace_adjacency.py) не сходится:
на арте несколько разных идиом (карточка с чёрной обводкой, хаб-контур вокруг
названия, карточка поверх туннеля, сайты без колец вообще), и правило, которое
чинит один тайл, ломает другой. Поэтому спорные кольца — те, что лежат примерно
посередине между двумя сайтами, — размечаются вручную по рисунку, а этот
инструмент готовит картинки для такой сверки.

Запуск:
    python3 tools/render_labelled_hex.py C1 "путь/к/board hexes" out.png
"""

import json
import sys
from pathlib import Path

import cv2
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data" / "board"


def load(name):
    return json.loads((DATA / f"{name}.json").read_text(encoding="utf-8"))


def render(hex_id, hex_dir, out_path):
    sites, routes, snap = load("site_data"), load("route_slots"), load("snap_report")
    img = cv2.imread(str(Path(hex_dir) / f"hex_{hex_id}.png"))
    if img is None or hex_id not in snap:
        print(f"нет данных для {hex_id}")
        return
    cal = snap[hex_id]
    scale, (cx, cy) = cal["scale_px_per_unit"], cal["centre_px"]

    def to_px(x, z):
        return int(round(cx + x * scale)), int(round(cy - z * scale))

    def label(text, at, colour, size=1.5, thick=4):
        cv2.putText(img, text, at, cv2.FONT_HERSHEY_SIMPLEX, size, (0, 0, 0), thick + 8,
                    cv2.LINE_AA)
        cv2.putText(img, text, at, cv2.FONT_HERSHEY_SIMPLEX, size, colour, thick,
                    cv2.LINE_AA)

    # сайты: зелёные точки, подпись у первого слота
    for index, site in enumerate(sites.get(hex_id, [])):
        for slot in site["troop_slots"]:
            p = to_px(slot["x"], slot["z"])
            cv2.circle(img, p, 20, (0, 0, 0), -1, cv2.LINE_AA)
            cv2.circle(img, p, 14, (60, 220, 80), -1, cv2.LINE_AA)
        first = to_px(site["troop_slots"][0]["x"], site["troop_slots"][0]["z"])
        label("S%d %s" % (index, site["name"]), (first[0] + 26, first[1] + 12),
              (80, 255, 110))

    # маршрутные кольца: оранжевые точки с крупной подписью r0, r1, ...
    for slot in routes.get(hex_id, []):
        p = to_px(slot["x"], slot["z"])
        cv2.circle(img, p, 26, (0, 0, 0), -1, cv2.LINE_AA)
        cv2.circle(img, p, 19, (30, 150, 255), -1, cv2.LINE_AA)
        short = slot["id"].split("_route")[-1]
        label("r" + short, (p[0] + 32, p[1] + 16), (90, 200, 255), 2.0, 5)

    label("hex " + hex_id, (30, 70), (255, 255, 255), 2.0, 5)
    img = cv2.resize(img, (1100, 1100), interpolation=cv2.INTER_AREA)
    cv2.imwrite(str(out_path), img)
    print(f"сохранено: {out_path}")


if __name__ == "__main__":
    render(sys.argv[1],
           sys.argv[2] if len(sys.argv) > 2 else str(ROOT / "hexes"),
           sys.argv[3] if len(sys.argv) > 3 else f"labelled_{sys.argv[1]}.png")
