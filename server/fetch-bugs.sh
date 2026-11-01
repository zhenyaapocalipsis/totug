#!/usr/bin/env bash
# Скачать с сервера отчёты BUG REPORT (этап Bug-1) в "Claude outputs/bug_reports/".
# Запуск из Git Bash:  bash server/fetch-bugs.sh
# Каждый отчёт — папка: report.txt, screen.jpg, log.txt, game.replay (смотреть —
# скопировать в user://replays/ и открыть из истории/реплеев).
set -euo pipefail
HOST=root@129.101.123.70
KEY=~/.ssh/tyrants_vps
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/Claude outputs"
mkdir -p "$OUT"
ssh -i $KEY $HOST "cd '/opt/tyrants/.local/share/godot/app_userdata/Tyrants of the Underdark' && [ -d bug_reports ] && tar czf - bug_reports || true" \
  | tar xzf - -C "$OUT"
ls -1 "$OUT/bug_reports" 2>/dev/null || echo "No bug reports yet."
