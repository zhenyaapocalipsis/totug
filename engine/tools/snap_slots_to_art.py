#!/usr/bin/env python3
"""
Уточнение координат троп-слотов ПО ПЕЧАТНОМУ АРТУ.

Координаты из мода TTS оцифрованы человеком на глаз и местами расходятся с
рисунком (проверено: у B1 кольцо туннеля на север записано со сдвигом ~0.45
единицы = 57 px на реальном арте, из-за чего перекашивалась подгонка всего гекса).

Здесь координаты берутся из самого арта: на картинке гекса детектируются
печатные круги, подбирается преобразование "единицы арта -> пиксели", и каждый
слот сдвигается точно в центр своего печатного круга. Идентичность слота
(id, принадлежность сайту, VP) остаётся из данных Lua — оттуда её взять больше
неоткуда, на арте её нет.

Устойчивость подгонки:
  * масштаб общий для всех гексов (медиана по всем) — он и правда константа,
    разброс по 21 гексу был 0.43 px на 128, то есть 0.3%. Меньше свободных
    параметров — меньше шансов, что одна кривая точка утащит всю подгонку.
  * центр подбирается на гекс, с отбрасыванием выбросов: после подгонки точки
    с отклонением больше порога исключаются и подгонка повторяется. Иначе
    ровно та кривая точка из B1 сдвигает центр и портит все остальные слоты.

Выход:
  data/board/site_data.json, route_slots.json  — с уточнёнными координатами
  data/board/snap_report.json                  — что и насколько сдвинулось

Запуск:
    python3 tools/snap_slots_to_art.py "путь/к/board hexes"
"""

import json
import math
import sys
from pathlib import Path

import cv2
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from calibrate_hexes import detect_circles, load, DATA  # noqa: E402

# Слот сопоставляется кругу, если тот ближе этого (в единицах арта).
MATCH_TOLERANCE_UNITS = 0.55
# При подгонке центра точка считается выбросом, если её отклонение больше
# этого числа медианных отклонений (и больше 12 px — чтобы на идеальных
# гексах не выбрасывать ничего из-за шума в пару пикселей).
OUTLIER_FACTOR = 2.5
OUTLIER_FLOOR_PX = 12.0
# Сдвиг больше этого (в единицах арта) считается исправлением ошибки оцифровки
# и попадает в отчёт.
REPORT_THRESHOLD_UNITS = 0.12


def hex_slots(hex_id, sites, routes):
    """[(ключ, x, z)] — ключ позволяет записать координату обратно."""
    out = []
    for si, site in enumerate(sites.get(hex_id, [])):
        for ci, s in enumerate(site["troop_slots"]):
            out.append((("site", si, ci), s["id"], s["x"], s["z"]))
    for ri, s in enumerate(routes.get(hex_id, [])):
        out.append((("route", ri, None), s["id"], s["x"], s["z"]))
    return out


def fit_centre(units, circles, scale, initial_centre):
    """
    Подбирает только центр (масштаб фиксирован) с отбрасыванием выбросов.
    Возвращает (центр, соответствия slot_index -> координата круга).
    """
    centre = np.array(initial_centre, dtype=float)
    excluded = set()
    matches = {}

    for _ in range(30):
        projected = centre + scale * units
        pairs = []
        for i, pt in enumerate(projected):
            for j, c in enumerate(circles):
                d = math.hypot(pt[0] - c[0], pt[1] - c[1])
                if d <= MATCH_TOLERANCE_UNITS * scale:
                    pairs.append((d, i, j))
        pairs.sort()
        taken_i, taken_j = set(), set()
        matches = {}
        for d, i, j in pairs:
            if i in taken_i or j in taken_j:
                continue
            taken_i.add(i)
            taken_j.add(j)
            matches[i] = circles[j][:2]
        usable = [i for i in matches if i not in excluded]
        if len(usable) < 2:
            # Слишком мало точек, чтобы подобрать собственный центр гекса
            # (например, у X3 всего один троп-слот). Центр по всем гексам —
            # величина почти постоянная, поэтому берём переданный начальный
            # и просто снимаем что нашлось.
            break

        # при фиксированном масштабе центр — просто среднее невязок
        offsets = np.array([matches[i] - scale * units[i] for i in usable])
        new_centre = offsets.mean(axis=0)

        residuals = {
            i: math.hypot(*(new_centre + scale * units[i] - matches[i])) for i in usable
        }
        median = float(np.median(list(residuals.values()))) if residuals else 0.0
        limit = max(OUTLIER_FLOOR_PX, OUTLIER_FACTOR * median)
        new_excluded = {i for i, r in residuals.items() if r > limit}

        converged = np.allclose(new_centre, centre, atol=0.05) and new_excluded == excluded
        centre, excluded = new_centre, new_excluded
        if converged:
            break

    return centre, matches


def main():
    hex_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("hexes")
    sites = load("site_data")
    routes = load("route_slots")
    hex_ids = sorted(set(list(sites.keys()) + list(routes.keys())))

    # --- проход 1: масштаб по каждому гексу, чтобы взять общую медиану ----
    per_hex = {}
    scales = []
    for hex_id in hex_ids:
        img_path = hex_dir / f"hex_{hex_id}.png"
        if not img_path.exists():
            continue
        img = cv2.imread(str(img_path))
        h, w = img.shape[:2]
        circles = detect_circles(img)
        slots = hex_slots(hex_id, sites, routes)
        # Гексы с одним-двумя слотами (A7 после правки, X3) тоже обрабатываем —
        # центр им достанется медианный, см. ниже.
        if len(circles) < 1 or len(slots) < 1:
            continue
        units = np.array([[s[2], -s[3]] for s in slots], dtype=float)
        per_hex[hex_id] = (img, w, h, circles, slots, units)
        # грубая оценка масштаба через собственную подгонку из калибратора
        from calibrate_hexes import calibrate, data_points
        cal = calibrate(hex_id, img, data_points(hex_id, sites, routes))
        if cal:
            scales.append(cal["scale_px_per_unit"] / (w / 1816.0))

    global_scale_1816 = float(np.median(scales))
    print(f"общий масштаб: {global_scale_1816:.3f} px на единицу при картинке 1816 px")
    print(f"  (по {len(scales)} гексам, разброс {np.std(scales):.3f})\n")

    # --- проход 2: центр на гекс с фиксированным масштабом, снап ----------
    report = {}
    moved_total = 0
    unmatched_total = 0
    slots_total = 0

    print(f"{'гекс':5} {'слотов':>7} {'снято':>6} {'без круга':>10} {'макс сдвиг':>11}  исправления")
    print("-" * 84)

    # Центр гекса почти не гуляет от картинки к картинке, поэтому для гексов
    # с одним-двумя слотами (X3) берётся медианный центр по остальным, а не
    # центр картинки: так единственный слот всё равно садится в свой круг.
    provisional = {}
    for hex_id, (img, w, h, circles, slots, units) in per_hex.items():
        scale = global_scale_1816 * (w / 1816.0)
        provisional[hex_id] = fit_centre(units, circles, scale, (w / 2.0, h / 2.0))
    reliable = [c for hid, (c, m) in provisional.items() if len(m) >= 4]
    median_centre = np.median(np.array(reliable), axis=0) if reliable else None

    for hex_id, (img, w, h, circles, slots, units) in per_hex.items():
        scale = global_scale_1816 * (w / 1816.0)
        centre, matches = provisional[hex_id]
        if len(matches) < 3 and median_centre is not None:
            centre, matches = fit_centre(units, circles, scale, median_centre)
            if not matches:
                centre = median_centre

        entries = []
        max_shift = 0.0
        for i, (key, sid, x, z) in enumerate(slots):
            slots_total += 1
            if i not in matches:
                unmatched_total += 1
                entries.append({"slot": sid, "status": "нет печатного круга"})
                continue
            px = matches[i]
            new_x = float((px[0] - centre[0]) / scale)
            new_z = float(-(px[1] - centre[1]) / scale)
            shift = math.hypot(new_x - x, new_z - z)
            max_shift = max(max_shift, shift)

            kind, idx, sub = key
            if kind == "site":
                target = sites[hex_id][idx]["troop_slots"][sub]
            else:
                target = routes[hex_id][idx]
            target["x"] = round(new_x, 4)
            target["z"] = round(new_z, 4)
            if kind == "route":
                target["radius"] = round(math.hypot(new_x, new_z), 4)

            if shift >= REPORT_THRESHOLD_UNITS:
                moved_total += 1
                entries.append({
                    "slot": sid,
                    "status": "исправлено",
                    "было": [round(x, 4), round(z, 4)],
                    "стало": [round(new_x, 4), round(new_z, 4)],
                    "сдвиг_единиц": round(shift, 4),
                    "сдвиг_px": round(shift * scale, 1),
                })

        fixes = [e for e in entries if e.get("status") == "исправлено"]
        missing = [e for e in entries if e.get("status") == "нет печатного круга"]
        note = ""
        if fixes:
            note = ", ".join(f"{e['slot']} ({e['сдвиг_px']:.0f}px)" for e in fixes[:3])
            if len(fixes) > 3:
                note += f" и ещё {len(fixes) - 3}"
        print(f"{hex_id:5} {len(slots):7} {len(matches):6} {len(missing):10} "
              f"{max_shift:11.3f}  {note}")

        report[hex_id] = {
            "scale_px_per_unit": round(scale, 3),
            "centre_px": [round(float(centre[0]), 2), round(float(centre[1]), 2)],
            "slots": len(slots),
            "snapped": len(matches),
            "entries": entries,
        }

    # маршрутные слоты меняли радиус — пересчитать привязку к ребру
    dir_angles = {"N": 90, "NE": 30, "SE": -30, "S": -90, "SW": -150, "NW": 150}
    for hex_id, slots in routes.items():
        for s in slots:
            angle = math.degrees(math.atan2(s["z"], s["x"]))
            best_dir, best_delta = None, 999.0
            for d, a in dir_angles.items():
                delta = abs((angle - a + 180) % 360 - 180)
                if delta < best_delta:
                    best_dir, best_delta = d, delta
            s["edge_dir"] = best_dir
            s["edge_angle_delta"] = round(best_delta, 4)

    (DATA / "site_data.json").write_text(
        json.dumps(sites, ensure_ascii=False, indent=2), encoding="utf-8")
    (DATA / "route_slots.json").write_text(
        json.dumps(routes, ensure_ascii=False, indent=2), encoding="utf-8")
    (DATA / "snap_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    print("-" * 84)
    print(f"слотов всего:            {slots_total}")
    print(f"снято на печатный круг:  {slots_total - unmatched_total}")
    print(f"без печатного круга:     {unmatched_total}")
    print(f"исправлено (>{REPORT_THRESHOLD_UNITS} ед.):  {moved_total}")
    print(f"\nобновлены site_data.json, route_slots.json; отчёт в snap_report.json")


if __name__ == "__main__":
    main()
