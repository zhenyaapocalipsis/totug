#!/usr/bin/env bash
# Выложить архив игры (GAME online/TyrantsOfTheUnderdark.zip) на GitHub —
# постоянная ссылка для новых игроков (владелец, 2026-10-24):
#   https://github.com/zhenyaapocalipsis/totug/releases/download/client/TyrantsOfTheUnderdark.zip
# Один релиз с тегом "client", архив в нём каждый раз заменяется, ссылка не меняется.
# Нужен GitHub CLI (gh), один раз войти: gh auth login. Запуск из Git Bash:
#   bash server/github-release.sh
# deploy.sh вызывает его сам в конце, если gh установлен и вход выполнен.
set -euo pipefail
REPO=zhenyaapocalipsis/totug
TAG=client
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZIP="$ROOT/GAME online/TyrantsOfTheUnderdark.zip"

if [ ! -f "$ZIP" ]; then
  echo "No $ZIP (run server/deploy.sh first)." >&2
  exit 1
fi
if ! gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  gh release create "$TAG" --repo "$REPO" --title "Tyrants of the Underdark - game" --latest \
    --notes "Download TyrantsOfTheUnderdark.zip below, unpack it anywhere and run TyrantsOfTheUnderdark.exe (keep the .pck next to it). The game updates itself on start."
fi
gh release upload "$TAG" "$ZIP" --repo "$REPO" --clobber
echo "https://github.com/$REPO/releases/download/$TAG/TyrantsOfTheUnderdark.zip"
