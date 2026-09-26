# Game server (VPS)

- Host: `129.101.123.70` (Ubuntu 24.04), SSH as root with key `~/.ssh/tyrants_vps` (no password login needed).
- Game: `/opt/tyrants/godot` (official Godot 4.7.2 Linux build) + `/opt/tyrants/tyrants_server.pck`, run as user `tyrants`.
- Service: `tyrants` (systemd, file `server/tyrants.service`), restarts itself and starts on boot. UDP port 7780 open in ufw.
- Update after any network/rules change: `bash server/deploy.sh` (Git Bash). Bump `NetSession.PROTOCOL` when old clients must not join.
- Logs: `ssh -i ~/.ssh/tyrants_vps root@129.101.123.70 journalctl -u tyrants -f`
- Ratings (Elo of online games): `/opt/tyrants/.local/share/godot/app_userdata/Tyrants of the Underdark/ratings.json` (appears after the first rated game). `deploy.sh` only replaces the .pck, so ratings survive updates; back the file up now and then.
