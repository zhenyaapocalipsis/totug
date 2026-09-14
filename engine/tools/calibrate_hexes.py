#!/usr/bin/env python3
"""
Калибровка данных доски по печатному арту гексов.

Зачем: координаты троп-слотов извлечены из мода TTS и заданы в абстрактных
единицах арта. Чтобы проверить их правильность (и корректно рисовать overlay),
нужно найти преобразование "единицы арта -> пиксели картинки гекса".

Как: на картинке детектируются печатные белые круги (троп-слоты сайтов и кольца
на туннелях), затем методом наименьших квадратов подбирается подобие
    пиксель = центр + масштаб * (x, -z)
итеративно, с переназначением соответствий (ICP). Три неизвестных: масштаб и
две координаты центра; поворот не нужен — картинки гексов в печатной ориентации.

Результат — data/board/calibration.json: на каждый гекс масштаб, центр,
сколько слотов нашли себе печатный круг и остаточная ошибка. Гексы с большой
ошибкой или малым числом совпадений — кандидаты на ручную проверку: значит,
данные из Lua для них расходятся с артом.

Запуск:
    python3 tools/calibrate_hexes.py "путь/к/board hexes"
"""

import json
import math
import sys
from pathlib import Path

import cv2
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data" / "board"

# Стартовая догадка масштаба: подобрана по A1, где шесть кругов карточки
# The Great Web образуют однозначную сетку 3x2. ~128 px на единицу арта
# при картинке 1816 px, то есть примерно ширина_картинки / 14.2.
SCALE_GUESS_DIVISOR = 14.2

# Слот считается сопоставленным печатному кругу, если центр круга ближе этого
# (в долях текущего масштаба, т.е. в единицах арта).
MATCH_TOLERANCE_UNITS = 0.55


def load(name):
    return json.loads((DATA / f"{name}.json").read_text(encoding="utf-8"))


def data_points(hex_id, sites, routes):
    """Все ожидаемые троп-слоты гекса: (id, x, z, вид)."""
    pts = []
    for site in sites.get(hex_id, []):
        for s in site["troop_slots"]:
            pts.append((s["id"], s["x"], s["z"], "site", site["name"]))
    for s in routes.get(hex_id, []):
        pts.append((s["id"], s["x"], s["z"], "route", None))
    return pts


def detect_circles(img):
    """Печатные круги на арте. Параметры подобраны под белые кольца троп-слотов."""
    grey = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    grey = cv2.medianBlur(grey, 5)
    h, w = grey.shape
    scale_ref = w / 1816.0
    found = []
    for dp, param1, param2 in [(1.0, 120, 38), (1.2, 120, 45), (1.0, 100, 32)]:
        circles = cv2.HoughCircles(
            grey, cv2.HOUGH_GRADIENT, dp=dp,
            minDist=int(55 * scale_ref),
            param1=param1, param2=param2,
            minRadius=int(30 * scale_ref), maxRadius=int(100 * scale_ref),
        )
        if circles is not None:
            found.extend(circles[0])
    if not found:
        return np.zeros((0, 3))
    found = np.array(found)
    # схлопнуть дубли между прогонами
    kept = []
    for c in found:
        if all(math.hypot(c[0] - k[0], c[1] - k[1]) > 30 * scale_ref for k in kept):
            kept.append(c)
    return np.array(kept)


def fit_similarity(units, pixels):
    """
    Наименьшие квадраты для  пиксель = центр + масштаб * единица.
    units, pixels — массивы Nx2. Возвращает (масштаб, центр).
    """
    u_mean = units.mean(axis=0)
    p_mean = pixels.mean(axis=0)
    du = units - u_mean
    dp = pixels - p_mean
    denom = (du * du).sum()
    if denom < 1e-9:
        return None, None
    scale = float((du * dp).sum() / denom)
    centre = p_mean - scale * u_mean
    return scale, centre


def calibrate(hex_id, img, points):
    """ICP: подгоняет масштаб и центр, переназначая соответствия на каждой итерации."""
    circles = detect_circles(img)
    h, w = img.shape[:2]
    if len(circles) < 3 or len(points) < 3:
        return None

    # ось Z в данных вверх, Y на картинке вниз
    units = np.array([[p[1], -p[2]] for p in points], dtype=float)

    scale = w / SCALE_GUESS_DIVISOR
    centre = np.array([w / 2.0, h / 2.0])

    matched_idx, matched_circ = [], []
    for _ in range(25):
        projected = centre + scale * units
        matched_idx, matched_circ = [], []
        tol = MATCH_TOLERANCE_UNITS * scale
        used = set()
        # жадно, от самых уверенных пар
        pairs = []
        for i, pt in enumerate(projected):
            for j, c in enumerate(circles):
                d = math.hypot(pt[0] - c[0], pt[1] - c[1])
                if d <= tol:
                    pairs.append((d, i, j))
        pairs.sort()
        taken_i, taken_j = set(), set()
        for d, i, j in pairs:
            if i in taken_i or j in taken_j:
                continue
            taken_i.add(i)
            taken_j.add(j)
            matched_idx.append(i)
            matched_circ.append(circles[j][:2])
        if len(matched_idx) < 3:
            break
        new_scale, new_centre = fit_similarity(
            units[matched_idx], np.array(matched_circ)
        )
        if new_scale is None:
            break
        if abs(new_scale - scale) < 0.01 and np.allclose(new_centre, centre, atol=0.05):
            scale, centre = new_scale, new_centre
            break
        scale, centre = new_scale, new_centre

    if len(matched_idx) < 3:
        return None

    projected = centre + scale * units
    residuals = [
        math.hypot(projected[i][0] - c[0], projected[i][1] - c[1])
        for i, c in zip(matched_idx, matched_circ)
    ]
    rms = math.sqrt(sum(r * r for r in residuals) / len(residuals))
    return {
        "scale_px_per_unit": round(scale, 3),
        "centre_px": [round(float(centre[0]), 2), round(float(centre[1]), 2)],
        "image_size": [int(w), int(h)],
        "circles_detected": int(len(circles)),
        "slots_total": len(points),
        "slots_matched": len(matched_idx),
        "rms_px": round(rms, 2),
        "rms_units": round(rms / scale, 4),
        "unmatched_slots": [
            points[i][0] for i in range(len(points)) if i not in set(matched_idx)
        ],
    }


def main():
    hex_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "hexes"
    sites = load("site_data")
    routes = load("route_slots")

    hex_ids = sorted(set(list(sites.keys()) + list(routes.keys())))
    result = {}

    print(f"{'гекс':5} {'кругов':>7} {'слотов':>7} {'совпало':>8} {'масштаб':>9} "
          f"{'RMS px':>7} {'RMS ед':>7}  центр")
    print("-" * 78)

    for hex_id in hex_ids:
        img_path = hex_dir / f"hex_{hex_id}.png"
        if not img_path.exists():
            print(f"{hex_id:5} — нет изображения")
            continue
        img = cv2.imread(str(img_path))
        pts = data_points(hex_id, sites, routes)
        cal = calibrate(hex_id, img, pts)
        if cal is None:
            print(f"{hex_id:5} — не удалось откалибровать")
            continue
        result[hex_id] = cal
        flag = ""
        if cal["slots_matched"] < cal["slots_total"]:
            flag = f"  ! не нашли {cal['slots_total'] - cal['slots_matched']}"
        print(f"{hex_id:5} {cal['circles_detected']:7} {cal['slots_total']:7} "
              f"{cal['slots_matched']:8} {cal['scale_px_per_unit']:9.2f} "
              f"{cal['rms_px']:7.1f} {cal['rms_units']:7.3f}  "
              f"({cal['centre_px'][0]:.0f}, {cal['centre_px'][1]:.0f}){flag}")

    (DATA / "calibration.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    if result:
        scales = [c["scale_px_per_unit"] / (c["image_size"][0] / 1816.0) for c in result.values()]
        rms_units = [c["rms_units"] for c in result.values()]
        print("-" * 78)
        print(f"масштаб (приведён к 1816 px): среднее {np.mean(scales):.2f} "
              f"разброс {np.std(scales):.2f}  min {min(scales):.2f} max {max(scales):.2f}")
        print(f"RMS в единицах арта: медиана {np.median(rms_units):.4f} "
              f"max {max(rms_units):.4f}")
        total = sum(c["slots_total"] for c in result.values())
        matched = sum(c["slots_matched"] for c in result.values())
        print(f"слотов сопоставлено печатным кругам: {matched} из {total}")
        print(f"\nсохранено: {DATA / 'calibration.json'}")


if __name__ == "__main__":
    main()
