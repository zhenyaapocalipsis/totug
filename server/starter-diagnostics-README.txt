STARTER DECK DIAGNOSTICS

1. Extract collect-starter-diagnostics.bat and .ps1 beside the game's .exe and .pck.
2. Close the game, then double-click collect-starter-diagnostics.bat.
3. Send the tyrants-starters-*.zip created on your Desktop to the game owner.

Windows PowerShell 5.1 is sufficient; Godot and Python are not required.
The collector reads package hashes, rules/data, up to 3 recent game logs and
3 bot replays. It does not read profiles/account keys, send anything over the
network, launch/update the game or modify its files.
If collection fails, send the resulting ZIP anyway: diagnostics.json records
the error. Temporary extracted diagnostics remain in the Windows TEMP folder.
