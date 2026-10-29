# MOKSHA — first-play handoff

**Build:** Relay Works Districts checkpoint. **Archive:** `MOKSHA-Relay-Works-Districts-2026-10-23-Project.zip`. Verify its SHA-256 against the separately delivered `Works-Project-manifest.json` (an archive cannot contain its own final hash).
Human first-play pacing and usability are not yet established. Please do not read route guides or watch scripted walkthroughs before this session.

## Open and play

1. Extract the complete project to a writable folder. In **Godot 4.6.3**, import the extracted `MOKSHA/project.godot` and let the initial import finish.
2. Open the project and press **F5** (Run Project). Click the game window if it needs keyboard focus. The configured campaign scene is `demo/mission.tscn`.
3. Press **Enter** for a new mission. **C** on the title resumes an available checkpoint; use that only if this is intentionally a continuation.
4. Play naturally. Follow the on-screen objectives and make your own choices. You do not need to collect everything, defeat every enemy, inspect every route, or deliberately backtrack. Stop whenever you want; a stopped session is still useful feedback.

### Controls

- **A/D or arrow keys:** move. **Space:** jump; release for a shorter jump, press again for an air jump.
- **W/S:** climb ladders; **Space** jumps off. **S + Space:** drop through a thin platform.
- **J:** attack; fresh presses chain attacks. **K:** timed parry, or hold to guard. **Shift:** roll.
- **Q:** make a sound pulse. **E:** interact with something nearby; read the panel before choosing.
- **R:** retry the current area. **Esc:** pause. **M:** mute. **F12:** save a screenshot to the game's user-data folder.

## Simple session record

**Anonymous alias:** ___  **Date:** ___  **Build/archive hash:** ___
**Computer/OS/input device:** ___  **Prior familiarity with this game/controls:** ___
**New game or Continue:** ___

- Wall-clock start/end: ___ / ___
- HUD timer at start/end: ___ / ___
- Deaths / manual retries: ___ / ___
- Ending reached, or last area and reason for stopping: ___
- Brief time-stamped notes when useful: reading/planning; optional exploration; replay after a retry; pause/away/technical interruption; help requested or received (what, when, and how long).
- After playing: What felt clear? Where were you unsure what to do or where you could stand? Which choices mattered? What felt repetitive or frustrating?

The HUD timer measures time in the playing state, **including standing still**. Reading or planning may overlap that timer; paused/dialogue time and technical interruptions need separate notes. Do not add these overlapping observations together or turn retry/idle time into a claimed content duration. No need to narrate constantly or pause just to fill this form. If someone observes, they should avoid coaching unless you request help and record any help separately.

## Optional module inspection — after the first-play session

These are separate experiments, not campaign completion or pacing evidence:

- Open `sandbox/assembly.tscn`, then **F6** (Run Current Scene): **1** traversal, **2** combat, **3** freight; **R** reloads the selected station.
- Or open `sandbox/stations/traversal.tscn`, `combat.tscn`, or `freight.tscn` and press **F6** for that station alone.
- Open `demo/tests/works_district_review.tscn` and press **F6** for isolated Works review with saving disabled. This skips earlier campaign context; do not use it as the first-play route.
- For reusable-piece configuration, see `sandbox/README.md` and `simulation/ASSEMBLY_CHECKPOINT.md`. Example scene files are `simulation/actors/shared_actor.tscn`, `simulation/world/moving_lift.tscn`, and `simulation/world/mission_cargo.tscn`; the bench supplies their playable surroundings.
