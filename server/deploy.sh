#!/usr/bin/env bash
# Выложить текущую версию игры на сервер и перезапустить его.
# Запуск из Git Bash:  bash server/deploy.sh
# Нужен ключ ~/.ssh/tyrants_vps (см. server/README.md).
#
# Заодно: новая игра для автообновления (game.pck + version.txt по адресу
# http://129.101.123.70/tyrants/, см. scenes/updater.gd) и свежий exe с архивом
# в "GAME online" — для тех, у кого игры ещё нет.
set -euo pipefail
HOST=root@129.101.123.70
KEY=~/.ssh/tyrants_vps
GODOT="/c/godot/Godot_v4.7.2-stable_win64_console.exe"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/engine/build"
OUT="$ROOT/GAME online"

echo "== build number"
BUILD=$(date +%s)
printf 'extends RefCounted\n## Номер версии для автообновления. Пишет server/deploy.sh, в git не хранится.\nconst BUILD := %s\n' "$BUILD" > "$ROOT/engine/godot/build_info.gd"
echo "$BUILD"

echo "== export"
mkdir -p "$BUILD_DIR"
cd "$ROOT/engine/godot"
"$GODOT" --headless --path . --export-pack "Linux Game" ../build/tyrants_server.pck >/dev/null 2>&1
# Игра для Windows — два файла: exe (движок) и .pck рядом (сама игра). Этот
# же .pck и скачивают игроки при автообновлении.
"$GODOT" --headless --path . --export-release "Windows Game" ../build/TyrantsOfTheUnderdark.exe >/dev/null 2>&1
SHA=$(sha256sum "$BUILD_DIR/TyrantsOfTheUnderdark.pck" | cut -d' ' -f1)
echo "$BUILD $SHA" > "$BUILD_DIR/version.txt"
ls -la "$BUILD_DIR/tyrants_server.pck" "$BUILD_DIR/TyrantsOfTheUnderdark.pck" "$BUILD_DIR/TyrantsOfTheUnderdark.exe"

echo "== GAME online"
cp "$BUILD_DIR/TyrantsOfTheUnderdark.exe" "$BUILD_DIR/TyrantsOfTheUnderdark.pck" "$OUT/"
powershell.exe -NoProfile -Command "Compress-Archive -Force -Path '$(cygpath -w "$OUT/TyrantsOfTheUnderdark.exe")','$(cygpath -w "$OUT/TyrantsOfTheUnderdark.pck")','$(cygpath -w "$OUT/README.txt")' -DestinationPath '$(cygpath -w "$OUT/TyrantsOfTheUnderdark.zip")'"

echo "== upload"
scp -i $KEY -q "$BUILD_DIR/tyrants_server.pck" "$HOST:/opt/tyrants/tyrants_server.pck.new"
scp -i $KEY -q "$BUILD_DIR/TyrantsOfTheUnderdark.pck" "$HOST:/opt/tyrants/www/game.pck.new"
scp -i $KEY -q "$BUILD_DIR/version.txt" "$HOST:/opt/tyrants/www/version.txt.new"
# Архив целиком — ссылка для новых игроков: http://129.101.123.70/tyrants/TyrantsOfTheUnderdark.zip
scp -i $KEY -q "$OUT/TyrantsOfTheUnderdark.zip" "$HOST:/opt/tyrants/www/TyrantsOfTheUnderdark.zip.new"
scp -i $KEY -q "$ROOT/server/tyrants.service" "$HOST:/etc/systemd/system/tyrants.service"
scp -i $KEY -q "$ROOT/server/nginx-tyrants.conf" "$HOST:/etc/nginx/sites-available/tyrants"

echo "== restart"
ssh -i $KEY $HOST 'set -e
cd /opt/tyrants
mv tyrants_server.pck.new tyrants_server.pck
# Сначала игра, потом номер версии: клиент не должен увидеть новый номер
# раньше, чем появится файл.
mv www/game.pck.new www/game.pck
mv www/version.txt.new www/version.txt
mv www/TyrantsOfTheUnderdark.zip.new www/TyrantsOfTheUnderdark.zip
chown -R tyrants:tyrants /opt/tyrants
ufw allow 7780/udp >/dev/null
ufw allow 80/tcp >/dev/null
nginx -t -q && systemctl reload nginx
systemctl daemon-reload
systemctl enable tyrants >/dev/null 2>&1
systemctl restart tyrants
sleep 3
systemctl is-active tyrants
journalctl -u tyrants -n 5 --no-pager -o cat'
