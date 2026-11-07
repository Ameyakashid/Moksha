# November 6 improvement pass

The runtime is frozen at `bf3ebd382eb9485eeaffcdff9fe9bfcfda8d3ad5`.
Delivery provenance separately identifies the final documentation/test commit.
Earlier reports remain historical and keep their original hashes.

## Player-facing changes

- Full campaign controller navigation, including title lens choice, interaction,
  sonar, journal paging, pause, retry, sight trade, upgrades and both endings.
  Prompts change only after intentional keyboard/controller input. The original
  actor still owns movement, jumping, rolling, shields and strike admission.
  Campaign-private default bindings also accept controllers assigned IDs above
  zero. Native aggregate input edges, custom mappings and the original InputMap
  remain authoritative; held input is suppressed on mounting and re-entry.
- Menu and scene boundaries release held gameplay actions. Skipping the opening,
  returning from the journal, choosing an upgrade or retrying cannot accidentally
  turn the menu button into a jump, strike or guard. If a held key or stick is
  still blocked, the NEXT line explains how to release it. Normal objective
  guidance returns immediately when the input is released.
- Losing window focus or disconnecting the active controller pauses active play.
  Returning does not silently resume. Pending transitions also stop at this
  boundary; choice and progression state must remain coherent.
- A presentation-only camera follows sustained travel with bounded look-ahead and
  a vertical comfort window. Ordinary jumps no longer pull the whole room up and
  down. The camera does not change motion, collisions or inputs.
- All 32 districts receive seeded, muted architectural identity: skyline crops
  preserve their aspect ratio, industrial bays and machinery vary by location,
  and small wall landmarks provide orientation. This decoration has no collision
  or gameplay authority and disappears when sight is traded.
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
- Fresh archive and defeat sounds finish at the moment of their feedback, rather
  than starting after the panel closes or a retry begins. Old-room spatial sounds
  are retired on replacement; existing world sounds still pause normally. Mute
  now works consistently in the journal, upgrade and final-choice panels too.
- Long-session cleanup retires old sonar shape subscriptions and decorative-object
  records after district changes and cargo replacements. Live contours, propagation
  timing and sound-triggered reveal remain exactly equal to the inherited model.
  This is a campaign-only adapter; the original demo and controller stay intact.
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

The preceding `b2e7f35` runtime earned the following acceptance with Godot 4.6.3.
These reports retain that exact identity and are not relabelled as later results:

- **44/44 focused stages** passed at 60/120 Hz, including actual keyboard/joypad
  event paths, modal/focus boundaries, upgrades, checkpoint feedback, HUD ownership,
  camera, audio routing, cache lifecycle, scenery and deliberately regressed controls.
- **125/125 inherited stages** passed: foundation 72, original suite 19, campaign
  audit 14 and quality 20. All 244 original preservation hashes remain intact.
  Twelve seeded replay traces match the preceding cache-fix runtime across
  12,960 ticks. All 137 inherited engine logs are free of errors and warnings.
- **24/24 optional-district routes** cover all 34 optional objectives and 31 reward
  IDs. Twelve further 120 Hz retained/traded-sight routes, 40 real reward collections
  through retry/Continue and six runner guards also passed. These are district-start
  physics routes and persistence fixtures, not one continuous optional campaign.
- **31 native interface/sight captures from the actual exported PCK** were reviewed
  at full size. Menus, controller prompts, both held-input hints, checkpoint warnings
  and blind concealment were readable. These use controlled scene setups, not route
  traversal. All 31 capture receipts succeeded without game/resource/leak diagnostics.
- A separate **ordinary packed-game keyboard smoke** exercised New, move, jump/air
  jump, ladder descent/ascent, journal, real Alt-Tab focus pause and title/Continue.
  It did not complete the opening district. Its ordinary-close diagnostic is retained
  and explained below rather than presented as a clean-shutdown pass.

The focused, inherited and optional runs each reverified all 2,724 archived Git
blobs without drift. Evidence is under `campaign/quality/nov6_acceptance/b2e7f35/`.
Reports distinguish raw observations, controlled fixtures, intentionally broken
negative controls and genuine route completions. Failed earlier observer runs are
preserved; they are not relabelled as passes.

- **Six continuous campaigns** passed on that exact runtime: Neutral at 60/120 Hz
  with retained/traded sight, Strength at 60 Hz and Agility at 60 Hz. Every run
  completed all 32 districts and required goals, five level receipts and four real
  upgrade choices, with no deaths, engine errors or source drift.
- **Eight transition-stress runs** passed, including seeded 60/120 Hz runs, replay,
  negative controls, isolation refusal and cumulative upgrades. Each main run
  checked 444 scenarios and 202,265 assertions. Cumulative cases checked 36
  scenarios and 5,292 assertions per rate.

The final controller follow-up was independently checked before integration:
9,226 positive assertions across 60/120 Hz, preserved negative controls, 1,176
focused source checks, and 426 checks against its exact exported PCK. The same
standalone device fixture demonstrates the preceding runtime's failure on device
IDs 1 and 3 while device 0 passes. This isolates the reason for the final change.
All original actor/demo/simulation sources remain unchanged.

### Final runtime checkpoints

On the exact `bf3ebd3` archive, **46/46 focused stages** passed with no source
drift; all 3,301 archived Git blobs were independently reverified afterwards.
The default-controller device fixture passes all 213 checks at each rate.

The immutable `c489885` tooling/documentation checkpoint contains the same
production runtime. Its actual PCK passes **30 rehearsal stages plus a fresh
Windows-ZIP extraction/resource audit**, with no fixture overlays. Both exported
controller matrices pass, as do 37 output-guard checks and 16 packaging unit tests.
All **31 final-runtime native captures** were individually reviewed at full size.
Evidence is in `campaign/quality/nov6_acceptance/bf3ebd3/`.

A separate ordinary final-PCK keyboard smoke reached the first ladder/roof and
verified journal, pause, real focus-loss pause, Title/checkpoint Continue and F12.
It saved 18.79 active seconds and did not complete a district. Ordinary Alt-F4
exited successfully without resource-leak diagnostics in that particular run;
the intermittent engine/audio close warning below remains documented.

The final runtime also passes **125/125 inherited stages**, with all 12 replay
traces equal to b2 across 12,960 ticks and all 137 raw logs clean. The pristine
archive matches all 3,301 Git blobs. Its executed copy changes seven generated
historical reports, with no runtime/test-source changes; every before/after pair
and exact test writer is preserved, including process-local IDs in the Warden
report. These report writes are not hidden as unchanged-source claims.

The complete optional matrix passes again: **24 district starts, 12 focused
120 Hz routes, 40 real reward collections and six runner guards**. Expanded
transition acceptance passes all **eight runs**, with 617,379 positive assertions
across 1,404 cases including replay. Command/state digests match b2, and intentional
negative controls and save-isolation refusal behave as expected. Both suites
reverify all 3,301 source blobs without changes.

The final six continuous source campaigns are still finishing. An additional
actual-PCK continuous route is running separately with external QA only. Final
delivery-source/archive receipts remain separate and must be added before this
becomes the final delivery record.

## Limits that remain

Physical gamepad hardware, native Windows execution, target-machine frame rate,
audible mix, a complete human-controlled campaign and first-play human duration
remain unverified unless a later report explicitly supplies that evidence.
The 15–20-minute per-level goal remains a design target, not a measurement.

On the tested Linux/X11 software-rendered runtime with Dummy audio, ordinary
window-close can report an exit-only retained `AudioStreamWAV`/playback resource.
The unchanged inherited audio director already clears its players and streams.
A separate pure-Godot project with no game code/assets reproduces the same
diagnostic; no campaign node is retained and the process exits successfully.
Waiting for audio retirement in a test fixture avoids the warning, but that is
not evidence of a clean ordinary close. This known engine/audio-environment
diagnostic is preserved under `b2e7f35/exit_diagnostic`; Windows and soundcard
behavior are not inferred from it. No global close-delay workaround was added.

No repository publication, commercial asset import, new sensory-trade mechanic,
roguelite adaptation or resolution of the unresolved time-loop/immortality story
is implied by this pass.
