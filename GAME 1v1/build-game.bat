@echo off
chcp 866 > nul
title Tyrants of the Underdark - build

echo.
echo   Собираю игру из частей...
echo.

if exist "Tyrants-1v1.exe" del /f /q "Tyrants-1v1.exe"

copy /b /y game.part.00 + game.part.01 + game.part.02 + game.part.03 + game.part.04 + game.part.05 + game.part.06 "Tyrants-1v1.exe" > nul

if not exist "Tyrants-1v1.exe" (
  echo   ОШИБКА: не удалось собрать. Проверь, что все 7 файлов
  echo   game.part.00 - game.part.06 лежат в этой же папке
  echo   и что старая игра сейчас не запущена.
  echo.
  pause
  exit /b 1
)

del game.part.0* > nul 2>&1

echo   Готово. Появился файл  Tyrants-1v1.exe
echo   Запусти его двойным щелчком.
echo.
pause
