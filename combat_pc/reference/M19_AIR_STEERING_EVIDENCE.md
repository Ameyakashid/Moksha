# M19 ordinary airborne steering: source boundary and authored calibration

Audited 2026-10-06. Scope: one horizontal steering pass after the approved M18 ground response. This document records source inspection and an independent numerical replay of MOKSHA's horizontal update formula. **The numbers below are formula results, not Godot runtime measurements, recorded Dead Cells gameplay measurements, or recovered Dead Cells constants.** The implementation and engine tests are separate work; this audit did not change runtime code or operate a UI.

## What the pinned Dead Cells source actually establishes

The reference remains [DeadCellsDecomp commit `77c3ad263c4187ade6d048ba77bb61f79e6cec44`][repo]. The existing source inventory identifies the repository's target as PC v35 / `50edff4`. The following bodies and declarations were freshly fetched from that exact revision, rather than inferred from symbol names or an earlier audit's summary.

| Path under `deadcells/src/game/` | Freshly inspected evidence | What it can establish |
|---|---|---|
| [`en/Hero.hx`][hero], blob `fd03750543f136f7487bf1a030489cddb7cb4280` | **BODY:** `moveControlled()` at 600–602 returns `cd.fastCheck.exists(1231028224)`. **DECL:** `runSpd` and `accelFactor` are uninitialized fields; `airControl()` at 764–765 and `fixedUpdate()` at 868–869 have empty recovered bodies. `controlsLocked()` is a throwing stub | A real cooldown-backed base control predicate exists. Its key lifecycle, polarity at call sites, input sampling, motor integration and ground/air acceleration are not recovered. An empty recovered routine is not evidence that the shipped game performs no air control |
| [`en/hero/Beheaded.hx`][beheaded], blob `deb5c783b4c72fabc71cd2f70414d6e3f97b6f1a` | **DECL:** `moveControlled()` at 53–55 overrides the base method with a throwing stub | The base Hero predicate alone cannot establish the Beheaded's actual movement-control behavior |
| [`tool/HeroMainSkill.hx`][main], blob `f781f60f2ec11622bf325015d500c42b1f3fb834` | **BODY:** base `isUsingInputs()` returns true; `canBeInterruptedBy()` returns true; `shouldHaveSmallHitbox()` returns false; `canWallGrab()` and `canJumpThroughUp()` return true. `isActive()` checks cooldown key `721420288`. **DECL:** start/end/update and interrupt execution are unavailable | These are real generic capability defaults. They support separating capabilities and activity from a movement label. They do not prove subclass permissions, action priority, duration or air steering |
| [`tool/mainSkills/Jump.hx`][jump], blob `390b524bcce1b5e0468bd181612993861210ae0d` | **DECL:** `holdNormalJumpLock` and shared blackboard fields; `canUse()` and overridden `isUsingInputs()` throw; `passiveFixedUpdate()`, `onStart()` and `normalJump()` are empty | No normal-jump launch, input-hold rule, inherited horizontal velocity or airborne acceleration is recovered. The missing input override prevents treating the base true return as the jump's proven permission |
| [`tool/mainSkills/JumpBeheaded.hx`][jumpb], blob `c5a29abafe8aca6c6630ee1368477ccc438fbe36` | **DECL:** `jumpExtra`; `passiveFixedUpdate()` and `normalJump()` at 11–15 are empty | No Beheaded-specific jump launch or ordinary air steering implementation |
| [`tool/mainSkills/AirJump.hx`][airjump], blob `2991081b3d442874d71bf8476a1aa956d89c695a` | **CALL:** `onStartClimbing(onLadder)` at 44–46 invokes `set_airJumps(0)`. **DECL:** getter/setter and `canUse()`/`isUsingInputs()` throw; `passivePreUpdate()` and `onStart()` are empty | The climbing callback dispatch is real. With its setter absent, it does not recover used-versus-remaining counter semantics, a refund policy, or any steering/launch constant |
| [`tool/mainSkills/AirJumpBeheaded.hx`][airjumpb], blob `e92ed40b6a7c0fe3aa4f370f65e9fbf6219d2bbe` | **DECL:** `onStart()` and tutorial-start override at 11–15 are empty | No Beheaded air-jump implementation to translate |
| [`tool/mainSkills/blackboards/JumpBlackBoard.hx`][blackboard], blob `72f9bd3060a8d9672e5efabd5d12def72c415261` | **DECL:** `airJumps` and `isHoldJumpLock` fields | Shared storage is visible; its mutation and interpretation are not |
| [`tool/hero/HeroMainSkillsManager.hx`][mainmanager], blob `cc77011495a33fc9651bb6b9660cffea676bcd12` | **DECL:** pre/fixed/post updates at 19–26 are empty; `tryInterruptBy()`, `shouldHaveSmallHitbox()` and `canWallGrab()` at 72–82 throw | No established main-skill admission, ordering, capability aggregation or interruption sequence |
| [`tool/Weapon.hx`][weapon], blob `5515da6ac74a18b7188d1670e3611c14168e58ac` | **BODY:** `allowTurnDuringCharge()` at 141–143 returns true. **DECL:** `airControlOwner()` at 175–176 is empty | A base charge-facing permission exists. It supplies neither ordinary horizontal air acceleration nor weapon-conditioned air-control strength/axes/timing |
| [`tool/hero/HeroWeaponsManager.hx`][weaponmanager], blob `4d0481b00096601195e18ae3616630d253b9faf4` | **DECL:** update/admission methods at 147–162 and pre/fixed/post updates at 179–186 are missing/empty | No recovered order between weapon control, main skills, facing and horizontal/vertical movement |

`FACING_AIR_CONTROL_EVIDENCE.md` also distinguishes the historical official Update 23 weapon/strike-zone feature from ordinary locomotion. That is a different boundary and is not a reason to add target-dependent steering here. This pass uses no other game's controller, constants, state machine or collision logic to fill the missing bodies.

**Faithful translation boundary:** preserve actual known capability separation and do not reinterpret the recovered calls beyond their bodies. There is currently no recovered ordinary airborne motor body to translate into a justified numerical acceleration. The optional **2300 px/s²** is explicitly original MOKSHA calibration, pending engine validation and the user's play test.

## Current MOKSHA behavior and the narrow change

`resources/movement_profile.gd` supplies the legacy airborne acceleration **1450 px/s²**, ordinary cap **218 px/s**, and neutral drag **120 px/s²**. `movement_profile.tres` has no overrides. M18's optional ground response supplies **4800 / 2700 / 6200 px/s²** acceleration/braking/reversal and a **0.07 s** turn timer. Retain that approved ground option unchanged.

`player.gd::_update_horizontal()` computes `target = move_x * maximum`, with maximum still derived from run/crouch speed and the effective weapon movement scale. Ground movement follows its existing ground-only branch. With nonzero airborne intent, the old branch approaches the target at 1450; neutral airborne input approaches zero at 120. Both acceleration and reversal therefore use the same air rate, unlike the ground branch's dedicated reversal rate.

The concrete mismatch is momentum response: at full 218 px/s, the old ordinary-air branch continues moving in the old direction for about 158–167 ms after a full opposite input and takes about 308–317 ms to reach the opposite cap at the tested formula rates. This can move the actor another 14.58–15.48 px toward an edge or past an intended landing alignment. Facing itself already changes immediately when permitted; the delay is in horizontal velocity, not the facing permission. Whether that delay feels wrong remains a play-test judgment, not a source-derived defect.

The proposed optional `ordinary_air_response` changes **only the admitted branch's acceleration from 1450 to 2300**. It preserves the speed target, analog target scaling, neutral drag, vertical jump speed, jump release cap, gravity, terminal speed, jump/coyote/buffer budgets and collision solver. It leaves the legacy resource available as the comparison baseline. The M19 candidate resource composes the approved M18 ground option with this air option.

## Owner gate and call-order audit

The inspected candidate `_air_acceleration()` positively admits only an actor that is airborne, has `main_action` equal to `locomotion`, `jump` or `air_jump`, is not crouched, has no live `_drop_body`, has no valid `_action_driver`, and has both weapon and shield phases idle. Invalid or missing response resources fall back to the legacy acceleration.

Why each boundary matters:

- `locomotion` must be included: walking off a ledge and ordinary falling do not invent a separate `fall` main action. Grounded locomotion must still use the ground branch.
- `roll` recovery calls `_update_horizontal()` while roll still owns the action. It must retain legacy air acceleration; checking only idle weapons is insufficient.
- `dive` recovery also calls the shared horizontal update. Dive startup and descent already use dive-specific horizontal drag; impact sets velocity to zero. Keep all four phases outside the new response.
- `hurt` and `defeated` use their own drag/vertical branch in the normal tick. Positive action admission additionally protects shared-helper fallback paths and prevents a later shared call from accidentally obtaining ordinary response.
- Wall run/slide/kick, climb and ledge owners remain excluded. Wall kick forces its horizontal speed throughout the existing commitment, so the new response must not preempt it.
- `_end_drop_action()` can retire `drop` to `locomotion` before the targeted collision exception clears. The live-drop exclusion and crouch exclusion preserve that remaining traversal constraint and short collider's old motion.
- `begin_main_action()` permits host-owned built-in IDs such as `jump`/`locomotion` with a custom driver. That driver may return false to borrow shared movement. Excluding a valid `_action_driver` preserves the old fallback response even when its action name looks ordinary.
- Idle weapon and shield phases are both necessary. Windup, charge, recovery and held defenses can permit scaled horizontal motion while retaining their own owner. Active melee has a separate airborne drag branch. None is ordinary uncommitted steering.

The normal `physics_tick()` order is existing MOKSHA policy, not a recovered Dead Cells order: advance shield/combat/down/wall/landing owners; refresh effective permissions and axes; refresh contact; update facing/crouch; arbitrate roll, down action, jump, shield, attack, climb, wall; refresh permissions and axes again; dispatch owned motion; otherwise update horizontal then vertical; perform collision sweep and landing/wall/ledge handoff. `_refresh_axes()` sets `move_x` to zero unless `_uses_inputs()` and effective `can_move` are true. The new response is consulted only inside the nonzero-air-intent branch, so neutral and these denied-input paths retain legacy drag.

For a strictly freely-steerable helper, explicitly requiring `_uses_inputs()`, effective `can_move`, and positive effective `move_scale` is a useful additional guard. The first two are already enforced by the normal caller; a zero movement scale is different because `move_x` can remain nonzero while target speed becomes zero. Without a positive-scale guard the candidate would accelerate that forced stop faster. Preserve legacy behavior for that host restriction as part of the bounded pass. Positive fractional scales should continue to scale the target normally, rather than being mistaken for a new action.

**Ownership ends at the existing handoff, not at landing.** After wall kick commitment expires, `_advance_wall()` explicitly retires `wall` and enters `jump`; ordinary steering may then use the candidate. A wall/climb/ledge release likewise eventually leaves freely steerable airborne locomotion. This changes post-handoff trajectory when horizontal intent is held; it does not change the preceding traversal commitment, release impulse or transition clock. Do not claim the complete post-wall-kick or post-traversal arc is identical. A new jump's horizontal path also changes intentionally while its vertical arc/budget remains unchanged.

## Independent formula replay

Unobstructed full digital input; initial velocity 0 for rest-to-cap and +218 for reversal; horizontal velocity is updated once per step with `move_toward`, and position uses that updated velocity. `dt` is exactly 1/60 or 1/120. First opposite motion means the first update with strictly negative velocity. Old-direction travel sums positive post-update velocities after the reverse input; it excludes the last movement tick before the reversal.

| Simulation rate | Acceleration | Rest to cap | First opposite motion | Opposite cap | Old-direction travel during reversal |
|---|---:|---:|---:|---:|---:|
| 60 Hz | 1450 | 166.67 ms | 166.67 ms | 316.67 ms | 14.575 px |
| 60 Hz | 2300 | 100.00 ms | 100.00 ms | 200.00 ms | 8.583 px |
| 120 Hz | 1450 | 158.33 ms | 158.33 ms | 308.33 ms | 15.481 px |
| 120 Hz | 2300 | 100.00 ms | 100.00 ms | 191.67 ms | 9.442 px |

The candidate reduces old-direction travel by roughly **39–41%** in this formula replay while retaining an acceleration ramp. This is the authored rationale for the single candidate; there is no evidence that it is a recovered optimum or an exact Dead Cells response. No separate air-reversal constant, cap increase, neutral stopping change or vertical retuning is needed for this comparison.

A neutral release from +218 over the first 100 ms remains **+206 px/s** and **21.10 px** of travel at 60 Hz / **21.15 px** at 120 Hz in both profiles. That continuing drift is deliberate in this bounded pass. Faster steering must not be described as faster neutral braking.

## Required validation outside this audit

Use actual Godot ticks to compare the M18-ground-only baseline and the M19 candidate at 60/120 Hz. Cover both signs for ordinary airborne start/reversal; neutral drift; analog targets; first and air jumps; walking off support; a held-input launch; jump release; hitpause/resume; blocked movement/input/zero scale; moving carriers; wall contact and floor landing. Independently compare vertical samples and airborne budgets, not only the final landing time.

Exercise the admission boundary with weapon windup/charge/active/recovery, shield phases, airborne roll recovery, dive, hurt/defeat, crouch/targeted-drop clearance, custom IDs and custom drivers borrowing ordinary IDs. Preserve the wall-kick commitment and sample its explicit return to ordinary jump separately. Verify ground traces remain the approved M18 traces. Label resulting data as runtime observations only after they actually run; these formula figures do not replace that evidence. The final feel decision remains the user's personal play test.

[repo]: https://github.com/N3rdL0rd/DeadCellsDecomp/tree/77c3ad263c4187ade6d048ba77bb61f79e6cec44
[hero]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/en/Hero.hx
[beheaded]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/en/hero/Beheaded.hx
[main]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/HeroMainSkill.hx
[jump]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/mainSkills/Jump.hx
[jumpb]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/mainSkills/JumpBeheaded.hx
[airjump]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/mainSkills/AirJump.hx
[airjumpb]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/mainSkills/AirJumpBeheaded.hx
[blackboard]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/mainSkills/blackboards/JumpBlackBoard.hx
[mainmanager]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/hero/HeroMainSkillsManager.hx
[weapon]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/Weapon.hx
[weaponmanager]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/hero/HeroWeaponsManager.hx

Implementation note: the completed M19 helper also explicitly checks input eligibility, effective movement permission and a positive move scale. Invalid optional resources fall back to the unchanged base acceleration. Actual engine and native observations are recorded separately in the M19 verification report.
