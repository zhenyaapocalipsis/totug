@echo off
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0collect-starter-diagnostics.ps1" -GameDirectory "%~dp0."
pause
