# Play locally and measure real pacing

## Windows

1. Extract **all** files from `MOKSHA-Windows-x64-4ea2c11.zip`.
2. Open its `MOKSHA-Windows` folder.
3. Run **`Run-MOKSHA.cmd`** or **`MOKSHA.exe`**. Keep `MOKSHA.pck` beside the EXE. No Godot editor installation is needed for this export.
4. Choose1 Neutral,2 Strength or3 Agility; Enter starts a new campaign. C continues a checkpoint.

The executable was exported from verified official Godot4.6.3 templates. It is not code-signed; do not disable antivirus/security controls to run it. The package contains checksums, engine/project licenses and build notes. The export and its actual packed content were tested on Linux/headless; native Windows execution and rendered pixels were not available in this executor.

Full-color environment/operative/security presentation is enabled by default. F8 toggles the original wireframe debug view without changing rules. See the root README for the complete controls. Quick essentials: A/D move; Space jump/air jump; J strike; K parry/guard; Shift roll; W/S ladder; E use; Q sound; Tab journal; Esc pause.

## Saves and automatic timing

This project uses Godot's default user-data directory, with project name **MOKSHA — Five Ascents** (the character between MOKSHA and Five is an em dash). On Windows paste this into File Explorer's address bar:

```
%APPDATA%\Godot\app_userdata\MOKSHA — Five Ascents\
```

Godot documents the default Windows location as `%APPDATA%\Godot\app_userdata\[project_name]`. No custom user-directory setting is enabled in this build. [Official Godot data-path documentation](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html)

- `moksha_five_levels_v1.json`: current district checkpoint, lens, sight choice, upgrades, per-level unpaused seconds and completed-level receipts.
- `moksha_five_levels_results.json`: written after the final choice; contains the ending, total `active_seconds`, five `levels` entries, district metrics, build, deaths and kills.
- F12 screenshots, when supported by the renderer, also go in this directory.

**What the clock means:** it runs during unpaused gameplay, including standing still or thinking in the world. Pauses, archive panels, the journal, upgrade screens and sight/final choices are excluded. It is not an automatic detector of attention or purposeful action. Checkpoint data reflects the most recent checkpoint/objective save; final results record the completed run. Retrying adds further unpaused time rather than erasing the attempt.

Continue resumes the saved district start. After completion it replays the final district; New starts fresh progress but does not delete the previous results file. Legacy demo save filenames are never modified.

## Simple first-play notes (optional)

The15–20minute target for each level is **unverified**. To assess it without guessing a bot multiplier, keep a short note for each level:

| Level | Unpaused game time | Wall-clock time | Reading/planning | Voluntary exploration | Retries | Confusing/blocking moment |
|---|---|---|---|---|---|---|
| City | | | | | | |
| Foundry | | | | | | |
| Residences | | | | | | |
| Works | | | | | | |
| Crown | | | | | | |

Record whether this is a first encounter with the layouts, lens/sight choices, and any long idle interruption. Preserve the final results JSON if sharing feedback. Useful feedback is a district name, what you tried, what you expected and what happened—not a forced playtime estimate.

The automated tests know geometry and enemy behavior. Their times prove controlled traversal, not how long a human will need or whether unfamiliar players understand every route.
