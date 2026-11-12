# November 12 foundation checkpoint

This is an incremental source update, not a claim of a finished commercial game.
The five levels and 32 authored districts remain intact. The November 6 portable
Windows build remains `c73159b`; pulling this source does not update that EXE.

## What changed

- Build arithmetic and campaign checkpoint validation are now pure modules.
- A validated content catalog stops startup with an actionable error when a level
  definition is missing or IDs/dependencies are invalid, instead of silently
  starting a shortened campaign.
- Run snapshots and decoded checkpoint envelopes are detached from their inputs.
- `campaign/save/checkpoint_store.gd` owns checkpoint reads, invalid-file backup
  preservation and pending-file commits. Version 1 save meaning and write order
  are preserved; the campaign host still applies live state and owns transitions.
- `Play-MOKSHA.cmd` provides version-checked source startup and asset import.
  See [Windows quickstart](PC_QUICKSTART.md). No installation, network download,
  administrator access or security-setting change is performed by the launcher.
- Objective captions now render above crates while remaining hidden when sight
  is traded away. A native Capacitor Mill fixture confirmed the occlusion fix.

The original `combat_pc/`, `simulation/` and `demo/` implementations are unchanged.
There is no new controller, ECS, combat rewrite or copied commercial implementation.

## Reference-led boundaries, not folder imitation

[The foundation blueprint](REFERENCE_FOUNDATION.txt) records the inspected source
links, actual REA run, limitations and explicit responsibility mapping. Official
REA 6.8.0 analyzed a pinned public **shapez.io source** checkout. This was not
Dead Cells binary decompilation. Separately attributed Dead Cells field notes
inform bounded observations, not a recovered complete original source tree.

The blueprint is the pre-migration plan. This checkpoint implements small parts
of Phase 1: content validation and detached persistence responsibilities. Live
run state, actor construction and transition ownership are not fully migrated.
Later phases must pass their gates rather than being inferred from new folders.

## Verified evidence

Combined production source `a517f46` passed 10/10 isolated integration stages:
content/detachment contracts, 8,750 pure-policy checks, all 32 district loads,
and live-build/save/adversarial restore checks at 60/120 Hz. The objective paint
contract passed 151 checks; the source launcher has two structural tests.
Source hashes, commands and stage receipts are in
[`nov12_integrated_foundation`](../quality/nov12_integrated_foundation/).
Phase-specific negative controls and PC native screenshots are also retained
in the neighboring `nov12_phase1`, `nov12_architecture` and `nov12_pc_startup` folders.

Actual recorded baseline gameplay is labeled `c73159b`, automated real inputs
at normal speed on Linux. The complete Level 1 recording reaches all six
districts and the level ending; later-level clips are checkpoint-start excerpts.
Those recordings do not show subsequent visual or level-layout improvements.

## Still unverified or incomplete

- Native Windows execution, Windows launcher behavior and Windows hardware performance.
- A new portable export containing these source changes.
- Full human playthrough, audible mix and the 15–20-minute-per-level pacing target.
- The entire proposed ownership migration, upcoming neon crowds and redesigned routes.

Headless contracts, native scene fixtures and input-driven playthroughs prove
different things. Architecture references alone do not guarantee quality.
