@echo off
chcp 866 > nul
title Board viewer - build

echo.
echo   Собираю программу из частей...
echo.

copy /b board.part.00 + board.part.01 + board.part.02 + board.part.03 + board.part.04 + board.part.05 + board.part.06 "board-viewer.exe" > nul

if not exist "board-viewer.exe" (
  echo   ОШИБКА: не удалось собрать. Проверь, что все 7 файлов
  echo   board.part.00 - board.part.06 лежат в этой же папке.
  echo.
  pause
  exit /b 1
)

del board.part.0* > nul 2>&1

echo   Готово. Появился файл  board-viewer.exe
echo   Запусти его двойным щелчком.
echo.
echo   Этот файл (build-viewer.bat) больше не нужен, можно удалить.
echo.
pause
