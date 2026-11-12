# Play locally and measure real pacing

## Windows

For cloning this repository and running editable source with Godot 4.6.3, use the [PC quickstart](PC_QUICKSTART.md). The steps below are for the separately exported portable build.

1. Extract **all** files from the Windows x64 archive supplied with this November 6 build. `CHECKSUMS.sha256` inside the package lists its extracted files; the package's `BUILD_REPORT.json` describes the tested content. If you received split ZIP parts, read the parts’ `START_HERE.txt` first and verify the reconstructed archive before extracting.
2. Open its `MOKSHA-Windows` folder.
3. Run **`Run-MOKSHA.cmd`** or **`MOKSHA.exe`**. Keep `MOKSHA.pck` beside the EXE. No Godot editor installation is needed for this export.
4. Choose 1 Neutral, 2 Strength or 3 Agility; Enter starts a new campaign. C continues a checkpoint. With a controller, use the D-pad to choose a lens, A or Start to begin, and X to continue.

The executable was exported from verified official Godot 4.6.3 templates. It is not code-signed; do not disable antivirus/security controls to run it. The package contains checksums, engine/project licenses and build notes. The export and its actual packed content were tested on Linux/headless; native Windows execution remains unverified. Separately, representative source scenes and real inputs were reviewed in native Godot on the supported cloud desktop, with recorded screenshots; that is not a full human playthrough.

Full-color environment/operative/security presentation is enabled by default. F8 toggles the original wireframe debug view without changing rules. The complete controls are in the editable project's root `README.md`, or `docs/PROJECT_README.md` in a playable package. Quick essentials: A/D move; Space jump/air jump; J strike; K parry/guard; Shift roll; W/S ladder; E use; Q sound; Tab journal; Esc pause.

Controller menus use the on-screen prompts. See [the controller guide](NOV6_GAMEPAD.md) for the complete bindings. After leaving a menu, release any held gameplay buttons before pressing them again. Losing focus or disconnecting an active controller pauses play; resume explicitly.

## Linux

If you have the optional Linux x86-64 package, extract the entire archive, open a terminal in its `MOKSHA-Linux` folder and run `./Start-MOKSHA.sh`. It includes the same verified game content and its Godot runtime. No editor installation is needed. On a system that does not preserve executable permissions when extracting ZIPs, run `chmod +x Start-MOKSHA.sh MOKSHA` inside that same folder first. The package does not install anything or request administrator access.

## Saves and automatic timing

This project uses Godot's default user-data directory, with project name **MOKSHA — Five Ascents** (the character between MOKSHA and Five is an em dash). On Windows paste this into File Explorer's address bar:

```
%APPDATA%\Godot\app_userdata\MOKSHA — Five Ascents\
```

Godot documents the default Windows location as `%APPDATA%\Godot\app_userdata\[project_name]`. No custom user-directory setting is enabled in this build. [Official Godot data-path documentation](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html)

- `moksha_five_levels_v1.json`: current district checkpoint, lens, sight choice, upgrades, per-level unpaused seconds and completed-level receipts.
- `moksha_five_levels_results.json`: written after the final choice; contains the ending, total `active_seconds`, five `levels` entries on a first completion, district metrics, starting lens, level upgrades, deaths and kills. It does not include the optional-augment reward dictionary.
- F12 screenshots during gameplay, when supported by the renderer, also go in this directory. For journal, upgrade and final-choice panels, use your operating system's screenshot shortcut instead.

**What the clock means:** it runs during unpaused gameplay, including standing still or thinking in the world. Pauses, archive panels, the journal, upgrade screens and sight/final choices are excluded. It is not an automatic detector of attention or purposeful action. Checkpoint data reflects the most recent checkpoint/objective save; final results record the completed run. Retrying adds further unpaused time rather than erasing the attempt.

Continue resumes the saved district start. After completing and returning to Title, Continue replays the final district and adds another receipt and active time to the same run when completed again. Closing directly from the ending instead resumes the last saved checkpoint, before that final completion was recorded in checkpoint data.

New starts fresh progress and initially leaves the previous results file intact. The next completion, including a final-district replay, overwrites that single results file. Copy it elsewhere before another completion if you want to keep the earlier result. Legacy demo save filenames are never modified.

## Simple first-play notes (optional)

The 15–20-minute target for each level is **unverified**. To assess it without guessing a bot multiplier, keep a short note for each level:

| Level | Unpaused game time | Wall-clock time | Reading/planning | Voluntary exploration | Retries | Confusing/blocking moment |
|---|---|---|---|---|---|---|
| City | | | | | | |
| Foundry | | | | | | |
| Residences | | | | | | |
| Works | | | | | | |
| Crown | | | | | | |

Record whether this is a first encounter with the layouts, lens/sight choices, and any long idle interruption. Preserve the final results JSON if sharing feedback. Useful feedback is a district name, what you tried, what you expected and what happened, rather than a forced playtime estimate.

The automated tests know geometry and enemy behavior. Their times prove controlled traversal, not how long a human will need or whether unfamiliar players understand every route.
