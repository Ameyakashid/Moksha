# MOKSHA combat PC: movement and coupled combat

This is an original MOKSHA motor informed by the Dead Cells audit, **not recovered Dead Cells v35 code or exact tuning**. No other game's movement controller, constants, resource system, or state hierarchy is used. Read the bundled `reference/DEAD_CELLS_MOVEMENT_AUDIT.md`, `reference/DEAD_CELLS_COMBAT_AUDIT.md`, and `reference/PARAMETER_EVIDENCE.json` for the evidence boundary. MOKSHA's own design is in `docs/MOKSHA-source.md`.

The audit supports the architecture: a main-action capability contract, separately owned weapon charge/execution/recovery permissions, and forgiving traversal intent. Most player motor and manager implementations are missing. The implementation authors the arbitration and movement algorithm and marks every profile number as original tuning. The movement-only milestone 1 remains preserved as a separate recoverable checkpoint.

## Deliverable and scope

- Reusable scene: `res://combat_pc/player.tscn`
- Motor: `MokshaCombatPlayer`, `res://combat_pc/player.gd`
- Tunable resources: `MokshaMovementProfile`, `resources/movement_profile.tres`, and `MokshaCombatProfile`, `resources/combat_profile.tres`, `MokshaShieldProfile`, `resources/shield_profile.tres`, and optional `MokshaMeleeChainProfile` / `MokshaMeleeStepProfile` resources
- Visual child named `Visual`, implemented independently; it never changes physics
- Implemented: fast run, braking/reversal, permitted facing independent from velocity, ground/air jump, variable ascent, landing buffer/grace, crouch clearance, swept ledge catch/hang/pull/step, moving-support transport and ledge-loss recovery; horizontal roll, one melee weapon with windup/active/recovery, explicit cancellation, actor-local hitpause, finite hurt/knockback and live strike identity; targeted one-way drop and downward dive/impact/recovery; deliberate ladder/vine attachment, swept alignment/climbing, and connected action detachment; gated finite wall run, slide, outward kick and ledge handoff; optional high-fall impact/recovery with explicit fall history, retained input queues and action-scoped descent-roll protection; shield attempt/held guard, structured incoming resolution and physical counter/reflection adapter hooks; optional configured light-melee chain with per-step input/contact identity
- Not implemented here: health/death, held charge, optional held-repeat, further weapon families, inventory unlock progression, NPCs or additional levels

The extension hooks remain available for later actions; setting an arbitrary action name does not implement its behavior. There is no stamina system and no imported catalogue of unrelated player states.

## Scale and initial tuning

The actor root is the foot pivot, positive Y downward. Standing body is 16×34, crouched body 16×20. All durations are seconds and velocities pixels/second. The motor uses the supplied delta directly; the current project's 120 Hz rate can remain unchanged. The Dead Cells nominal 60 FPS observation is not asserted to be its exact simulation algorithm.

Run speed 218, jump speed 365 and gravity 1100 start from preserved original MOKSHA tuning. Ground acceleration 3100, braking 1850, reversal acceleration 3600 and air acceleration 1450 are new MOKSHA choices. Reversal changes permitted facing immediately while physical velocity brakes and crosses zero; releasing horizontal input retains a short visible brake drift. Soft-landing and turn pose durations do not lock movement. The optional hard-landing outcome has its own explicit commitment described below.

One air jump is available and uses a 350 impulse. The 0.05 s grace is an authored starting point informed by the developer's approximate 2019 two-to-three-frame example. The 0.10 s input buffer is a MOKSHA choice. Jump release caps upward speed at 165 and increases upward gravity; descent uses 1.25× gravity. These are not decompiled values or measurements of v35.

## Host and input API

Set `automatic_physics=false` for a controlled harness, then call:

- `physics_tick(dt, frame=null)`: null samples InputMap; an empty dictionary means neutral input
- Frame keys: numeric `left/right/up/down` strengths, held `jump/roll/attack` booleans. Optional `*_pressed` and `*_released` override derived edges for that tick
- `telemetry() -> Dictionary`: a new snapshot; reading it does not advance the motor
- `reset_actor(world_position, facing=1)`: clear motion, input buffer, jump budget, contacts, active action and ledge traversal
- `can_stand(at=null) -> bool`: queries full standing clearance at the current or supplied foot position

Default actions are `cp_left/right/up/down/jump/roll/attack`. Empty bindings receive A/D/W/S, arrow keys, Space/C, Shift, J and gamepad D-pad, left stick, A, right shoulder and X. Existing customized bindings are preserved. Opposing axes cancel; held jump does not repeatedly consume air jumps. The input buffer is consumed once when a ground or air jump starts.

The profile is an exported Resource; duplicating it creates an independently tunable character. Terrain bodies use collision layer 1 by default; the player uses layer 2, mask 1. `terrain_mask` can change the query/motion mask. StaticBody2D and moving PhysicsBody2D geometry work without a special tile or source-game class.

## Grounding and jumps

Movement uses Godot continuous shape sweeps (`move_and_collide`) and tangent sliding, plus a short downward floor probe. It does not depend on `move_and_slide`'s implicit engine delta, so injected 60/120 Hz test steps use their stated delta. Ground support is geometric and floor normals are angle-limited. Shape sweeps prevent a high-speed actor from skipping a thin wall.

This solver, floor snap, collision margin, ceiling stop and slope policy are authored Godot adaptations. The audit's isolated native ceiling multiplier does not recover its missing caller/integration; this motor does not claim that the Godot ceiling response implements that helper.

A jump clears ground grace immediately. Only a real floor contact replenishes the air-jump budget. Catching/hanging on a ledge does not replenish it. A released ledge clears grace and the pending jump buffer; a later fresh press can use any genuinely remaining air jump. Eligible buffered input is consumed on a soft landing; optional hard recovery retains it until control returns. Holding jump alone does not queue another jump.

Crouch changes the collision body around the same foot pivot. Releasing crouch keeps the small body until standing space is clear. A buffered jump cannot expand the actor through a low ceiling.

## Main-action capability contract

`begin_main_action(id, capabilities, motion_driver=Callable()) -> bool` is an extension entry. It rejects an empty ID, the internally managed `ledge/roll/hurt/drop/dive/climb/wall/hard_land` actions, and an interruption denied by the current action. Supported capability keys are:

| Key | Meaning |
|---|---|
| `uses_inputs` | Read directional/jump input for normal motor control |
| `can_wall_grab` | Permit a new ledge catch or enabled wall traversal |
| `can_jump_through_up` | Permit ordinary upward one-way passage; false adds a full-shape upward obstruction sweep |
| `small_hitbox` | Require the crouching-sized collision body |
| `can_drop_through`, `can_dive`, `can_climb` | Permit the corresponding traversal action |
| `interruptible_by` | Array of allowed action IDs (`"*"` allows any), or `Callable(next_id)->bool` |

Those names are an adapter API for the audited capability concepts; default policy and resolution are authored MOKSHA behavior. `can_interrupt_with(id)` queries the current contract. `finish_main_action()` returns to normal locomotion.

An optional action motion driver has signature `(player, dt, input_frame) -> bool`. Return true when the action has authored `player.velocity` for this tick; the common collision/grounding solver still runs. Return false to keep ordinary movement/gravity. This prepares a later roll, stagger or traversal action without cloning/replacing the collision motor. Built-in roll and hurt use the same common collision solver; the hook remains available for authored external actions.

Weapon permissions are independent: `set_weapon_permissions({can_move, can_turn, can_jump, can_roll, can_attack, can_drop_through, can_dive, can_climb, can_wall_traverse, move_scale})`, or `{}` to restore defaults. Turning can remain permitted while movement is locked. An opposite-facing ledge catch is rejected while turning is forbidden, so assisted traversal cannot bypass a weapon-facing lock. The supplied melee phases intersect these external host permissions. A phase cannot reopen a host denial. `can_move` gates ordinary input movement and the melee nudge; `can_roll` separately gates a motion-owned roll. This is authored weapon policy, not a universal recovered attack-cancel matrix.

## Ledge traversal

Detection requires an allowed airborne arrival toward a wall, a wall-face ray, a separate top-surface ray on the same collider, an upright top normal, body clearance and a safe path to the hang point. Rising/falling speed gates, reach, durations and probe geometry are MOKSHA choices. There is no instantaneous root teleport onto the ledge.

The authoritative world `ledge_anchor`/`palm_target` is the wall's top corner. For the default profile, root targets relative to the anchor are:

- Catch/hang: `(-facing×9.2, +29)` maximum drop; arrivals already higher retain their current height instead of moving down to the nominal hang
- Pull endpoint: `(-facing×9.2, -1)`
- Step/plant endpoint: `(facing×12, 0)`

Catch sweeps to the hang point over 0.065 s. Neutral input can remain hanging. Toward/up/fresh jump begins a clearance-checked pull; away/down releases. Pull raises the root outside the wall over 0.17 s; step crosses above the edge over 0.14 s and physically plants on the top. The full standing shape must fit above and along the path. A narrow surface that cannot support the step destination or blocked headroom yields `pullup_blocked` and keeps a releasable hang. New obstacles encountered during an active segment abort safely.

Every segment uses continuous sweeps subdivided into at most 2-pixel requested increments. The actor never disables world collision to mantle. Queries use the committed PhysicsServer transform; a queued AnimatableBody2D Node target is applied as swept support transport at tick end, so current collision geometry is not mixed with next-step anchors. A moving support's own collider is temporarily excluded only while transporting an established supported/grabbed relative position or sweeping upward out of a confirmed flat support's small motion-query penetration; all other geometry remains blocking. Pull and step do not exclude the ledge. A removed/disabled/rotated-away surface, excessive anchor shift, or obstructed transport releases the actor with a regrab delay.

`automatic_arrival_pull` optionally remembers an arrival pull request; it defaults false. Holding toward during the hang still requests pull, so continuous run→jump→catch→pull works while releasing to neutral allows a hang.

## Visual and event API

Child `Visual` implements `present(dt, snapshot)` (or `update_visual` alias). Its `movement_event` subscription receives semantic events. The motor does not manipulate joints, animation timers or sprite scale.

Snapshot keys include `position/world_position`, `velocity`, `facing`, `grounded`, `move_x/y`, `crouched`, `body_width/height`, `main_action`, `pose/state`, `action_phase`, `phase_progress`, `air_jumps_left`, `ledge_anchor/palm_target`, `ledge_direction`, `hang_target/pull_target/step_target`, `support_id/support_displacement`, `ceiling_contact`, `wall_normal`, `time`, and `run_speed`.

Poses are `idle`, `run`, `brake`, `turn`, `jump_rise`, `jump_apex`, `fall`, `land`, `crouch`, `ledge_catch`, `ledge_hang`, `ledge_pull`, `ledge_step`. They describe observable movement, not a recovered game animation graph.

Signals:

- `movement_event(name, payload)`: `ground_jump`, `air_jump`, `landed` (with `preimpact_speed`), `turn`, `brake`, `crouch_enter/exit`, `ceiling_contact`, `ledge_catch`, `pullup_begin`, `ledge_step`, `pullup_end`, `pullup_blocked`, `ledge_release`, `footstep`, `reset`
- Every movement payload includes world `position` and `facing`
- `noise_requested(world_position, kind, loudness, source)`: matches MOKSHA NoiseBus.emit_noise argument order and unitless loudness. Default footstep loudness is 0.65; landing loudness scales with impact speed. The host may connect it to NoiseBus; there is no automatic singleton dependency
- `action_changed(previous,current)`

## Preserved movement-only verification

The archived milestone 1 was accepted for the tested authored movement scope:

- Godot 4.6.3 parse/import succeeds
- Independent real-physics runs pass **36 connected scenarios and 98 assertions at each of 120 Hz and 60 Hz**, with zero failures
- Coverage includes connected run/reversal/jump/ledge flow, variable and air jumps, buffer/grace consumption, crouch/ceiling clearance, thin walls, slopes, blocked/removed/moving ledges, facing/movement permissions, motion-driver cancellation, and clean resets
- Moving-body tests exposed and verified the Node/PhysicsServer transform reconciliation; overlap checks were retained, not loosened
- Final controller SHA-256: `183a3ad30c9f278fabab1e7db5a71b5c2c861ec6d4a11d4a061e4dd3eadd330c`
- See `combat_pc/verification.md` and `combat_pc/verification.json`, with complete physics/input traces in `combat_pc/tests/results_120hz.json` and `results_60hz.json`

The two tested rates have small expected integration differences; the paired report measures their bounds rather than claiming identical sampled trajectories. Native run/jump/catch/pull-up was also exercised in the native lab. These results verify original MOKSHA contracts, not recovered Dead Cells code, exact v35 timing, or unimplemented roll/combat features.


## Coupled roll and melee: authored policy

The Dead Cells evidence supports distinct main-action capabilities, weapon charge/execution/cooldown concepts, movement permission and interrupt surfaces. The consumers and weapon timings are absent. The following matrix, thresholds and all `combat_profile` values are original MOKSHA design. In particular, the isolated native `getNoDodgeCancelRatio() == 0.25` does **not** supply this policy or any number below.

| Current owner/phase | Movement and facing | Accepted ordinary interruption |
|---|---|---|
| Locomotion / jump / air jump | Existing motor and host permissions | Roll, eligible ground/air jump, melee |
| Roll start / travel | Direction latched; forced horizontal speed, ordinary gravity; small body, no ledge catch | Attack at elapsed ≥0.16 s; jump at elapsed ≥0.18 s if jump budget and standing clearance permit |
| Roll recovery | Ordinary horizontal control and facing reopen, subject to host permissions; body remains small | Same late roll windows; another roll must wait until current roll ends and cooldown expires |
| Melee windup | Movement ×0.35; turning allowed | Roll or eligible jump cancels swing |
| Melee active | Contact-facing fixed; ordinary directional control and jump locked; ground nudge 65 px/s if host permits movement; air speed brakes with gravity retained | Ordinary roll/jump denied and may remain queued; forced hit may interrupt |
| Melee recovery | Movement ×0.70; turning allowed | Roll or eligible jump cancels recovery; a new attack waits until recovery finishes |
| Ledge catch / hang / pull / step | Existing traversal path | No roll/attack start; traversal release rules remain authoritative |
| Hurt | Finite recoil, gravity and world collision; input movement/turn/actions disabled | Forced interruption only; new presses may queue near its end |

Simultaneously eligible requests resolve **roll → jump → attack**. Each action checks both main-action interruption and the weapon owner before committing. A successful interruption retires the old motion driver and contact owner; a denied request does not alter either. Higher-priority acceptance consumes its own queue only; other queued presses expire normally. No held-attack or held-roll repeat is implemented.

The supplied roll lasts 0.04 s start +0.18 s travel +0.08 s recovery. Committed travel decreases from 385 to 300 px/s, and exit speed is capped at 218 px/s. Its collider remains the 16×20 small body for the complete action, independent of invulnerability. Expiry or cancellation calls ordinary standing-clearance logic; it never forces the actor to stand inside a roof.

Combat boundary comparisons absorb only 1e-9 seconds of arithmetic roundoff, so an accumulated nominal endpoint does not gain an extra sampled tick. Roll invulnerability uses the separate half-open interval **0.035 ≤ elapsed <0.20 seconds**, only while the roll is live. Cancellation ends it immediately. The 0.42 s cooldown starts on entry, persists through cancellation, and advances only on actor simulation ticks. One air roll is available until a real floor contact. A ground roll that leaves the floor consumes that airborne use. A ledge catch, release, attack, roll cancellation or cooldown expiry does not replenish it. Rolling never refreshes air-jump budget or adds vertical lift.

One melee swing uses 0.09 s windup, 0.075 s active, 0.18 s recovery. Repeated fresh presses produce separate swings, each with a new monotonically increasing serial; there is no implied three-hit combo. Strike timing comes from this weapon phase owner, never from drawing, sprite frames, animation callbacks or a deferred contact timer.

### Input and local hitpause

`allow_input=false` masks directional/button intent and clears pending queues. Physical held history is still tracked, so enabling input with an already held button cannot create a synthetic press. Existing live action progression is not canceled by disabling input. Reset clears actions, buffers, hitpause, contact history, cooldown, hurt and traversal state; attack serial is deliberately **not** reset, so a delayed callback from an earlier life cannot match a future swing.

Jump/roll/attack presses are sampled before hitpause and stored independently. Their remaining lifetimes are 0.10/0.12/0.14 seconds of actor simulation time. Each queue holds one latest press: another fresh press renews that queue, acceptance consumes it, and expiry discards it. Holding does not renew it. Jump release is latched through pause; a newer jump press resets the old release latch, so the latest press owns its variable-height intent.

`apply_hitpause(seconds=-1)` extends remaining local pause to the maximum of its current value and the requested duration; the default is 0.045 s. Paused physics callbacks continue input sampling and decrement pause in real supplied delta. Movement/action/cooldown/buffer/visual clocks do not advance. The callback that expires the pause stays paused; the next callback resumes, making the sampling boundary explicit. Established support motion is still swept, and grabbed ledges remain validated, to keep separately moving terrain safe. A hit retains its former carrier solely for transport through the local freeze; this does not mark hurt grounded, restore budgets, or alter recoil, and it detaches when simulation resumes. A callback already admitted as active completes its current ordered step if a synchronous event requests pause midway through it. The newer action owner wins immediately, so its normal recoil may integrate once; subsequent callbacks freeze. This does not undo movement or clocks already processed, and same-sample strike contacts retain their existing confirmation policy. No global Engine time scale or world pause is changed.

### Strike and passive-contact boundary

The player scene includes `ContactAdapter`, owned separately from the motor. It receives:

`signal strike_sample(actor: Node2D, snapshot: Dictionary)`

Only an active simulation tick emits a sample. Paused public snapshots are ineligible and delayed confirmations during pause are rejected; synchronous targets within the same emitted sample may all confirm even when its first target starts hitpause. Paused carrier travel refreshes the previous center without sampling, preventing a resume sweep over terrain crossed only during pause. Snapshot fields:

| Key | Type and meaning |
|---|---|
| `serial` | Increasing integer identity for this swing |
| `center`, `previous_center` | Current and previous world-space hitbox centers for swept contact sampling |
| `size` | Vector2 box dimensions; default (32,24) |
| `origin` | World-space strike origin for obstruction and forward-half-space checks |
| `facing` | Integer ±1, fixed throughout active contact |
| `damage` | Authored numeric payload; default 1 |
| `impulse` | World-space impulse request; default (facing×260,-80) |
| `phase`, `eligible` | Live phase name and eligibility; only active is eligible |

Default center is root +(facing×24,-20), with the vertical offset following the physical crouch height under a roof. The origin is root +(facing×3,-22), similarly kept within the body. `strike_snapshot()` returns a fresh snapshot for inspection; callers cannot use a stale snapshot to authorize a later hit.

`confirm_strike(serial:int, target_id:int, contact_position:Vector2) -> bool` rechecks current active identity and rejects a stale/canceled/non-active swing or an already confirmed target. The adapter must call this immediately before applying contact. Both adapter and motor deduplicate by target/serial. The first confirmed contact per swing applies 0.045 s actor hitpause; additional targets in that same swing can be hit once without repeatedly extending it. Starting a new swing clears that swing's target set and increments its serial.

The separate contact adapter samples the swept forward volume, checks obstruction against real world geometry, and routes the accepted hit to passive `receive_strike(payload)`, original MOKSHA prop `launch(direction, scale)`, or an existing `take_hit(damage,direction)` boundary. No NPC or enemy behavior is required for this milestone. The unchanged older StrikeComponent is not attached because it uses the older player's private state fields.

### Incoming hit / interruption boundary

`receive_hit(payload: Dictionary={}) -> bool` supports:

- `rollable: bool=true`: rejected only during the live roll's invulnerable interval; false explicitly bypasses roll invulnerability
- `impulse: Vector2`: direct requested recoil velocity; otherwise authored defaults use 180 px/s away from `source_position` (or opposite facing) and -130 px/s vertically
- `source_position: Vector2`: optional origin used for default recoil direction
- `stun_seconds: float=0.18`: finite authored hurt duration
- `hitpause: float=0.06`: actor-local pause on accepted hit
- `amount: float=1`: informational damage payload for the host; this pass has no health/death system

Accepted hits cancel both action owners and any ledge contact, invalidate outgoing contact immediately, clear pre-hit input queues, and apply the recoil through the same world collision motor. A rejected hit changes neither actions nor buffers. Accepted-hit repetition is a host/contact-fixture policy; this actor does not invent a post-hit immunity period. Newly pressed inputs during pause or late hurt are captured normally and may execute once hurt ends if their queues remain live.

### Added telemetry and semantic events

Telemetry extends the movement snapshot with `roll_phase`, `roll_progress`, `roll_phase_progress`, `roll_direction`, `roll_elapsed`, `roll_invulnerable`, `roll_cooldown`, `air_roll_available`, `weapon_phase`, `weapon_phase_progress`, `weapon_elapsed`, `attack_serial`, `attack_facing`, `strike_active`, `strike_center/size`, `hitpause_remaining`, `paused`, `hurt_progress/direction`, `allow_input`, and remaining `jump_buffer/roll_buffer/attack_buffer` lifetimes.

Pose precedence is hurt → live roll → live melee → existing movement. Airborne attacks retain the weapon pose and airborne telemetry; landing does not discard a live swing. Roll poses use `roll_direction`; active attack poses use `attack_facing`. Drawing cannot change facing, root position or collider. `present(0, snapshot)` updates paused presentation without advancing its clock.

New movement events are `roll_started`, `roll_phase_changed`, `roll_finished`, `roll_cancelled`, `attack_started`, `attack_phase_changed`, `attack_finished`, `attack_cancelled`, `strike_confirmed`, `hurt_started/finished`, `hit_evaded`, and `hitpause_started/ended`. Attack events include serial and phase when relevant. Existing position/facing payload enrichment and NoiseBus-compatible signal remain intact. Roll, strike and hurt emit authored unitless loudness values.

## Preserved movement-plus-combat verification

The archived milestone 2 motor and scene parsed under Godot 4.6.3. Its independent actual-physics acceptance passed at both 120 Hz and 60 Hz:

- **49 connected combat scenarios / 135 assertions per rate**, zero failures
- **36 prior movement compatibility scenarios / 98 assertions per rate**, zero failures, written to separate M2 traces
- All 14 cross-rate measurement bounds pass
- Controller SHA-256: `3f0b054a88b1a4cd6dd61573ad85d83be416addea67b46b02cc6fcac83e0a588`
- Source hashes stayed stable during every accepted run; historical M1 harness/report/trace bytes remain unchanged

See [combat_verification.md](combat_verification.md) and [combat_verification.json](combat_verification.json) for exact source hashes, test coverage, corrected-defect evidence, trace links and reproduction commands. The tests include real passive contacts, thin-wall obstruction, a real original MOKSHA crate impulse, per-target identity, stale cancellation/reset callbacks, iframe endpoints, finite air roll, hurt carrier clearance, hitpause input/release ownership and all existing ledge/slope flows. Native presentation and feel review belongs to the lab owner and is separate from these headless results.

The accepted scope remains this original MOKSHA contract. Arbitrary rotated/concave contact-shape fidelity, unavoidable continued crushing, unspecified profile extremes, health/death, NPC behavior and exact Dead Cells parity are not established by these checks.


## Contextual drop and dive: evidence boundary

The pinned [JumpDown declaration](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/mainSkills/JumpDown.hx) declares a normal-jump lock and shared jump blackboard; use/start/drop/update bodies are unavailable (blob `d921c5f46da5c795a5c794a07c54ecbf25185695`). The pinned [DiveAttack declaration](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/mainSkills/DiveAttack.hx) names startup/update, landing, cancel/end, height-ignored and interruption concepts but does not recover their implementation or values (blob `04f717390c616be1ee05ebc8a00a09ac1f3b27d9`). The generic main-skill duration/cooldown defaults are not move-specific tuning.

[Official update 2](https://deadcells.com/patchnotes/2), June 2017, records a fix preventing roll plus jump-down from bypassing a solid wall. [Official update 14.6](https://deadcells.com/patchnotes/14), August 2019, describes a narrow roll-during-stomp landing-stun exception. These support explicit collision safety and action interaction, but do not recover bindings, velocities, phase timing, floor breakthrough, invulnerability or a general high-fall-stun algorithm. The implementation below is authored MOKSHA policy; it adds no floor-breaking, health damage area or generic high-fall stun system.

### Input, ability and cancellation policy

A **fresh Down+Jump** press is classified once from a non-mutating physical support probe at capture (so spawning/resetting directly on a platform needs no invisible settle tick):

- Grounded: request `drop`
- Airborne: request `dive`

The request has a separate 0.10 s simulation-time buffer and keeps its original kind across hitpause, landing or action changes. Accepting or denying it consumes that chord; it cannot subsequently become a normal jump, air jump, or another down-action. Holding the buttons does not repeat. Plain Jump retains the existing ground/air-jump behavior. Down+Attack retains ordinary melee behavior.

Arbitration priority is **roll → contextual down-action → plain jump → melee**. A phase-locked request may wait until its queue expires. A disabled ability, denied capability, unsupported platform, changed ground/air context or inadequate dive height emits `drop_denied` or `dive_denied` and consumes only that chord, without an upward-jump or melee fallback.

Actor exports `allow_drop_through` and `allow_dive` default true. Main capabilities and external weapon permissions also expose `can_drop_through` and `can_dive`; all relevant gates must permit a new start. Ability changes affect **new starts only**. A live dive retains its finite phase/cancel policy, and a drop's collision cleanup completes safely even if the ability is disabled meanwhile. Host `allow_input` behavior remains unchanged.

| Current action | Ordinary interruption policy |
|---|---|
| Drop release | Roll or melee can interrupt; jump/dive waits until the target exception has cleared |
| Dive startup | Roll, eligible ground/air jump or melee |
| Dive descent | Roll, subject to real remaining air-roll use and cooldown |
| Dive impact | Briefly committed; forced hit/host interruption only |
| Dive recovery | Roll, eligible jump or melee |

Windup/recovery melee may be canceled by drop/dive; committed active melee cannot. Existing roll accepts drop/dive only at its authored late jump-cancel boundary. Forced damage cancels outgoing dive/weapon ownership immediately. Reset cancels both actions and clears pending intent, target cleanup and blocked geometry state. Dive and melee use separate monotonically increasing identities, so canceling either cannot create a delayed impact or stale strike.

One authored `dive_available` use is available per airborne trip. A dive start spends it; only actual floor contact or reset restores it. Cancellation, a ledge grab, timeout or weapon start does not. This prevents repeated startup-brake/cancel cycles from creating unlimited hovering, while preserving the existing air-jump and air-roll budgets. A drop neither spends nor replenishes either existing budget.

### Dedicated one-way support policy

The drop adapter inspects the **actual supporting PhysicsBody2D** and its enabled shape-owner flags. It accepts only upright, positive-scale rectangular shapes whose one-way top planes are coplanar within the authored 0.05 px tolerance. Multiple rectangles on one such body are supported as one platform. It refuses mixed solid/one-way bodies, stacked top planes within one body, rotated/non-rectangular shapes and unsupported or missing support geometry.

Before starting, it temporarily excludes only that candidate from a 4 px downward full-body sweep. A second overlapping support, nearby solid floor or other obstructing body makes the request refuse. A separate lower one-way body remains collidable and can catch the drop. A solid wall never disappears from the actor's mask, even during a roll interruption. There is no global one-way layer change, shape disabling or unchecked root movement.

A successful drop retains a collision exception for that **one validated body**, clears coyote and the accepted chord, and requests at least 100 px/s downward velocity through the common sweep solver. The short `drop` action lasts 0.08 s; its capability requires the small body and suppresses ledge catches. Roll/melee/damage can replace that action while its targeted collision cleanup remains independently tracked.

The exception restores only after full current-body separation below, above or horizontally outside the platform bounds, including the authored clearance/margin. The actor keeps its small collider while cleanup is live, independently of which action now owns movement. Plain jumps and current-root standing queries are denied throughout that cleanup; replacing/expiring the short drop action cannot bypass the expansion guard. After the finite drop owner ends, a new dive may start while cleanup remains because it retains the small body and swept downward motion; it carries the same targeted exception until full separation. This permits the connected drop→dive flow without expanding into the ignored geometry. Standing after cleanup still requires ordinary clearance.

At the 0.30 s cleanup deadline, an unresolved overlap emits `drop_cleanup_blocked` **once** and retains only that validated one-way exception. Movement and permitted escape actions remain available. New targeted drops are refused until this older cleanup clears. The deadline does not forcibly restore an overlapping collider or ignore any other body. Closely stacked platforms that cannot fit the body may therefore retain cleanup and report the blocked condition; the host can move geometry or reset, and the actor can escape sideways if space permits.

If the ignored body becomes unsupported solid/mixed/rotated geometry while overlapping, the actor restores its collision, cancels live actions and reports `drop_geometry_blocked`. Its root remains still and the pose is `drop_blocked`; actor clocks resume only after physical separation/removal or reset. This conservative safety check uses shape-owner bounds, because a just-replaced shape can precede the physics broadphase query update. This is an explicit malformed/physically trapped scene boundary, not an attempt to teleport out or pass through the new solid. Removing a target or changing its geometry while separated restores normal collision directly. The target RID is retained independently and a disconnectable `tree_exiting` hook clears the exception before body destruction; normal clearance and reset also disconnect the hook. Moving targets are checked against their committed PhysicsServer transforms, consistent with the existing moving-support solver.

### Dive phases and impact

All new numbers are exported original MOKSHA values. Drop parameters are grouped in `MokshaMovementProfile`; dive parameters are grouped in `MokshaCombatProfile`.

1. `startup`: 0.08 s, fixed entry facing, horizontal drag 1800 px/s², vertical braking 4000 px/s². An 8 px downward floor-clearance check rejects starts too close to a real floor. The body remains clearance-safe; no forced expansion occurs.
2. `descent`: initial downward speed at least 180 px/s, approaching 700 px/s at 2000 px/s², with the same horizontal drag and continuous collision sweep. No ledge catch or jump/weapon cancellation. A roll may cancel while its genuine air use/cooldown permits it. The authored 2.0 s descent deadline returns to normal falling without generating an impact.
3. `impact`: only an actual downward floor contact while in descent creates it. The root is physically grounded, velocity is zero, and the phase lasts 0.06 s. Exactly one `dive_impact` event carries serial, surface instance ID, contact normal, pre-impact speed and fall distance; default impact loudness is 1.3. The ordinary `landed` semantic event still occurs, but its extra landing noise is suppressed for this impact.
4. `recovery`: 0.14 s, ordinary permitted movement/facing return; jump, roll or melee can interrupt. Losing the supporting floor cancels safely into normal falling. Startup landing likewise cancels without a fabricated descent impact.

The descent retains its entry facing in `dive_direction` (±1). It supplies no i-frames, enemy behavior, area damage, floor breakthrough or health system. Incoming rollable/unrollable hit behavior remains the established hurt contract.

### Traversal telemetry and hooks

New snapshot keys: `drop_active`, `drop_phase` (`release` while the target exception is live, otherwise `clear`), `drop_progress`, `drop_target_id`, `drop_exception_active`, `drop_ignore_elapsed`, `drop_cleanup_blocked`, `drop_geometry_blocked`, `down_intent`, `down_buffer`, `allow_drop_through`, `allow_dive`, `dive_available`, `dive_phase`, `dive_phase_progress`, `dive_serial`, `dive_direction`, `dive_fall_distance`, and `dive_impact_speed`.

Drop progress is elapsed /0.08 s, clamped. Dive progress is elapsed/current phase duration, clamped; descent uses its finite 2.0 s maximum. These are presentation values only. Poses are `drop`, `drop_blocked`, `dive_startup`, `dive_descent`, `dive_impact`, and `dive_recovery`. Paused snapshots still advance no visual time.

Events: `drop_started`, `drop_finished`, `drop_denied`, `drop_clearance_restored`, `drop_cleanup_blocked`, `drop_geometry_blocked`, `drop_geometry_unblocked`, `dive_started`, `dive_phase_changed`, `dive_denied`, `dive_cancelled`, `dive_impact`, and `dive_finished`. All retain the existing world position/facing payload enrichment. No new singleton or scene fixture class is required by the motor.

## Preserved drop/dive verification

The final motor parses under Godot 4.6.3. Independent actual-physics acceptance passes at both 120 Hz and 60 Hz:

- **64 connected traversal scenarios / 222 assertions per rate**, zero failures
- **36 prior movement scenarios / 98 assertions per rate** and **49 prior combat scenarios / 135 assertions per rate**, zero compatibility failures
- All 20 cross-rate measurement bounds pass
- Controller SHA-256: `6ed04e06c22d6f1354ea5add49f49e72463d6dadedf4c7d4940473227a1127f0`
- All 14 historical M1/M2 evidence artifacts and both saved milestone archives retain their verified bytes

See [traversal_verification.md](traversal_verification.md) and [traversal_verification.json](traversal_verification.json) for exact hashes, traces, corrected-defect evidence and reproduction commands. Coverage includes dedicated multi-shape and separate stacked platforms, mixed/rotated/ambiguous refusal, thin walls through roll cancellation, moving/removed/disabled targets, context capture, hitpause, ability gates, every dive phase/cancel path, real slope impact, timeout, persistent cleanup across owner changes and reset. A 40 px stack with a 6 px upper platform correctly retains crouch while clearing the old exception and accepting a new drop; 44 px permits standing.

The explicitly reported blocked-cleanup and changed-geometry conditions remain intentional safety limits. Impact has semantic/noise hooks only. These checks establish the original MOKSHA contract, not recovered Dead Cells code or timing. Native presentation and feel review remain separately owned by the lab review.

## Ladder and vine evidence boundary

The pinned [Hero climbing declarations](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/en/Hero.hx#L787) name climb sound, start/stop climbing and top exit, but their bodies are empty (Hero blob `fd03750543f136f7487bf1a030489cddb7cb4280`). The [AirJump climbing callback](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/mainSkills/AirJump.hx#L44) calls a missing counter setter (blob `2991081b3d442874d71bf8476a1aa956d89c695a`); this is not proof of remaining-budget semantics or an air-jump refill. The Ladder collision category establishes a named concept, not a solver.

[Official update 1](https://deadcells.com/patchnotes/1), May/June 2017, records improvements to grabbing ladders from above and jumping away at their top. [Update 29.3](https://deadcells.com/patchnotes/29), July 2022, prevents the accessibility auto-jump option from triggering on ladders. [Official update 3](https://deadcells.com/patchnotes/3), July 2017, also describes stronger vertical intent to reduce accidental diagonal ladder grabs and a faster top exit by rolling. These primary observations support deliberate traversal and responsive exits. Speeds, geometry, input/cancel policy and poses below are original MOKSHA choices; no complete ladder algorithm or v35 tuning was recovered or copied.

### Placeable climbable and geometry contract

`res://combat_pc/components/climbable.tscn` is an independent `MokshaClimbable` Area2D. Place its root at the bottom; positive exported `height` extends upward, with the axis at local X=0. Exports are `width=20`, `height=140`, `climb_type="ladder"` or `"vine"`, `enabled=true`, `selection_priority=0`, `sensor_layer=16` and `draw_guide=true`. Its original line guide is optional. Both types share the same physical policy; no vine unlock is inferred.

The sensor uses layer 16, mask 0 and an enabled rectangle child `SensorShape`. It has no physical terrain collision and does not replace a real floor, wall or one-way top. The actor's exported `climbable_mask=16` selects these areas separately from `terrain_mask`. `climb_geometry() -> Dictionary` returns `axis_x`, `top_y`, `bottom_y`, `width`, `type`, `priority`, `rung_spacing`, `rung_origin_offset`; empty means unavailable. The sensor extends 2 px above/below its nominal endpoints so a supported actor can request Down from the top boundary.

Supported transforms are upright, positive-scale translation. Rotation, skew, zero/negative scale, disabled layer/monitorability/shape, missing/nonrectangle shape, or a manually changed child shape/transform inconsistent with the exported bounds makes the geometry unavailable. Change dimensions through the exports. A live dimension/scale change detaches safely; translating a live sensor is supported. Type, priority and guide-only changes do not invalidate physical contact.

Overlapping eligible sensors are selected deterministically by descending `selection_priority`, then nearest horizontal axis, then full scene node path. A sensor whose top has already been reached for Up, or bottom for Down, is removed before sorting so it cannot hide another usable overlapping sensor. There is no automatic mid-climb transfer to another sensor.

### Entry, motion and exits

A permitted vertical input of at least 0.5 while physically overlapping an eligible sensor requests attachment only when its magnitude exceeds raw horizontal input by the exported `climb_entry_vertical_margin=0.15`. Equal keyboard diagonals therefore do not grab; near-vertical analog input can. This numeric dominance predicate is authored MOKSHA policy. Running past or falling through without vertical intent does not attach. Existing action priority is roll → contextual down-action → plain jump → melee → climb entry. Committed melee/roll/dive/hurt and main-action interruption gates remain authoritative; windup/recovery can yield to a permitted climb. `allow_climb`, main `can_climb`, external weapon `can_climb`, `uses_inputs` and movement permission gate a new entry.

The main owner becomes `climb`. Phases are `align`, `idle`, `ascend`, `descend`, `top_exit`, `blocked`. The motor first sweeps horizontally to the axis at 160 px/s, with a 0.25 s alignment deadline; an obstructed/deadline alignment releases. Climbing then approaches 115 px/s up or 145 px/s down at 1100 px/s². Neutral brakes at 1800 px/s² and holds without gravity. All values are exported under the movement profile's ladder/vine group. World collision remains continuously swept; upward one-way permission is carried from the interrupted main owner. Input/movement lock holds an established grip still while moving-sensor transport continues.

The root remains a foot pivot and normally keeps its 16×34 body. Crouch/headroom and outstanding drop cleanup remain authoritative, including the 16×20 body until safe expansion. Climbing does not force a body expansion through a ceiling or ignored platform.

Up approaches the top with the same centered sweep; `top_exit` labels the last body-height of actual travel. Only reaching the geometric foot endpoint completes the exit. A downward floor probe then establishes real support; with no top surface the actor returns to ordinary falling. A blocked ceiling reports `blocked` and stays attached, permitting downward reversal, horizontal release or allowed action interruption. No timer teleports the actor through a roof or sideways onto a platform. Up while already supported above that sensor does not repeatedly attach.

Down at the bottom releases; a downward sweep reaching an intermediate actual floor also releases. On a supported one-way above a climbable, deliberate Down calls the existing targeted drop validation and preflight before attachment. Solid/mixed/ambiguous support is refused. The same single-target exception and independent small-body cleanup remain alive through climbing and later interruptions. Reversing a partial top entry rises a few extra **swept** pixels above the cleanup margin, restores the platform safely, then settles onto it. A previous unrelated/live drop cleanup prevents a new climb entry.

Every detach sets a 0.18 s regrab delay and requires physical vertical neutral before another attachment. Holding Up/Down cannot create an attach/detach loop after top/bottom exit, blocked alignment, removal or cancellation. Horizontal-only input deliberately releases with a 48 px/s side request through ordinary collision, providing escape even when air-action budgets are exhausted. No horizontal position is assigned directly.

### Connected actions, budgets and lifetime

- A fresh plain Jump from a valid attached grip requests the normal 365 px/s launch and existing variable-release response. It does **not** spend or restore the prior air-jump, air-roll or dive budget. This supported grip jump is explicitly authored MOKSHA policy, including when the prior air jump is spent. After voluntary horizontal release only, an exported 0.06 s `climb_jump_grace_seconds` preserves one such supported launch when direction and Jump arrive on adjacent ticks. The released sensor must remain enabled, geometrically valid and nearby. Grace uses the actor simulation clock (frozen during hitpause), is consumed once, and clears on a new accepted action, damage, forced completion or reset. Other release reasons grant no grace. Another supported launch requires a new physical attachment after neutral and delay. Host jump permission and body/drop clearance still gate it.
- Attached Down+Jump is classified once as `dive`. If its ability, phase, height or existing dive budget denies it, that press is consumed and the actor stays attached; it cannot become a jump or drop. An eligible dive detaches and uses the existing phases/identity/budget.
- Roll and melee detach only when their existing gates/budgets accept them. Roll consumes the genuine airborne roll use. Melee creates its usual new strike serial; climb cannot keep a stale weapon owner. Down+Attack remains ordinary melee.
- Damage and forced host completion detach immediately and clear the contact. Accepted hurt preserves its ordinary recoil/hitpause behavior; a sensor itself is not a physical support to exclude from collision. Reset clears target, phase, regrab state and traversal telemetry. No sensor callback or collision exception is introduced beyond the existing top-entry drop cleanup.
- Attachment, holding, sensor motion and ordinary release never refresh any air-action budget or ground grace. Real floor contact and reset retain their existing replenishment rules.

`allow_climb=false`, external `can_climb=false`, removed/disabled/unsupported geometry, excessive sensor motion or obstructed sensor transport releases a live climb. This intentionally differs from drop/dive's new-start-only ability policy: gravity is safe after releasing a sensor grip, while their existing finite motion/cleanup must finish. A live `can_move=false` holds climbing motion, while the independent jump/roll/attack permissions can still allow detachment. `allow_input=false` holds the grip and suppresses new input actions. Queued inputs and physical held-state tracking preserve the established hitpause contract.

Sensor translation is swept against all ordinary terrain, capped by `climb_max_transport_speed=420` px/s plus 1 px step tolerance. The sensor is an Area, so no terrain body is omitted for this transport. A carried `can_jump_through_up=false` also blocks upward sensor transport through a one-way, including during hitpause. A blocked or excessive shift releases at the last safe position, with no teleport to the moved sensor. During actor-local hitpause, only this safe transport and validity checking continues; climbing, phase clocks and queued-input expiration remain frozen. Arbitrary crushing geometry or a climbable intentionally moved through a solid is an explicit detach boundary, not an invented depenetration path.

### Climb telemetry and events

Snapshot fields: `allow_climb`, `climb_active`, `climb_phase`, `climb_phase_progress`, `climb_target_id`, `climb_axis_x`, `climb_top_y`, `climb_bottom_y`, `climb_width`, `climb_type`, `climb_velocity`, `climb_distance`, `climb_transport`, `climb_regrab_remaining`, `climb_needs_neutral`, `climb_jump_grace`, `climb_rung_spacing`, `climb_rung_origin_offset`. Signed `climb_distance` accumulates downward root travel excluding sensor transport. `climb_transport` is this tick's actual swept sensor displacement. The ladder guide's first rung is 4 local pixels above its bottom (vine cross-grips start at 8); spacing is 12 local pixels. Both telemetry values are transformed by positive sensor Y scale into world distances. Presentation may derive contacts from these values but cannot author movement.

`climb_phase_progress` describes alignment elapsed/deadline or actual approach within the final body-height at top; idle/ascend/descend/blocked use zero. Phases select `climb_<phase>` poses. `grounded=false` while attached; normal floor semantics resume on physical exit. Fresh jump/roll/dive/attack/hurt pose ownership replaces climb immediately.

Events use the existing enriched movement signal: `climb_attached` (`target_id`, `type`, `top_entry`), `climb_phase_changed` (`phase`), `climb_denied` (`reason`) and `climb_detached` (`reason`, `target_id`). Reasons include `top_exit`, `bottom_exit`, `floor_exit`, `horizontal_release`, accepted action name, `damage`, `forced`, `reset`, `target_removed`, `target_changed`, `target_disabled`, `target_moved_away`, `transport_blocked`, `alignment_timeout`, `alignment_blocked`, `ability_disabled` and `drop_geometry_blocked`. No new noise or damage area is implied by attaching a sensor.

### Preserved climb verification

Motor and component parse, and headless project import succeeds under Godot 4.6.3. Final independent actual-physics acceptance passes at both 120 Hz and 60 Hz:

- **85 connected climb scenarios / 215 assertions per rate**, zero failures
- **36 prior movement scenarios / 98 assertions**, **49 prior combat scenarios / 135 assertions**, and **64 prior drop/dive scenarios / 222 assertions per rate**, zero compatibility failures
- Final controller SHA-256: `3595e1b919b0fd7fff7be6eebf6b44e487e11fddcb744fa04c197848f8b49231`
- All 23 cross-rate measurement bounds pass
- Sources stayed stable during every accepted run; all 27 earlier milestone evidence files and saved archives retain their verified bytes

Coverage includes supported ground/air/top entry, actual top/bottom/intermediate-floor exits, overlapping sensor selection, keyboard diagonal refusal and near-vertical analog intent, shape/layer/method mutation, stale moving-area queries, blocked headroom, safe transport during pause, upward one-way permission, body/drop cleanup, all action detachments and gates, and no budget refill on attachment. Native adjacent A/D then Space tests cover the authored grip-jump grace in both directions, along with expiry, pause, target invalidation, single-use behavior and every specified clearing action. Focused independent lifetime review found no remaining concrete defect.

See [climb_verification.md](climb_verification.md) and [climb_verification.json](climb_verification.json) for exact hashes, traces, corrected-defect evidence and reproduction commands. These checks establish this original MOKSHA contract and the supported upright sensor geometry. Native presentation/feel review is separately owned; exact Dead Cells parity, arbitrary crushing/depenetration and unimplemented mechanics are not claimed.

## Gated wall traversal: evidence and authored policy

The developer's [14 November 2017 announcement](https://store.steampowered.com/news/posts/?enddate=1510678900&feed=steam_community_announcements) embeds [an observed wall traversal clip](https://imgur.com/cdkBTwq): airborne approach, upward right-wall contact, outward leftward kick and a higher opposite landing. This supports the connected sequence. It does not demonstrate exhaustion/slide, input bindings, passive rearming, ledge handoff, phase timing or weapon cancellation. The pinned Hero/main-skill movement and permission consumers remain absent. The real AirJump climbing callback writes through a missing setter; it does not establish a refill rule. See [the bundled evidence boundary](reference/WALL_TRAVERSAL_CONTRACT.md).

Historical performer accounts describe item/attack-based same-wall renewal. Their current-version applicability and missing consumers are unresolved. This motor does not silently implement that historical reset technique, nor claim a ground-only restriction as recovered behavior. All new values and transitions below are **original MOKSHA tuning**, with a configurable rearm policy.

### Ability, surface and contact authorization

`allow_wall_run=false` on the reusable actor is the ability gate. The inspection lab explicitly grants it; no true value is serialized into `player.tscn`. New wall entry also requires the current main owner's existing `can_wall_grab`, external weapon/host `can_wall_traverse`, `can_move`, `uses_inputs`, accepted interruption and weapon-phase cancellation. `can_wall_traverse` defaults true in the permission dictionary; effective entry still requires the separately locked ability. This new permission does not globally replace ordinary ledge eligibility.

Entry requires an airborne, standing-clear body, no live drop exception or malformed-drop safety hold, and raw horizontal input toward the wall of at least 0.5 with no Down intent. It cannot force a facing reversal while turning is denied. Body clearance remains independent from presentation. Supported candidates have two real horizontal face probes at 35% and 75% of body height, reaching at most 3 px beyond the actor side, with outward horizontal normals of at least 0.98 magnitude.

Each carrier must be a dedicated upright, positive-scale, single enabled solid `RectangleShape2D` on an ordinary `PhysicsBody2D` in `terrain_mask`. One-way sides, mixed/multiple enabled shapes, nonrectangular shapes, rotation/skew and invalid/layer-disabled bodies are refused. Disabled sibling shapes do not count as active geometry. This is a conservative Godot adapter boundary, not a claim about supported Dead Cells geometry.

A body may set `wall_traversal_blocked=true` metadata to refuse entry and invalidate live/recent wall support. This is a small eligibility hook for future spike/locked geometry; it supplies no hazard damage system and does not alter the separate ordinary ledge hazard policy.

Both committed PhysicsServer geometry and an already-planned Node pose are checked before authorizing fresh entry. A changed/rotated rectangle, excessive pending displacement or obstructed pending transport refuses before canceling an action, consuming an episode or emitting attachment. This avoids granting contact from stale broadphase data when a wall moved away earlier in the physics tick.

### Motion, phases and action order

One managed `wall` action has `run`, `slide` and `kick` phases. Run/slide own velocity through the same continuous collision sweep used by ordinary movement; no wall snap, replacement physics motor, stamina or invulnerability is added.

- **Run:** velocity approaches 180 px/s upward at 1500 px/s². It ends at 72 px actual accumulated upward travel relative to the support, or 0.50 s of active run time, whichever occurs first. Existing approach momentum is approached rather than overwritten. Requested upward motion is capped to the remaining rise. Entering slide removes residual upward velocity, so passive deceleration cannot add an untracked ascent beyond that cap.
- **Slide:** velocity approaches 90 px/s downward at 900 px/s². This finite phase ends after 1.20 s and returns to ordinary gravity. Its elapsed allowance survives same-contact cancellation/reentry. A ceiling switches run to slide; collision stays authoritative. A small 24 px/s inward request maintains actual side contact without assigning position.
- **Kick:** a fresh accepted supported Jump requests 230 px/s outward and 365 px/s upward. It consumes the jump press once, preserves the previous ordinary air-jump/roll/dive budgets and clears planted wall contact immediately. For 0.09 s, the horizontal request remains outward and ordinary steering/facing changes and ordinary action cancels are committed. Existing jump-release gravity still applies. Afterward the main action becomes ordinary `jump` with normal air control. Incoming damage, reset or forced completion can interrupt immediately.

Wall side/contact normal and actor facing are distinct. Entry normally faces the wall; kick normally faces outward. A host turning denial preserves the current facing even when kick motion goes outward. Visuals receive both values.

Input priority remains **roll → contextual down-action → supported/ordinary jump → melee → climb entry → wall entry**. Run/slide accept eligible roll, dive, supported jump or melee before evaluating voluntary release. Those replacements retire wall ownership and planted contacts; their existing permission, cooldown, budget and strike-identity rules remain intact. A committed weapon-active phase cannot yield to wall entry; windup/recovery can when their other gates permit it. Kick permits only forced replacement until its short commitment ends; new ordinary presses can remain buffered under the existing expiration rules.

A fresh toward+Jump at a currently valid eligible contact can establish wall authority and kick **before** ordinary air-jump consumption, even after release grace has expired. If the regrab cooldown is the only blocker and will expire strictly before the existing jump buffer, that same intent waits in the ordinary buffer. It grants no contact, cancels no weapon, and spends no air jump while waiting. Every live tick rechecks the complete entry permissions, real contact, pending carrier pose and collision safety. Losing eligibility permits the still-buffered ordinary jump under its usual gates; expiry consumes nothing. Hitpause freezes both existing clocks, and a released queued tap keeps its variable-jump release cut, including across a temporary host jump lock. Its release history belongs to that press until consumption, expiry, explicit buffer clearing or a newer fresh Jump replaces it. There is no additional grace window or timer.

If a wall kick is genuinely unavailable, an accepted ordinary air jump retains its upward motion against the already-nearby wall face. Automatic wall entry on that side waits until the jump reaches its apex, actually separates from that face, lands or accepts a replacement action. This geometric guard crosses collider seams and does not block approaching a different wall after separation. A new, separately pressed supported Jump may deliberately request a kick. Every accepted jump also suppresses automatic entry for its launch tick. Ground/coyote jumps retain their established priority and no resource is consumed twice.

Attached Down+Jump is classified once as dive. A disabled/denied dive consumes that chord with its existing denial event and preserves contact for that tick, without a jump fallback. Continued Down on the following tick is an ordinary release. Neutral, away or Down releases run/slide into normal gravity. New movement/input/ability denial also releases supported wall motion; it does not suspend the ascent clock into an unlimited hang. If a kick has already launched, a new ability/input/movement denial does not extend it or cancel collision: its finite committed sweep completes normally. Forced damage/reset remains immediate.

### Recent support and rearm are separate policies

Neutral and explicit-away voluntary release grant a separate, single-use 0.06 s wall-kick grace. This covers a real direction key-up/away edge arriving just before Space. Down, exhausted slide, invalid support, control/ability loss, damage and other accepted actions grant none. The old wall must remain a valid nearby rectangle with a clear ray to its face; its pending pose must remain valid too. Host jump locks and body/drop clearance still gate the launch. The grace clock freezes during actor hitpause, but invalid support revokes authority even while paused. It is separate from ladder grip-jump grace and clears on accepted replacements/reset. Tool-imposed longer input gaps do not enlarge this gameplay window.

Contact identity, the episode serial, run elapsed/rise, slide elapsed and signed relative travel are tracked independently from the action name. Default `wall_rearm_policy=0` permits a new finite run after **genuine separation and recontact**, with a 0.16 s regrab delay. Separation means no solid side-facing contact within 6 px beyond the actor side. The test observes geometry rather than only collider identity. Held contact and the active carrier's pre-transport displacement cannot count as separation.

Same-contact reentry after a cancellation may resume its remaining run/slide allowance, but does not restart it. If the slide allowance has ended, that unseparated episode cannot attach again. Policy `1` instead rearms only after real floor contact or reset. All physical landing paths reset the wall allowance immediately, including buffered landing→jump and completed ledge stepping. Neither policy refills ordinary air jumps, air roll or dive merely through wall contact, detachment, a ladder grip or a ledge hang.

The delay begins at supported detachment or actual kick launch. Finishing kick commitment does not start a second delay. A fresh physical contact can occur on the same body; there is no permanent once-per-wall lock. The default deliberately allows repeated same-wall traversal after real separation, and is labeled authored rather than inferred from a missing source consumer.

### Seams, ledges, moving supports and lifetime

Separate dedicated rectangles with contiguous coplanar faces may form one continuous wall contact. Probes can span their seam, and the active carrier can transfer as the actor actually crosses it. This preserves episode/rise/time and emits `wall_support_changed`; it does not count as rearm. Transport excludes only the single currently validated rectangle, so adjacent bodies and every unrelated floor/wall remain collidable.

A covered top on a lower rectangle is not a ledge. An additional continuation-plane probe rejects that false corner for both wall and ordinary approach, preventing release from falling through into an impossible hanging state. Real wall→ledge handoff uses the existing top/side probes, rising-speed limit, full-body clearance and swept catch/pull/step path. Higher-priority actions resolve first. Handoff retires wall contact immediately while preserving episode bookkeeping; only actual top floor contact replenishes ordinary airborne budgets.

Wall transport uses committed body geometry first and then safely sweeps its pending translation. Translation is limited to 420 px/s plus 1 px per-step tolerance. Shape/layer/metadata changes, removal, excessive displacement, blocked transport and loss of real contact release without snapping. Inherited upward-one-way restriction also gates upward carrier movement. Validity and safe transport continue through hitpause; phase/budget/regrab/grace clocks freeze. A real floor stops wall motion and uses normal landing logic.

Accepted damage retires wall ownership immediately. During its local hurt pause, the former validated single-rectangle carrier may still transport the frozen actor safely, using the existing transport-only hurt boundary. That reference does not grant a wall pose, jump, refill or changed recoil velocity; it is dropped when recoil simulation resumes. Changed/removed carriers invalidate it. Physically impossible continuing crush geometry remains a host/scene boundary, not permission to teleport or disable another body.

### Wall API, telemetry and authored tuning

All numerical defaults are in the movement profile's wall traversal group: `wall_toward_threshold`, `wall_probe_reach`, `wall_separation_distance`, `wall_run_speed`, `wall_run_acceleration`, `wall_run_max_rise`, `wall_run_max_seconds`, `wall_slide_speed`, `wall_slide_acceleration`, `wall_slide_max_seconds`, `wall_contact_push_speed`, `wall_kick_horizontal_speed`, `wall_kick_vertical_speed`, `wall_kick_commit_seconds`, `wall_kick_grace_seconds`, `wall_regrab_delay`, `wall_max_transport_speed`, and `wall_rearm_policy`. They are original tuning, never recovered constants.

Snapshot fields are `allow_wall_run`, `wall_active`, `wall_phase`, `wall_phase_progress`, `wall_side`, `wall_normal`, `wall_plane_x`, `wall_contact_point`, `wall_contact_id`, `wall_top_y`, `wall_bottom_y`, `wall_relative_travel`, `wall_run_rise`, `wall_run_elapsed`, `wall_run_progress`, `wall_exhausted`, `wall_slide_elapsed`, `wall_support_transport`, `wall_kick_direction`, `wall_kick_progress`, `wall_regrab_remaining`, `wall_rearm_ready`, `wall_episode_serial`, and `wall_kick_grace`. `wall_jump_waiting` reports a live jump buffer that has been reserved for a supported-jump wait; `wall_air_jump_guard_sides` is a side bitmask (1 right, 2 left) protecting an already accepted ordinary air-jump ascent. Neither field grants new support authority.

`wall_active` means supported run/slide only, so it is false during kick/grace. Side is +1 for a wall to the right; outward normal/kick direction points away. Relative travel is signed downward displacement excluding carrier transport; run rise separately accumulates upward movement. Contact bounds merge the contiguous faces currently probed. Run progress is the larger consumed time/rise ratio; slide/kick progress use their finite phase durations. Existing `wall_normal` remains ordinary collision telemetry when no supported wall action owns it.

Events use the existing enriched movement signal: `wall_attached` (contact ID, side, episode, resumed), `wall_phase_changed` (phase, episode), `wall_detached` (reason, prior phase/contact, episode), `wall_kick` (outward direction, episode), `wall_ledge_handoff`, and `wall_support_changed` (previous/current contact IDs, episode). Typical detach reasons are `neutral_release`, `away_release`, `down_release`, `control_disabled`, `ability_disabled`, `support_invalid`, `support_moved_away`, `transport_blocked`, `contact_lost`, `slide_finished`, `jump`, `kick_finished`, accepted replacement action, `landed`, `ledge_handoff`, `forced` or `reset`.

Poses `wall_run`, `wall_slide` and `wall_kick` are authored presentation. The rig reads plane, normal, relative travel, support transport and authoritative facing; no hand/foot solve changes root, collision, contact eligibility or clocks. No new damage area or noise contract is inferred from this traversal action.

### Current wall verification

The corrected implementation parses under Godot 4.6.3. Independent actual-physics acceptance passes at both 120 Hz and 60 Hz:

- **146 connected wall scenarios / 478 assertions per rate**, zero failures
- Prior movement **36/98**, combat **49/135**, drop/dive **64/222**, and climb **85/215** scenarios/assertions per rate all pass on the same candidate
- All **28 paired rate bounds** pass; all ten engine logs are clean
- Controller SHA-256: `1484ba48cd23fe0bc0742472e2fd8f5674830919e1767036b08bd775c7b437b9`
- Movement/combat tuning is byte-identical to the provisional `e772` checkpoint, including regrab and grace values
- All 39 earlier accepted result/report/harness artifacts and four milestone archives retain their recorded hashes. The packaging-only `TRACE_ARCHIVE.md` change is explicitly recorded with both hashes and its original text; 26 provisional M5 evidence files are also preserved unchanged

The previous `e77231758417e33e609d2b70882aae80cf18a8d72c0988a29b8ca8a9d4496ed7` checkpoint passed the original paired physical suite, but subsequent native review found a regrab-boundary failure: a Jump just before cooldown expiry became an air jump, then automatic contact replaced it on the following tick. That checkpoint remains provisional evidence. The corrected candidate reserves the existing jump buffer across that boundary and protects genuinely accepted ordinary air-jump ascent. A subsequent independent probe also verified that a temporary host jump lock cannot discard a queued tap's release cut.

See [wall_verification.md](wall_verification.md) and [wall_verification.json](wall_verification.json) for exact hashes, full traces, reproduction commands and six retained pre-fix defect records. Revised coverage includes mirrored parsed Jump presses before/at/after the regrab boundary, taps through hitpause and temporary permission locks, support invalidation, buffer lifetime and ordinary ascent through multiple later ticks. The connected action, collision, carrier, permission, budget and prior-milestone coverage remains green. No collision tolerance, profile value or fixture input was changed to hide either boundary failure.

Native review on the queue-fixed candidate independently observed a real supported wall kick, higher opposite landing and the return through ledge catch/pull/step and dive without an air-jump event at the formerly failing boundary. Final-hash native capture and isolated reusable-host boot are separately reported by the integration owner. Presentation is an original telemetry-driven wireframe. Verification covers the documented MOKSHA policy within its conservative geometry limits; no recovered v35 timing, historical item exploit, hazard system or unimplemented action is claimed.


## Optional high-fall recovery (M6)

### Evidence and scope

The pinned [Hero landing declarations](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/en/Hero.hx#L512-L536), Entity fall-history and DiveAttack consumers are empty. No threshold, fall-history reset, duration, pose or input-lock algorithm was recovered. [Official update 14.6](https://deadcells.com/patchnotes/14) supports the narrower historical behavior that rolling before contact during an active stomp avoids high-fall stun only while that roll lasts. It does not establish ordinary air-roll immunity or an immunity flag after roll completion. The complete source boundary is [HARD_LANDING_CONTRACT.md](reference/HARD_LANDING_CONTRACT.md); every value and decision below is original MOKSHA policy. Existing roll cancel windows are unchanged, and this pass adds no health, damage area, fatal fall, respawn or progression behavior.

`enable_hard_landing` is an exported actor rule, default **false**. Hosts explicitly opt in. It is evaluated at a new physical landing; changing it does not cancel a committed recovery already in progress. Initial placement/reset directly on a floor initializes resources without fabricating an impact.

### Excursion and physical contact

Fall history is independent of air-jump, roll and dive resources. A free excursion tracks its highest reached root position and the downward distance from that apex. An accepted normal, air, grip or wall-kick jump starts a new excursion, including its later ascent/apex. Genuine floor contact, ladder/vine grip, ledge grip and supported wall run/slide break the old history. A subsequent release starts from the actual release position, excluding the last supported movement. Wall-kick completion does not break its jump history. Roll, dive startup/descent, weapon phases and incoming hurt do not erase an existing excursion.

Established carrier transport translates the recorded apex without adding fall distance. This applies during normal movement and local hitpause. `reset_actor` clears history; arbitrary external position assignment is outside the reset contract. No timer estimates height. The final collision sweep and floor-margin correction are included before touchdown classification.

One landing dispatcher covers the initial floor probe, ordinary movement sweep, detached-climb sweep, direct climb exits and completed ledge stepping. It classifies contact before resetting history and before accepting buffered next actions. A continuous floor contact refills air-jump, air-roll, dive and wall allowance once; it does not repeatedly refill them merely because several grounded ticks pass. The ordinary coyote clock still refreshes while physically grounded.

The optional hard outcome requires both:

- `hard_land_min_distance = 220.0` pixels of current free-fall distance
- `hard_land_min_relative_speed = 400.0` pixels/second downward relative impact speed

The second value is `max(0, actor_preimpact_velocity.y - floor_surface_velocity.y)`, rather than total speed or projection along a slope normal. Moving AnimatableBody2D contact uses a nonzero pending Node versus committed PhysicsServer translation when present; otherwise it retains the collision solver’s reported surface velocity. Hurt-pause fall exclusion records the actual swept carrier displacement, including a partial move before obstruction. These thresholds use the established tiny arithmetic-boundary tolerance, never a whole-frame threshold expansion. Routine jumps, small steps and low drops remain soft.

A qualifying impact replaces the prior main recovery/weapon owner with `hard_land`, including an existing hurt owner. A later incoming hit can replace it immediately with hurt. It does not grant damage invulnerability. The actor emits one enriched `landed` event and refills resources once regardless of whether the outcome is soft, hard or roll-protected. Landing arbitration happens before a live melee strike sample, so a canceled weapon identity cannot hit after the impact.

### One recovery owner

The managed main action `hard_land` has `hard_land_kind` of `ordinary` or `dive` and two finite phases:

| Phase | Authored duration | Movement and actions | Turning |
| --- | --- | --- | --- |
| `impact` | `hard_land_impact_seconds = 0.06` s | Swept floor-following skid; move/jump/roll/attack and traversal starts locked | Locked |
| `recovery` | `hard_land_recovery_seconds = 0.12` s | Same finite skid and action commitment | Permitted only if the host permits turning |

One elapsed clock carries impact overshoot into recovery. The first free tick is the first simulation tick reaching the combined duration; no additional clip or per-phase rounding extends the lock. Local hitpause freezes that clock while still validating/translating the supporting contact. New-contact rule disabling leaves this short commitment intact.

Both phases use the existing small 16×20 body. At hard-impact handoff, the incoming horizontal component is preserved after retiring the previous owner, except where a real wall collision has already blocked it. Downward impact projection from the inherited slope solver cannot create an extra horizontal hard skid. The shared floor-contact policy below now applies the same horizontal-momentum principle to soft contacts as well; the hard outcome retains its explicit captured incoming component and recovery ownership. Horizontal velocity brakes toward zero at exported `hard_land_braking = 2800.0` px/s², with the requested displacement following the currently confirmed floor tangent through ordinary collision. This keeps a fast downhill skid on the real slope instead of outrunning the short floor probe; ledges, walls and ceilings still block or release it. No root motion, teleport, floor bypass or hovering is introduced. Standing expansion after release still requires the normal clearance test. Ground loss, incoming hurt, forced host completion/replacement and reset end hard recovery safely. A newer hurt/forced owner applied synchronously from a retirement, action-change, collider or hard-phase signal also wins; unfinished hard-only setup and later stale phase events stop. Already-delivered events remain valid observations of the transition. Ground loss also begins a fresh excursion from the last supported position. A removed/changed support cannot keep a planted pose merely because the timer remains.

A real high dive still emits its existing `dive_impact` once with the same dive identity and actual collision data, but hands recovery to `hard_land` with kind `dive`; it does not also run the old dive impact/recovery driver. Its semantic dive completion uses reason `hard_landing`. Low dives retain the prior M3 impact/recovery. Startup contact or an expired dive is an ordinary landing and cannot fabricate a descent impact.

One dominant landing noise is emitted: `hard_land` at authored `hard_land_loudness = 1.4`, existing `dive_impact` for a low real dive, or existing `land` for a soft ordinary contact. Locked hard skids emit no footstep, and a contact tick cannot also emit a travel footstep.

### Queue and roll-protection lifetime

Fresh input edges are captured normally while committed. Existing jump, roll, attack and contextual down-action buffer clocks pause for the bounded hard recovery, then resume their usual finite lifetimes. A tapped Jump retains its release history until consumption, expiration, explicit buffer clear or a newer fresh Jump replaces it, including across local hitpause and a temporary host denial. The first eligible free tick applies existing roll → down-action → jump → melee priority. Holding a consumed button does not repeat. `allow_input=false` still clears/masks requests while retaining physical held-edge history.

Only a roll actually accepted from **live dive descent before contact** receives `roll_fall_protected`. This descent-only choice is an authored narrow interpretation of the historical still-active stomp condition. The token records that roll's monotonically increasing `roll_serial`; it is independent of damage i-frames, fall height and every air-action budget. Roll completion, cancellation, hurt, another main owner or reset removes it. Roll clocks expire before that tick's sweep/landing dispatch, so contact at or after the roll-lifetime endpoint is not protected.

Ordinary air roll, dive startup, an already-expired dive, post-impact roll and an earlier canceled roll do not grant this token. It suppresses hard recovery only while that exact roll lives; physical landing dispatch and resource refill still occur. A genuinely accepted air jump independently begins a new fall excursion and must not be misreported as leaked roll protection.

### Host, telemetry and events

All six numerical fields are in the movement Resource's optional high-fall group. The actor exposes `enable_hard_landing`, `is_roll_fall_protected()` and existing main-action/weapon permissions. `hard_land` is reserved as a managed action; ordinary custom starts cannot bypass its commitment. `finish_main_action()` ends it as forced completion, while `begin_main_action(&"forced", ...)` uses the existing explicit forced-owner contract.

Read-only snapshot fields are `fall_history_active`, `fall_distance`, `fall_apex_y`; `hard_land_active`, `hard_land_kind`, `hard_land_phase`, `hard_land_phase_progress`, `hard_land_progress`, `hard_land_fall_distance`, `hard_land_relative_impact_speed`, `hard_land_entry_horizontal_speed`, `hard_land_skidding`; `floor_normal`, `floor_contact_point`, `floor_relative_velocity`; `roll_serial` and `roll_fall_protected`. Existing grounded, support ID/displacement, action permissions, velocity and facing remain authoritative. `floor_contact_point` is world-space and follows current carrier translation, including during pause. Nonzero floor-relative motion is labeled skidding; presentation must not label those contacts planted. Historical hard-impact fields do not select a pose outside the current owner.

Events use the existing enriched `movement_event` signal:

- `hard_land_started`: kind, fall distance, relative impact speed, surface ID
- `hard_land_phase_changed`: phase and kind
- `hard_land_finished` or `hard_land_cancelled`: reason, kind and prior phase
- `landed`: existing preimpact speed plus relative impact speed, fall distance, ordinary/dive kind, hard/protected classification and the captured surface ID, normal and world contact position. The hard flag records physical qualification before synchronous callbacks; `main_action` / `hard_land_active` describe the current owner if a later hurt/forced reaction supersedes it.
- Existing `dive_impact`, with no duplicate impact or recovery owner

The view selects `hard_land_impact` / `hard_land_recovery` directly from owner/phase progress and kind. It does not advance an independent recovery clock, move the root, infer floor contact from pose time or change permissions.

### M6 verification

The motor parses in Godot 4.6.3. Independent actual-physics acceptance passes at both 120 Hz and 60 Hz on controller SHA-256 `55dd19f58275d91d86122dd44e602927618f168c380611ad1f07d0e527465b41`:

- **100 hard-landing scenarios / 349 assertions per rate**, zero failures
- Movement **36/98**, combat **49/135**, drop/dive **64/222**, climb **85/215** and wall **146/478** compatibility scenarios/assertions per rate all pass on the same candidate
- All **55 paired bounds** pass, including the unchanged 28 earlier bounds; all twelve engine logs are clean
- All 99 earlier evidence artifacts and five milestone snapshots retain their recorded hashes. The trace-archive instruction change is separately documented with its original text and before/after hashes

[hard_landing_verification.md](hard_landing_verification.md) and [hard_landing_verification.json](hard_landing_verification.json) pin the source/resources, harnesses, exact physics traces, corrections and reproduction commands. Coverage includes dual threshold boundaries, moving-floor relative velocity, incoming horizontal momentum and slope contact, single impact/noise/resource dispatch, exact roll-protection lifetime, ordinary/air/grip history resets, carrier exclusion, queued taps/represses, body clearance, support loss, forced/damage/reset paths and synchronous callbacks during dive handoff and hard setup/phase changes. Correction evidence distinguishes independently reproduced physical failures, direct kernel reproductions and static-review refinements verified afterward.

Hard recovery preserves the same controlled incoming horizontal momentum at both tested rates. At this M6 checkpoint, the inherited final collision travel and ordinary soft-land solver were unchanged; the result does not claim frame-identical arbitrary pre-impact trajectories. The subsequent M7 section records the focused repair of that shared floor response. Native presentation/feel, final packaged-project boot and controlled test-drop captures are separate integration checks. No recovered Dead Cells timing, health/respawn behavior or broader collision-world guarantee is inferred from this acceptance.


## Ordinary slope contact and ground following (M7)

### Measured problem and policy

The focused before/after review identified an inherited Godot-adapter discontinuity: a sweep landing projected vertical fall speed into horizontal motion, while a probe landing preserved horizontal speed. A nominally identical ordinary drop could therefore stop within a few pixels at one rate and continue downhill for hundreds of pixels at the other. Repeatedly flattening then projecting uphill velocity also reduced sustained speed once per tick; a fixed 2 px post-movement probe could miss a 45° downhill at 60 Hz. This is an original MOKSHA implementation correction, with no claim of recovered Dead Cells slope constants or code.

The common collision policy now preserves **the current collision's incoming horizontal velocity and horizontal remainder** at a walkable floor. It does not restore an earlier pre-tick value after a real side collision has removed that component. Vertical landing velocity and unused vertical fall displacement cannot manufacture X motion. This policy applies to ordinary locomotion and the shared roll/hurt/dive/hard-contact solver; each owner's existing impact, cancellation, input, resource and noise behavior remains authoritative. A dive can still deliberately stop at impact, and M6 hard recovery still preserves its explicitly captured incoming horizontal component.

Ground speed remains horizontal world-space speed: held run targets X=±218 px/s on a supported slope, with the existing acceleration, reversal and braking. Neutral input brakes that actual horizontal momentum toward zero and supplies no downhill energy. The standing `velocity.y=0` representation is retained between supported callbacks. Sweeps derive their Y displacement from the confirmed floor tangent; a genuine departure carries the swept tangent velocity into ordinary air motion. Fresh accepted jumps and explicit upward owner motion leave support rather than being pulled back by following. If a synchronous collision callback replaces the owner, old floor evidence is retired too, so the outer probe cannot reclaim a new upward hurt/jump as grounded.

### Bounded support-following sweeps

Following begins only after revalidating actual floor contact **after** action arbitration and collider/world changes. It follows the owner's horizontal displacement, including neutral brake drift, rather than requiring a held direction. Established carrier translation is handled separately and does not enlarge the follow request.

Supported movement uses short continuous sweep segments. Their horizontal size is bounded by the existing `collision_path_step`, `floor_probe` and maximum permitted floor angle, accounting for the worst uphill-to-downhill crest. After each segment, the actor must reacquire a real walkable surface using the unchanged **2 px floor probe**. There is no new 8 px snap parameter and no unchecked root assignment. Continuous flat/slope joins, crests and valleys can remain supported; an abrupt missing or too-distant surface retires following and sends the remaining travel through ordinary continuous airborne collision.

One `_sweep_motion` callback has a fixed **32-segment work allowance**. Failed sweep/probe revalidation also consumes that allowance, preventing recursive near-contact disagreement from creating an unbounded loop. If unusually large externally authored speed/delta uses the allowance, the remaining displacement is still a continuous collision sweep, with no further support subdivision for that callback. This computational bound is an authored Godot implementation policy, not a recovered movement parameter or permission to ignore walls. Ordinary run/roll at the tested 60/120 Hz rates stays well within it.

The standard five-collision iteration bound remains inside each sweep. A constrained floor/ceiling corner retains the last safe root and retires unresolved horizontal motion. Upward one-way denial is checked on each actual upward sweep segment; selecting a new floor tangent cannot bypass it. World/body collision remains enabled throughout.

### Contact observation and numerical skin

The collision margin remains **0.02 px**. No collision-oracle tolerance was widened. Actual motion collisions are observed without treating recovery-only separation normals as new side-wall hits. Godot still performs its normal collision recovery; this only prevents an imprecise recovery normal from rewriting the movement velocity.

An already-confirmed walkable floor contact may refine its normal/point with a short vertical ray on the **same body and within twice the existing collision skin** of the reported contact. A second ray under the body’s actual supporting corner must confirm the same geometric facet normal. A shared crest vertex alone therefore cannot select a downhill facet while the trailing footprint still rests on the flat/other face. It cannot select an unrelated or distant floor. This supplies the real surface plane rather than repeatedly integrating noisy kinematic recovery normals. If the upright body's support-plane gap is already within the existing skin, the floor probe records support without pushing the touching body down again. Real separation or penetration still receives the ordinary safe vertical sweep. The actor never restores X by teleport or excludes a floor body for this correction.

These choices remove repeated skin recovery from commanded ground travel while keeping geometric support and collision checks. Subpixel floating-point contact error is reported explicitly by the independent geometric oracle; this is not a universal strict-zero-overlap or frame-identical trajectory claim.

### Public contract and verification checkpoint

`_sweep_motion(motion)` and `_refresh_ground()` retain their prior signatures. No gameplay profile value changed and no new action, ability, state, timer or input binding was added. Existing `grounded`, `floor_normal`, `floor_contact_point` and support identity remain geometric observations. `floor_relative_velocity` now reports the full supported tangent vector for ordinary motion too, while public grounded `velocity.y` remains zero. The view must not mistake geometric uphill travel for an airborne jump.

New read-only diagnostics are `ground_follow_segments` and `ground_follow_limited`, describing the current callback's spatial work and whether bounded residual fallback was required. They do not grant support or alter presentation ownership.

The implementation parses in Godot 4.6.3. Independent actual-physics acceptance passes at both 120 Hz and 60 Hz on controller SHA-256 `4aa4132650037e5c975de27547ef06c6dd1e95a3c7384d9744524de048a8760a`:

- **146 slope scenarios / 893 assertions per rate**, zero failures
- Movement **36/98**, combat **49/135**, drop/dive **64/222**, climb **85/215**, wall **146/478** and hard landing **100/349** compatibility scenarios/assertions per rate all pass on that same candidate
- All **743 cross-rate bounds**, **40 within-rate approach-phase bounds** and **16 complete stock/observer comparisons** pass; all fourteen engine logs are clean
- All **135 historical evidence files and six milestone snapshots** retain their recorded hashes. New results use separate M7 filenames

[soft_slope_verification.md](soft_slope_verification.md) and [soft_slope_verification.json](soft_slope_verification.json) pin the exact sources, profiles, traces, logs, correction evidence and reproduction commands. The new harness records an immediate before/after observation around one production call in every actual engine physics callback, with consecutive engine-frame IDs and supplied deltas. Earlier compatibility formats remain preserved as originally recorded, without claiming they captured additional fields or start hashes.

Coverage includes mirrored 26.565°/45° plane approaches, zero-X and moving neutral stops, steady uphill/downhill speed and actual travel, nearby approach heights, continuous hills/valleys/separate-body joins, the real native course at local and world origins, genuine gaps, jumps, walls, ceilings, one-way drop, moving-support pause, oversized-motion fallback, owner replacement and all shared actions. Exact full-shape/plane observations bound contact error within the authored skin; this is not a universal strict-zero-overlap claim. Pre-fix traces separately retain the original floor-projection defect, the recovery/contact residual, the crest-facet regression and the supported ceiling-callback failure.

Plane comparisons begin at each run's actual contact rather than assuming identical arbitrary pre-impact paths. Legitimate collision positions may change under the repaired shared floor response; existing action/history/queue/collision contracts remain covered by the compatibility suites. Native presentation/feel and final isolated packaged-project boot are separate integration checks. No new mechanic, profile tuning, recovered Dead Cells algorithm or broader arbitrary-world guarantee is inferred from this acceptance.

## M8 shield and structured incoming contact

The shield is an original MOKSHA weapon owner layered over the same shared motor. Read `reference/SHIELD_PARRY_EVIDENCE.md` (the full research copy is `../reference_sources/dead-cells-audit/SHIELD_PARRY_EVIDENCE.md`). The pinned source supplies a `canBeHeld` outer cancellation gate and a separate outgoing counter whose success callback depends on the outgoing result. The hold/parry lifecycle, front/back tests, timings, final cancellation rules and damage math are missing. Historical developer notes distinguish partial held guard from full parry, reflection, miss locks and shield/dodge lock fixes. None recovers the implementation below.

`MokshaShieldProfile`, `resources/shield_profile.gd/.tres`, is exported as `shield_profile`. Every field is authored tuning. The independent `parry_window_from/until` and `counter_damage` values support the later MOKSHA agility/strength tradeoff without implementing lenses or progression. The default absorption of 0.75 is a MOKSHA choice informed by a historical approximately-75% developer statement, not a recovered v35 constant. There is no health, stamina, shield energy, global parry invulnerability, grenade/fuse simulation or NPC in this pass.

### Input, exclusive ownership and cancellation

`cp_shield` receives K / gamepad left shoulder only if its bindings are empty. Injection adds `shield`, `shield_pressed`, `shield_released` with the same physical-held tracking as other buttons. `allow_shield=true`, main capability `can_shield=true`, and external weapon permission `can_shield=true` are independent gates. Revoking one withdraws active defense safely; incoming contact checks those gates immediately, including during local hitpause. The independent use lock remains. Input disable masks and clears queued intent; an existing finite attempt still progresses, and a hold releases when its action simulation resumes.

One fresh accepted press starts one monotonically increasing `shield_serial`. A tap retains its finite attempt; release never creates a new parry. The accepted press has its own held latch: releasing it permanently prevents that attempt from entering hold, even if a newer press is queued. Holding alone cannot renew a window. A fresh denied press remains only in its finite 0.12 s buffer. Ordinary buffer expiration continues through shield phases; existing local hitpause and committed hard landing retain their established queue behavior.

The shield has separate `shield_phase` fields while existing `weapon_phase` remains the melee vocabulary. A shared monotonically increasing weapon generation makes them exclusive and invalidates old callbacks. Main-action generation remains independent. Simultaneous admission is **roll → contextual down action → jump → shield → melee → deliberate climb/wall attachment**.

| Shield phase | Authored default | Movement / facing | Ordinary replacement |
|---|---|---|---|
| `raise` | Elapsed <0.025 s | Ground move ×0.45, air move ×0.65; host-approved turning | Committed; vulnerable |
| `parry` | Half-open [0.025,0.16) s | Same; responsive host-approved turning | Committed; one eligible full parry closes the attempt |
| `hold` | First closed sample if the accepted press stayed held and profile is holdable | Same movement; responsive turning | Jump/roll/melee/drop/dive/climb/wall after elapsed ≥0.16 s and all other gates |
| `miss_recovery` | 0.14 s after an unheld or nonholdable attempt expires | Same movement/turn intersection | Committed |
| `success_recovery` | 0.08 s after one successful incoming parry | Same movement/turn intersection | Committed; no remaining parry window |
| `release_recovery` | 0.08 s after held guard releases | Same movement/turn intersection | Committed |

The four `allow_turn_raise/parry/hold/recovery` fields default true. Movement and replacement commitment never implicitly lock facing. A resolved contact snapshots its facing, origin and normal, so a later turn cannot redirect the already accepted effect. `can_be_held=false` prevents ordinary weapon cancellation through every shield phase; its attempt still finishes automatically. This outer gate reflects a recovered concept, while the permitted hold cancellation matrix is authored.

Every accepted shield use incurs an independent 0.22 s `use_lock_seconds` clock that prevents new shield or melee starts. It survives ordinary cancellation into roll, jump, traversal and forced host replacement; it is not erased by `_cancel_attack`. A successful parry retains the already-incurred remainder, and a miss does not reset it. Hurt/reset deliberately clear it as an authored lifecycle policy. A hold may roll after commitment while this lock is still nonzero; the lock continues preventing shield/melee rearm during that roll. Existing roll cancel thresholds are unchanged. The clock freezes with actor-local hitpause and advances during other action simulation. An explicit reset is a stronger lifecycle boundary: it retains a complete neutral input snapshot and changes a reset epoch, so an admitted old tick stops at the next phase/arbitration/contact callback boundary instead of continuing against reset state. This does not alter the existing mid-tick hitpause policy.

Melee windup/recovery may yield to shield, while active melee refuses. Shield may enter a late roll using the existing attack-cancel threshold, or replace dive startup/recovery. It refuses ledge traversal, dive descent/impact, hard landing and hurt. Accepted shield from climb/wall detaches through their normal release contracts and retires their contacts; it neither supplies a grip nor refills a budget. Automatic ledge catch is refused while shield owns the weapon. A cancellable held shield can yield to a validated climb/wall entry. A natural soft landing completes the jump/air-jump movement owner while preserving a live shield or melee weapon. Hard landing still retires the weapon, and explicit host `finish_main_action()` remains forced cancellation. Ground/air movement, gravity, crouch clearance, fall history, one-way cleanup and actual landing dispatch remain the shared motor's responsibility.

### Descriptor and compatibility API

`receive_hit(payload={}) -> bool` remains available and returns true only when the normal hurt response was actually applied. Legacy descriptors without `attack_id` retain their existing roll/hurt behavior and do not gain shield eligibility.

`receive_attack(payload) -> Dictionary` accepts the old `amount`, `impulse`, `stun_seconds`, `hitpause`, `rollable` and `source_position` keys, plus:

| Key | Contract |
|---|---|
| `attack_id` | Positive integer identity issued by this authenticator; issuance may be monotonic but arrival need not be |
| `kind` | `melee`, `projectile`, or `area` |
| `source` | Original source Node, live for melee/area; nullable or freed for a live projectile |
| `carrier` | Live Node authenticating a projectile independently of its remote source |
| `origin` | Actual incoming world origin, not automatically the source's position |
| `contact_position` | Actual world contact on the current actor body |
| `incoming_velocity` | World approach vector; zero melee/area may use origin→contact, zero projectile cannot defend |
| `blockable`, `parryable`, `reflectable`, `counterable` | Independent booleans, all default false |

The exact key is authenticator instance ID + kind + attack ID. The authored per-authenticator/per-kind recent-ID range defaults to 256 (`incoming_history_window`). Within [highest accepted ID-255, highest accepted ID], exact consumed IDs are deduplicated and nearby out-of-order arrivals remain eligible. Older IDs return `rejected` with `reason=stale_attack_id`, unconsumed and silent; pruning never makes an old contact eligible again. Only an accepted physical contact advances the range. New projectiles have their own live-carrier bucket, so a newer shot from the same remote owner does not invalidate an older slow shot. Records persist across shield attempts, roll and hurt; freed authenticator buckets are safely removed. Reset clears incoming history but never reuses a shield serial. Identified discrete evasion consumes one attack identity. A persistent hazard must issue a fresh identity for each intended hit interval. Legacy Pulse keeps its old retry behavior.

Malformed identified descriptors, dead required authenticators, contacts outside the body (existing collision margin ×2 only), and terrain-occluded origin→contact paths return `rejected`, unconsumed and silent. The attack ray never borrows the actor's temporary one-way exception. Behind/above/equal-X attacks that physically reach the body remain valid hits but cannot gain defense.

The authored shield band is centered at root +(facing×(body_width/2+3), -body_height×0.55), with width 10 and height max(8,body_height-4), adapting to the actual small body. Defense requires the contact inside this band, a nonzero origin offset with forward separation >0.0001 px, origin direction within 60° of the outward normal, and normalized incoming direction dot normal ≤-0.25. These are MOKSHA geometry choices. Block and parry eligibility remain separate: only the parry phase can fully parry; only held guard absorbs. A frontal nonparryable hit during the parry interval is not silently converted to guard.

Result keys are `outcome` (`hurt`, `evaded`, `guarded`, `parried`, `duplicate`, `rejected`), `consumed`, `residual_damage`, `attack_key`, `shield_serial`, `shield_facing`, `defender_origin`, `incoming_origin`, `contact_position`, `counter_confirmed`, `reflection_confirmed`, and `hurt_applied`. Guard/parry also carry frozen outward `normal`. Duplicate returns consumed=false and produces no response. A new valid identified contact is marked consumed before any callback. Guard residual is amount×(1-absorption), reported for a future host health policy; it does not also run full hurt or add health here. Guard keeps ownership and requests 65 px/s horizontal recoil through the regular swept motor. Parry suppresses incoming damage and closes its attempt before callbacks. No air-action resource or fall excursion is refreshed.

### Physical counter/reflection boundary

`signal shield_effect_requested(actor: Node2D, request: Dictionary)` is synchronous. The contact adapter supplies actual range/occlusion/contact and target receiver checks. The controller never claims physical retaliation merely because defense succeeded.

Request keys: `shield_serial`, `attack_key` (String), `effect` (`counter` / `reflect`), `source/source_id`, `carrier/carrier_id`, `target_id`, `defender_origin`, `incoming_origin`, `contact_position`, `facing`, `normal`, `damage`, `impulse`, `reflect_direction`, `reflect_speed`, `max_range`. `origin` is a compatibility alias of the frozen defender origin. A counter is requested only for explicitly counterable melee and targets the live original source. A reflection is requested only for explicitly reflectable projectiles and targets the live carrier. A distant projectile owner is never magically struck.

Default counter damage 3, impulse (facing×280,-90), range 52 and reflection speed 420 are independent original values. The adapter must call `shield_effect_is_current(serial, attack_key, effect)` immediately before its physical target operation, then `confirm_shield_effect(serial, attack_key, effect, target_id, accepted, details={}) -> bool`. The request scope closes as the signal returns. Failed target results have no success event; delayed, duplicate, wrong-target, removed-target, reset or replaced-owner confirmations fail. Main and weapon generations are checked separately. A successful physical result sets only its corresponding `counter_confirmed` or `reflection_confirmed` field; incoming parry success remains independent if the effect fails.

Contact position, defender origin, facing and normal are frozen before synchronous callbacks. Reentrant damage, reset, forced owner changes or gate withdrawal stop later shield setup/effects. The ordinary hurt path also checks both generations after retirement, action admission and feedback callbacks, preserving a newer host phase/recoil instead of continuing stale hurt setup; an already delivered incoming-defense result remains that contact's resolved result. An effect's own physical operation may already have occurred before its callback replaces ownership; the controller suppresses stale later confirmation rather than attempting to undo external physics.

### Feedback and telemetry

`movement_event` adds `shield_started`, `shield_phase_changed`, `shield_finished/shield_cancelled`, `defense_resolved`, `shield_counter_confirmed`, `shield_reflection_confirmed`. Incoming resolution precedes a separately confirmed counter/reflection. `defense_resolved` includes the result keys above; confirmed effects include their frozen request geometry and adapter details. Each newly guarded/parried identity emits one guard/parry noise with default loudness 0.85/1.25. Occluded/rejected/duplicate contacts are silent. Only the first guarded/parried contact in an attempt may spend its feedback pause budget (0.025/0.045 s); subsequent distinct guard contacts cannot indefinitely renew the same window through hitpause. Existing mid-tick pause and swept carrier rules remain unchanged.

Telemetry adds `shield_active`, `shield_phase`, `shield_phase_progress`, `shield_elapsed`, `shield_serial`, `shield_facing`, `shield_center/size/normal`, `shield_parry_open`, `shield_buffer`, `shield_lock_remaining`, `shield_holdable`, `last_defense_outcome`, `shield_effect_pending`, `allow_shield`, `weapon_generation`, `incoming_history_entries/sources/window`. Live poses are `shield_<phase>`; an obsolete field cannot override a new hurt/hard-land/traversal owner. Visuals consume the same actual floor/air/small-body context and never decide contact eligibility.

### M8 verification checkpoint

The frozen controller is `69b74005a5e2bae8e89287e1c089795de910bc4ebfcace2ecf880aad418cc7e4`. Independent Godot 4.6.3 acceptance passes **215 shield scenarios / 930 assertions at each of 120 Hz and 60 Hz**, with clean logs and stable source hashes. All seven earlier suites also pass at both rates: movement 36/98, combat 49/135, drop/dive 64/222, climb 85/215, wall 146/478, hard landing 100/349 and ordinary slopes 146/893. These are 16 separate final runs; prior milestone evidence remains preserved.

Coverage includes exact attempt boundaries, fresh/held/released/queued input, lock lifetime, host/main/weapon arbitration, physical incoming melee/projectile/prop contacts, guarded residuals, source/carrier distinction, direction and occlusion, bounded reordered identity history, separate accepted/failed counter and reflection effects, local pause, moving support, air/traversal budgets, natural soft versus hard landing, and synchronous reset/forced/hurt callbacks. Three reproduced lifecycle defects were corrected and retained: stale hurt continuation after a newer owner, soft landing incorrectly canceling an airborne shield, and reset callbacks leaving the old physics tick with an incomplete input snapshot. The collision motor and earlier gameplay tuning were not changed.

See `shield_verification.md/.json` for the independent physical report and pinned traces. Separate actual motor/view integration passes 1,090 checks on the same controller, including mirrored held-shield soft landings and real guard/counter/rejected-counter/reflection markers. The results validate this authored MOKSHA contract and do not establish exact Dead Cells timing, damage or cancellation parity.

## M9 optional chained light melee

Read `reference/MELEE_COMBO_CHARGE_EVIDENCE.md` and `MELEE_COMBO_SOURCE_FACTS.json`. The source distinguishes weapon cycle, anticipation, held/released input, charge, animation completion and control locks, but its actual combo scheduler and most consumers are absent. The three-step schedule, input policy, geometry, powers and cancellation below are original MOKSHA tuning. A weapon cycle is separate from a damage-streak buff or the source game's named Combo mutation.

The actor exports optional `melee_chain: MokshaMeleeChainProfile = null`. Null preserves the existing `combat_profile` single swing. The lab may opt into `res://combat_pc/resources/light_chain.tres`; the reusable player scene does not silently select it. `resources/melee_chain.gd` and `melee_step.gd` define independent configuration Resources. Runtime indices, clocks, requests, hit sets and serials belong to the actor. A committed episode deep-copies the chain and every step; no shared Resource is modified. In-place configuration edits affect the next episode. Assigning a different `melee_chain` increments an assignment epoch, immediately makes the old strike query invalid and safely retires its state at the next actor validation. Changing and restoring the original resource in one callback still invalidates old intent; assigning the same value is inert. This epoch is separate from in-place Resource edits. Configuration changes without any melee context do not cancel an independently active shield; it cannot convert an old request into a fallback swing. The null-chain compatibility buffer is also configuration-bound: assigning a chain clears an older denied fallback press, so switching back cannot resurrect it.

The chain accepts one to 16 valid steps with a configured `start_step` and each step's `next_step` (-1 means finish). Invalid configuration refuses without starting an attack. Each phase must be finite and at least 0.001 s. There is no attack-speed multiplier, held-repeat or charge branch in this pass. Those remain separate pending policies; holding J cannot manufacture another press or become a charge.

### Example light chain and clocks

| Field | Slash / index 0 | Backhand / index 1 | Finisher / index 2 |
|---|---:|---:|---:|
| Pose ID | `slash` | `backhand` | `finisher` |
| Windup / active / recovery (s) | .07 / .065 / .16 | .065 / .07 / .17 | .12 / .10 / .24 |
| Next step | 1 | 2 | -1 |
| Follow-up acceptance [from,until), step age (s) | [.035,.295) | [.035,.305) | None |
| Earliest next-step commit, recovery age (s) | .06 | .065 | None |
| Recovery cancellation opens (s) | 0 | .02 | .06 |
| Windup / recovery movement scale | .50 / .80 | .45 / .75 | .25 / .50 |
| Active grounded speed (px/s) | 70 | 55 | 90 |
| Active air drag (px/s²) | 950 | 950 | 950 |
| Strike size | (34,24) | (36,26) | (42,28) |
| Strike center offset before facing | (25,-20) | (26,-21) | (29,-20) |
| Damage / impulse | 1 / (240,-70) | 1.15 / (260,-95) | 1.8 / (340,-125) |
| Prop launch scale | 1 | 1 | 1.25 |
| Contact hitpause / strike loudness | .04 / 1 | .045 / 1.05 | .06 / 1.25 |

All three use origin offset (3,-22), with the existing physical small-body height clamp. All values are authored. Each step's independent `reuse_lock_seconds` defaults 0 for this light chain; when configured, it blocks new melee/shield admission, survives ordinary or forced cancellation, and freezes with local pause. Hurt/reset clear it. M8's independent shield use lock is always intersected rather than overwritten.

The chain advances on actor simulation time; hitpause freezes phase, pending-input, retention and reuse clocks. Phase residual time is carried. For an unusually large supplied delta, a configured chain stops advancement at active entry so that its only contact phase receives at least one admitted sample; residual time continues on the next callback. If a phase-entry feedback callback starts local pause before any sample is admitted, active persists on resume until one eligible sample occurs or the action is canceled. It cannot synthesize additional input or commit multiple steps from one press. Presentation progress clamps to [0,1]. This is a bounded safety policy, not arbitrary time-scale equivalence. Exact default behavior is checked at 120/60 Hz; the null-chain fallback keeps its existing scheduler.

### One pending fresh intent

Every physical attack edge receives a monotonically increasing `attack_input_id`, independently of held state, step index, chain episode and strike serial. A chain has one pending slot for both idle starts and live follow-ups. The first accepted request owns it; further presses are consumed/rejected with `queue_full` and do not replace or refresh its lifetime. With repeat absent, holding is inert after its one edge.

Capture happens before that callback advances clocks, including during local hitpause. A live-step press is classified against the step's pre-advance age and half-open acceptance window. Too-early, closed-window and finisher presses are consumed with explicit reasons and never become an idle-buffer attack. An edge on the callback that later completes a step is still a live-step edge. Accepted live follow-ups have a 0.22 s lifetime; fresh idle requests use the existing 0.14 s attack-input lifetime. Ordinary queue clocks continue through weapon recovery; local hitpause and the existing bounded hard-landing input hold freeze them.

A naturally completed nonfinal step retains its configured next index for 0.30 s of idle actor time, even after a whiff. A fresh idle press sampled while retention is positive latches that next index and gets its own input deadline. Retention reaching zero afterward does not erase that reserved request or turn it into step 0; it can wait only until its independent deadline. Once no reserved request remains, expired retention clears the episode. A fresh press sampled after expiry starts the configured first step. Finisher completion clears the chain. No contact or damage success is required to continue.

A pending request carries its input identity, chain serial, expected next index, configuration identity, kind and remaining lifetime. Temporary host denial preserves it only until its own deadline. Successful admission consumes it once. A fresh later press may request again after expiration, subject to the current step window/retention. Input disable, damage, reset, accepted shield/roll/jump/drop/dive/climb/wall/forced replacement and configuration replacement clear old chain intent. Natural jump completion and ordinary soft landing preserve the separate weapon/chain; they are not explicit weapon cancellations.

### Permissions, facing and interruption

The step's windup/active/recovery cancellation arrays are separate, plus `recovery_cancel_after`. Default windup allows roll, ground jump, air jump, shield, drop, dive, climb and wall entry. Active is committed by default. Recovery allows the same family only after its step's threshold. Automatic ledge catch remains denied while any melee step is live. Hurt, forced replacement and reset always retire the strike; no heavy-weapon damage resistance or invulnerability is inferred.

Every transition also checks main-action admission, actual resource/clearance/budget constraints and external permissions. Ground versus air jump is resolved before applying its corresponding step cancellation entry. A pending next attack has its own early-recovery commit threshold; it is not a generic attack-cancel permission. Simultaneous requests retain **roll → down action → jump → shield → melee → climb/wall** priority, so a queued chain cannot run before a newly accepted higher-priority replacement.

`can_attack` governs admission. Revoking it after a step commits preserves that step's remaining windup/contact/recovery while preventing another commit. A withdrawal during the previous step's finish callback is rechecked before the next commit; its pending request may survive only to its deadline. Movement and turn permissions remain live host intersections. Active ground motion is a swept authored nudge, respects host movement denial and never seeks a target. Air drag and ordinary gravity remain the existing behavior; no hover, conditional air assistance, jump/roll/dive refill or fall-history reset is added.

Default windup and recovery allow turning, while active turning is disabled. Phase advancement precedes ordinary facing control: direction first arriving on the windup-to-active callback is subject to the newly active permission and does not retroactively turn the committed strike. Earlier permitted windup input turns normally. The explicitly pre-advance queue sampling rule does not imply pre-advance facing. `allow_turn_windup/active/recovery` are independent step fields. Active contact facing is always latched, even if body turning is configured during active. That contact-facing remains through the step's recovery; permitted body-facing may turn independently. A later step samples permitted facing for its own windup/active strike. No already-committed strike changes its direction retroactively.

Explicit host `finish_main_action()` now retires melee as well as shield and clears its chain intent. Automatic soft-landing movement completion uses its separate nonforced path. This closes the old ambiguity without treating ordinary landing as weapon interruption.

### Per-strike contact and synchronous callbacks

Each committed step increments `attack_serial`, clears only its own hit set and resets sweep history. One target can be hit once in that step and again by a later valid step. New active entry seeds its own center, never a previous step's center or a paused carrier path. The existing contact adapter still requires real forward volume, terrain visibility and live target eligibility.

`is_strike_current(serial:int)->bool` validates active serial/phase, live actor, eligible main owner, current configuration identity and the admitted sample's main/weapon generations. The one synchronous `strike_sample` scope remains current after its first target starts hitpause, allowing a second physical target in the same admitted sample. A later paused callback has no such authority. `strike_snapshot().eligible` remains false during pause; it is not a substitute for that scope-aware query.

`confirm_strike` rechecks generation/identity after `strike_confirmed` and hitpause callbacks before returning acceptance. The adapter rechecks current owner, serial and target lifetime before the actual side effect and after target callbacks before continuing its old sweep. A reset or accepted replacement cannot authorize a captured old payload. An effect already physically applied before a target callback changes the owner remains recorded as applied; later stale feedback/contacts are suppressed.

Phase entry, strike noise, step finish and next-step commit also guard synchronous callbacks. `physics_tick` admits one scheduler call at a time: recursive positive-delta calls return without advancing clocks or capturing input, and zero-delta calls remain inert. A callback may immediately reset/force/finish/change configuration, but a new attack requires fresh input on a later real callback. A newer reset, hurt, forced owner or configuration replacement wins; old continuation cannot reinstall its phase, clear the newer hit set, advance another step or emit stale success. Runtime configuration and contact values are snapshotted for the episode/step rather than read from a shared edited Resource mid-strike.

A physical contact already resolved in an admitted sample remains valid from frozen geometry when source/strike/target identities survive, even if a callback directly changes a position. After all sample callbacks, the next sweep origin is seeded from the actual current strike center, preventing that observed relocation from creating hits across the skipped path. `reset_actor` is the supported teleport API and invalidates the old request. Arbitrary raw teleports outside those observed callback boundaries remain outside the supported contract.

### Telemetry and event extension

The view receives `attack_pose_id`, `attack_step_index` (zero-based; -1 fallback), `attack_step_label`, `chain_serial`, `chain_id`, `chain_next_step`, `chain_retention_remaining`, `chain_pending_input_id/step/remaining/kind`, `attack_input_id`, `attack_consumed_input_id`, `attack_step_elapsed`, `attack_active_sampled` and `melee_reuse_lock_remaining`, alongside existing attack serial, committed facing, phase/progress, contact geometry and physical movement context.

Chain poses are `attack_slash_<phase>`, `attack_backhand_<phase>`, `attack_finisher_<phase>` for windup/active/recovery. The null fallback retains `attack_<phase>`. Early chaining begins the next windup at progress 0; the view may blend its previous recovery pose without delaying simulation or moving the root.

Existing `attack_started`, `attack_phase_changed`, `attack_finished`, `attack_cancelled`, `strike_confirmed` and strike payloads add `chain_serial`, `step_index`, `step_label`, `attack_pose_id`, `input_id`. New `chain_input_queued/rejected/expired` events expose input identity, expected step and reason; `chain_reset` identifies the retired episode, step and pending request. `attack_finished.early_chain` distinguishes a valid early recovery handoff. These are semantic observations, not animation-driven damage authority.

### M9 verification checkpoint

The controller is frozen at `a1f37be07965aa1956dfb73d372b24579371a0178df44e7cc3805097a5550b99`. Independent Godot 4.6.3 acceptance passes **295 M9 scenarios at each rate: 1,360 assertions at 120 Hz and 1,384 at 60 Hz**. The report independently explains the 24-check difference from the sampled 0.020 s recovery-cancel gate. All eight earlier compatibility suites also pass at both rates, giving 18 clean, source-stable final runs.

The strict audit passes 2,024 profile timing checks, 1,826 cross-rate bounds (including all 814 inherited bounds without widening), and 8 same-rate physical prop-scale ratio checks. All 384 recorded historical artifacts and eight milestone snapshots retain their hashes. See `combo_verification.md/.json` for exact scenario traces, effective profile snapshots, contact populations and limits.

Coverage includes fresh/held input, first-slot ownership, acceptance/expiry/retention boundaries, temporary admission denial, per-step cancellation and facing, mirrored hit/whiff/two-target/occlusion cases, real prop launches, air/landing/slopes/roof/support and traversal interactions, shared-Resource isolation, assignment-epoch round trips, fallback input retirement, entry hitpause, recursive-tick refusal and synchronous owner/target callbacks. Preserved corrections cover stale strike application after callback retirement, a short active phase losing its eligible sample through entry pause, and a fallback request surviving configuration replacement. Already-applied effects and later acknowledgement are counted separately; an actor contact event alone is not proof of a physical receiver effect.

These results validate the configured original MOKSHA chain and its retained single-swing fallback. Held-repeat, charge and target-conditioned aerial assistance remain pending; no reference-game timing, damage or cancellation parity is claimed.

## M10 optional held input policies

Read `reference/M10_CHARGE_INPUT_ADDENDUM.md` and its source-facts JSON. Official historical notes support optional held chaining and a Katana slash-to-held-charge family, and identify simultaneous held-shield charging as unwanted. The pinned charge/update/input consumers are missing. The selected automatic trigger, clocks, rearm, interruption and movement below are **authored MOKSHA rules**. No target seeking, charge scaling, stamina, airborne assistance, new gravity or reference-game parity is supplied.

### Configuration and ownership

`melee_input_profile: MokshaMeleeInputProfile = null` is optional. Null retains M9's exact fresh-only chain or null-chain single swing. `resources/melee_input_profile.gd` defines `Mode.FRESH_ONLY=0`, `HELD_REPEAT=1`, `HELD_CHARGE=2`. The reusable scene and preserved `light_chain.tres` do not select an optional mode. Example Resources are `resources/held_repeat.tres` and `resources/held_charge.tres`; a host can switch them explicitly.

Repeat uses the selected ordinary `melee_chain`, including its existing phases, follow-up windows, retention and contact policy. With a null chain it repeats the compatible single swing after full recovery. Charge deliberately uses its own `charge_starter` and `charge_strike` step references instead of traversing the light-chain graph. Both charge steps require `next_step=-1`. There is one weapon owner, one pending request slot and no simultaneous shield/charge or repeat/charge ownership.

The input profile and its nested charge steps are deep-copied for the accepted configuration episode. A continuously held repeat keeps that input-policy copy across natural chain wraps; each newly admitted chain cycle still takes its own ordinary M9 chain/step snapshot. In-place Resource edits cannot alter a committed step or an ongoing hold/chain; they apply after that episode ends. An accepted fresh follow-up within a retained chain still belongs to that snapshot. A rejected press cannot change its snapshot or held authority. Assigning a different input profile shares M9's configuration-assignment epoch, immediately invalidating an old strike query and retiring old intent on validation. Change-and-restore within one callback still invalidates; assigning the same Resource is inert. The existing independent actor state, generation guards and nonrecursive `physics_tick` contract remain in force.

### Physical edges, held requests and rearm

The button remains `cp_attack` (J / gamepad X). `attack_input_id` counts physical fresh edges only. Every offered request additionally receives a separate monotonically increasing `request_id`. A synthetic request carries its originating physical `input_id`/`hold_id` and `request_kind=held_repeat`; it does not pretend to be another physical press. A charged execution has `request_kind=charge_commit` and its own request/strike identities. Physical requests use `request_kind=fresh`. Each committed strike latches its originating `hold_id` independently: queuing a newer held episode cannot change that strike's event, sample or contact provenance. Fresh-only strikes use hold origin 0; optional-mode strikes use their admitted originating physical input ID.

Input is sampled before actor clocks, including local hitpause. Physical release permanently ends that hold's eligibility. Release cancels only a repeat-generated pending request, leaving a genuinely fresh queued tap subject to its ordinary deadline. It never executes a charged strike. The optional modes observe physical neutral even while controls are disabled, so re-enabling a button already held cannot manufacture an edge.

Accepted non-melee interruption, damage, reset, configuration replacement, input disable or an expired optional-mode request disarms the held episode. Explicit external `can_attack=false` also disarms an admitted repeat and cancels active loading. Existing committed starter/ordinary/thrust strokes retain M9's admission-only attack gate and may finish; re-enabling the gate cannot resurrect the old hold. Initial denied fresh intent has only its existing finite admission buffer. Rearm requires physical release followed by a fresh press. Reset's internal neutral snapshot is not a physical release.

### Held repeat

`held_repeat.tres` uses `repeat_restart_seconds=0.08`. At most one automatic request is offered in one admitted physics callback, before clock advancement, and only while the admitted original hold remains eligible. For a live chain it waits for the ordinary next-step input window to open, then occupies the same first-slot-wins queue with the existing finite follow-up lifetime. It does not renew a full slot or flood requests through denied gates. Post-landing arbitration cannot create a second request in the same callback.

An admitted repeat follows the configured step graph, including whiffs and per-step facing/permissions. The final step must complete its entire recovery. A still-valid original hold may then begin a new episode after the 0.08 s actor-time restart delay. A null-chain single swing uses the same full-recovery/restart rule. A neutral release stops future repeats; it does not cancel an already committed strike. Local hitpause freezes queue and restart clocks while still observing release. Existing hard-landing queue rules apply, but that accepted replacement has already disarmed repetition.

### Starter, charge and thrust

The example has one qualitative slash-to-held branch and one automatic outcome. No early-release attack or release-to-execute alternative is exposed.

| Phase | Entry and duration | Movement / facing | Exit |
|---|---|---|---|
| Starter Slash | One fresh admitted press; ordinary `.07/.065/.16` s step | Existing Slash movement and phase permissions | Release before branch leaves only the ordinary Slash; valid uninterrupted hold may branch during recovery from `.06` s until natural completion |
| Charge | Begins only after the starter is retired; `.45` s actor time | Normal collision, gravity and air budgets; `charge_move_scale=.35`; `charge_allow_turn=true` intersected with host turning | Release cancels without strike/noise. A permitted roll/jump/air-jump/shield/drop/dive/climb/wall replacement cancels. Full duration requests one Charged Thrust |
| Charged Thrust | Ordinary `.06/.10/.24` s windup/active/recovery | Windup move `.35`, recovery `.65`, active grounded speed `260` px/s; existing air drag, no air dash | Ordinary step cancellation: windup permits shared actions, active committed, recovery permits them from `.06` s. Full completion requires release/new press |

Fresh charge-mode presses while its initial request, starter, loading or thrust remains live are consumed/rejected as `charge_episode_busy`; there is no second charge episode queue and a newer press cannot restore a released starter hold. The starter cannot bank charge time during its earlier phases. A closed/missed starter branch leaves no delayed charge request. Charge readiness is only committed at the normal melee arbitration position, after roll → contextual down-action → plain jump → shield. A fresh release is captured first and therefore wins even on the callback that would reach full duration. A higher-priority accepted replacement also wins. New charge branch/execute admission rechecks `uses_inputs`, `can_attack`, main interruption, shield ownership and existing shield/melee locks. Loading cancels on live input or attack-permission withdrawal. Turning and movement remain independent: movement denial does not by itself prevent an otherwise permitted turn.

A load cannot coexist with a held shield. Starter admission can use the existing legitimate shield-to-melee cancellation path only after its hold commitment and incurred locks permit it. Raising a shield during loading is an authored cancellation through the existing shield gates; it cannot both preserve charge and activate defense. Automatic ledge catching remains refused while the weapon owns a phase. All accepted traversals retire loading through their normal swept movement paths, preserving air-jump/roll/dive budgets and fall history.

Full charge begins ordinary thrust **windup**. Direction remains responsive where that step permits turning. Actual active entry latches strike direction, exactly as in M9. Later permitted body/recovery turning cannot rotate that active sweep or frozen contact feedback.

The thrust's authored contact is `44×24` px, center `(30,-20)`, origin `(3,-22)`, damage `2.6`, impulse `(360,-100)`, prop scale `1.25`, hitpause `.06` s and loudness `1.25`. Its active grounded movement is a normal swept speed command, not teleportation or roll invulnerability. The same terrain obstruction, swept forward volume, target deduplication and generation-safe confirmation path applies. The starter and thrust have distinct strike serials and separately initialized sweep histories. Loading has no strike volume or damage/noise event; ordinary movement can still make ordinary footsteps.

### Callback and clock boundaries

A charge clock advances only after the initial local-pause check; release and invalidation are still observed during pause. A pause requested by a callback retains the established admitted-tick convention. `charge_started`, `charge_committed` and cancellation callbacks are observable owner boundaries: reset, hurt, forced completion, configuration replacement or withdrawn admission can invalidate the continuation. `charge_committed` records an admitted transition request before installing the thrust; a synchronous replacement can still retire it. It is not proof of target contact. Only the normal later strike/receiver confirmation establishes a physical hit.

The charged step inherits M9's minimum 0.001 s phase validation and guaranteed eligible active-sample behavior. If one delta crosses an entire valid starter recovery, a still-eligible hold receives one real arbitration opportunity at that boundary; higher-priority input or withdrawn gates can still prevent the branch. The charge timer saturates at its configured duration; it does not loop or execute twice under a large delta. Only one scheduler callback may run at a time. No arbitrary time-scale equivalence or recursive simulation is claimed.

### Read-only interface

Telemetry adds `input_mode` (`fresh_only`, `held_repeat`, `held_charge`), `attack_hold_id`, `attack_hold_armed`, `attack_hold_released`, `attack_rearm_required`, `attack_request_id`, `attack_request_kind`, `attack_origin_hold_id`, `pending_attack_request_id`, `pending_attack_request_kind`, and `repeat_restart_remaining`.

Charge telemetry is `charge_serial`, `charge_role` (empty, `starter`, `charged`), `charge_phase` (empty, `loading`, `ready`), `charge_elapsed`, `charge_duration`, and clamped `charge_progress`. Loading owns `weapon_phase=charge` and `pose=attack_charge`. The normal starter has `attack_pose_id=slash`, `attack_step_index=0`; the charged step uses `charged_thrust`, index 1. The latter exposes `attack_charged_thrust_windup/active/recovery` poses. A view must use authoritative ownership, actual locomotion and current body-facing rather than treating loading as a stationary root.

`charge_started`, `charge_cancelled` and `charge_committed` carry `charge_serial`, `hold_id`, originating `input_id`, `request_id`, elapsed and duration; cancellation includes `reason`. Existing strike/attack payloads add `request_id`, `request_kind`, latched `hold_id`, `charge_serial` and `charge_role`. Actor `attack_hold_id` telemetry describes the current physical held episode, while `attack_origin_hold_id` describes the committed strike. Existing main/weapon generations, physical contact facts, current-strike query and adapter API are unchanged.

### M10 verification checkpoint

The controller is frozen at `c7c18b726210665df2304ff4aba190edda54816eaeb6fded1b44a63751f1987d`. Independent Godot 4.6.3 acceptance passes **114 M10 scenarios and 333 assertions at each of 120 Hz and 60 Hz**. All nine earlier compatibility suites also pass at both rates, giving 20 complete, source-stable accepted runs with clean engine logs. The strict audit passes 976 M10 profile timing checks, 2,314 cross-rate bounds (including every inherited bound without widening), and seven deliberately corrupted in-memory evidence probes that are correctly rejected. All 518 recorded historical files and nine M1–M9 snapshot archives retain their exact bytes.

Coverage includes optional-mode isolation, physical versus synthetic request identity, repeat wrap/release/expiry, charge opening/readiness/rearm, shared input and shield locks, per-phase facing, air/fall/resource behavior, ground and moving support, thin walls, small-body clearance, actual passive-target and rigid-prop contacts/noise, minimum valid phases, configuration snapshots/assignment epochs, local pause and synchronous owner/receiver replacement. Each committed strike's hold provenance remains fixed even when a later physical press changes current held ownership. Three corrected defects retain their distinct evidence origins: two implementation before/after physical reproductions (unused snapshot canceling an independent shield; short recovery skipping the charge branch), and one independently discovered physical trace defect (mutable strike hold provenance).

See `held_verification.md/.json` for the case inventory, timing policy, contact populations, hashes and limitations. One initial combo120 process was externally terminated with no engine diagnostic; its cause remains unconfirmed and it is excluded from acceptance. The same harness rerun alone completed 295 scenarios/1,360 assertions cleanly, with both attempts retained in `tests/held_execution_recovery.json`.

These results validate the selected original MOKSHA held-repeat and automatic-charge configurations while preserving the fresh-only baseline. They do not establish reference-game timing or cancellation parity, arbitrary custom-configuration equivalence, or packaged/native presentation acceptance.

## M11 optional first-entry facing assist

`enable_attack_entry_assist=false` preserves the accepted manual baseline. This opt-in helper applies one horizontal-facing suggestion at a genuinely initial fresh starter's admitted windup. It does not add a main action, target catalogue, pursuit, homing, ranking, movement speed, gravity rule, air-jump refund or hit authority. The design follows the bounded perceived-target proposal and its cited primary/source evidence. All admission, geometry, perception and precedence rules here are authored MOKSHA policy; the reference game's selection and scheduler remain unavailable.

### Initial admission and manual priority

Initial admission is explicit provenance passed by the normal weapon admission path, not `step_index==0`. An ordinary new chain episode may begin at any configured index. A retained follow-up or loop back to that index is still a continuation. A fresh null-chain swing and M10 Starter Slash are eligible. Held-derived repeat steps, even a natural repeat wrap, and Charged Thrust are ineligible. A queued or rejected request does not query. `attack_initial_fresh_admission` exposes this distinction independently of step, input, request and strike IDs.

The helper runs after installing the admitted windup and its effective permissions, before `attack_started`. **Any nonzero normalized horizontal input vetoes the query**, including tiny nonzero input and movement-locked input. Neutral means input X zero, not zero physical velocity. Main input capability, `allow_input`, external turning permission and the current step's windup turning permission must all allow turning. Movement permission does not imply turn permission or vice versa.

At most one synchronous offer is requested for that attack entry. A successful suggestion changes only `facing` and its inactive windup preview. Later permitted manual windup input still wins; ordinary active entry commits the final strike direction and resets its sweep history. Target movement or disappearance after entry cannot turn the attack again. The suggested direction can change the direction of an existing configured active forward-speed command; it never creates a new approach or extends its range.

### Provider registration and exact offer schema

The reusable actor exposes:

- `set_attack_entry_provider(provider: Callable)` replaces the one provider
- `attack_entry_provider_matches(provider: Callable) -> bool` checks exact ownership
- `clear_attack_entry_provider(provider: Callable) -> bool` clears only that still-bound callable

An old host must use the matching-owner check before toggling enablement, and exact-owner clear on detach. Replacing the provider or changing enablement increments an authority epoch, including change-and-restore within one callback. Assigning the same callable/value is inert. No provider is installed by the player scene.

The callable receives `(actor, request: Dictionary)` and returns `{}` or one Dictionary. It is synchronous and read-only. There is no asynchronous response, polling, secondary offer or previous-frame cache. Request keys are:

| Key | Meaning |
|---|---|
| `token` | Monotonic actor-local query identity; not reset into an old query's identity |
| `sample_tick`, `engine_tick` | Admitted actor callback number and observed engine physics callback |
| `actor_id`, `attack_serial` | Requesting instance and already admitted windup strike |
| `input_id`, `request_id`, `request_kind`, `hold_id` | Physical edge, admitted request, kind and **committed strike** hold origin |
| `preview_left`, `preview_right` | Current starter's mirrored world `Rect2` contact-preview boxes |
| `origin_left`, `origin_right` | Mirrored world contact-ray origins, adjusted for the actual body height |
| `terrain_mask` | Actor's current terrain query mask |

A nonempty offer must echo the exact integer `token`, `sample_tick`, `actor_id` and `attack_serial`, and provide:

| Key | Required value |
|---|---|
| `candidate` | A live `Node2D` in this scene tree, not queued for deletion |
| `candidate_id` | That node's exact integer instance ID |
| `local_anchor` | Finite `Vector2` in the candidate's local space |
| `anchor_world` | Finite `Vector2`, exactly equal to its current `candidate.to_global(local_anchor)` |
| `classification` | String or StringName `opponent` |
| `eligible`, `perceived`, `visible` | Each explicitly Boolean `true`; missing, unknown, numeric truthy or false rejects |

The host owns the semantic meaning of opponent, aim eligibility and current perception. Damageability, proximity or overlap alone does not establish those facts. The actor rejects malformed offers, itself/its descendants/ancestors, invalid or mismatched candidate identity, a root hidden in the scene tree, and a candidate explicitly in group `props`, even if the offer claims otherwise. Hidden child artwork alone does not determine perception: a future host may perceive an opponent whose art is intentionally hidden. These concrete contradiction checks do not replace the host's awareness contract.

### Geometry, lifetime and authority

Preview boxes use the current admitted starter's actual size/offset and current small/standing body adjustment. Their **closed union** includes all edges, giving symmetric left/right boundary behavior. No new aim radius or target extent is added. The anchor itself must lie in that union. Equal X preserves facing; an already-facing candidate also causes no turn.

After the provider returns, the actor independently ray-checks from the corresponding current side origin to the validated current anchor using its terrain mask. It queries bodies with `hit_from_inside=true`, excludes only itself, and does not borrow a drop-through/platform exception or grant the target a terrain exemption. The representative passive target is an Area2D and supplies no blocking body. A terrain body in that line refuses the offer even if the host claimed visibility. The check uses the current physics space, as ordinary strike obstruction does.

The actor validates reset, action, weapon, melee-configuration and provider epochs; tick/admission/strike identity; windup ownership; neutral input; and all turn gates before applying. It also compares the observed actor/preview/contact state across the callback. Calls to public mutators such as reset, forced action, damage, hitpause, input-buffer clearing or permission assignment are recorded as mutation even if the callback restores the prior value. Recursive physics admission or recursive assistance marks the query reentered and discards its result. Newer legitimate host changes remain in place; rejection does not restore an old action or position. A provider is trusted host code under a read-only contract, not a sandbox for arbitrary property mutation.

No target handle or anchor is stored in actor state, telemetry or the damage pipeline. A successful offer supplies no authorization to hit it: subsequent movement, active-phase geometry, world obstruction, strike serial, target deduplication and receiver validation still decide actual contact. The M10 distinction between current physical `attack_hold_id` and latched `attack_origin_hold_id` remains intact; the request carries the latter as `hold_id`.

### Diagnostics and presentation

Read-only telemetry adds `entry_assist_query_count`, `entry_assist_token`, `entry_assist_attack_serial`, `entry_assist_reason`, `entry_assist_manual_x`, `entry_assist_facing_before` and `entry_assist_facing_after`. Counts/tokens are actor-local and monotonic across resets. These are decision facts, not a retained target or evidence of a physical hit.

`movement_event` may emit `entry_assist_resolved` with `token`, `attack_serial`, `query_count`, `request_kind`, `reason`, `manual_x`, `facing_before` and `facing_after`. Reasons distinguish applied/already-facing/equal-X decisions, input/turn/provider vetoes, malformed/stale/unknown offers, identity/anchor/bounds/terrain rejection and provider mutation/reentry. No unperceived target position or identity is exposed. Invalidated/reentered provider calls update diagnostic reason without emitting a stale owner event. The disabled path does not call a provider or emit this event. Existing presentation continues to use current body facing and the ordinary active-entry contact latch; no new pose clock is added.

### M11 verification checkpoint

The controller is frozen at `123058595238d83090cead600dc0934df527f5cd4a18c555d4da52ea971abaa1`. Independent Godot 4.6.3 acceptance passes **71 M11 scenarios and 163 assertions at each of 120 Hz and 60 Hz**. All ten earlier compatibility suites also pass at both rates, giving 22 clean, complete final runs. The strict audit retains all 2,314 inherited cross-rate bounds without widening, passes 976 held-input timing checks, and rejects 14 deliberately corrupted in-memory evidence probes. All 707 recorded historical files and ten M1–M10 snapshot archives remain byte-identical.

Per rate, the final M11 traces record 62 provider calls, 67 decision events, 28 actual target effects and 28 adapter receipts. Those are separate populations: input/permission vetoes can decide without querying, a provider may offer nothing or be invalidated, and an accepted facing suggestion is not proof of a hit. Coverage includes mirrored real contacts; manual and turn-gate precedence; closed preview edges; live identity/current anchors; unknown perception, hidden-root and prop contradictions; terrain obstruction; arbitrary chain starts/loops; retained, repeat and charged-followup exclusions; provider replacement/detach, mutation and recursive admission; and generation-safe reset/cancellation.

The off/on contact demonstration uses an explicitly stationary comparison strike to isolate facing. Default configured strikes retain their existing facing-dependent forward nudge, whose direction can change after a valid suggestion. A separate contact-free airborne comparison verifies unchanged gravity, fall history and action budgets; contact-driven hitpause is not misreported as motion equivalence.

See `entry_assist_verification.md/.json` for the complete inventory, source hashes and limits. No production defect was found during this acceptance. The sole recorder correction changed a test-only Dictionary merge to overwrite initialized candidate-observation flags; its original and corrected evidence remain distinguished in `tests/entry_assist_evidence_notes.json`. These results validate the optional authored MOKSHA interface and representative passive host, without establishing reference-game targeting parity or broader perception behavior.
