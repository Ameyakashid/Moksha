# November 6 improvement pass

The runtime is frozen at `b2e7f352b96b11e9a5137145416ddeaf4a974e27`.
Delivery provenance separately identifies the final documentation/test commit.
Earlier reports remain historical and keep their original hashes.

## Player-facing changes

- Full campaign controller navigation, including title lens choice, interaction,
  sonar, journal paging, pause, retry, sight trade, upgrades and both endings.
  Prompts change only after intentional keyboard/controller input. The original
  actor still owns movement, jumping, rolling, shields and strike admission.
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

On the exact runtime archive, with Godot 4.6.3:

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

The final six continuous campaigns, expanded transition-stress archive and exact
delivery-source packaging acceptance are still being finalized. Their completed
receipts must be added before this becomes the final delivery record.

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
