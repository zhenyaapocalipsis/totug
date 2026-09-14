#!/usr/bin/env python3
"""
Проверка hex_edges.json по печатному арту тайлов.

Зачем. Таблица `demonwebEdgeConnByTile` в Lua-скрипте мода размечена вручную и
неполна: у 21 тайла из 27 просто проставлено «все шесть рёбер открыты», а
«false» автор расставил лишь там, где заметил. Из-за этого движок считал
состыковавшимися рёбра, где туннеля нет, и наоборот — разрывал настоящие.
Первым это заметил владелец игры: между C5 и C3 линия была красной, хотя на
арте туннель C5 доходит до края.

Как определяется выход туннеля. Туннели нарисованы чистым белым штрихом
шириной ~12 px и доходят до самой границы шестиугольника (там их встречает
чёрная точка, напечатанная снаружи тайла). Меряем длину непрерывной белой
полосы поперёк середины ребра на двух глубинах: у самой границы (0.99
апофемы) и заметно внутри (0.90). Туннель даёт белую полосу на обеих;
карточка локации, придвинутая к краю, — только на внутренней; фоновый арт
не даёт нигде.

Чёрные точки снаружи признаком не годятся: они напечатаны на ВСЕХ шести
рёбрах каждого тайла, в том числе глухих.

    python3 tools/verify_hex_edges.py [тайл ...]
"""
import json
import math
import sys
from pathlib import Path

import cv2
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data" / "board"
ART = Path("/mnt/user-data/uploads/tyrants of the underdark godot/board hexes")

DIRS = {"N": 90, "NE": 30, "SE": -30, "S": -90, "SW": -150, "NW": 150}
WHITE = 225        # белее этого — туннель или карточка, а не арт
DEPTHS = (0.90, 0.99)
MIN_RUN = 5        # штрих туннеля даёт полосу 11-15 px, тонкий отросток от карточки - 7
HALF_WIDTH = 150


def hex_metrics(img):
    """Центр и радиус шестиугольника — см. подробности в tools/render_board.py."""
    mask = np.any(img < 205, axis=2).astype(np.uint8)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    cols = np.flatnonzero(mask.sum(axis=0) > 0)
    x0, x1 = int(cols[0]), int(cols[-1])

    def column_centre(x):
        return float(np.flatnonzero(mask[:, x:x + 3].sum(axis=1) > 0).mean())

    return np.array([(x0 + x1) / 2.0, (column_centre(x0) + column_centre(x1 - 2)) / 2.0]), (x1 - x0) / 2.0


def white_run(img, centre, radius, direction, depth):
    """Самая длинная непрерывная белая полоса поперёк середины ребра."""
    apothem = radius * math.sqrt(3) / 2.0
    angle = math.radians(DIRS[direction])
    out = np.array([math.cos(angle), -math.sin(angle)])
    along = np.array([-out[1], out[0]])
    base = centre + out * apothem * depth
    best = current = 0
    for t in range(-HALF_WIDTH, HALF_WIDTH + 1):
        p = base + along * t
        x, y = int(round(p[0])), int(round(p[1]))
        white = (0 <= y < img.shape[0] and 0 <= x < img.shape[1]
                 and bool(np.all(img[y, x] >= WHITE)))
        current = current + 1 if white else 0
        best = max(best, current)
    return best


def art_edges(hex_id):
    img = cv2.imread(str(ART / f"hex_{hex_id}.png"))
    if img is None:
        return None, {}
    centre, radius = hex_metrics(img)
    runs = {}
    for direction in DIRS:
        runs[direction] = [white_run(img, centre, radius, direction, d) for d in DEPTHS]
    return img, runs


def main() -> int:
    edges = json.loads((DATA / "hex_edges.json").read_text(encoding="utf-8"))
    wanted = sys.argv[1:] or sorted(edges)
    mismatches = []
    print("тайл ребро  полоса@0.90 @0.99   в данных  на арте")
    for hex_id in wanted:
        img, runs = art_edges(hex_id)
        if img is None:
            print(f"{hex_id}: арт не найден")
            continue
        for direction in DIRS:
            inner, outer = runs[direction]
            seen = inner >= MIN_RUN and outer >= MIN_RUN
            listed = direction in edges[hex_id]
            flag = ""
            if seen != listed:
                flag = "   <<< РАСХОЖДЕНИЕ"
                mismatches.append((hex_id, direction, listed, seen))
            print("%-4s %-4s %9d %6d      %-5s     %-8s%s"
                  % (hex_id, direction, inner, outer, "да" if listed else "нет",
                     "туннель" if seen else "глухо", flag))
    print("\nрасхождений: %d" % len(mismatches))
    for hex_id, direction, listed, seen in mismatches:
        print("  %s %-3s данные: %-3s   арт: %s"
              % (hex_id, direction, "есть" if listed else "нет",
                 "есть" if seen else "нет"))
    return 1 if mismatches else 0


if __name__ == "__main__":
    raise SystemExit(main())
