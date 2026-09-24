@echo off
title Tyrants - install server key
echo.
echo   Installs your key on the game server (one time only).
echo.
set /p IP=  Server IP address (for example 185.12.34.56): 
echo.
echo   Now type the root password of the server and press Enter.
echo   (the password is not shown while you type - that is normal)
echo.
type "%USERPROFILE%\.ssh\tyrants_vps.pub" | ssh -o StrictHostKeyChecking=accept-new root@%IP% "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys && echo && echo   KEY INSTALLED - tell Claude the IP address"
echo.
pause
