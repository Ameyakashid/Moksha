# November 6 improvement pass

This record describes the new implementation. Its final acceptance section is
completed only after a stable source snapshot is tested. Earlier reports remain
historical and keep their original hashes.

## Player-facing changes

- Full campaign controller navigation, including title lens choice, interaction,
  sonar, journal paging, pause, retry, sight trade, upgrades and both endings.
  Prompts change only after intentional keyboard/controller input. The original
  actor still owns movement, jumping, rolling, shields and strike admission.
- Menu and scene boundaries release held gameplay actions. Skipping the opening,
  returning from the journal, choosing an upgrade or retrying cannot accidentally
  turn the menu button into a jump, strike or guard. Release and press again.
- Losing window focus or disconnecting the active controller pauses active play.
  Returning does not silently resume. Pending transitions also stop at this
  boundary; choice and progression state must remain coherent.
- A presentation-only camera follows sustained travel with bounded look-ahead and
  a vertical comfort window. Ordinary jumps no longer pull the whole room up and
  down. The camera does not change motion, collisions or inputs.
- The HUD shows health numerically, district/lens/progress and a clear next step.
  Objective labels distinguish optional, unavailable and completed states. Menu
  prose is measured; pause controls use separate keycaps and aligned columns.
  Notifications no longer cover a floor-standing operative's lower body.
- The real HUD owner retains typed campaign fields without changing the original
  simulation HUD contract. This fixes a native-rendered integration defect that
  direct View-only tests did not expose.
- Interaction uses the same nearby-objective selector and radius as its prompt.
  Finished or unusable housings no longer steal the use command from a nearby
  eligible terminal. Circuit breakers recheck prerequisites at physical contact.
- Health or speed augments no longer replace an unchanged melee chain and cancel
  a live strike. Upgrades still apply additively from base resources; capacity
  augments do not heal and retries do not multiply bonuses again.
- Checkpoint failures explain what happened. A failed write retains any last valid
  checkpoint. Starting New after an invalid checkpoint preserves and verifies an
  exact copy before replacing it; failed preservation leaves the original alone.

## Six authored layout corrections

1. Stamping's optional plate starts unloaded. Its crate at `(3900,300)` must be
   pushed onto the plate at `(4000,300)` and settle.
2. Waterline's optional plate also starts unloaded; its crate begins at `(3510,300)`.
3. City Evacuation's western-refuge rescue opens a real walkable underpass rather
   than a door inside a solid plinth. The existing roof bypass remains available.
4. Market's first lock moves to x3130, leaving safe closed-gate staging.
5. Drainage's first lock moves to x3270 for the same reason.
6. Thermal's final floor arc moves to x3370 under the preceding gallery gap,
   clearing the mandatory closed-door approach.

The five levels, 32 districts, 123 authored objectives and 250 enemy placements
remain intact. No hazard damage/period, ordinary enemy statistic, player controller,
elapsed-time gate or forced wave was added to create artificial duration.

## Reproducible focused tests

Run from the project root with Godot 4.6.3 on PATH:

```
python3 tools/verify_nov6.py --output /absolute/new-evidence-directory
```

The runner gives each test its own user-data directory, rejects engine errors and
missing/failed completion receipts, hashes source before and after, and rejects
source drift. Tests include actual `Input.parse_input_event` keyboard/joypad paths,
real shared actor physics, the host-to-HUD-owner-to-View pipeline and intentionally
regressed level placements. Controlled setup/position fixtures are labelled and
are not represented as full traversal.

Full input campaigns, inherited foundation/legacy tests, native rendered review
and packed-runtime acceptance are separate checks. The native review fixture at
`campaign/quality/nov6_native_review.tscn` places a scene for screenshots; it never
counts as a played campaign.

## Acceptance record

Pending final source freeze and fresh acceptance reports. Do not treat this
implementation list or an earlier green report as proof of the current source.

## Limits that remain

Physical gamepad hardware, native Windows execution, target-machine frame rate,
audible mix, a complete human-controlled campaign and first-play human duration
remain unverified unless a later report explicitly supplies that evidence.
The 15–20-minute per-level goal remains a design target, not a measurement.

No repository publication, commercial asset import, new sensory-trade mechanic,
roguelite adaptation or resolution of the unresolved time-loop/immortality story
is implied by this pass.
