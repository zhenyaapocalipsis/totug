#!/usr/bin/env bash
# Выложить текущую версию игры на сервер и перезапустить его.
# Запуск из Git Bash:  bash server/deploy.sh
# Нужен ключ ~/.ssh/tyrants_vps (см. server/README.md).
set -euo pipefail
HOST=root@129.101.123.70
KEY=~/.ssh/tyrants_vps
GODOT="/c/godot/Godot_v4.7.2-stable_win64_console.exe"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "== export game pack"
mkdir -p "$ROOT/engine/build"
"$GODOT" --headless --path "$ROOT/engine/godot" --export-pack "Linux Game" ../build/tyrants_server.pck >/dev/null 2>&1
ls -la "$ROOT/engine/build/tyrants_server.pck"

echo "== upload"
scp -i $KEY -q "$ROOT/engine/build/tyrants_server.pck" "$HOST:/opt/tyrants/tyrants_server.pck.new"
scp -i $KEY -q "$ROOT/server/tyrants.service" "$HOST:/etc/systemd/system/tyrants.service"

echo "== restart"
ssh -i $KEY $HOST 'set -e
cd /opt/tyrants
mv tyrants_server.pck.new tyrants_server.pck
chown -R tyrants:tyrants /opt/tyrants
ufw allow 7780/udp >/dev/null
systemctl daemon-reload
systemctl enable tyrants >/dev/null 2>&1
systemctl restart tyrants
sleep 3
systemctl is-active tyrants
journalctl -u tyrants -n 5 --no-pager -o cat'
