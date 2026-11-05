#!/usr/bin/env bash
# Выложить текущую версию игры на сервер и перезапустить его.
# Запуск из Git Bash:  bash server/deploy.sh
# Нужен ключ ~/.ssh/tyrants_vps (см. server/README.md).
#
# Заодно: новая игра для автообновления (game.pck + version.txt по адресу
# http://129.101.123.70/tyrants/, см. scenes/updater.gd) и свежий exe с архивом
# в "GAME online" — для тех, у кого игры ещё нет.
set -euo pipefail
# Исправления интерфейса/обновлятора не требуют остановки игровых комнат.
CLIENT_ONLY=false
BUILD_ONLY=false
PUBLISH_ONLY=false
for arg in "$@"; do
  case "$arg" in
    --client-only) CLIENT_ONLY=true ;;
    --build-only) BUILD_ONLY=true ;;
    --publish-only) PUBLISH_ONLY=true ;;
    *) echo "Usage: bash server/deploy.sh [--client-only] [--build-only | --publish-only]" >&2; exit 1 ;;
  esac
done
if [ "$PUBLISH_ONLY" = true ] && { [ "$BUILD_ONLY" = true ] || [ "$CLIENT_ONLY" = false ]; }; then
  echo "--publish-only requires --client-only and cannot be combined with --build-only" >&2; exit 1
fi
HOST=root@129.101.123.70
KEY=~/.ssh/tyrants_vps
GODOT="/c/godot/Godot_v4.7.2-stable_win64_console.exe"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/engine/build"
OUT="$ROOT/GAME online"
# Закрытый ключ подписи обновлений — только на этом ПК, не в git (этап Sec-1).
# Без него не выкладываем: игра не примет неподписанную версию.
UPDATE_KEY=~/.ssh/tyrants_update.key
if [ "$PUBLISH_ONLY" = false ] && [ ! -f "$UPDATE_KEY" ]; then
  echo "No update signing key $UPDATE_KEY (see server/README.md, 'Update signing key')." >&2
  exit 1
fi
command -v node >/dev/null || { echo "Node.js is required to build update patches." >&2; exit 1; }
if [ "$PUBLISH_ONLY" = false ]; then
# Keep exact exported bytes: patches also work for players who skipped releases.
node "$ROOT/server/update_patches.cjs" archive "$(cygpath -m "$BUILD_DIR")"

echo "== build number"
BUILD=$(date +%s)
printf 'extends RefCounted\n## Номер версии для автообновления. Пишет server/deploy.sh, в git не хранится.\nconst BUILD := %s\n' "$BUILD" > "$ROOT/engine/godot/build_info.gd"
echo "$BUILD"

echo "== export"
mkdir -p "$BUILD_DIR"
cd "$ROOT/engine/godot"
if [ "$CLIENT_ONLY" = false ]; then
  "$GODOT" --headless --path . --export-pack "Linux Game" ../build/tyrants_server.pck >/dev/null 2>&1
fi
# Игра для Windows — два файла: exe (движок) и .pck рядом (сама игра). Этот
# же .pck и скачивают игроки при автообновлении.
"$GODOT" --headless --path . --export-release "Windows Game" ../build/TyrantsOfTheUnderdark.exe >/dev/null 2>&1
SHA=$(sha256sum "$BUILD_DIR/TyrantsOfTheUnderdark.pck" | cut -d' ' -f1)
# Подпись "<номер> <sha256>"; старые клиенты третье поле не читают.
SIG=$("$GODOT" --headless --path . --script res://tools/sign_update.gd -- --sign "$(cygpath -m "$UPDATE_KEY")" "$BUILD" "$SHA" | sed -n 's/^SIG://p' | tr -d '\r')
if [ -z "$SIG" ]; then
  echo "Signing the update failed." >&2
  exit 1
fi
echo "$BUILD $SHA $SIG" > "$BUILD_DIR/version.txt"
node "$ROOT/server/update_patches.cjs" generate "$(cygpath -m "$BUILD_DIR")" "$(cygpath -m "$UPDATE_KEY")"
ls -la "$BUILD_DIR/TyrantsOfTheUnderdark.pck" "$BUILD_DIR/TyrantsOfTheUnderdark.exe"
if [ "$CLIENT_ONLY" = false ]; then
  ls -la "$BUILD_DIR/tyrants_server.pck"
fi

echo "== GAME online"
cp "$BUILD_DIR/TyrantsOfTheUnderdark.exe" "$BUILD_DIR/TyrantsOfTheUnderdark.pck" "$OUT/"
powershell.exe -NoProfile -Command "Compress-Archive -Force -Path '$(cygpath -w "$OUT/TyrantsOfTheUnderdark.exe")','$(cygpath -w "$OUT/TyrantsOfTheUnderdark.pck")','$(cygpath -w "$OUT/README.txt")' -DestinationPath '$(cygpath -w "$OUT/TyrantsOfTheUnderdark.zip")'"
else
  read -r BUILD SHA REST < "$BUILD_DIR/version.txt"
fi
node "$ROOT/server/update_patches.cjs" validate "$(cygpath -m "$BUILD_DIR")"
if [ "$BUILD_ONLY" = true ]; then
  echo "== local build ready: $BUILD (no server changes)"
  exit 0
fi

echo "== upload"
# Versioned patch files must be present before version.txt advertises them.
ssh -i $KEY $HOST 'mkdir -p /opt/tyrants/www/patches'
scp -i $KEY -q -r "$BUILD_DIR/patches/$BUILD" "$HOST:/opt/tyrants/www/patches/"
if [ "$CLIENT_ONLY" = false ]; then
  scp -i $KEY -q "$BUILD_DIR/tyrants_server.pck" "$HOST:/opt/tyrants/tyrants_server.pck.new"
fi
scp -i $KEY -q "$BUILD_DIR/TyrantsOfTheUnderdark.pck" "$HOST:/opt/tyrants/www/game.pck.new"
scp -i $KEY -q "$BUILD_DIR/version.txt" "$HOST:/opt/tyrants/www/version.txt.new"
# Архив целиком — ссылка для новых игроков: http://129.101.123.70/tyrants/TyrantsOfTheUnderdark.zip
scp -i $KEY -q "$OUT/TyrantsOfTheUnderdark.zip" "$HOST:/opt/tyrants/www/TyrantsOfTheUnderdark.zip.new"
if [ "$CLIENT_ONLY" = false ]; then
  scp -i $KEY -q "$ROOT/server/tyrants.service" "$HOST:/etc/systemd/system/tyrants.service"
fi
scp -i $KEY -q "$ROOT/server/nginx-tyrants.conf" "$HOST:/etc/nginx/sites-available/tyrants"

echo "== restart"
if [ "$CLIENT_ONLY" = true ]; then
  ssh -i $KEY $HOST bash -s <<'REMOTE_CLIENT'
set -e
cd /opt/tyrants
OLD_BUILD=$(cut -d' ' -f1 www/version.txt)
NEW_BUILD=$(cut -d' ' -f1 www/version.txt.new)
test "$OLD_BUILD" -le "$NEW_BUILD" || { echo "Refusing to replace a newer client" >&2; exit 1; }
test "$(sha256sum www/game.pck.new | cut -d' ' -f1)" = "$(cut -d' ' -f2 www/version.txt.new)"
PID_BEFORE=$(systemctl show tyrants -p MainPID --value)
cp -p www/game.pck www/game.pck.previous
cp -p www/version.txt www/version.txt.previous
cp -p www/TyrantsOfTheUnderdark.zip www/TyrantsOfTheUnderdark.zip.previous
mv www/game.pck.new www/game.pck
mv www/TyrantsOfTheUnderdark.zip.new www/TyrantsOfTheUnderdark.zip
mv www/version.txt.new www/version.txt
chown -R tyrants:tyrants /opt/tyrants/www
nginx -t -q && systemctl reload nginx
systemctl is-active tyrants
test "$(systemctl show tyrants -p MainPID --value)" = "$PID_BEFORE"
echo "Game server PID unchanged: $PID_BEFORE"
REMOTE_CLIENT
else
ssh -i $KEY $HOST bash -s <<'REMOTE_SERVER'
set -e
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
journalctl -u tyrants -n 5 --no-pager -o cat
REMOTE_SERVER
fi

# Тот же архив — на GitHub (постоянная ссылка, см. server/github-release.sh).
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  echo "== GitHub"
  bash "$ROOT/server/github-release.sh"
else
  echo "== GitHub: skipped (no gh or not logged in: gh auth login)"
fi
