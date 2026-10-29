# Simulation gym and production shared-melee verification

The latest accepted production-listener configuration is documented at the end of this file. Earlier sections retain their historical checkpoint scope.

## Preserved shared incoming-strike checkpoint

Godot 4.6.3, 2026-10-19. This checkpoint adds an actual-contact incoming-melee bridge and fifth strike
stage to the shared actor/intent, footing, hearing and physical-impact gym. It adds no campaign content or replacement engine. The detailed acceptance matrix and
remaining parity gaps are in `simulation/README.md`.

## Frozen-source automated checks

- Foundation runner: 26/26 stages pass; no code/scene/resource changed during the
  final run. The report records SHA-256 for tested source files.
- Shared footing: 25/25 assertions at each of 60 and 120 Hz. This covers actual
  NPC knockback off support, real PC strike/contact/damage/knockback/fall, support
  removal under both production PC and NPC, masks, configurable body geometry,
  invalid inputs and correct fractional-braking stopping distance.
- Shared hearing: 38/38 assertions at each rate. A real falling crate generates
  collision sound; PC and NPC sensors receive it and NPC AI investigates it.
  Other cases are explicitly labelled API/lifecycle fixtures: thresholds,
  deafness, real wall attenuation, floor-contact origin tolerance, invalid input,
  mutable-copy isolation, immutable notifications, cross-world/detached/pause
  behavior, rebind and per-instance profiles.
- Shared physical impact: 225/225 assertions at each of 60 and 120 Hz. Actual
  side/drop/rotating contacts and relative normal velocity use the same admission
  for production PC/NPC. Raw J launches cargo through the existing strike adapter;
  raw K exercises guard/parry. Tests also cover walls, slow/off-mask contacts,
  passive and launch epochs, disabled profiles/hosts/receivers, death, optional
  hitpause, immutable receipts, malformed/fabricated packets, callback reentrancy,
  reset/replacement/cross-world/pause between capture and delivery, and stale
  source/host/terminal-health callbacks. Boundary fixtures are explicitly labelled
  and do not fabricate successful gameplay collisions. See `IMPACT_CONTRACT.md`.
- Shared actor movement: 1330/1330 checks at 60 Hz and 2581/2581 at 120 Hz,
  including 417/834 tick-pair comparisons. Maximum translated-position drift is
  0.007489/0.033627 px with a 0.05 px tolerance; velocity difference is zero.
  Same action/support states, genuine cargo/contact/health/noise, actual InputMap,
  independent terrain/LOS policy, capability isolation and adverse lifecycle
  cases pass. Repeated tick assertions are not distinct gameplay scenarios.
  Shared melee composition is now positively smoke-tested; dedicated strike
  tests below establish the incoming contact/defense boundary.
- Shared incoming melee: 62 scenarios / 162 checks pass at each rate. Actual PC↔NPC
  and NPC↔NPC contacts, guard/parry/roll, absent shield, occlusion/range/self,
  canonical forgery, source binding, reset/replacement, adverse callbacks,
  ALWAYS-mode pause cycles, lethal Health/Defeat/Noise, cargo and autonomous
  attack choice are covered. Real side walls keep the idle stage onscreen.
- Stock adapter compatibility: combat 135 checks pass at each rate; combo
  passes 1384/1360 checks at 60/120 Hz respectively.
  Legitimate legacy fixtures/props and the existing enemy suites remain supported;
  historical reports are restored by run_strike_compatibility.py.
- Gym lifecycle: 50/50 checks. All five stage buttons, actual R/Esc key events,
  repeated entry/reload/exit and no orphan bus listeners.
- Existing enemy, ranged, Warden and expanded-host suites pass at both rates:
  44, 74, 76 and 68 checks respectively. Existing movement-NPC checks pass.
- Historical aggregate: 19/19 stages pass, including preservation checks.
- Full retained demo routes: all four retained/sacrificed-sight × 60/120 Hz paths
  freshly passed with zero deaths/retries and no source changes during execution.
  Runs are separately recorded by `run_demo_routes.py`; exact final results are in
  `evidence/route_summary.json`. These are informed automated routes, not human
  completion-time or difficulty evidence.

Run `python3 simulation/tests/run_foundation.py` from a copied project, with
`GODOT_BIN` set if needed. On the build workspace, `--require-preservation` also
requires and checks the saved v28 ZIP. On other machines the unavailable archive
is explicitly marked not checked. Run `python3 simulation/tests/run_demo_routes.py`
for the four actual-input mission paths; it restores historical demo reports
and writes current reports under simulation/evidence.

## Native review

The four-stage selector and movement stage were independently reviewed in the
supported cloud Godot UI. Actual A/D moved across flat terrain and up the slope;
Space showed airborne support=false/jump, Shift showed roll, and J a strike pose.
The NPC independently repeated flat/slope travel and stayed in its lane. R
restored initial positions and both sound counts to zero; Esc returned to the
selector. Text was readable and unclipped. K was sent but guard was not proven
by that viewing sample. The debugger showed VSync/audio fallback and lint warnings, with no gameplay
runtime fault. This is not performance, edge-braking
internal-state or melee-receiver certification.

The prior three-button selector and physical-impact stage were separately reviewed
in the supported cloud Godot UI. Ordinary gravity visibly left both PC and NPC
at 27 health / one hit / hurt, from initial 30. D and Space moved/jumped; J struck
and rotated/launched cargo. R restored 30 health, zero hits, waiting state and
crates. Escape returned to the selector. Text and layout were readable/unclipped.
K was sent, but guard absorption was not separately established by this native
sample; the automated actual-contact cases are its evidence. The debugger showed
VSync/audio fallback and five lint warnings, with no runtime gameplay fault.

The earlier footing/hearing native acceptance remains:

The supported cloud Godot UI launched the selector and both stages. The selector
was readable and unclipped. Actual movement crossed the footing ledge; hearing
stage D+J struck/rotated cargo and Space jumped. Sound counters changed (one pass reached PC6/NPC1), Q produced tap observations,
and R reset the stage/counters. Final Clear/Escape wording was rechecked. Escape returned to the selector. A blank clear-terrain
diagnostic was changed to “Clear”, and Escape was added to stage headers.

Native screenshots are actual F12 viewport captures, named `native_gym.png`,
`native_footing.png`, `native_hearing.png`, `native_impact.png`, and `native_movement.png` in evidence (all 1280×720). They are
view/interaction samples, not proof of all test scenarios. Cloud audio fell back
to a dummy device, so audible mix is not verified. The debugger also showed VSync
and script lint warnings; no runtime gameplay error was observed in this pass.

## Preservation and remaining scope

The immutable v28 archive remains byte-identical:
`153fd2824303354b1f70dea66c7ba91b27bc204da9c16a05f9b1a27a29955937`.
Against that archive, 398 existing code/scene/resource files are byte-identical;
only existing enemy, ranged-enemy and movement-NPC-intent scripts changed. The
new components, resources and stages are under simulation/. Default F5 still
opens the prior mission; F6 on simulation/gym.tscn opens the gym.

At the prior impact checkpoint, the delta against the immutable foundations ZIP
(`891c3f393f440fc626bb1f235890b0807252bcc71a4b5887a61c6a5ef4eeec9d`)
changed four existing simulation files and added thirteen simulation
source/scene/test files. No non-simulation code, scene, resource or
project configuration changed. Exact file lists and hashes are recorded in
`evidence/impact_source_delta.json`; both immutable ZIPs were rehashed unchanged.

Independent read-only code/test review approved the bounded impact contract after
corrections to captured-source authority, callback reentrancy, legacy API bypass,
and terminal/stale diagnostic handling. That reviewer ran no tests; the recorded
execution evidence comes from the implementation and aggregate runs.

The two production actor motion solvers and general incoming attack protocols
remain separate. The opt-in cargo path shares admission; default mission props
still retain their legacy NPC-focused damage route. Acoustic reflection,
diffraction/material behavior, physical corpse behavior and complete asset/view
separation are not implemented by this checkpoint. No claim of universal parity,
full physical realism or finished game feel is made.


### Shared actor checkpoint preservation and review

The prior shared-impact ZIP remains immutable at SHA-256
`5a18425ce2e83b22af82411f188e99f3733b1190c887e4c73dd6de4877ddc72b`.
The shared-actor slice changes three existing simulation code/scene/test files
and adds nine simulation source/scene/test files, plus simulation docs/runner
updates. It changes no non-simulation source or project configuration. The controller
remains byte-identical (`2f0d4d0b93aa1f0eb3f21e94fb96af09923892d0aef1c7f0cf1704a9b22e9997`).
The detailed delta is `evidence/movement_source_delta.json`. All three immutable
archives are rehashed during final preservation checks.

Independent read-only boundary review prompted ownership-safe reset hooks,
source/policy callback retirement, held/tap rearming, scheduler replacement and
cross-owner same-frame fencing, explicit ALWAYS-mode pause quarantine, and
inward patrol recovery after external displacement. The reviewer independently
ran focused tests and adversarial fixtures. The final independent assessment found no remaining blocking issue and reran
both final-rate suites plus the original adverse fixtures. Evidence is retained
in `evidence/movement_independent_review.json`.

Shared movement is now demonstrated in the reusable composition. The following
strike slice supersedes the old layer 2/combat_pc and absent-receiver boundary,
while production mission actors still use their separate solvers.


### Shared incoming-strike checkpoint

The prior Shared-Movement ZIP remains immutable at SHA-256
`745821c401bcc20619d7bed43dd2a5d13de1b40b82e72522476da55b3e515570`.
The sole changed non-simulation source is ContactAdapter: bound-source/lifecycle
validation, self-descendant exclusion, canonical snapshot validation and opt-in
capture/permit handling. The combat controller, shield resolver, Health and
Defeat components remain unchanged. Exact source/file deltas and all four archive
hashes are recorded in the strike acceptance evidence.

Independent review prompted fail-closed missing-shape handling, early canonical
validation, ending a retired sampled sweep, stable host visitation and an internal
PAUSABLE lifecycle fence for ALWAYS-mode actors. The callback contract explicitly
distinguishes rejecting a stale capture from allowing a later actual live sample
against an eligible actor. Final independent runs pass at both rates: focused
62 scenarios/162 checks, adverse 17 scenarios/40 checks and pause-fence 7 scenarios/13
checks. Core hashes and a 300-file production snapshot stayed unchanged. Evidence,
logs and preserved probe scripts are under evidence/strike_independent/. The first bridge deliberately has no shared counter
response. Sentinel migration is gated on that separately proven capability.

Native review of the corrected physical arena observed repeated actual NPC→PC
health loss, actual J reducing NPC 30→29 with one receipt, both actors remaining
visible at the solid left wall, R resetting health/receipts and Esc returning.
The UI and selector were readable. Guard effectiveness was not established in
that viewing sample; automated actual-contact tests are its evidence. The stage
caption was inset into HUD presentation and the final native check confirmed it
fully visible beyond the physical wall.
Native captures are `native_gym.png` and `native_strike.png`. Native audio/mix,
continuous combat feel and every automated scenario remain outside that sample.

### Shared shield-counter checkpoint (preserved earlier checkpoint)

The counter slice adds a detachable actor-registered receiver which reuses the
actual incoming hurtbox and calls the existing controller/Health response. The
Strike stage explicitly enables the configurable opt-in and shows counter counts
plus a read-only NPC weapon-phase cue. See `COUNTER_CONTRACT.md` and the amended
`STRIKE_CONTRACT.md` for the observation-only completed-parry exception.

Final frozen-source evidence:

- Foundation: 28/28 stages, no source changes during the run. This includes the
  existing footing, hearing, impact, movement, strike, mission-host and lifecycle
  checks and the new counter suite at both rates.
- Counter: 79 scenarios / 222 checks at each of 60/120 Hz. Real mirrored PC↔NPC
  and NPC↔NPC timed raw parries deliver three authored counter damage, stop the
  attacker through the existing recoil owner, preserve the completed defender
  zero-loss parry receipt, and emit actual parry/hurt noises. Lethal damage is
  capped at remaining health with one defeat. Range, terrain, absent/disabled
  receivers and absent capabilities preserve independent incoming outcomes.
  Explicit forgery, replay, reset, replacement, shape, pause, cross-world and
  nested callback probes are boundary fixtures, not fabricated gameplay hits.
- Stock compatibility: all ten both-rate suites pass. Combat 135 checks, shield
  215 scenarios / 930 checks, Health 182 checks and guard-component smoke 25 checks
  at each rate; combo 1384/1360 checks at 60/120 Hz. Legacy enemy counters and
  projectile reflection remain supported. Historical report files are restored.
- Historical aggregate: 19/19 stages. All four retained/sacrificed-sight × 60/120 Hz
  real-input mission routes complete with zero deaths/retries. Source hashes are
  stable throughout the final pipeline. Exact routes and timings remain in
  `evidence/route_summary.json`, not claims of human completion time.
- Independent read-only review approved the bounded slice after 20 final suites,
  4,306 checks total at both rates, no runtime/parser errors and stable hashes.
  It reproduced and prompted corrections to late validation callbacks, nested
  incoming-validation callbacks, post-receipt confirmation and stale parry
  observation. Its original report, final logs and reproducible probes are
  preserved under `evidence/counter_independent/`. It explicitly approved the
  completed-parry observation without reauthorizing the cancelled attacker sweep.

Native review separately confirmed readable counter/health HUD, the NPC weapon
phase cue, corrected selector footer, R reset and Esc return. Three attempted
manual K timings did not demonstrate an actual counter; native counter timing
remains unverified, while both-rate actual-input automated tests establish it.
The actual final viewport is `native_counter.png`, with refreshed `native_gym.png`;
the prior strike capture remains preserved. No audible-mix claim is made.

All six preexisting MOKSHA ZIPs remain byte-identical, including Shared-Strike:
`fff9e5423029e449bf41bc6119e28be9f54b3a70d0659e4800f187efedee0d0a`.
Against that checkpoint, 492 source files are unchanged; nine existing source
files change and five are added. The only non-simulation source changes are the
shield contact adapter, the contact adapter's read-only receipt predicate and an
eight-line read-only canonical shield snapshot accessor on the controller. The
controller's authoritative movement/defense/receive_attack logic, Health, Defeat,
mission actor scripts and project configuration stay unchanged. Exact hashes and
deltas are in `counter_source_delta.json`, `counter_file_delta.json` and
`counter_acceptance.json`. No sentinel or other production mission migration is
included; that is the next separately gated slice.


## Production ordinary-sentinel checkpoint (preserved)

Godot 4.6.3, 2026-10-19. The real default mission now instantiates ordinary
sentinels from the shared actor, using an intent-only policy and the unchanged
combat controller, Health, contact/counter receivers and committed-noise pipeline.
The mission PC adds only an incoming receiver to its existing scheduler/Health.
See `SENTINEL_CONTRACT.md` for configuration, host APIs and honest boundaries.

Final acceptance: `evidence/sentinel_acceptance.json` and
`evidence/sentinel_final_gates.json`. All 518 source files match the final tested
manifest; the full pipeline exits zero and records unchanged source hashes.

- Foundation 34/34 stages, including all gym lifecycle/boots and both-rate shared
  actor, strike, counter, impact, footing, hearing, legacy enemy/ranged/Warden,
  expanded mission integration and new production scene/factory checks.
- Production sentinel 26 scenarios/111 checks at each 60/120 Hz. Actual PC↔sentinel
  contacts, mission damage 12, directional guard 75%, rear bypass, timed/lethal
  parry/counter, cancelled ghost sweep, Health-confirmed exact sound provenance,
  stock-crate physical contact, support removal, sight/hearing, and generation/
  defeat/reset/room-clear boundaries. Explicit lifecycle fixtures are labelled.
- Stock 10/10 both-rate suites, retaining combat, combo, shield/projectile, Health
  and guard component contracts. Historical aggregate 19/19; old report files are
  restored by the acceptance runner.
- All four actual-input production routes reach all 8 sector completions with zero
  deaths/retries:60 Hz retained 174.23s/sacrificed 163.28s; 120 Hz retained 161.40s/
  sacrificed 150.76s. These are layout-aware automated simulated times, not human
  completion-duration evidence. Current reports are directly under `evidence/`.
- Independent isolated boundary review: 22 scenarios/81 checks at each rate, clean
  logs and matching production hashes. It prompted stale-hearing callback and
  inherited removal-cleanup corrections. Original reports/harnesses/logs are in
  `evidence/sentinel_independent/`.

The initial routes exposed an old planner link through the blocked bottom of the
Quarantine Intake ladder. Identical baseline/migrated physical fixtures identify
the unchanged terrain block. A generic test-planner correction rejects obstructed
ascent corridors and admits supported intermediate boarding. No game geometry,
collision, AI, health, timeout or success criterion changed. Independently reviewed
baseline/migrated×60/120×both-sight comparison 8/8 passes, source-stable with zero
deaths/retries/errors. Initial failures remain in `sentinel_route_initial_failure/`;
comparison reports and exact patch remain in `sentinel_ladder_diagnosis/`.
The lower 70px of the drawn ladder still cannot be boarded from the floor. Humans
must board from the reachable block top or use the upper-platform route; this
pre-existing visual-access caveat is deliberately not hidden as a repaired layout.

Native F5 review observed start/movement/jump, tan sentinel approach/STEP marks,
a warning circle, NPC-caused player defeat, R reset, actual J/K reducing enemy
bars to DOWN bodies, and readable HUD/pause/death views. Saved evidence is the
whole supported Sky desktop JPEG `native_sentinel_defeat_desktop.jpg`; it shows
the post-fight scene, not the already-faded bodies. Native sight-trade/room
transitions, noise causality, parry timing fairness and audible mix remain unproven.
See `evidence/native_sentinel_review.md` for exact observations and limits.

Against the immutable Shared-Counter ZIP: 498 source files are unchanged, 8 existing
sources change and 12 are added; none are removed. Only four pre-existing
production assets change: mission composition, legacy hearing-peer filter and
ranged/Warden peer-group scene data. Other changes are test/planning/runner sources.
All 11 independently recorded counter authority hashes and all 7 prior ZIPs remain
unchanged. Exact maps are in `sentinel_source_delta.json` and
`sentinel_archive_preservation.json`. No other archetype or stock-cargo-source
migration is included. Authenticated cargo, physical corpses and a complete
hearing/navigation/gameplay rewrite are not claimed.

## Production listener configuration checkpoint

Godot4.6.3,2026-10-19. All13 authored mission listener placements now use the same
shared scene/controller/facade as ordinary sentinels. One data-only archetype
resource supplies health2, speed112, windup0.46/recovery0.68, strict sight<86,
noise memory3.2 and lavender/ear styling. Profile isolation and existing positive
mission override precedence are proven. No second controller, facade, receiver,
Health store or AI action timer is introduced. See `LISTENER_CONTRACT.md`.

Final acceptance is `evidence/listener_acceptance.json`; the complete pipeline
and522-file frozen source manifest are in `evidence/listener_final_gates.json`.
Sources remained unchanged throughout all four pipeline stages.

- Foundation36/36, including all independent gym boots/lifecycle and both-rate
  physical simulation, mission contract/integration, legacy enemy/ranged/Warden
  and production sentinel/listener suites.
- Listener38 scenarios/173 checks at each60/120Hz. The inherited genuine contact,
  guard/parry/counter/lifecycle suite runs with listener data. Extra cases prove
  strict sight boundaries, lower detection overrides, real wall sight, priority
  over opposing remembered sound,3.2-second memory/expiry, sensor range and
  optional one-ray attenuation, actual gravity-driven crate sound→investigation,
  same-sweep peer non-damage, raw strike-induced edge fall, private profiles,
  all13 factory placements and actual mission listener HIT/DOWN integration.
- Original sentinel26 scenarios/111 checks still pass at both rates.
- Stock10/10 both-rate combat/combo/shield/Health/guard suites; historical19/19.
  Historical non-simulation reports are restored after the aggregate.
- Four real-input mission routes each complete all8 sectors with zero deaths,
  retries or failures:60Hz retained172.67s/sacrificed163.27s;120Hz retained161.08s/
  sacrificed150.82s. Times are automated simulated durations, not human duration.
  No route planner, mission geometry/objective, timeout or success gate changed.
- Isolated independent review reruns the full listener suite and adds8 scenarios/
  35 checks per rate: two actual PC sword hits kill default-health2 listener;
  genuine default lethal counter; an intervening listener blocks the counter ray
  without redirecting damage; actual peer windups remain filtered; default
  foot-origin unoccluded hearing, explicit hearing-profile precedence, reset
  isolation and queued-source rejection. Zero failures, matching frozen sources.
  Reproducible non-executable harness/logs/JSON/hashes are in
  `evidence/listener_independent/`.

Native ordinary run/roll/jump reached the first-room listener. Lavender body,
readable double ear arc and warning circle were observed; actual enemy contact
reduced PC60→48, then ordinary J/K left a lavender DOWN silhouette. The two
verified whole-desktop JPEG captures show the encounter and fallen silhouette.
Native blind reveal, exact perception thresholds/retention, exact defense timing,
transition and sound mix were not established. Debugger count stayed at prior21
but its entries were not freshly inspected, so exhaustive native error clearance
is not claimed. See `evidence/native_listener_review.md` for exact scope/hashes.

Against the preserved sentinel archive,511 source files are unchanged,7 existing
sources change and4 are added; none are removed. Only4 existing production
scripts change (factory, shared facade, policy and view);2 new production
resources carry listener data. Other changes are test-harness/runner sources.
Controller, all shared scene/contact/counter/hearing/physics code, capability and
contact resources, legacy enemy/ranged/Warden, prop sources, route bot and world
geometry remain byte-identical. All8 prior immutable ZIPs remain unchanged.
Exact maps: `listener_source_delta.json`, `listener_archive_preservation.json`.

The stock-cargo compatibility shim, missing physical corpse capability, default
unoccluded hearing and optional single-ray limitations remain explicit. The
pre-existing misleading lowest70px of Quarantine Intake ladder remains unchanged.
No ranged, Warden or mission cargo-source migration is included in this slice.


## Production charged-cargo admission checkpoint (latest)

Godot4.6.3,2026-10-19. Ordinary mission crates and designated freight now inherit
the shared physical source. Both factories use mask43, deliberately enabling
PC vulnerability and real cargo-to-cargo collisions. Mission impact eligibility
remains charged-only; the gym's passive source remains independently configurable.
No actor role chooses contact admission or damage math. Existing guard/roll and
Warden bracing are explicit host capabilities. See `MISSION_CARGO_CONTRACT.md`.

Final acceptance is `evidence/cargo_acceptance.json`. The four-stage aggregate
and frozen525-file source manifest are `evidence/cargo_final_gates.json`; every
source stayed byte-identical during that full run and still matched afterward.

- Foundation42/42: all gym boots/lifecycle, both-rate physical simulation,
  sentinel/listener, mission contracts/integration, legacy enemy/ranged/Warden,
  new production cargo and freight suites.
- New mission cargo30 scenarios/157 checks at each60/120Hz. Actual raw J launches
  production cargo into PC, sentinel, listener, legacy enemy, Sentry and Warden:
  equal unguarded damage3 and exact requested impulse(180,-80), with each existing
  motion owner responding. Actual front guard/parry/rear/roll produce29.25/30/
  27/30 Health from30; cargo advertises no reflection/counter. Warden's genuine
  autonomous windup preserves full damage and authored short-impact bracing.
- Real captured contacts exercise charged-only passive rejection, relative
  normal closing and rotation, expiry/relaunch/reset/replacement, immutable
  receipts, break/noise and source/host retirement. A raw sword-to-two-crate chain
  transfers real momentum/charge into the PC without synthesizing a launch or
  new recipient epoch. Resting contacts cannot perpetually refresh charge.
  Actual mission PC falling-cargo damage, retry replacement and freight factory
  composition pass. Existing physical-impact225 checks pass at both rates;
  freight component186 and freight host12 checks pass at each rate.
- Stock10/10 both-rate combat/combo/shield/Health/guard stages and historical19/19
  pass.206 non-simulation historical Markdown/JSON/log artifacts match the prior
  Listener ZIP exactly; only current root delivery docs are intentionally updated.
- All four real-input eight-sector routes complete with zero deaths, retries or
  failures:60Hz retained176.78s/sacrificed167.17s;120Hz retained165.82s/
  sacrificed159.38s. These are automated simulated times, not human duration.
  No route bot, production trajectory tuning, world geometry, objective, timeout
  or success criterion was changed to accommodate the new physical interactions.
- Independent isolated review executes83 additional boundary assertions plus the
  full157/225 suites at both rates:930 assertions, zero failures or engine/script
  errors, exact13-file before/after hash match. Its probes cover forged/nested
  captured attacks, source retirement, target receipt resets/disable/unbind,
  optional receiver absence, separate cargo/wall obstruction, unauthorized carrier
  exclusion, spent recipient epochs, donor/recipient relaunch distinctions,
  charge reentry, terminal break callbacks and zero mission legacy take_hit calls.
  Reproducible non-executable harnesses, logs, red/green evidence and final review
  are in `evidence/cargo_independent/`.

The first source-stable aggregate had one failing historical impact60 fixture
(two target-contact assertions); stock, historical and all four routes already
passed. Its raw launch trajectory was made deterministic with test-only target/
crate placement and horizontal/no-spin tuning, preserving raw input, real solver
contact and the unchanged80 closing threshold. Production465/-185/random9..17
launch tuning was never changed. Initial failure, source manifests and independent
approval reasoning remain in `evidence/cargo_initial_gate/`. This fixture proves
admission/response, not that every randomized ballistic launch must hit.

Native ordinary movement/jump/strike displaced and rotated crates, with a fall
into an encounter and visible break effect. A retry strike/HIT near a falling
crate could not be attributed reliably to a charged launch or actor damage.
Four verified whole-desktop JPEG captures are retained. The file named `launch`
shows only strike/break aftermath; it is explicitly not launch proof. Incoming PC
cargo damage, chains, exact guard/roll outcomes and Freight machinery remain
native-unproven. Current refreshed mission Output showed0 errors/0 warnings;
Debugger21 was retained baseline history, not an empty-debugger claim. See
`evidence/native_mission_cargo_review.md` for exact scope and final-boundary-fix
chronology. No full native feel/audio/human playthrough claim is made.

Against the immutable Listener archive:510 source files are unchanged,12 existing
sources change and3 test/runner sources are added; none are removed. Ten changed
production assets include source/configuration, receiver composition, minimal
stock-prop extension hooks and narrow shared-controller admission corrections.
The latter authenticate captured solver geometry and exclude only its exact
permitted physical carrier from its own obstruction ray; other obstacles and
all defense/lifecycle checks remain. No motor, NPC AI, ranged or Warden controller
is migrated. All9 prior immutable ZIPs remain unchanged. Exact patches/maps are
`cargo_changed_sources.diff`, `cargo_source_delta.json`, and
`cargo_archive_verification.json`.

The old stock-cargo take_hit shim remains solely for historical compatibility
fixtures; production cargo cannot dispatch it or fall back after shared rejection.
Ranged protocol/controller migration, physical corpses, acoustic propagation and
complete simulation/feel remain outside this slice. The earlier misleading bottom
70px of the Quarantine Intake ladder remains an explicit unchanged layout caveat.

## Shared projectile adapter checkpoint, 2026-10-19

The opt-in `shared_ranged_actor` and sixth standalone gym stage now use the
existing shared controller for both PC raw input and NPC intention. The precise
scope/lifetimes/remaining limits are in `PROJECTILE_CONTRACT.md`. Production
sentry/factory and Warden scenes remain unchanged.

Final frozen-source acceptance:

- Focused projectile: 39 scenarios / 115 checks at each of 60 and 120 Hz, zero
  failures. Successful cases use ordinary input and real swept collision.
- Foundation: 45/45 stages, including sixth-stage boot and 60-check gym lifecycle.
- Preserved stock compatibility: all 10 suite/rate combinations pass.
- Historical aggregate: 19/19 stages with preservation checks.
- All four retained/sacrificed-sight × 60/120 full mission routes finish with
  zero deaths, zero retries and no failures. Active simulated times are
  178.100 / 167.117 / 167.108 / 156.592 seconds respectively; these are automated
  informed routes, not human difficulty or performance evidence.
- `projectile_final_gates.json` confirms no code/scene/resource/script changes
  during the complete serial acceptance. Final live hashes were rechecked.
- Independent review: 20 exact-source suite runs, 42 boundary scenario runs per
  rate, 66 additional recorded outcome checks, obstruction/terminal assertions
  (32 per rate), and stock Health/shield 214 checks per rate. The separate
  post-claim subclass probe also rejects stale target authority. All eight
  reviewed production hashes match the final live files.
- Independent no-cache import and 300-frame scene boot pass without diagnostics.
  Original failure reproductions and final corrections are retained separately
  under `evidence/projectile_independent`; probe sources are nonexecutable text.
- Ten prior project/checkpoint ZIPs are verified unchanged, including the shared
  production-cargo archive SHA-256
  `6d8e82d72251017b585e9e470448d6948f47f5b02544b6bb9416fab1754f925b`.

Native supported-Godot review saw ordinary J create a traveling orange bolt,
autonomous NPC firing after movement/jump cleared the cargo, live PC Health loss
and an observed player shot reducing NPC Health. R restored both to 30 Health
and zero shot/contact counters, and Esc returned to the readable six-button
selector. The saved `native_projectile.png` specifically shows a traveling bolt,
PC 23/contact 7, NPC 30/contact 0, and one live carrier. It is an earlier frame
than the separately witnessed NPC 29/contact 1 state; it does not itself prove
that NPC debit. `native_gym.png` records the corrected selector/footer layout.

Cargo interception was inferred from bolt ending/no target contact rather than
an exact native collision frame. Native timed guard reflection and audible mix
remain unproven; the automated physical tests establish reflection. A transient
editor inheritance/parse state was seen during implementation writes. A final
full Project Reload restart on frozen sources followed by F6 gym→Projectile
closed it: no current parse/gameplay runtime error, only audio-device/dummy/VSync
and existing lint warnings. The native reviewer left sources untouched.

## Production shared sentry checkpoint, 2026-10-19

All thirteen authored mission sentries now come from `shared_sentry.tscn` through
`demo/mission.gd`. They reuse the existing shared actor/controller, root Health,
intention scheduler, incoming contacts, hearing/noise and the canonical projectile
emitter. `SENTRY_CONTRACT.md` records the complete behavior and deliberate changes.
The stock controller/carrier, legacy ranged implementation and legacy ranged
regression remain byte-identical to the preceding projectile checkpoint.

Final frozen-source acceptance:

- Production sentry: 35 scenarios / 202 checks at each of 60 and 120 Hz, no
  failures. Actual factory placements, genuine ordinary attacks/defenses and
  swept contacts cover aim, timing, damage, filtering, cargo and lifecycle.
- Foundation: 48/48 stages, comprising the preceding 45 plus production sentry
  at both rates and the isolated native-review scene boot.
- Stock compatibility: all 10 suite/rate combinations pass.
- Historical aggregate: 19/19 stages with preservation checks. Its report is
  retained as `sentry_historical_report.json`; older non-simulation reports were
  restored by the wrapper.
- All four retained/sacrificed-sight × 60/120 full mission routes finish with
  zero deaths, zero retries and no failures. Active simulated times are
  177.483 / 166.350 / 171.283 / 161.117 seconds respectively. These are automated
  informed routes, not human difficulty or play-duration evidence.
- `sentry_final_gates.json` confirms all four serial gate groups passed with no
  code, scene, resource or runner changes. All 548 final live source hashes
  matched the frozen map after acceptance.
- Independent review: 18 final runs; production 35/202, generic projectile
  39/115 and legacy ranged 16/74 at both rates, plus six adversarial families
  totaling 32 scenarios / 153 checks per rate. The 19 reviewed source hashes
  match the final live files. Fresh no-cache import and a 300-frame scene boot
  pass. Explicit extension-hook variants and original failures are preserved
  under `evidence/sentry_independent`.
- The independent owner-layer/filter capture finding and retreat-facing
  oscillation are fixed and covered. The initially unreliable cargo fixture was
  corrected to wait for real warning before inserting the actual production
  crate; zero lift/spin are explicit deterministic fixture settings. It still
  requires ordinary sword launch, a real single Health3 debit and cancellation.
  Original failed evidence is retained under `evidence/sentry_initial_gate`.
- Relative to the preceding projectile checkpoint, 529 existing sources are
  unchanged, 9 are modified and 10 are added; none are removed. All 11 prior
  project/checkpoint ZIPs are verified unchanged. Exact maps, patch and receipts
  are `sentry_source_delta.json`, `sentry_changed_sources.diff`,
  `sentry_archive_preservation.json` and `sentry_acceptance.json`.

The production collision masks deliberately select both PC and NPC peers as
physical blockers in both directions (43). Configurable actual-owner layer
admission filters friendly damage; it does not remove physical interception.
Cargo now consistently blocks sight, release clearance and flight. Reflections
change actual ownership/collision exclusion, permitting the original shooter or
another shared NPC to receive real returned damage. Standalone damage is 1 with
minimum return 2; mission canonical damage/return is 12. Warden remains the
explicit temporary blocker-only exception with no projectile Health receipt,
awaiting its own shared migration. There is no hidden fallback damage path.

Native review used the actual mission factory and authored Intake sector through
`simulation/sentry_review.tscn`, with an explicit initial spawn at (790,135) and
saving disabled. Ordinary inputs showed the cyan bow/antenna, orange warning
ring/! and aim line, a raised shield, sword damage then cyan prone defeat, and
normal R retry. The earlier ordinary full-route attempt remained in Rainline;
those screenshots are accurately separate. No live teleport, AI disabling or
forced outcome was used for native observation.

The final native warning-to-recovery observation did not establish a distinct
free-flight bolt, projectile-caused PC damage, guard interception, reflection
or cargo/filter collision. The `release` screenshot is shield/recovery timing,
not bolt proof. These physical outcomes are established by automated contacts.
Audio mix is unverified. Current Output showed 0 errors/0 warnings, while the
accumulated Debugger count 24 was not exhaustively inspected. Full details and
capture hashes are `native_sentry_review.md` and `native_sentry_capture_hashes.json`.
No full native route, universal actor parity or finished balance claim is made.

## Generic committed hurt/bracing checkpoint, 2026-10-19

This is a role-neutral capability checkpoint, before Warden migration. An empty
default response profile preserves ordinary recoil; explicitly protected copied
melee steps admit full Health damage and existing hitpause while resisting short
recoil/interruption during windup/active. The strict 0.70-second threshold, genuine
counter override and complete lifecycle contract are in `HURT_RESPONSE_CONTRACT.md`.
No production factory, enemy sequence, mission geometry or difficulty is changed.

Final frozen-source acceptance:

- Hurt response: 104 scenarios / 398 checks at each of 60 and 120 Hz, zero failures.
  Actual melee, cargo and canonical counter contacts cover equal-config PC/NPC
  paths, phase boundaries, full damage, threshold/impulse independence, noise,
  hitpause, lethal Defeat, failed counters, snapshots and callback retirement.
- Projectile hurt response: 12 scenarios / 73 checks at each rate, zero failures.
  Successful cases use real emission, timed reflection and returned sweeps.
- Foundation: 53/53 stages; stock compatibility: 10/10 suite/rate combinations.
  Held-input preservation additionally passes 114 scenarios / 333 checks per rate.
- Historical aggregate: 19/19 stages with preservation checks. All four retained/
  sacrificed-sight x 60/120 full routes complete with zero deaths, zero retries
  and no failures. Active simulated times are 177.550 / 166.867 / 169.750 / 163.483
  seconds respectively. These informed automated routes are not human play-time
  or difficulty measurements.
- `hurt_final_gates.json` records all six serial gate groups passing with no
  source changes. All 554 code/scene/resource/runner/project hashes still match
  that freeze. The independent review's four production hashes match it too.
- Independent exact-source review: 22 isolated runs / 2,390 checks across both
  rates, zero failures or runtime errors. This includes independently authored
  116-check bracing and 63-check lifecycle suites, 38-check post-claim target/source
  retirement probes, Health binding/nested admission probes and liveness checks.
  Harnesses, original red reproductions and logs are under `evidence/hurt_independent`.
- Relative to Sentry, 540 existing sources are unchanged, 8 modified and 6 added;
  none are removed. The original `_receive_hurt` body is byte-identical. All 12
  preceding project/checkpoint ZIPs and 645 preceding report/document files are
  verified unchanged, excluding four intentionally updated contract/index docs.
  See `hurt_source_delta.json`, `hurt_changed_sources.diff`,
  `hurt_archive_preservation.json`, `hurt_report_preservation.json` and
  `hurt_acceptance.json` in `evidence`.

Three narrow lifecycle/compatibility corrections accompany the opt-in capability:
entry-reserved admission serials and a fixed Health binding floor prevent an old
in-flight contact from debiting a replacement/rebound Health; scalar receipt flags
use the existing integer format; and final captured target/source reads reject
counter claims retired by late validation callbacks. Both claim-boundary and
Health replacement bugs were independently reproduced on the immutable Sentry
baseline before correction. The first aggregate was interrupted for the source
boundary finding, then rerun in full after final review; no pass is claimed for
the interrupted run. Existing defaults are not claimed byte-identical as a whole.

Native Godot review observed the readable seven-button selector, gold shoulders
during an NPC committed action, ordinary J/K exchanges with Health loss in both
directions, one Health-backed braced-hit count, R reset and Esc return. The saved
frame shows PC Health 19 / braced hits 1 and NPC Health 29, with both counter counts
zero. Continuous uninterrupted action retention and a successful timed counter
were not established natively; exact semantics come from automated contacts.
Cargo/projectile response, audible mix and precise threshold timing were also
outside this native observation. Debugger count 9 was stable but not exhaustively
inspected; no visible runtime interruption occurred. Details and image hashes are
in `native_bracing_review.md` and `native_bracing_capture_hashes.json`.

Production Warden remains unchanged. Its old separate recoil scaling/cap,
source-pause copying and retaliation on a failed counter are intentionally not
part of the new shared response. This checkpoint does not establish full mission
actor parity, final balance, physical corpses or acoustic propagation.


## Production shared Warden — final frozen checkpoint

The actual factory now uses the shared controller for all four enemy archetypes.
`WARDEN_CONTRACT.md` defines the generic independent fresh-start sequence, copied
attack-plan diagnostics, exact pending-recovery adjustment and synchronous genuine
Health receipt scope. The authored Warden facade/view owns no motion, damage or
weapon clock. Its inherited registered projectile receiver closes the previous
blocker-only gap. Legacy Warden source/scene and its 15-scenario / 76-check suite
remain unchanged and separate from production evidence.

Frozen source acceptance:

- Foundation: 62/62 stages, including all current actor, cargo, projectile, hurt,
  legacy and mission suites at both physics rates; no source changes/errors.
- Stock compatibility: 10/10 suite/rate combinations; held input separately
  retains 114 scenarios / 333 checks per rate. Historical aggregate: 19/19 stages.
- Generic attack-plan suite: 15 scenarios / 103 checks per rate. Production
  Warden: 37 scenarios / 170 checks per rate. Genuine reflected-return suite:
  4 scenarios / 44 checks per rate. Production sentry: 35/202; cargo: 31/165.
- Actual all-four factory/final-room test uses only the generic route planner:
  857 checks at 60 Hz, 1820 at 120 Hz. The three real foes must die before the
  seal opens once; three kills and sixteen Warden Health are accounted for.
  Explicit retry creates fresh Health16, opening cut and phase1.
- All four complete current mission routes retain objectives and timeouts:
  - 60 Hz retained: 178.700 active simulated seconds; 0 deaths, 0 retries.
  - 60 Hz sacrificed: 167.600 active simulated seconds; 0 deaths, 0 retries.
  - 120 Hz retained: 174.675 active simulated seconds; 0 deaths, 0 retries.
  - 120 Hz sacrificed: 163.658 active simulated seconds; 0 deaths, 0 retries.
- `warden_final_gates.json` records all six serial gate groups passing on the
  same 566-source freeze. `warden_acceptance.json` indexes the proof.

Independent exact-source review is green with no remaining source-correctness
finding. Besides the focused suites, it covers 33 direct API/lifecycle checks,
182 Health checks per rate, exact-once six-counter duel observations (six genuine
Health receipts totaling16, six damage noises, one death/defeat/phase2 and no
post-victory work), and 430 outgoing-source/factory checks per rate across
19 sentinels, 13 listeners, 13 sentries and one Warden. See
`evidence/warden_independent/INDEPENDENT_REVIEW.md` and its artifact manifest.

The unchanged planner's original four routes are retained under
`evidence/warden_initial_gate`: retained60 aborted after twelve deaths; retained120
completed with six deaths; both sacrificed paths completed without death.
Independent contact telemetry proved that sword advance closed to about9px and
placed contacts 0.55–0.82px behind the shield rectangle despite active parry.
Facade elapsed matched canonical elapsed exactly; source origin remained forward.
The approved generic protected-capability-aware strategy reserves defense and
uses ordinary early retreat/facing/shield input. No role branch, gameplay source,
contact geometry, objective or timeout was changed to make it win. The same bot
also completed all four sealed-Hurt production routes with zero deaths and
unchanged production sources. Timings differ; this is compatibility evidence.

A preserved cargo diagnostic demonstrates real rate-sensitive solver admission:
kinematic target contact velocity can reduce normal closing below80 despite a
fast-looking moving crate. Final phase-response fixtures explicitly assert an
actual qualifying normal-speed receipt before checking damage/bracing. No fake
contact, lower threshold or alternate damage fallback was added.

Native isolated actual-factory review observed distinct crown/gold shoulders,
readable warning/active rectangles, J Health loss, roll movement and R restoring
PC60/all three foes. Five verified1364x1024 JPEGs and hashes accompany
`native_warden_review.md`. Exact alternation, uninterrupted brace continuation,
successful timed counter, defeat and room clear were not established natively.
This starts in a save-disabled configured final room, not a full campaign.
A fresh-directory import and actual review-scene boot matched every frozen source
and reported no SCRIPT ERROR/ERROR; archived `.gd.txt` probes do not execute.
The native debugger's27 unexpanded entries are not claimed investigated.

Relative to Hurt, 544 existing sources are unchanged,
10 modified and 12 added; none removed. All13 prior ZIP hashes and
757 preceding report/document files are verified unchanged, excluding
the four intentionally updated index/contract documents. See
`warden_source_delta.json`, `warden_changed_sources.diff`,
`warden_archive_preservation.json` and `warden_report_preservation.json`.
The first full gameplay gate passed, but final preservation verification caught
a runner-only prefix selector deleting three legacy Warden report/document files.
They were restored byte-for-byte from the sealed Hurt ZIP. The selector now
exempts current Warden evidence only in its direct output directory; 17 independent
helper checks pass. The entire six-group frozen gate was then rerun successfully
with that final helper hash. Original failure and first-run evidence remain under
`warden_initial_gate`; no gameplay change was needed for this correction.

Decorative extraction, physical corpses, acoustics, final balance and human
full-campaign timing remain outside this checkpoint.


## Production actor / cargo physical interaction — frozen source acceptance

`ACTOR_CARGO_CONTRACT.md` describes the bounded shared material/support and canonical melee rules. PC now observes cargo for terrain/body support and obstruction; equipped NPC melee can launch cargo through the same canonical contact adapter. Sentry remains melee-disabled. Faction, authored weapon/damage differences, perception and mission geometry remain explicit. Boundary hazards are outside this slice.

- Final acceptance: all six gate groups passed on the same 580-source freeze. Foundation69/69 retains all62 prior stages; stock compatibility10/10; held input114 scenarios/333 checks per rate; historical aggregate19/19. No source drift or logged SCRIPT ERROR/ERROR.
- Actor/cargo real-physics suite:466 checks at60 Hz and676 at120; production defense79 per rate; unchanged independent request-lifetime fixture178 per rate. All pass. Genuine autonomous sentinel/listener/Warden intent reaches canonical sword contact and cargo launch; downstream charged contacts debit actual PC/NPC Health. Geometry/lifecycle API probes remain separately labelled.
- Grounded pressure is bounded1400×dt, applied at real contacts through Godot impulse response. Real support includes moving/rotating/removed/broken cargo, occupied launch, wall/ceiling blockage and falling; grounded/hurt support diagnostics record actually solved movement. The swept controller remains actor authority.
- Equal-configuration nonrotating PC/NPC controls agree exactly within each rate:116.414px at60 and120.079px at120 with production friction. Freely rotating fixtures differ, and their full observations remain: PC118.553/102.517px and NPC119.593/118.168px at60/120. Tiny opposite signed settled angles and actual contact-point selection produce different torque; this is shared-law evidence, not deterministic cross-instance trajectory proof. See the contract’s explicit limitations and first-contact traces.
- All four actual-input production mission routes preserve the objectives and timeouts, with zero deaths, retries or failures:60 retained178.600s,60 sacrificed159.267s,120 retained176.383s,120 sacrificed168.217s active simulated time. The120-retained trace records genuine grounded cargo support at feet y242.1789 and the observer-only stance projection from y270 to242.1784.

The original four candidate route traces are retained under `actor_cargo_preflight_*`: three stalled after the freight objective when the input observer waited for a staging point inside newly solid cargo;60-sacrificed passed. The generic observer correction requires a real inside-support point query and a walkable first ray hit on that same current support, retaining X, staging tolerance and success conditions. Only the observer was changed in a separate untouched-Warden control; all four control routes pass with no deaths/retries and unchanged production sources.

Corrected baseline traces are reproduced against the untouched Warden archive, with original source/hash provenance. Invalid initial double-driver instrumentation, intermediate pressure experiments, rejected free-chain impacts and independently reproduced stale-request failures remain labelled and preserved. Exact unchanged independent fixture runs passed after binding private one-frame demand to actor generations and body configuration/lifecycle. Its historical frozen-player metadata names the first experiment; the corrected/final manifests identify the source actually tested.

Native isolated-start Rainline review observed grounded walking pressure and a genuine J launch with upward/rightward motion and visible rotation. Top-standing was not established natively; missed/crossed/falling attempts remain as images. NPC launch, incoming damage and precise support/force/defense semantics are automated evidence, not native claims. Eight verified1364×1024 JPEGs and hashes accompany `actor_cargo_native_review.md`. R resets but restores the ordinary tutorial caption. Debugger24 entries remained stable and unexpanded; the native run is not claimed error-free.

`actor_cargo_final_gates.json`, `actor_cargo_acceptance.json`, `actor_cargo_source_delta.json` and `actor_cargo_changed_sources.diff` index the frozen evidence. Relative to Warden,552 source files are unchanged,14 modified,14 added and none removed. All14 prior ZIPs are hash-identical. Historical report/document preservation is verified separately, excluding the four intentionally updated contract/index documents. Final clean-directory import/package verification belongs to the delivery checkpoint.


## Shared non-solid world boundary — frozen source acceptance

`BOUNDARY_CONTRACT.md` defines the common origin witness, source-local half-plane,
initial occupancy policy and one-attempt outside episode. Production PC, all four
NPC factories and configured physical cargo use it. Actor responses go through
the existing controller/Health/Defeat chain; cargo explicitly retires current
impact and charge authority before its one destroyed fact. Mission loss observes
a current DefeatResponse lease rather than a PC-only position/failure shortcut.

- Final acceptance: all 14 serial groups pass on one 592-source freeze.
  Foundation72/72 retains all69 prior stages; stock10/10; held333 checks per rate;
  historical19/19; all eight explicit Health/Defeat/shield compatibility runs pass.
  No source drift or logged SCRIPT ERROR/ERROR occurs in these final gates.
- Main boundary suite:51 scenarios/174 checks per rate. These include actual
  gravity across PC/sentinel/listener/sentry/Warden, real configured defenses,
  safe landing/edge/jump return, fixed/zero damage and true reentry, passive/charged
  cargo and actual freight factory, genuine pending solver callbacks, current
  Health/life fences, stale mission observations, actual Cistern fall/retry, and
  explicitly labelled locked-gap room clear. API/lifecycle probes are separate
  from physical crossing evidence; no test teleport is a gravity outcome.
- Independent review:26 scenarios/95 checks and original Health25/182 per rate,
  plus22 overlapping standalone reproducer checks;576 executed checks total.
  Exact frozen528 Godot sources match, with zero final errors/warnings.
  Capacity16 reservations/128 disjoint history ranges, copied/stripped/original
  receipt replay, nested ordinary ordering, source/receiver races and genuine
  inbound/outbound pending cargo authority are covered.
- All four full input-driven production mission routes preserve objectives and
  timeouts and complete without failure:
  - 60 Hz retained: 178.200s active simulated time; 0 deaths, 0 retries.
  - 60 Hz sacrificed: 159.267s active simulated time; 0 deaths, 0 retries.
  - 120 Hz retained: 175.550s active simulated time; 0 deaths, 0 retries.
  - 120 Hz sacrificed: 167.625s active simulated time; 0 deaths, 0 retries.

The independent reviewer caught freed-reference type-entry runtime errors and a
real World2D swap-and-restore stale lethal debit. Validity-before-type entry
guards and synchronous canvas/world invalidation fixed them. The unchanged
red/green reproducers, precise commands and source manifests are retained under
`evidence/boundary_independent`; initial failed Health0/unchanged epochs are not
reported as final acceptance. `boundary_iteration_notes.md` also labels early
fixture/import and writable-XDG invocation failures.

Native review of the isolated, labelled locked-gap fixture observed ordinary D
fall to0/60, standard defeat, Enter retry to60/crate/four guards, and four airborne
guards disappearing with HUD changed to Reach door. Actual J cargo launch and
rotation were observed; exact cargo retirement timing and witness/Health chain
are headless evidence. A final presentation-only check accepted the complete
two-line fixed legend and visible red line after an earlier clipped world label.
Seven verified1364x1024 JPEGs have recorded hashes. Debugger29 entries remained
stable and unexpanded; native error-free status and full-route play are not
claimed. Subsequent lifecycle-guard corrections were independently tested
headlessly and did not change the reviewed presentation.

Fresh-directory import plus default mission and standalone review boot pass with
all592 frozen sources matched and unchanged. Relative to Actor-Cargo,572 sources
are unchanged,8 modified,12 added and none removed. All15 prior ZIP hashes match.
Historical report/document preservation is checked separately, excluding only
README.md, simulation/README.md and this intentionally appended verification
index. `boundary_acceptance.json`, `boundary_final_gates.json`, source delta/diff,
archive/report preservation and clean verification index the evidence.

Point observation is not shape-overlap collision or swept trajectory proof.
Arbitrary external moving ancestors require the documented invalidation hook.
Decorative asset extraction, physical corpses, acoustics, final balance and human
full-campaign duration remain outside this checkpoint.


## Reusable room backdrop — first decorative extraction

The production room now composes `demo/views/room_backdrop.tscn` with a typed
bounds/theme/seed profile and its existing presentation clock. It owns only the
original background fill, skyline/windows, pipes and rain. Floor/platform/sign,
interaction and HUD drawing remain unchanged. The view has no host/world lookup,
physics, sonar, noise, Health or progression authority. `ROOM_BACKDROP_CONTRACT.md`
defines local bounds, intentional overscan, seed-zero parity and lifecycle.

- All 17 aggregate groups pass on the same 602-source freeze, terminal exit 0.
  Existing foundation 72/72, focused 97 per rate, stock 10/10, held 333 per rate,
  eight explicit Health/Defeat/shield runs, historical 19/19 and four routes pass.
  All current aggregate sources remain unchanged and older reports are restored.
- All four actual-input mission routes complete with zero deaths/retries/failures:
  60 retained 178.050s, 60 traded 158.917s, 120 retained 175.283s and
  120 traded 167.808s of active simulated time. These are automated route results.
- Corrected native X11/GL Compatibility evidence records 98 exact pixel matches
  and six rendered isolation checks. All eight canonical room compositions are
  compared directly with the exact archived boundary room script, including
  multiple fixed times, rain wrapping, display states, full decorative overscan,
  hiding, quiet black cover and visible white contour pulses. Repeated transformed
  standalone instances also compare exactly. These are frozen presentation
  snapshots; direct pulse setup is explicitly a presentation fixture.
- Actual scene checks preserve body/shape geometry, masks, layers, one-way states,
  materials, groups and sonar contours, including deferred freight creation.
  Independent profile/time state, inherited pause/visibility and actual mission
  pause/replacement are checked at both rates. Only mission_room.gd changes an
  existing code file; 10 source files are added and none removed.

Independent review caught and closed a test-tree pause inheritance defect before
native execution. Expanded native diagnostics then caught canvas_transform being
submitted before SubViewport tree registration. That harness-only ordering was
fixed and the native matrix was rerun on a newly frozen manifest. The earlier
98-match report/source/diagnostic image remain explicitly superseded. Final
debugger inspection found no canvas-map error; environment audio/VSync messages
and lint warnings remain, so a zero-warning editor or audio certification is not
claimed. Live four-panel placement/hide/restore and input response were observed;
continuous freeze timing was visually subtle without a numeric clock.

Current reports live under `evidence/room_backdrop_gates/`, with native, focused,
source delta, archive/file preservation and final index under `room_backdrop_*`.
All 16 prior ZIPs remain hash-identical. Only this verification appendix,
MODULE_MAP.md and RUN_SIMULATION_CHECKPOINT.md are intentionally updated prior
documents. Final clean-import/package verification is the next delivery step.

This checkpoint does not extract surfaces, interactive markers or HUD, add
levels, change gameplay tuning, certify a frame-rate budget, or extend physical
acoustics/rigid-body/corpse rules.


## Placeable static platform extraction

Every production `data.platforms` rectangle now instantiates a reusable center-origin
StaticBody2D with a private RectangleShape2D and optional paint-only view. The mission
retains geometry, order, theme and the height <=18 one-way rule. The private floor
canvas preserves render order; floors, walls, signs, interaction views and HUD remain
outside this extraction. See `STATIC_PLATFORM_CONTRACT.md`.

The immutable comparison archive is `MOKSHA-Reusable-Room-Backdrop-2026-10-20.zip`,
SHA-256 `8bb0bbefcecd635fed7f0f235ab22ba429f9d8d83da210084dc59f57323fa5b8`.
Of its 602 sources, 601 are unchanged and only `demo/components/mission_room.gd`
is modified; 12 sources are added and none removed. All 614 frozen hashes match
current files, the final aggregate and corrected native pixel evidence.

The final complete aggregate exits 0 with all 19 groups passed: foundation 72/72,
focused platform checks 172 at 60 Hz and 292 at 120 Hz, preceding backdrop checks,
stock 10/10, held-input checks, eight explicit Health/Defeat/shield runs, historical
19/19 and four complete input-driven routes. Routes complete without deaths,
retries or failures: 60 Hz retained 170.300 s, sacrificed 158.767 s; 120 Hz retained
177.200 s, sacrificed 160.625 s of active simulated time. These are automated routes.
An independent isolated reviewer passed both focused rates plus eight lifecycle
checks. Those independent runs predate showcase reframing and are not represented
as testing the later complete source freeze; production platform code is unchanged.

Native X11 / GL Compatibility evidence contains 100 zero-difference image pairs:
96 complete-room states, two repeated transformed standalone views and two deliberate
overlap compositions. All six isolation/reuse checks pass. These frozen presentation
snapshots do not establish physical behavior or audible-mix quality.

Corrected live review used actual input in the fully framed 640×360 logical scene:
jump and landing, H-hidden paint while standing and traversing, restored appearance,
autonomous NPC motion, S+Space drop-through, R reset and repeated use were observed.
Literal Down+Space through the CUA route jumped rather than dropped; that exact
chord remains unverified, although S and Down are configured for the down action.
Seven original desktop captures are hashed separately. Expanded native diagnostics
showed baseline audio initialization/fallback, V-Sync and seven script warnings;
no gameplay crash or assertion was observed. This is not a zero-warning claim.

The original clipped-framing captures and `static_platform_native_pixels_before_live_framing.json`
remain preserved and superseded for current-source/live claims. The current pixel
matrix was rerun after reframing. The native review report distinguishes qualitative
input observations from the separate deterministic physical and frozen-image gates.

Two earlier aggregate attempts each passed 18/19 groups but stock combo120 exited
with SIGKILL (-9), without assertions or a completed report. Both attempts remain
preserved in their `static_platform_recovered_interrupted_stock_*` directories.
Cold preserved copies were moved from RAM-backed /tmp to disk, retaining path
symlinks and a relocation manifest. Subsequent identical isolated candidate and
sealed-backdrop combo120 runs each pass 295 scenarios / 1,360 checks in about 56 s,
with approximately 2.56 GiB peak RSS, unchanged source and the original 180 s timeout.
The first baseline import crashed; its contaminated run was rejected, retained and
repeated after a successful import. No OOM-killer evidence establishes the earlier
SIGKILL cause. No tests, thresholds or timeouts were weakened. The final full
aggregate, not these isolated diagnostics alone, establishes the accepted gates.

All 1,610 preceding report/document hashes were restored before documentation edits.
Only this appendix, MODULE_MAP.md and RUN_SIMULATION_CHECKPOINT.md are intentional
documentation changes. All 17 prior ZIPs remain hash-identical. Current gate reports
are under `evidence/static_platform_gates/`, with native, independent, recovery,
source-delta and preservation evidence indexed by `static_platform_acceptance.json`.
Fresh-directory import and new archive packaging remain separate delivery steps.

No new levels, balance changes, full human campaign playthrough, acoustic-mix quality,
frame-rate budget, general game feel or remaining decorative extraction are certified.
