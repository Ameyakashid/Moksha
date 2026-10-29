# Dead Cells movement and combat reference audit
Read-only research, 2026-10-04. **Target: Dead Cells behavior for the original MOKSHA reusable combat PC. No substitute game's controller is the implementation target.**

## Result
The pinned Dead Cells repository is useful evidence for the actual class boundaries, collision categories, timing conventions and a small number of implemented helpers. It is not a recovered complete player motor. We inspected 52 targeted source files and classified 1,715 function declarations rather than treating filenames or empty signatures as implementations. The resulting map below preserves the full requested movement/combat scope while identifying each missing contract.

This supports an independently authored, Dead Cells-grounded MOKSHA controller with explicitly labeled tuning and observation gaps. It does not support claiming a literal or frame-identical port. No game executable, original asset pack, ROM or decompiler was downloaded or run; no gameplay implementation was changed by this audit.

## Source and version ledger
- Public repo: https://github.com/N3rdL0rd/DeadCellsDecomp
- Pinned revision: `77c3ad263c4187ade6d048ba77bb61f79e6cec44`; main still points here; branch enumeration returned only main
- [Pinned README](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/README.md) identifies PC v35, build `50edff4`
- Tree inspection returned all 1,888 entries without truncation
- [Root LICENSE](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/LICENSE) is MIT attributed to the repository author. The same pinned README says the copyrighted game decompilation is not open-source licensed. This conflict does not establish permission from Motion Twin/Evil Empire to transplant the game's implementation. Use behavior analysis and independent code, with no proprietary code/assets in the deliverable
- [Getting-started guide](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/docs/gettingstarted.md) says the project does not compile, but later commit history contains a clean-build claim and the checked-in opcode comparison implies partial recompilation. **Do not repeat non-compiling as a verified current fact.** No build was run here
- [Progress report](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/docs/progress/index.html) reports 2,547/20,412 byte-matched functions, 15.8% mean opcode score and zero files marked complete. These are the project's own archived measures, not our test results, and not a percentage of recovered movement
- The resource directory contains only .gitkeep. No original player clip timelines, frame-event data or game tuning database was recovered
- Primary developer accounts below date from 2018–2019; official patch notes supply later examples. Historical descriptions are not automatically exact v35 constants

## Evidence labels
- **BODY:** inspected nonempty method implementation. This still is a WIP decompilation, not independent runtime equivalence proof
- **CALL:** implemented wrapper/delegation with a missing callee; confirms a dependency, not its full behavior
- **DECL:** class, field, enum, signature or empty/stub body; confirms a named concept only
- **PRIMARY:** developer's own explanation or official patch note, with date/version context
- **MEASURE:** observable reference-video/capture work still needed for quantitative or pose claims
- **MOKSHA:** proposed original design/tuning or requirement from the user's project; never relabel it as recovered Dead Cells

Companion files:
- FUNCTION_COVERAGE.json: per-file class identities, method classification, source line range, pinned link and blob hash. Multiple classes in one Haxe file are retained
- PARAMETER_EVIDENCE.json: recovered numerical facts, precise meanings, and the inference they do NOT permit
- DEAD_CELLS_COMBAT_AUDIT.md: builder's independent narrow weapon/skill audit, incorporated below

## Actual dependency shape
The Beheaded uses Hero and Entity, plus separate main-skill, weapon and active-skill managers. Locomotion-related main skills include Jump/JumpBeheaded, AirJump/AirJumpBeheaded, JumpDown, Dodge/DodgeRoll and DiveAttack. They are not the same thing as an eight-entry player state machine.

[CollisionMode](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/CollisionMode.hx) declares Normal, All, None, Ladder, Pully, WallGrab, IgnoreOneWay and IgnoreWalls. [ColType](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/level/ColType.hx) declares Empty, Plain, OneWay, Ladder, RollZone, Invisible and left/right slopes. These are collision categories, not proof of algorithms or transitions.

WeaponSkill exists as a secondary class inside [Weapon.hx](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/Weapon.hx#L275-L285), extending OldSkill. Its standalone filename is absent, but the class is not missing. Skill is a different class; its owner-lock wrappers must not be attributed to WeaponSkill without a verified caller. BaseMelee.hx was not found in the full tree.

## Complete requested mechanic/gap map

| PC surface | Actual inspected evidence | What remains unavailable / must be observed or authored |
|---|---|---|
| Ground run and acceleration | DECL: Hero.runSpd, accelFactor, frameWalkSpd, walkCycle, runFrames, speedComboRun; Entity.dx,frict,tempFrict. [Hero.fixedUpdate](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/en/Hero.hx#L868-L869) is empty | Run cap, acceleration curve, input priority, ground/air distinction, speed-combo trigger/expiry |
| Braking, reversal, stopping | DECL: direction, recoil and run fields; [triggerOnStopAffixes](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/en/Hero.hx#L666-L667) empty; [getRunAnimId](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/en/hero/Beheaded.hx#L33-L35) stub | Stop distance/time, reversal response, foot plant/brake/turn pose keys and transition timing. Do not borrow a skid rule |
| Movement/control lock | BODY: [moveControlled](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/en/Hero.hx#L600-L602) checks a hashed cooldown key. Beheaded override is a stub. CALL/DECL: cancelSkillControlLock, charging/movement permission surfaces | Meaning and lifecycle of that key, which states/weapons lock what, priority between release/reversal/attack |
| Crouch and small-body collision | DECL: Hero.bodyHei,crouchHei,smallHitbox; [updateBodyHeight](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/en/Hero.hx#L643-L644) empty; skill shouldHaveSmallHitbox and canJumpThroughUp gates mostly stubs | Exact standing/crouched dimensions, clearance checks, transition/cancel rules, roll-to-crouch exit |
| Normal jump | DECL: Jump.holdNormalJumpLock and blackboard; [normalJump](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/mainSkills/Jump.hx#L29-L30) and [normalJump](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/mainSkills/JumpBeheaded.hx#L14-L15) empty | Impulse, grace consumption, launch pose, horizontal inheritance, gravity and apex/landing timing |
| Variable jump/hold behavior | DECL: Jump hold lock, JumpBeheaded.jumpExtra, blackboard.isHoldJumpLock; passiveFixedUpdate missing | Whether/how hold changes ascent in this build; early-release curve and lock duration. Hold-to-jump accessibility is not proof of variable-height physics |
| Double/air jump | DECL: AirJump and shared blackboard; CALL: [onStartClimbing](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/mainSkills/AirJump.hx#L44-L46) calls set_airJumps(0), but setter missing. PRIMARY: developer slide says double jump is available from outset | Air-jump impulse, count semantics, reset cases, input edge consumption and animation. A call to set_airJumps(0) does not by itself prove remaining-vs-used counter meaning |
| Input buffering and held repeat | DECL: Controller has pressTimers,framePresses,needRelease,longPressLock; controller update/query logic incomplete. PRIMARY: v29 added hold-to-jump/roll, v34.1 fixed auto-consumed double jump | Exact buffer length, simultaneous-action priorities and whether queued input survives hitpause/landing. Preserve MOKSHA's tested input capture as its own contract |
| Off-edge/coyote grace | PRIMARY: Bénard's 2019 interview gives an approximate two-to-three-frame late-jump example | Exact v35 threshold and eligibility/exclusions; historical estimate must remain labeled |
| Assisted arrival/edge snap | PRIMARY: developer describes forgiving near-miss arrivals; slide lists arrival adjustments by snap, hop or climb | Probe geometry, direction tests, safe-landing/hazard restrictions, thresholds and priority |
| Ledge grab, hang, mantle/pull-up | DECL: WallGrab/Pully collision modes, Hero.climbPhase,climbPushDir; [startHoldPull](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/en/Hero.hx#L790-L791), startClimbing and stopClimbing are empty. PRIMARY confirms assisted climbing at arrivals | Separate hanging vs automatic pull-up, mantle path, clearance, interruptibility, duration, root offset and pose sequence. Do not invent an instant teleport and call it a recovered mantle |
| Wall climbing / unlock | DECL: wall-grab permission surfaces; concrete predicates absent. PRIMARY: official updates refer to wall-run mechanics/animations and Spider Rune-gated level access | Rune predicate, wall-run impulse/duration, wall slide/reattach/jump rules and exhaustion behavior. Do not import stamina climbing |
| Ladders/vines and top/bottom exits | DECL: Ladder collision mode/type; climb methods and exitLadderTop empty. PRIMARY: official patch1 improved ladder-top grab and jump exits | Enter/exit alignment, acceleration, step pose timing, cancellation, lock precedence |
| Drop-through one-way platforms | DECL: JumpDown, IgnoreOneWay, holdNormalJumpLock; [jumpDown](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/mainSkills/JumpDown.hx#L30-L31) empty. PRIMARY: official patches discuss drop-through and fixed roll+drop wall bypass | Which input, temporary ignore duration/target platform, falling/layer logic and solid-wall safety |
| Horizontal dodge/roll travel | DECL: DodgeRoll active update/start/end/applyDodgeMovement/applyEndDodgeMovement missing; stopDodgeOnCliff field | Speed curve, distance, direction latch/reversal, airborne variant, cooldown, collider shrink and exit velocity |
| Roll invulnerability | DECL: Dodge perfectDodge/onOwnerDamaged, Hero.get_isRollParry and relevant damage handlers missing. Official balance notes distinguish attacks that are not rollable | Exact i-frame interval, exception categories, invulnerability-vs-hitbox distinction. No total roll duration recovered |
| Roll interruption/cancel | BODY: [getNoDodgeCancelRatio](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/mainSkills/DodgeRoll.hx#L42-L44) returns0.25. Consumer and dodgeCancelCpt logic missing | Which action can cancel, when ratio applies, how cancellation changes cooldown/invulnerability/momentum. It is NOT proven to mean a quarter-duration lock for all actions |
| Roll landing | BODY: [onOwnerLand](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/mainSkills/DodgeRoll.hx#L62-L67) adds facing×0.2 to dx if active | Native dx-to-pixels/s conversion, exact active window and whether other landing logic overrides it |
| Dive/stomp | DECL: DiveAttack start/activeFixedUpdate/isDiving/land/end/cancel/interrupt hooks missing | Startup/downward velocity, floor breakthrough, impact stun/cancel and height thresholds |
| Hard landing / stun / roll exit | DECL: isFallingTooFast, fallStartY, fatal-fall and land handlers. PRIMARY patch14.6 describes a roll-during-stomp exception to high-fall stun | Thresholds, stun duration, exact impact transition and priority. This exception is not blanket fall immunity |
| Ceiling, wall, ground and slopes | BODY: [onTouchCeil](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/Entity.hx#L878-L881) clears bump-Y and scales dy by0.8. DECL: slopeCollisionHandling,updatePositionXY,fixedUpdate and Hero contact hooks missing | Sweeps/step order, overlap tests, corner/step correction, one-way crossings, actual grounding. Enum names do not supply those |
| Knockback / recoil / hitpause | BODY: [recoil](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/Entity.hx#L562-L564) stores recoilX; DECL: bdx,bdy,bumpFrict,gravityFrict, Boot.slowMo/cancelSlowMo (not complete) | Knockback integration/resistance, hitpause scope/duration and buffered-input retention. MOKSHA's existing hitpause is not a recovered Dead Cells implementation |
| Attack owner movement | DECL: OldSkill.canMoveDuringCharge/control-lock/charge/cooldown/hitFrame/animation flags; actual prepare/execute/update missing; Weapon.airControlOwner empty | Phase-dependent movement multipliers, facing locks, jump/dodge allowance and air-control behavior |
| Attack phase cancel/combo | DECL: OldSkill.interrupt and Weapon.tryToCancel/canCancel/chain logic missing. BODY: BroadSword cycle0 clears crit feedback, not combo timing. PRIMARY confirms active-skill cancels and deliberate weapon-specific cancel fixes | Complete action-by-phase cancel matrix, transitions, combo buffer, recovery ownership, weapon-specific restrictions |
| Shield hold / cancel / parry | BODY: BaseShield refuses tryToCancel when canBeHeld=false, otherwise CALL to missing base logic; counter dispatch implemented | Hold/parry durations, successful cancellation conditions, movement/invulnerability effect, numeric tag meaning. Do not infer a parry window from the counter callback |
| Combat facing / auto-aim | BODY: Weapon.allowTurnDuringCharge default true; concrete overrides may differ. PRIMARY GDC describes free turnaround and auto-aim | Exact per-weapon turn-lock moments, target selection range/priority and lockout exceptions |
| Animation state selection/transitions | DECL: AnimManager StateAnim priority/condition/speed/loop; Transition from/to/anim/condition/speed/reverse; register/apply/update consumers missing; Hero/Beheaded initAnims missing | Every actual priority predicate, state-to-clip mapping, run/stop/turn graph, interruption/resume rules and clip lengths |
| Root/attachment animation tracks | DECL: Hero.animationTracks; AnimationTrack x/y methods are stubs. HSprite frame/group/animation access incomplete | Per-frame roots, weapon/hand/body attachment tracks, hitFrame interpretation, footstep events |
| Readability and expressive poses | PRIMARY: Vasseur details timed pose-to-pose attack keys and iterative timing changes to fit gameplay | Original run/reversal/roll/ledge pose coordinates and counts are absent. Author wireframe clips deliberately; label their frame data as original MOKSHA art |
| Physics props / noise interface | MOKSHA contract from the builder, with existing rigid props, occluded strikes and noise behavior to preserve | This audit does not establish a Dead Cells rigid-body/noise API. Integrate with MOKSHA's own interfaces and tests |

## Useful recovered facts, with strict interpretation
1. [Entity position getters](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/Entity.hx#L155-L157) use a24-unit cell plus fractional coordinate. This is not a recovered collision solver or character width.
2. [Boot.init](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/Boot.hx#L172-L205) sets wantedFPS60, timer smoothing0 and max delta0.1. [Boot.update](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/Boot.hx#L255-L300) derives tmod from elapsed dt×wantedFPS. This is a nominal timing convention; it does not prove one fixed tick per displayed frame.
3. [secToFrames](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/HeroMainSkill.hx#L20-L22) uses that wantedFPS. Its generic unserialize defaults duration/cooldown1 are defaults, NOT roll/jump timings.
4. [canUpdate](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/Entity.hx#L276-L284) distinguishes always-updated entities, out-of-game and freeze flags. Missing scheduler bodies prevent reconstructing full ordering from this predicate.
5. [onTouchCeil](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/Entity.hx#L878-L881) retains80% of native dy after zeroing bdy; a port that simply zeroes vertical speed is not derived from this particular helper. Its call conditions remain missing.
6. DodgeRoll's0.25 getter and0.2 landing boost are isolated recovered facts. Never convert them into complete roll timing without the consumer.
7. [suspendForF](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/libs/heaps/slib/AnimManager.hx#L172-L175) stores requested frames+1; suspend/unsuspend and clearing overlap have bodies. The missing animation update means the exact effective pause duration/order is still unproven.

## Primary developer/official behavior evidence
### Developer postmortem, 2019
[Official GDC slides](https://media.gdcvault.com/gdc2019/presentations/Benard-Sebastian-DeepCells.pdf), especially pages14–17, describe late-jump forgiveness, assisted arrivals, immediate access to double jump, turnaround and aiming assistance. These support intent and feature selection, not v35 numeric motor values.

[Recorded GDC talk](https://www.youtube.com/watch?v=OfSpBoA6TWw) is verified as the GDC-published talk by Sébastien Bénard. The browser's auto-generated chapter list locates Control Tricks14:41, Traversal Without Helpers17:11, and Combat18:23. These are navigation markers, not frame measurements. In this session the player remained buffering and the transcript panel loading; no visual pose-timing measurement is claimed.

[Developer interview and transcript](https://arstechnica.com/video/watch/dead-cells-how-to-avoid-falling-to-your-death-war-stories/?c=series), July2019: Bénard gives approximate2–3-frame off-edge grace and a roughly5-pixel arrival near-miss example. Treat these as historical illustrations, not exact v35 constants. The emphasis is on leaving the challenge in combat rather than accidental traversal failure.

### Animation author, 2018
[Thomas Vasseur's own animation pipeline article](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-) explains that attacks are constructed around strong, correctly timed key poses, with interpolation before/after key poses rather than between them; effects reinforce impact. Timings and poses were repeatedly adjusted together for gameplay. This supports purposeful authored wireframe timing rather than smooth interpolation everywhere. The article's30fps comment is in discussion of the earlier prototype workflow; do not present it as a universal Dead Cells gameplay tick or every current clip's rate.

### Official change history (existence/interactions, not a current complete specification)
- [Patch1](https://deadcells.com/patchnotes/1): active skills can cancel attacks; rolls break doors; ladder-top ergonomics improved
- [Patch2](https://deadcells.com/patchnotes/2): roll-plus-drop-through must not bypass solid walls
- [Patch5](https://deadcells.com/patchnotes/5): wall-run animation revisions confirm this has a distinct presentation surface
- [Patch14](https://deadcells.com/patchnotes/14): rolling while still stomping can avoid high-fall stun only during the roll; climbing/water/duck interactions also received fixes
- [Patch29](https://deadcells.com/patchnotes/29): hold-to-jump/hold-to-roll are options; auto-jump was prevented from triggering on ladders
- [Patch33](https://deadcells.com/patchnotes/33): Spider Rune-dependent access fixes and restoration of a Katana cancel technique show unlock/weapon-specific exceptions
- [Patch34](https://deadcells.com/patchnotes/34): hold-to-jump double-jump consumption fix; some fire pillars explicitly made non-rollable
- [Patch35](https://deadcells.com/patchnotes/): movement/weapon-direction and drop-through fixes demonstrate that timing/interaction behavior can vary within the target major version

## What is still needed for honest high-fidelity reconstruction
The code map is now complete for the requested surfaces, including missing implementation locations. The game's behaviors themselves are not all recovered. Exact-feel claims require either authorized inspection of a matching owned build's missing code/data or version-identified gameplay captures with controlled input. Public footage can anchor visible behavior but cannot prove invisible i-frame/cancel rules without a suitable demonstrated interaction.

Minimum observation/capture matrix:
1. Flat ground: press, hold, release, opposite-direction press; track time-to-speed, stop/reversal distance, root/feet/torso/arms and stop-to-idle transitions
2. Jump: tap/hold/release at multiple ascent times, off-edge late press, landing buffer, air reversal, first/second jump, low ceiling
3. Ledges: short/tall fronts, corner near-miss, low overhead, moving-away input, hang/pull-up interruptions, collision/hazard clearance
4. Roll: ground/air, release/opposite input, wall/low tunnel/cliff, jump/attack/skill interruptions at every phase, landing while active, cooldown vs vulnerability interval
5. Climb: with/without Spider Rune, wall approach at different vertical speeds, wall-run end, reattach, wall-jump, ladder top/bottom and drop-through
6. Combat: each representative weapon's charge/active/recovery vs move/turn/jump/roll/block/skill; hits/misses/occlusion; hitpause with held/fresh input; props/knockback
7. Pose transition review: idle→run, run→stop, run→turn, takeoff→rise→apex→fall→land, land→run/roll/attack, roll→stand/crouch/air, ledge grab→hang→pull-up, each attack's anticipation/contact/follow-through

For every observed value, record game build, settings, FPS/source playback rate, timestamp/frame range, input sequence and uncertainty. Tune MOKSHA in its own source scale and mark authored parameters as MOKSHA. Do not silently fill gaps with another game's numbers, states, collision logic or animation graph.


## Main-skill capability defaults are not final player policy
[HeroMainSkill base](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/HeroMainSkill.hx#L91-L174) contains real default-return bodies:
- isUsingInputs=true; canBeInterruptedBy=true
- shouldHaveSmallHitbox=false
- canWallGrab=true; canJumpThroughUp=true
- canPreventStuckInWall=false; canBreakDoors=false; canBreakTiles=false
- canUseInteractive=true; isItemUseful=true
- isActive tests a hashed cooldown entry, while start/end/cancel and activity lifecycle consumers remain incomplete

These defaults do not mean the Beheaded can wall-grab, change hitbox or cancel every action at any time. [DodgeRoll](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/mainSkills/DodgeRoll.hx#L73-L101) overrides small-hitbox, wall-grab, upward-one-way, anti-stuck and door/tile break queries, but those override bodies are stubs. [DiveAttack](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/mainSkills/DiveAttack.hx) overrides interruption with a stub. [HeroMainSkillsManager](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/hero/HeroMainSkillsManager.hx) declares capability aggregation and tryInterruptBy, all unavailable. Hero's top-level wall-grab/jump-through checks are also stubs.

[RichterDodge](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/mainSkills/RichterDodge.hx) has a real canWallGrab result depending on inactive dodge, but Richter is a different playable-character path; do not apply this override as the Beheaded's recovered rule.

The supported architecture inference is a per-action capability contract and a separate arbitration layer, alongside weapon charge/execution/cooldown/control-lock state. Actual arbitration order, override resolution, conflicting actions and transition rules remain missing. Authoring those for MOKSHA is legitimate project design, but must not be described as recovered Dead Cells policy.

## Implementation handoff boundary
Preserve the requested integrated combat controller scope: fast grounded locomotion, expressive stop/reversal/landing/ledge actions, horizontal dodge/roll, jumps and movement assists, weapon phase/cancel/facing interactions, hitpause/knockback and the existing physics-prop/noise interfaces. Keep body evidence, developer design evidence, measurements and original tuning separately traceable. A successfully running demo or a large test count must not be described as exact Dead Cells parity while these gaps remain.
