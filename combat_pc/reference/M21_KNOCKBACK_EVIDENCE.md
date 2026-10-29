# M21 struck-target physical knockback audit

Read-only runtime/source audit, 2026-10-07, against the recovered v24 project. This document records observed contracts and a bounded implementation recommendation. It does not certify the subsequent M21 implementation, physics tests, or perceived feel. No runtime or UI files were changed by this audit.

## Finding and smallest coherent seam

The existing strike already carries an authored, world-directed `Vector2` impulse. Its passive `MokshaContactTarget` only stores that value and moves its drawing by three pixels; its `Area2D` transform and collision shape do not move. `MokshaChainTarget` records every delivery without hiding duplicates. The existing `MokshaMovementMotor` already supplies real `CharacterBody2D` motion, gravity, terrain collision, impulse, stun and local pause. One detachable `Node` can bridge the target's `struck(payload)` signal to that motor without replacing the player controller or touching the enemy health/AI path.

Use a separate passive fixture composed of the existing motor, its body shape, one contact-area child, and one receiver component. Keep the motor enabled with neutral intent and no input source. `enabled = false` exits before gravity and collision; it does not mean “passive dummy.” Use the contact area as the only melee collider, on the existing layer 4. The motor can collide with terrain while exposing no player-blocking layer. Preserve the existing contact/chain fixtures as baseline instruments.

This is a MOKSHA adapter design, not a recovered Dead Cells enemy response. Health, defeat, resistance classes, AI, combat decisions and player movement/combos are outside this pass.

## Actual contact order and payload authority

Source references below use the v24 function names; line numbers identify the audited snapshot and may move during implementation.

1. `player.gd::_run_physics_tick`, around lines 561–571, captures `strike_snapshot()`, opens a synchronous strike-sample scope and emits `strike_sample`. The scope stores attack serial plus action and weapon generations.
2. `contact_adapter.gd::sample_strike`, lines 28–82, rejects inactive/ineligible samples, checks the live source, performs swept shape intersection, forward-half-space and terrain-visibility tests, then calls `source.confirm_strike(serial, target_id, point)`.
3. `player.gd::confirm_strike`, lines 2527–2538, rejects old/already-hit identities, marks the target, emits `strike_confirmed`, rechecks generations, and applies the source's once-per-strike pause. Its observable callbacks can cancel/reset/free objects.
4. The adapter rechecks the live source and target after confirmation, marks the target visited, duplicates the captured strike dictionary, and adds `contact_position`, `source`, and `source_position`. It calls `target.receive_strike(payload)` only after those checks.
5. `contact_target.gd::receive_strike`, lines 34–42, records the delivery and emits `struck(payload)` synchronously. This is the receiver bridge's seam. The chain target records damage, serial, step and impulse before delegating to this method.
6. The adapter counts the completed delivery, rechecks current source/target, then emits the existing `contact_confirmed`. A receiver can apply an effect and then retire the source; the already-applied effect remains valid, but the adapter suppresses stale feedback and stops the old sweep.

The v24 strike contains serial, chain serial, step index/label, pose, input/request/hold/charge metadata, geometry, facing, fractional damage, impulse, prop launch scale, phase and eligibility. It contains **no stun duration and no hitpause duration**. The adapter adds a live source node reference, not a serialized ownership token. Do not retain that node strongly in an unbounded diagnostics history.

The horizontal impulse is already mirrored by the committed attack facing in `strike_snapshot`, lines 2515–2516. Apply it directly; multiplying it by facing again makes left-facing hits travel right. The vertical component must retain its sign and scale.

`is_strike_current(serial)` deliberately remains true inside the admitted sample even after confirmation starts hitpause. A newly requested `strike_snapshot().eligible` is then false. A receiver must recheck `is_strike_current`; rejecting because the source is paused or because a fresh snapshot is ineligible incorrectly discards genuine contacts. Delayed calls outside the sample during pause correctly fail the public current-strike check.

## Recommended receiver contract

- Bind explicitly to one live contact receiver and one live `MokshaMovementMotor` in the same world. Store weak references and a binding generation. Connect once using a callable carrying that generation; disconnect on explicit unbind, tree exit and replacement. Do not automatically search unrelated scene nodes during delivery.
- Permit one active physical receiver owner per motor/contact binding. Two bridges must not both apply the same signal. A weak owner registration, matching the existing optional-component style, is adequate.
- On delivery, validate the component, current binding, enabled state, live/non-deleting receiver, live/non-deleting motor, and same-world source. Require an actual nonnegative integer serial, the captured active/eligible flags, a `Vector2` impulse with finite components, and a source implementing the current-strike contract. Validate numeric pause/profile values before assigning motor state. Reject malformed payloads without changing velocity, pause, stun, deduplication state or diagnostics that claim success.
- After all potentially host-supplied eligibility checks, revalidate the binding and lifetimes. This protects against synchronous source methods or earlier `struck` listeners which reset, unbind, reparent, replace or free an endpoint.
- Deduplicate physical application by **source object identity plus strike serial**, not serial alone, chain serial, step index, or dictionary identity. Two sources may both issue serial 1; a later step from one source must remain eligible. Preserve the chain target's raw delivery count/history so adapter duplicates remain observable.
- Keep the per-source consumed high-water identity through diagnostic reset/disable/reattach while that source remains alive. Otherwise resetting the target while a source strike is still active can make a previously consumed payload replayable. Weak per-source records can be pruned when their source is gone; a bounded receipt ring is separate from the safety ledger. The PC's serial increases on new attacks, while source reset/cancellation immediately retires active authority.
- Validate first, then commit the consumed identity, `motor.apply_impulse(impulse, authored_stun_seconds)`, and `motor.apply_pause(current_source_pause)` together, without a deferred impulse or signal in between. The current motor methods do not emit external signals during these calls. Emit any physical-response receipt only after the commit, and perform no stale mutations after that observable dispatch.
- Impulse replacement is the motor's existing behavior: it sets velocity, cancels dash and jump-flight assistance, and assigns stun. It does not add a force, depend on mass, or sum multiple hits. Any change to that rule or receiver scale is authored MOKSHA tuning.
- `apply_impulse` does not clear input buffers. The passive fixture should supply no input and start with `clear_intent`. If later reused on a driven actor, interruption of its pending input requires a separately documented host policy rather than silently adding AI/input ownership here.

The adapter remains responsible for spatial acceptance and authoritative hit deduplication. The receiver is a synchronous defensive boundary, not an independent hit detector or a way to authorize arbitrary payloads. A copied dictionary is not an unforgeable contact receipt; only the authorized adapter-to-receiver call path establishes actual contact.

## Pause, reset and detach semantics

Read the source's **current remaining pause** after successful confirmation. Do not start another source pause. The source freezes only once per strike; a different target first contacted later in the same active strike may therefore receive zero remaining pause. Copying the authored full step pause in that case incorrectly freezes only the target. Reject nonfinite/negative values and use a documented upper bound if the new component supports arbitrary hosts; the bound is original defensive policy, not recovered game tuning.

Scheduling needs a real physics test. The PC normally runs at physics priority 0; `MokshaMovementMotor::_ready` sets priority 10. With those defaults, the source starts pause, the motor receives it, then the motor decrements it on the **same contact tick**, whereas the source does not decrement until its next tick. Equal durations alone therefore allow the target to resume one frame early. A passive host can schedule the motor before the source so both start decrementing on the following tick, or implement an explicit contact-frame fence. Do not hide the mismatch by lengthening the pause by an arbitrary fixed duration. Verify 60 and 120 Hz using real physics callbacks, including a motor that has already stepped in the contact frame.

During pause the motor returns before stun decrement, gravity or `move_and_slide`, retaining the committed velocity. Afterward the existing stun branch brakes horizontal velocity using `tuning.air_braking`, applies gravity and resolves collision. Stun expiration returns to ordinary neutral motor behavior; with the default instant-ground response, grounded horizontal motion then stops. This establishes physical collision behavior, not a guaranteed displacement or exact game-feel value.

Reset must be explicit host coordination: fence the receiver's in-flight binding/lifecycle, reset the body through `reset_at(position)`, and reset the contact instrument. `reset_at` clears velocity, pause, stun, intent, dash and flight state; resetting only the Area2D counters does none of that. Keep the consumed-strike safety identity even if visible hit counts clear. If a reset notification is introduced, give it a clear “before physical reset” ordering and test reentrant listeners. Source and fixture reset together may start a new episode, but no old strike may gain authority again.

Unbind/detach prevents later deliveries, clears only receiver-owned transient state, and leaves already-applied velocity/pause/stun with the motor. Do not teleport, stop, disable or rewind the body merely because its optional receiver is removed. A host wanting a stationary reset should invoke the explicit reset flow. Rebinding should not replay prior payloads; a replaced binding generation invalidates any old signal continuation.

No second audiovisual system is required. Keep existing `contact_confirmed`, flash and presentation ownership. A physical receipt can support instrumentation, but must not also emit combat noise, play another impact sound, invent a second contact pause, or create damage. The inherited three-pixel drawing recoil is not evidence of physical success: acceptance checks must measure body transform and collider movement.

## Pinned Dead Cells source recheck

The files below were retrieved directly from the GitHub connector at commit `77c3ad263c4187ade6d048ba77bb61f79e6cec44` on the audit date. BODY denotes a surviving nonempty implementation; DECL denotes fields, empty methods or throwing stubs. This decompiled representation does not independently establish runtime equivalence, and no source code/assets were copied into MOKSHA.

| Source | Retrieved blob | Surviving evidence and limits |
| --- | --- | --- |
| [Entity.hx][entity] | `69aa974fb93311fe58756200cfc8b0d2a74605d5` | BODY: `recoil` 562–564 stores `recoilX`; `onTouchCeil` 878–881 clears `bdy` and scales `dy`. DECL: `bdx`, `bdy`, `bumpFrict`, `bumpResistance`; `bump` 567–568, resistance 570–572, `bumpAwayFrom` 574–575, `applyAttackResult` 647–648, `onDamage` 662–663, `updatePositionXY` 1003–1004 and `fixedUpdate` 1006–1007 are unavailable. No horizontal/vertical knockback integration or resistance formula is recovered |
| [AttackData.hx][data] | `66632db96953ea3a104ebdcaa355e6c17d063eb9` | DECL: `targetFreezeCast` at 17. Its name alone supplies neither duration, hitpause scope nor a stun contract; creation/result/direction consumers are missing |
| [AttackTargetImpl.hx][target] | `eb29921dd1420bc397109b589231a13c39264f23` | DECL: pre-hit, `applyHit` 49–50, miss, and post-hit hooks are empty; front/back/facing checks throw. No accepted-hit response ordering is recovered |
| [MobAttackTarget.hx][mobtarget] | `f55fe306d9c140b325afe91743141559daf61955` | DECL: pre/post result hooks 21–25 and `extraDamageEffects` 27–28 are empty. No NPC impulse, stun or freeze consumer is recovered |
| [Mob.hx][mob] | `be50cd366b3177670b9162273525795ac8436e8f` | DECL: `applyAttackResult` 482–483 and `onDamage` 498–499 are empty; breach-related behavior is also unavailable. No generic enemy knockback values can be asserted |

The existing step impulses (Slash 240/-70, Backhand 260/-95, Finisher 340/-125), step contact pauses (0.04, 0.045, 0.06 seconds), motor gravity/braking, and any chosen receiver stun are authored MOKSHA values. None is extracted from these Dead Cells files. Existing `enemy.gd::take_hit` couples integer damage, AI windup, stun, impulse, multiple feedback effects and death; its reuse would expand this pass into an unrelated enemy overhaul.

## Focused acceptance matrix

1. At 60 and 120 Hz, genuine left/right contacts preserve payload impulse direction and lift; the body and contact shape move by a measurable amount after pause, land, and settle. Record physical displacement, not drawing recoil.
2. Source/target pause starts from the same remaining duration, freezes target velocity and stun clocks, and resumes under the documented scheduling rule. Include multiple targets in the initial sample and a later same-strike target after the once-only source pause ended.
3. One source/serial applies once, a later accepted serial applies again, and two sources with the same serial both apply. Replaying payloads after target diagnostic reset, disable/re-enable or detach/rebind cannot refresh impulse/pause for a consumed identity.
4. Wall/floor collision remains Godot collision. No direct target translation, tunneling workaround, player blocking, target-created attack, health change or AI action is introduced.
5. Malformed impulse/serial/source/pause, retired source, source reset/hurt, unbound/disabled receiver, freed/queued/reparented endpoints and another receiver owner reject cleanly. Include mutations in source confirmation callbacks and earlier target signal listeners.
6. Reset during pause restores the spawn body with zero velocity/pause/stun and clears visible counters; detach during pause lets the already-admitted motor response finish and prevents future response. A physical receipt listener may reset, detach or free its owner without stale continuation.
7. Terrain-occluded target, target behind the committed forward strike and canceled/stale adapter callback cause no new physical response. Existing fixtures still expose every adapter delivery. Existing PC movement/combo, feedback and prop paths retain their regression coverage.

[entity]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/Entity.hx
[data]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/atk/AttackData.hx
[target]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/atk/AttackTargetImpl.hx
[mobtarget]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/atk/atkTargets/MobAttackTarget.hx
[mob]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/en/Mob.hx
