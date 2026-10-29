# Simulation-first foundations

Run `res://simulation/gym.tscn` with Godot 4.6.3 (F6) to choose a stage. The default
mission entry and immutable delivered v28 ZIP are not replaced.

This is a bounded foundation set, **not a unified simulation rewrite**. The
sandbox composes existing player, NPC, support and cargo scenes. Ordinary player
controls and AI decisions produce contacts. No outcome trigger makes an actor
fall, take damage, hear something, or win. Reset reloads the complete scene.

## Axioms and interfaces

1. The physics owner is the only locomotion/collision authority. AI requests
   intent; it must not cancel external momentum merely to stay on a platform.
2. A terrain query is an observation, not support. `terrain_probe.gd` accepts any
   CollisionObject2D (PC, NPC or physical object), masks and slope limit. It never
   changes position, velocity, health or an authoritative grounded flag.
3. Prospective obstacle observations are local ray evidence. They are **not** a
   swept-path guarantee, navigation solution or proof of reachable footing. Real
   collision and gravity decide what happens. One-way rules remain solver-owned.
4. Edge avoidance uses braking distance plus next-step travel and a margin. The
   AI submits neutral intent and the motor applies its ordinary braking. External
   knockback is allowed to carry the same actor beyond support.
5. Differences in senses, actions and responses belong to capabilities/profile
   configuration. Existing differences are audited below, not silently labelled
   as parity. Godot remains the physical engine.
6. Composition belongs last. No new mission room, timer, boss or campaign content
   is part of this pass. Existing asset visuals remain with their current scenes.

## Actual parity audit / acceptance matrix

| Concern | Current production reality | Acceptance status |
| --- | --- | --- |
| Terrain observation | Movement NPC and mission enemy now use one read-only probe; callable by combat PC and rigid props | Tested masks, actual support removal, no mutation, PC/NPC/object inputs |
| Footing / collision | New shared actor scene uses the same combat controller for player and NPC intent; all four production enemy archetypes use this same controller; props remain rigid bodies | **All production actor controllers migrated**; legacy scenes remain separate |
| Ledge momentum | Mission enemy previously zeroed velocity at platform lips, including knockback; both AI clamps removed | Real horizontal impulse and raw PC strike can make NPC fall, 60/120 Hz |
| AI locomotion | Patrol/chase request intent; the common controller brakes and locks actions from authored phase data | Gap avoidance regression, existing NPC/enemy/ranged suites |
| Damage | Mission PC and all four production enemy archetypes share actual melee/counter/projectile/cargo receiver composition and root Health; legacy fixtures remain separate | Real PC↔NPC/NPC↔NPC melee and opt-in projectile receiving/return, equal guard/parry/roll, cargo, lifecycle and lethal accounting; **not universal attack parity** |
| Knockback | All production actors call the same controller recoil/impulse path; props use Godot rigid-body physics | Phase-qualified bracing is authored configuration; **not momentum-conserving physics** |
| Sound | Shared actor scene composes one committed-noise relay for both sources; all production enemies use the same commitment path with semantic names | **Shared-scene emitter parity tested**, all four integrated |
| Perception | NPC visibility uses ray; hearing uses radius and memory; sonar is stylized contour rendering | **No physical acoustic occlusion/reflection claim** |
| Assets | Sandbox instances independent support/player/NPC/cargo scenes; mission_room still centrally draws decoration | **Asset extraction incomplete** |
| Dead actors | Existing NPC defeat removes collision and stops movement | **Physical corpse capability not implemented** |
| World boundary | Production PC, four NPC families and configured cargo share one observed origin half-plane; actor Health/Defeat or explicit cargo retirement | **Shared boundary implemented**, point observation rather than shape collision; see `BOUNDARY_CONTRACT.md` |

## Verification

`godot --headless --path . --fixed-fps 120 --script res://simulation/tests/footing_regression.gd -- --hz=120`
Repeat with both numbers set to 60. The horizontal impulse case is explicitly an
API-boundary test; the separate contact case drives a real PC attack through the
production contact, health and knockback components. Initial fixture placement is
not a gameplay teleport. The physical fall result is never assigned by a test.

These checks prove bounded invariants, not final game feel, full physical realism,
full PC/NPC parity, audible mix quality or human playtest quality.

The default footing profile matches the present foot-origin, roughly 36-pixel
actors (wall samples -23/-9; prospective floor range -30..28). A reusable
`terrain_probe_profile.gd` now exposes those heights/depths plus braking margin
and minimum lookahead for differently sized or center-origin assets. PC/NPC role
never selects the geometry. Each NPC gets a private profile instance. The gym depends on existing project assets and
the NoiseBus autoload, so copy the whole project when sharing it.

## Reusable gym stages

Open `simulation/gym.tscn` (F6) to select a stage. Escape returns to the selector;
R reloads the current stage. Every stage also runs alone. These are persistent
acceptance fixtures, intended to grow a small stage at a time, not campaign rooms.

- `footing_sandbox.tscn`: existing actors, independent supports/ramp and cargo;
  physical collision, landing and real strike knockback.
- `hearing_sandbox.tscn`: same configurable hearing sensor on PC and NPC; actual
  gravity-driven crate contacts and committed PC noises. Moving around a real
  wall changes the evidence; the NPC chooses what to investigate separately.
- `impact_sandbox.tscn`: opt-in shared real cargo-contact admission for both
  production actors, with capability-configured defense/health/motion responses.
- `movement_sandbox.tscn`: one shared actor/controller scene with player raw input
  versus terrain-observing NPC intent; identical capability defaults.
- `strike_sandbox.tscn`: actual-contact incoming melee on that same scene,
  existing guard/parry/roll/Health/Defeat, and observation-driven NPC attack input.
- `projectile_sandbox.tscn`: opt-in shared action emission and real swept projectile receiving/reflection for both PC and NPC input; cargo blocks both directions.
- All four production enemy archetypes now use the shared controller and contact composition.
  Production cargo now uses common charged-contact admission, including PC vulnerability
  and real cargo chains. See `MISSION_CARGO_CONTRACT.md`, `SENTRY_CONTRACT.md` and
  `WARDEN_CONTRACT.md`; other material interactions remain separate work.

### Shared hearing contract

`hearing_query.gd` admits a real bus event using its unchanged origin, listener ear
position and `hearing_profile.gd`. It is role-neutral. `hearing_sensor.tscn` is an
optional detachable subscriber with immutable signal receipts and per-instance
profile configuration. Disabled hearing, range, gain, self-source handling and
optional terrain attenuation are capabilities/settings, not PC/NPC exceptions.

The mission enemy now uses the same query; without an explicit profile its old
hearing radius, loudness clamp and foot-origin ear are retained. Its choice to
ignore a configured peer-source group and remember sound stays AI policy.
Those groups preserve the old script partitions and are not a general faction model. The NPC adapter rejects dead/disabled/paused/detached hosts. The generic sensor
checks live/process state, global pause and explicit enabled/hearing capabilities;
it cannot infer an arbitrary host's game-defined death state. The hearing gym
wires NPC defeat to disable its diagnostic sensor and shares the NPC's actual
profile with that sensor. Rebinding and cross-world lifecycle are checked.

The optional obstruction model uses one straight terrain ray and reduces audible
range when blocked. It is deliberately **not acoustic propagation, travel time,
reflections, diffraction, material absorption or physically calibrated loudness**.
A configurable 0.1-pixel endpoint tolerance prevents the emitting contact surface
from becoming its own wall; blockers wholly inside that tolerance can be missed.
The audible threshold is inclusive; strength can be zero on its exact boundary.
Bus producers are trusted local gameplay code, not authenticated physics sources.
The real-contact test proves one genuine production event path, not all producers.

Run the combined foundation checks with `python3 simulation/tests/run_foundation.py`.
The retained demo route baseline after the footing correction passed all four
60/120 Hz × retained/sacrificed-sight paths without death/retry. The latest
production-cargo route acceptance and the earlier generic ladder-planner correction
are recorded in `VERIFICATION.md` and the respective checkpoint evidence. Scene boot and headless assertions are not native visual
or audible-mix review.

### Shared physical cargo contract

See `IMPACT_CONTRACT.md` for opt-in assets, exact contact/epoch/capability semantics,
health/guard/knockback ownership and honest remaining limits. The physical-impact
suite has 225 assertions at each of 60/120 Hz. The later production migration is
documented in `MISSION_CARGO_CONTRACT.md`: mission cargo is charged-only, the PC
is deliberately vulnerable, and mask43 enables actual cargo chains. The gym
retains passive-impact configuration. Native impact review saw equal ordinary gravity
hits on both actors, raw movement/jump/cargo launch, reset and selector return;
guard absorption is established by the automated contact tests, not that native
viewing sample. See `VERIFICATION.md` for the aggregate evidence.

### Shared actor/controller contract

See `MOVEMENT_CONTRACT.md` for exact source/intent/capability/lifecycle boundaries,
equal-input translated-geometry tests, native controls and the concrete next
production integration gates. The new stage proves common movement, committed
noise and common physical-cargo response for the same reusable actor scene.
Shared melee receiving is now composed into that same scene through the bounded
bridge below. Ordinary production sentinel replacement is now implemented; see `SENTINEL_CONTRACT.md`.


### Shared incoming melee contract

See `STRIKE_CONTRACT.md`. The detachable receiver shares the controller's actual
runtime body shape and calls the existing `receive_attack` contract only during
a live ContactAdapter permit. Source serial/epoch, receiver binding/reset and
canonical geometry are checked around callbacks; host-retained history prevents
replay across receiver replacement. The controller retains all response authority; this slice adds only a read-only
canonical shield-request snapshot accessor.
A dispatch commits one controller operation. Retirement stops its stale feedback
and remaining sampled sweep, while a later genuine active sample can contact an
eligible previously unhit actor. Counter response is now available through a separate detachable receiver;
`counterable` remains an explicit opt-in (enabled in the Strike gym). See
`COUNTER_CONTRACT.md` for its physical ray, one-use permit and receipt semantics.

Contact layers/masks/groups now come from a private per-actor configuration. The
shared scene defaults to body 32, hurtbox 64, target mask 76 and simulation_actors,
independent of player or NPC intention. Actual physical cargo compatibility is
regression-tested. All six stages remain independently runnable and use ordinary
inputs/physical observations. This is a reusable simulation foundation, not a
claim of finished combat feel, physical corpses or complete mission migration.

### Shared shield-counter contract

See `COUNTER_CONTRACT.md`. The actor-registered optional receiver reuses the real
incoming hurtbox, admits only one canonical synchronous ray-contact permit, and
calls the existing controller/Health path. Counter recoil ends the attacking
sweep while preserving the defender's completed parry receipt. Shared movement,
ordinary melee and counter response are now individually proven compositions;
ordinary sentinel migration now composes them in production; see `SENTINEL_CONTRACT.md`.

### Production sentinel migration

`SENTINEL_CONTRACT.md` defines the bounded first production use: real mission
sentinels now share controller, incoming melee/counter, Health and committed sound
with the PC. The listener now reuses that same scene with a data-only archetype profile; see
`LISTENER_CONTRACT.md`. Later sentry/Warden migrations complete the four production
controller paths; see their separate contracts. Explicit masks prevent new friendly fire.
Authored intent, telegraph and mission APIs remain; physical recoil/braking now
come from the common controller. Legacy stock-prop contact remains a documented
compatibility shim. Production-specific tests exercise the real factory and scene.

Current listener production acceptance passes 36 foundation stages, 10 stock suites, the
19-stage historical aggregate and all four full mission routes, with stable source
hashes. Listener-specific acceptance is in `evidence/listener_acceptance.json`.
Independent boundary and historical baseline-route comparison evidence is preserved.
The authored floor-level ladder access caveat and native-review limits remain
explicit in `SENTINEL_CONTRACT.md` and `VERIFICATION.md`.


### Shared projectile adapter (opt-in)

See `PROJECTILE_CONTRACT.md`. A ranged-only shared scene composes a canonical
controller-sample emitter, the preserved circular sweep, and one registered
actual-body projectile receiver for outgoing/reflected contacts. Controller and
Health retain every outcome. FRESH_ONLY windup 0.72/active 0.001/recovery 0.95,
world-point aim lock, cargo obstruction, source-owned flight leases and truthful
completed Health/reflection receipts are tested independently of actor role.
Normal hurt/recovery preserves a launched shot; reset/defeat/component retirement
does not. The sixth standalone stage uses ordinary controls and a readable aim
warning. Later production sentry and Warden checkpoints now compose these boundaries;
legacy projectile fixtures and all earlier archives are retained.

### Production shared sentry

The actual mission factory now selects `demo/components/shared_sentry.tscn` for
all thirteen sentries. It inherits the shared production actor/facade and composes
the already reviewed canonical emitter/physical projectile receiver. See
`SENTRY_CONTRACT.md` for exact authored timing, locked aim, source lifetimes,
explicit43/43 physical collision with configurable owner-layer damage filtering,
intentional cargo/peer blocking. The later Warden checkpoint closes its registered-receiver gap.
Legacy ranged scenes/tests are preserved separately. The independent native
entry is `simulation/sentry_review.tscn`, with a clearly bounded initial spawn
in the actual authored Intake sector and ordinary gameplay thereafter.

### Shared hurt/recoil capability

See `HURT_RESPONSE_CONTRACT.md`. Opt-in committed step data protects windup/active
from short recoil while retaining full actual Health damage, shared hitpause and
noise. Equal-duration or longer responses use ordinary hurt; lethal Defeat still
retires the action. A genuine configurable counter can break protection only
after its canonical ray and one-use claim. Defaults and recovery stay ordinary.
A narrowly reviewed admission-sequence/bind-floor correction prevents an older
in-flight contact debiting newly rebound Health. Stage 07 is the standalone
`bracing_sandbox.tscn`; all seven stages use ordinary inputs and real contacts.
Production Warden now opts in through its separate migration contract below.

### Production shared Warden

See `WARDEN_CONTRACT.md`. The final production factory actor now uses the common
controller, one Health and all four registered contact receivers. Optional generic
independent fresh-start sequencing alternates terminal cut/sweep commitments;
phase-qualified bracing retains real damage and genuine counters. A scoped actual
Health receipt latches below-half pressure and adjusts only pending recovery.
Legacy Warden sources/tests remain separate. `warden_review.tscn` is a save-disabled,
initially configured actual-factory final-room view, not a full-route claim.

### Production actor/cargo interaction

The current physical-contact slice is documented in `ACTOR_CARGO_CONTRACT.md`. Production PC/NPC support and physical swing obstruction include cargo; equipped NPC melee can canonically launch it. The native review scene `actor_cargo_review.tscn` uses the existing Rainline room with only an initial-spawn change. Matched-input physical evidence and autonomous production-policy evidence are kept separate.

### Shared non-solid world boundary

See `BOUNDARY_CONTRACT.md`. Every production actor and configured cargo observes
the same origin-witness half-plane. Actor effects flow through guarded existing
controller/Health/Defeat admission; cargo retires existing impact and charge
authority before its destroyed fact. Initial outside occupancy is distinguished
from crossing, and one outside episode cannot retry a retired partial effect.
The standalone `boundary_review.tscn` is explicitly a locked-gap fixture. Its
actual gravity outcomes and current mission observers are tested at both rates.

### Independently placeable decorative signs

`world_sign_review.tscn` presents original and custom world-sign configurations
without a mission or physics host. The reusable scene is
`simulation/world/world_sign.tscn`; see `WORLD_SIGN_CONTRACT.md` for baseline,
resource ownership and acceptance scope. All 14 decorative mission signs now
compose this asset; interaction-owned captions and HUD are still separate work.

## Placeable onward / LIFT marker

`world/onward_marker.tscn` composes independent appearance, a separate view and
the original nonblocking sonar contour. Run `onward_marker_review.tscn` for a
standalone state/label/paint review or `onward_marker_pixels.tscn` for the native
archive comparison. Open/closed is only explicit presentation state; mission
orchestration still owns E interactions and completion. Physical relay/freight
shutters, Exchange, relays, caches and HUD are outside this slice. See
`ONWARD_MARKER_CONTRACT.md`. No new level or artificial physical outcome is added.

## Placeable Exchange station

`simulation/world/exchange_station.tscn` owns station presentation and its
existing nonblocking contour, with separate appearance/view. The mission still
owns optional sight-trade choice and consequences. Host-local paint depths
preserve visual order while retaining physical/sonar traversal. Run
`simulation/exchange_station_review.tscn` for independent placement/style review.
See `EXCHANGE_STATION_CONTRACT.md` for the precise boundary and acceptance gates.


## Placeable relay marker

`simulation/world/relay_marker.tscn` owns relay paint and its original enabled,
nonblocking sonar contour. Active state is an explicit presentation input;
mission E activation, source noise, shutter selection and progression remain
unchanged. `simulation/relay_marker_review.tscn` demonstrates independent state,
style and visibility; `simulation/relay_marker_pixels.tscn` compares the frozen
archive artwork. See `RELAY_MARKER_CONTRACT.md` for ownership and gate scope.


## Placeable Field Cache

`world/field_cache.tscn` separates optional configurable ink from its original
enabled nonblocking 16 × 18 contour. All five production caches use the asset.
Found state removes its paint and sonar membership, while ordinary hiding or
removing View does not disable physics. Host-owned invalidation is explicit.
Collection, healing, archive/pause/save rules and persistence remain mission-owned.
See `FIELD_CACHE_CONTRACT.md`; `field_cache_review.tscn` is the isolated H/C/F/R
control fixture and `field_cache_pixels.tscn` is the finite native comparison.
The integrated assembly checkpoint adds explicit-input HUD/body echo and physical scene packages. See `ASSEMBLY_CHECKPOINT.md` and the final verification report; earlier slice reports retain their original scope.

## Current modular assembly bench

Open `res://sandbox/assembly.tscn` with F6. Three editor-authored stations compose the same reusable actors and physical assets; 1/2/3 switch stations. See `ASSEMBLY_CHECKPOINT.md`, `PHYSICAL_ASSET_SCENES.md`, `PHYSICS_COMPOSITION_CONTRACT.md`, and `HUD_CONTRACT.md`. Campaign main remains unchanged.
