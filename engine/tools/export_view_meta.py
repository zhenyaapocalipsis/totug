#!/usr/bin/env python3
"""
Готовит view_meta.json для сцены просмотра доски в Godot.

Сцена должна ставить и поворачивать тайлы ровно так же, как это делает
tools/render_board.py, но в Godot нет OpenCV, поэтому вся геометрия считается
здесь и передаётся числами:

  * hex_centre  — геометрический центр шестиугольника в пикселях текстуры.
                  Поворачивать и размещать тайл нужно вокруг него. Не путать
                  с art_centre: тот смещён на ~13 px, и поворот вокруг него
                  разъезжает соседние тайлы (было до 27 px зазора).
  * hex_radius  — радиус шестиугольника, из него шаг между соседями = sqrt(3)*R.
  * art_centre  — начало координат арта, по которому заданы троп-слоты.
  * art_scale   — пикселей текстуры на единицу координат арта.

Всё пересчитано под уменьшенные текстуры в godot/assets/hexes.

Запуск:
    python3 tools/export_view_meta.py "путь/к/board hexes"
"""

import json
import math
import sys
from pathlib import Path

import cv2

sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_board import hex_centre_radius  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data" / "board"
ASSETS = ROOT / "godot" / "assets" / "hexes"


def main():
    src_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("hexes")
    snap = json.loads((DATA / "snap_report.json").read_text(encoding="utf-8"))

    hexes = {}
    radii = []
    for asset in sorted(ASSETS.glob("hex_*.png")):
        hex_id = asset.stem.replace("hex_", "")
        original = cv2.imread(str(src_dir / asset.name))
        if original is None or hex_id not in snap:
            continue
        small = cv2.imread(str(asset))
        # текстуры уменьшены — вся геометрия масштабируется тем же коэффициентом
        factor = small.shape[1] / original.shape[1]

        centre, radius = hex_centre_radius(original)
        cal = snap[hex_id]
        hexes[hex_id] = {
            "texture_size": [int(small.shape[1]), int(small.shape[0])],
            "hex_centre": [round(centre[0] * factor, 3), round(centre[1] * factor, 3)],
            "hex_radius": round(radius * factor, 3),
            "art_centre": [round(cal["centre_px"][0] * factor, 3),
                           round(cal["centre_px"][1] * factor, 3)],
            "art_scale": round(cal["scale_px_per_unit"] * factor, 4),
        }
        radii.append(hexes[hex_id]["hex_radius"])

    median_radius = sorted(radii)[len(radii) // 2]
    meta = {
        "hexes": hexes,
        "hex_radius": median_radius,
        "neighbour_step": round(math.sqrt(3) * median_radius, 3),
        # мировая единица раскладки: соседи стоят на R_world*sqrt(3), R_world = 8.5
        "world_radius": 8.5,
    }
    (ROOT / "godot" / "data" / "board" / "view_meta.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    (DATA / "view_meta.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"гексов: {len(hexes)}")
    print(f"радиус шестиугольника в текстуре: {median_radius:.1f} px "
          f"(разброс {min(radii):.1f}..{max(radii):.1f})")
    print(f"шаг между соседями: {meta['neighbour_step']:.1f} px")
    print("сохранено: godot/data/board/view_meta.json")


if __name__ == "__main__":
    main()
