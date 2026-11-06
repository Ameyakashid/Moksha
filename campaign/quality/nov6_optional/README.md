# Optional branches and one-time rewards

This suite fills a coverage gap in the main-path bots: those bots deliberately skip optional campaign objectives. It does not change any production game, layout, actor, combat or physics file.

## Run

From the project root, after the normal Godot import:

```sh
python3 campaign/quality/nov6_optional/run.py \
  --kind all --workers 2 --output /absolute/path/to/NEW-evidence-directory
```

`GODOT_BIN=/path/to/godot` is supported. Output must be new; previous receipts are never overwritten. Each case owns a separate HOME and XDG save directory. An engine error fails the case even with exit status zero. Reports record source hashes, and the runner checks those files again after each run.

- `--kind routes`: 24 authored districts with optional campaign objectives, starting at each district's real authored spawn with a neutral, unupgraded build. All local required and optional goals must complete, all authored reward IDs must be present, and the district exit must be reached.
- `--kind lifecycle`: real physical collections at each of the three crate plates, plus a real walk/E recovery of the Foundry agility augment. Each is collected initially, after two ordinary R retries, after pause/N/C, and after a fresh host reads the genuine saved checkpoint. Runs at both 60 and 120 Hz, for 40 collections. Exact build snapshots must remain unchanged after repeated collection; a live pickup must not heal.
- `--kind all`: both groups, with the route group at 60 Hz retained sight by default.

Route filters may be repeated:

```sh
python3 campaign/quality/nov6_optional/run.py --kind routes \
  --district city_records --district l2_stamping_galleries \
  --district l3_water_clinic --district city_evac_spine \
  --district works_baffle_hall --district crown_ascent \
  --hz 120 --sight both --workers 2 \
  --output /absolute/path/to/NEW-focused-directory
```

Use `--hz 60 --hz 120` for both rates, `--sight retained|traded|both`, and `--seconds` to change the per-district simulated timeout. Longer timeouts are not longer human playtime.

`inventory.gd` independently enumerates production data. The current inventory is 32 districts, 89 required objectives, 34 optional objectives in 24 districts, and 31 optional reward IDs. Three optional terminals have no augment.

## Method and observer boundaries

The acceptance route observer is `all_optional_observer_v7.gd`. Its immutable predecessor layers preserve diagnostic source receipts. They add only button-planning policies:

- Collect a plate pocket before moving its loose cargo far down a corridor.
- Commit to the correct departure lip when returning from a low solid plinth.
- Jump over a real cargo obstruction even when the eventual destination is a distant ladder.
- Use the authored upper baffles rather than repeatedly crossing energized floor strips.
- Return to the Crown weather log through the unobstructed upper route.
- Board the eastern Stamping rescue ladder from its real solid plinth.
- Walk off the push side after a cargo-top landing before completing a plate.

Every measured route uses normal production movement/combat buttons and dispatched E/Q/menu keys, with live enemies, damage, props and collision. There are no measured-phase position, velocity, health, enemy, objective-completion, collision or gate writes. Initial district/lens/sight choices are explicit fixtures. The lifecycle tests additionally use a local initial spawn fixture, retained through Retry/Continue; they do not claim to reach that pocket from the district entrance.

A failed observer route is not automatically a game defect. The diagnostic runs retained outside the project include poor navigation, ordinary deaths from choosing live floor strips, and overly broad hash capture that noticed unrelated QA-script edits. Corrected observers change only inputs. Production files were not edited to make these tests pass.

## Limits

This is headless physics and checkpoint evidence. Isolated district starts do not prove a continuous all-collectibles campaign. Traded-sight setup does not prove the preceding Exchange choice route. The 34-goal inventory covers campaign objectives, not exhaustive collection of the inherited field caches and archives. Routes do not cover every possible order, every dynamic cargo loss, all starting lenses or arbitrary save editing. Native visuals, audio, controller hardware, Windows hardware and first-play human pacing remain separate checks. Optimized bot time is not a human duration estimate.
