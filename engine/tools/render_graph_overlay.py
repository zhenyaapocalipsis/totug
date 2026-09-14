#!/usr/bin/env python3
"""
Визуальная проверка топологии: рисует троп-слоты и выведенные связи
поверх реального изображения гекса.

Преобразование "единицы арта -> пиксели" берётся из data/board/snap_report.json
(порождается tools/snap_slots_to_art.py): общий масштаб для всех гексов плюс
подобранный на гекс центр. Раньше здесь масштаб подбирался отдельно для каждого
гекса по самой дальней точке — из-за этого точки уезжали с печатных кругов
тем сильнее, чем сильнее у гекса отличалась самая дальняя точка. Это была
ошибка отрисовки, а не данных.

Запуск:
    python3 tools/render_graph_overlay.py B1 [путь_к_папке_с_гексами] [выходной_файл]

Цвета:
    зелёный   — троп-слоты сайтов (подписаны именем сайта)
    оранжевый — троп-слоты маршрутов
    белая линия  — связь внутри сайта
    жёлтая линия — связь маршрутного слота с сайтом
    синий пунктирный круг — печатный круг, найденный на арте (контроль попадания)
"""

import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data" / "board"

# тот же порог, что в godot/core/map/board_builder.gd — держать синхронным
INTRA_SITE_MAX_DIST = 1.6


def load(name):
    return json.loads((DATA / f"{name}.json").read_text(encoding="utf-8"))


def collect_slots(hex_id, sites, routes):
    slots = []
    for site in sites.get(hex_id, []):
        for s in site["troop_slots"]:
            slots.append({
                "id": s["id"], "x": s["x"], "z": s["z"],
                "site": site["id"], "site_name": site["name"],
            })
    for s in routes.get(hex_id, []):
        slots.append({
            "id": s["id"], "x": s["x"], "z": s["z"],
            "site": None, "site_name": None, "edge_dir": s["edge_dir"],
        })
    return slots


def derive_links(slots):
    """Повторяет логику BoardBuilder._link_within_hex (шаги 1-2)."""
    links = []
    for i, a in enumerate(slots):
        for b in slots[i + 1:]:
            if a["site"] is None or a["site"] != b["site"]:
                continue
            if math.dist((a["x"], a["z"]), (b["x"], b["z"])) <= INTRA_SITE_MAX_DIST:
                links.append((a, b, "site"))
    site_slots = [s for s in slots if s["site"] is not None]
    for r in slots:
        if r["site"] is not None or not site_slots:
            continue
        best = min(site_slots, key=lambda s: math.dist((r["x"], r["z"]), (s["x"], s["z"])))
        links.append((r, best, "route"))
    return links


def render(hex_id, hex_dir, out_path):
    sites, routes = load("site_data"), load("route_slots")
    slots = collect_slots(hex_id, sites, routes)
    if not slots:
        print(f"у гекса {hex_id} нет слотов")
        return

    try:
        report = load("snap_report")[hex_id]
    except (FileNotFoundError, KeyError):
        print(f"нет калибровки для {hex_id} — сначала запусти tools/snap_slots_to_art.py")
        return
    scale = report["scale_px_per_unit"]
    cx, cy = report["centre_px"]

    img_path = Path(hex_dir) / f"hex_{hex_id}.png"
    if not img_path.exists():
        print(f"нет изображения {img_path}")
        return
    img = Image.open(img_path).convert("RGB")

    def to_px(s):
        # ось Z в данных вверх, Y на картинке вниз
        return (cx + s["x"] * scale, cy - s["z"] * scale)

    draw = ImageDraw.Draw(img, "RGBA")
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 34)
        small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 26)
    except OSError:
        font = small = ImageFont.load_default()

    for a, b, kind in derive_links(slots):
        colour = (255, 255, 255, 210) if kind == "site" else (255, 210, 40, 210)
        draw.line([to_px(a), to_px(b)], fill=colour, width=5)

    # перекрестие в центре печатного круга — видно попадание с точностью до пикселя
    for s in slots:
        x, y = to_px(s)
        is_site = s["site"] is not None
        fill = (40, 220, 90, 235) if is_site else (255, 150, 30, 235)
        r = 15
        draw.ellipse([x - r, y - r, x + r, y + r], fill=fill,
                     outline=(0, 0, 0, 255), width=3)
        arm = 34
        draw.line([(x - arm, y), (x + arm, y)], fill=fill, width=3)
        draw.line([(x, y - arm), (x, y + arm)], fill=fill, width=3)
        if not is_site:
            draw.text((x + 22, y - 40), s["edge_dir"], fill=(120, 200, 255),
                      font=small, stroke_width=3, stroke_fill=(0, 0, 0))

    seen = set()
    for s in slots:
        if s["site"] is None or s["site"] in seen:
            continue
        seen.add(s["site"])
        x, y = to_px(s)
        draw.text((x + 30, y + 20), s["site_name"], fill=(40, 255, 120), font=font,
                  stroke_width=4, stroke_fill=(0, 0, 0))

    snapped = report["snapped"]
    draw.text((24, 24),
              f"hex {hex_id} — слотов {len(slots)}, снято на арт {snapped}  "
              f"масштаб {scale:.1f} px/ед",
              fill=(255, 255, 255), font=font, stroke_width=4, stroke_fill=(0, 0, 0))

    img.thumbnail((1400, 1400))
    img.save(out_path)
    print(f"сохранено: {out_path}")


if __name__ == "__main__":
    hex_id = sys.argv[1] if len(sys.argv) > 1 else "B1"
    hex_dir = sys.argv[2] if len(sys.argv) > 2 else str(ROOT / "hexes")
    out = sys.argv[3] if len(sys.argv) > 3 else str(ROOT / f"overlay_{hex_id}.png")
    render(hex_id, hex_dir, out)
