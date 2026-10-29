# Movement source study

Reviewed 2026-10-04. The main implemented-game reference is the **Symphony of
the Night matching decompilation**, pinned to
`968f38954089656494b13e4c9500cdebbcf5918b`. The rows below describe inspected
function bodies, not inferred feature lists. Source was read separately; none
of its C implementation, assets, or fixed-point frame constants was imported into MOKSHA.
This is a Godot adaptation of identified mechanisms, not a faithful SOTN port.

`motor` below means `components/movement_motor.gd`; `motor tests` means
`tests/motor_regression.gd`. The current motor and tests were read alongside the
pinned reference. **Present**, **different**, and **deferred** distinguish actual
implementation from recommendations. The PC now defaults to a SOTN-informed
response profile; the NPC retains the optional smooth acceleration profile.

## Implemented-game mechanisms and their mapping

| Source / function | Verified branch and lesson | Godot mapping and status | Actual regression |
| --- | --- | --- | --- |
| [6DF70.c: CheckMoveDirection][direction] | A direction-lock bit returns neutral. Otherwise opposite input changes facing and reports a turn; matching input reports continued motion; no input preserves facing. Right wins simultaneous left/right. | **Present:** `set_intent()` owns facing independently of velocity; zero intent retains it. **Different:** Godot axis input cancels opposing keys, and the lab permits facing changes during stun/hit pause. | `_test_ground_response`, `_test_input_adapter`, `_test_air_reversal`, `_test_knockback` check facing separately from actual travel. |
| [71830.c: PlayerStepWalk / PlayerStepJump / PlayerStepFall][locomotion] | Walk applies facing-relative speed, then enters stand when direction input is absent. Ordinary jump steers in the air; fall uses a lower directional speed. | **Present:** default PC `instant_ground_response` and `instant_air_steering` assign the requested velocity directly. `jump_flight` distinguishes launched jumps from ledge falls; `walk_off_speed_ratio` lowers ledge-fall steering. **Different:** the NPC keeps optional acceleration/braking. | `_test_instant_response` checks one-tick travel/reversal/stop and slower ledge-fall steering. `_test_ground_response` and `_test_air_reversal` separately select and check the optional smooth profile. |
| [6E42C.c: func_8010E7AC][fall-entry]; [71830.c: PlayerStepFall][fall] | Fall entry arms a short jump-grace timer only when the previous contact flags showed ground. Falling accepts a fresh jump edge while this timer remains. | **Present:** `step_motor()` refreshes `coyote` on ground, expires it in air, and spends the missing ground jump after expiry. Timing is independently tuned in seconds. | `_test_coyote_and_walkoff` physically leaves a ledge, tests grace, expiry, and the remaining air-jump budget. |
| [71830.c: PlayerStepJump][jump] | During sufficiently fast ascent, released jump caps upward speed. A ceiling contact applies its own cap and blocks the ordinary apex modifier. Rising changes substate after vertical velocity becomes positive. | **Present:** release now caps ascent at `jump_release_speed_cap`, leaving slower ascent unchanged. Ceiling contact sets `apex_assist_blocked`; Godot stops upward collision motion. `RISE/APEX/FALL` are resolved from contact and vertical velocity. | `_test_release_and_apex_rules` measures the early cap, subsequent gravity and unchanged slow ascent near apex. `_test_variable_jump`, `_test_landing_buffer`, `_test_swept_collisions` check physical arcs and contact. |
| [6FDF8.c: func_8010FDF8][permissions] | Caller flags select available transitions. Ordinary apex gravity reduction additionally requires held jump and an unset modifier-block bit; descent speed is capped. Jump and air-jump consume newly pressed input; the air jump also requires an unspent flag and its unlock. | **Present:** `LocomotionMode` selects named action permissions before consumption; ground/air-jump budgets, dash-cancel interval and stun add gates. Apex assistance now requires held input and an eligible launched jump. Ceiling, air jump, dash and external impulse block it; ordinary descent uses the same default gravity. | `_test_modes_and_reset` checks policies and physical enforcement. `_test_release_and_apex_rules` / `_test_ineligible_apex` measure held eligibility and air-jump, walk-off, ceiling, dash and impulse exclusions. Jump/dash budget suites remain in place. |
| [692E8.c: EntityAlucard][input] | Previous held input and current input are kept separately; newly pressed edges are derived before state dispatch. The selected player step determines which handler executes. | **Present:** `player_intent.gd` stores press/release events, then supplies them independently of the held axis to `set_intent()`. Local pause retains pending intent; room pause/reset clears both adapter events and motor buffers. | `_test_input_adapter`, `_test_pause_buffers`; `lab_contracts.gd`: `_test_reset_pending_adapter_events`, `_test_pause_pending_adapter_events`, `_test_pause_resume`. |
| [692E8.c: CheckStageCollision / EntityAlucard][collision] | Contact flags gate directional motion. Floor, ceiling and wall sensors are resolved separately. Fast motion is divided into eight collision passes rather than taking one unchecked position step. | **Present by a different algorithm:** `CharacterBody2D.move_and_slide()` owns swept motion; a lateral collision terminates dash. Sprite drawing never moves the physics body. | `_test_swept_collisions` uses an extreme dash against a two-pixel wall, a fast jump under a two-pixel ceiling, and a fast fall onto a one-pixel floor. |
| [692E8.c: CheckStageCollision][collision]; [collider.c: CheckCollision][tiles] | Surface flags distinguish slopes and one-way contacts. The temporary drop-through branch can exclude a solid-from-above floor while retaining other solids. | **Present:** floor snap, maximum slope, constant slope speed and one-way surface properties. **Deferred:** explicit Down+Jump drop-through and changing body profiles. | `_test_slopes_and_snap` checks slope contact/rest; `_test_one_way_platform` physically passes upward without a ceiling hit, then lands on that same platform and restores jump eligibility. Lab `_test_serialization` checks stored properties. |
| [6FDF8.c: func_8010FDF8][permissions]; [6E42C.c: func_8010E470 / func_8010E570][landing] | Landing is considered while descending. Impact speed and prior movement flags select standing, crouched or momentum-carrying outcomes; landing entry zeroes vertical speed. | **Present:** motor records pre-collision impact speed and emits `landed`; grounded contact restores jump/dash budgets. **Different:** `LAND` is an observable interval, with no hard-landing movement lock. | `_test_landing_buffer`, `_test_double_jump`, `_test_air_dash_budget`; no claim that heavy-land recovery matches SOTN. |
| [7879C.c: EntityDiveKickAttack][divekick] | The attack entity destroys itself when its owning movement substate ends; a confirmed hit sets a bounce-request flag consumed by the jump handler. | **Deferred:** combat is outside this movement-only scene. The transferable boundary is that an interrupted action must not retain ownership of movement or future effects. | `_test_knockback` checks dash cancellation and no unsolicited restart. It is not a combat/dive-kick test. |

## Grounded enemy comparison

The same pinned commercial-game source supplies an NPC comparison. Both MOKSHA
actors use the source-informed shared motor; `npc_intent.gd` selects intent.
The adapter is a noncombat adaptation with explicitly different spacing behavior.

| Source / function | Verified branch and lesson | NPC mapping and status | Actual regression |
| --- | --- | --- | --- |
| [e_skeleton.h: EntitySkeleton][skeleton] | The approach state faces the player and enters retreat below its near threshold. Retreat keeps looking toward the player while moving away, then resumes approach beyond a separate far threshold. | **Present:** `_chase()` uses different entry/exit distances to prevent state chatter. **Deliberate difference:** MOKSHA enters `HOLD`, not backward retreat; target-facing at rest is independent of travel. No claim that its spacing behavior reproduces Skeleton. | `npc_regression.gd` checks chase stopping distance, hold hysteresis and resumed chase after crossing the outer threshold. |
| [entity_axe_knight.h: EntityAxeKnight][axe-knight]; [st_common.h: UnkCollisionFunc2][enemy-collision] | The knight's approach/retreat states reject blocked movement. The common helper probes forward support and side obstruction, rolling back the step and clearing horizontal velocity when necessary. | **Present by adaptation:** `_obstacle_reason()` rejects walls/edges before submitting movement. Predictive braking-distance rays, LOS acquisition/loss, bounded patrol and a turn pause are MOKSHA safety extensions. | `npc_regression.gd` checks wall/LOS turns, edge-safe patrol, gap blocking without teleport, target loss, disable and reset. |

Skeleton's attack timer, obstacle-triggered jump and retreating combat behavior
are deferred. The current NPC intentionally keeps the requested forward-facing
movement check easy to inspect before adding those actions.

## Deliberate adaptation boundaries

SOTN is the implemented commercial-game foundation reference for this pass.
Small demonstration projects are not evidence for its behavior. The retained
forward/air dash, captured dash direction, short landing-input buffer, local
hit-pause buffering and independently tunable NPC acceleration are MOKSHA
extensions. SOTN's inspected backdash entry instead starts motion opposite the
current facing ([func_8010FD88][backdash]); this lab does not present its forward
dash as a reproduction of that move.

The state permission structure, direct PC response, launched-jump versus
ledge-fall steering, held-jump apex condition, release cap and edge-grace path
are the concrete source-derived decisions. The default `walk_off_speed_ratio`
of `0.5` deliberately reflects SOTN's lower fall steering relative to launched
jump steering. Absolute pixel speeds, durations, jump impulses and Godot's
collision implementation remain project tuning. No PS1 fixed-point constants
or C code were imported, and this is not a frame-accurate SOTN port.

## What the Dead Cells decompilation does and does not establish

The inspected revision is `77c3ad263c4187ade6d048ba77bb61f79e6cec44`.

- [Entity][dc-entity] declares base/bump velocities separately from facing and
  collision mode. Its implemented `onTouchCeil()` clears bump Y and damps base
  Y, but `fixedUpdate()` and `updatePositionXY()` are empty. This fragment does
  not recover the complete collision algorithm.
- [Hero][dc-hero] declares movement/acceleration fields. `moveControlled()`
  checks a hashed cooldown entry; `airControl()` is empty and
  `controlsLocked()` throws a stub error. Hash presence does not establish the
  unnamed cooldown's timing or complete permissions.
- [CollisionMode][dc-collision] declares normal, disabled, ladder, wall-grab,
  one-way-ignoring and wall-ignoring modes. [HeroMainSkill][dc-skill] distinguishes
  hold, duration, cooldown, active state and interruptibility. Its manager's
  interruption/permission methods remain stubs. These are vocabulary and
  boundaries, not verified traversal implementations.

No MOKSHA timing is represented as recovered Dead Cells tuning. SOTN supplies
the implemented-game comparison; the small usable DC fragments do not replace it.

## Verification and reuse boundary

Final validation: **143 motor checks and 63 lab-contract checks passed** in
Godot 4.6.3 at 120 Hz, with no runtime/script errors. The measured ordinary held
jump reached **67.62 px**; early release reached **18.93 px**. These checks cover
the revised source profile, permission enforcement, actual collision/one-way
traversal, buffering, reset and optional smooth response. They establish the
listed behavior, not frame-accurate reproduction of the original game.
The unchanged NPC suite also passes all **10 patrol/chase/obstacle checks** with
the revised shared motor.

The inspected SOTN C files carry `SPDX-License-Identifier: AGPL-3.0-or-later`.
DeadCellsDecomp's README disclaims an
open-source license for the decompiled game source. This project incorporates
no source, assets, binaries, build dependency or frame constants from those
games. The document records branch-level observations and independently written
Godot equivalents; it does not claim that a copied or translated implementation
would have the same reuse boundary.

[direction]: https://github.com/Xeeynamo/sotn-decomp/blob/968f38954089656494b13e4c9500cdebbcf5918b/src/dra/6DF70.c#L101
[locomotion]: https://github.com/Xeeynamo/sotn-decomp/blob/968f38954089656494b13e4c9500cdebbcf5918b/src/dra/71830.c#L550
[fall-entry]: https://github.com/Xeeynamo/sotn-decomp/blob/968f38954089656494b13e4c9500cdebbcf5918b/src/dra/6E42C.c#L131
[fall]: https://github.com/Xeeynamo/sotn-decomp/blob/968f38954089656494b13e4c9500cdebbcf5918b/src/dra/71830.c#L749
[jump]: https://github.com/Xeeynamo/sotn-decomp/blob/968f38954089656494b13e4c9500cdebbcf5918b/src/dra/71830.c#L575
[permissions]: https://github.com/Xeeynamo/sotn-decomp/blob/968f38954089656494b13e4c9500cdebbcf5918b/src/dra/6FDF8.c#L5
[input]: https://github.com/Xeeynamo/sotn-decomp/blob/968f38954089656494b13e4c9500cdebbcf5918b/src/dra/692E8.c#L814
[collision]: https://github.com/Xeeynamo/sotn-decomp/blob/968f38954089656494b13e4c9500cdebbcf5918b/src/dra/692E8.c#L336
[tiles]: https://github.com/Xeeynamo/sotn-decomp/blob/968f38954089656494b13e4c9500cdebbcf5918b/src/dra/collider.c#L31
[landing]: https://github.com/Xeeynamo/sotn-decomp/blob/968f38954089656494b13e4c9500cdebbcf5918b/src/dra/6E42C.c#L18
[divekick]: https://github.com/Xeeynamo/sotn-decomp/blob/968f38954089656494b13e4c9500cdebbcf5918b/src/dra/7879C.c#L2065
[backdash]: https://github.com/Xeeynamo/sotn-decomp/blob/968f38954089656494b13e4c9500cdebbcf5918b/src/dra/6E42C.c#L913
[skeleton]: https://github.com/Xeeynamo/sotn-decomp/blob/968f38954089656494b13e4c9500cdebbcf5918b/src/st/e_skeleton.h#L118
[axe-knight]: https://github.com/Xeeynamo/sotn-decomp/blob/968f38954089656494b13e4c9500cdebbcf5918b/src/st/entity_axe_knight.h#L272
[enemy-collision]: https://github.com/Xeeynamo/sotn-decomp/blob/968f38954089656494b13e4c9500cdebbcf5918b/src/st/st_common.h#L297
[dc-entity]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/Entity.hx#L878
[dc-hero]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/en/Hero.hx#L581
[dc-collision]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/CollisionMode.hx
[dc-skill]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/HeroMainSkill.hx
