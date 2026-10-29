# MOKSHA combat PC: movement checkpoint

This module develops one reusable action-game character for MOKSHA. The target is Dead Cells-style combat movement: readable input, quick reversal, deliberate run/stop and landing poses, forgiving traversal, and a body that will share movement permissions with weapon and dodge actions. The first milestone implements locomotion and ledge actions. The second adds horizontal roll, one melee weapon, interruption and hurt/hitpause. These actions are coupled through an explicit authored permission matrix. The third adds targeted one-way drop and downward dive with impact/recovery. The fourth adds reusable ladder/vine traversal and supported detachment. The fifth adds a separately gated wall run, outward kick and ledge handoff, grounded in an observed developer demonstration. The sixth adds optional high-fall impact/recovery and a source-qualified live-dive-to-roll exception. The seventh corrects ordinary slope momentum/support. The eighth adds directional shield raise/parry/hold/recovery, accepted counters, ordinary projectile and rigid-prop reflection through replaceable adapters. The ninth adds a configurable fresh-press light chain with independent input, retention, strike, resource and interruption lifetimes. Remaining weapon/ability policies stay visible in COVERAGE.md.

The previous two-level game remains separately available. No Celeste movement system or special power is a design target here.

## What the reference actually establishes

The inspected Dead Cells revision is `N3rdL0rd/DeadCellsDecomp@77c3ad263c4187ade6d048ba77bb61f79e6cec44`, identifying PC v35. The complete audit contains30 consolidated behavior surfaces, per-function classifications and numerical evidence. It separates recovered bodies from declarations with missing consumers.

- **Recovered interfaces and small bodies:** `HeroMainSkill` has per-action input, interruption, wall-grab, upward one-way and body-size queries. The managers aggregate capabilities, but their arbitration bodies are absent. These support a per-action capability interface; they do not establish the final ordering or permission of every player action.
- **Declared locomotion structure:** Hero/Entity and Jump/AirJump/JumpDown/DodgeRoll/DiveAttack expose speed, acceleration, friction, jump, roll and traversal concepts. Core motor and many concrete action bodies are missing. These names do not reveal speeds or a complete state graph.
- **Primary developer behavior:** Sébastien Bénard describes double jump, late-jump forgiveness, assisted near-miss arrivals, responsive turnaround and aiming help. His2019 examples of2–3 frames of grace and roughly5 pixels of arrival assistance are historical approximations, not exact v35 constants.
- **Primary animation practice:** Thomas Vasseur describes strong pose-to-pose attack keys and timing changes made together with gameplay. Our wireframe joints, clips, durations and transition shapes are original MOKSHA work.

Reference links:

- [Main-action capabilities](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/HeroMainSkill.hx#L91)
- [Hero motor declaration and gaps](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/en/Hero.hx#L868)
- [Weapon skill and phase boundary](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/Weapon.hx#L275)
- [Developer control explanation](https://arstechnica.com/video/watch/dead-cells-how-to-avoid-falling-to-your-death-war-stories/?c=series)
- [Developer presentation, pages14–17](https://media.gdcvault.com/gdc2019/presentations/Benard-Sebastian-DeepCells.pdf)
- [Animation author's account](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-)

## Current movement acceptance

| Connected situation | Acceptance in this milestone |
|---|---|
| Press, release, reverse | Body accelerates quickly; braking produces a short visible drift; permitted facing follows new input immediately even while physical velocity is still reversing |
| Ground and air jump | Distinct takeoff and air-jump responses, finite jump budget, release response, airborne steering and landing reset |
| Near ledge and landing | Bounded late-jump/buffer assistance; no unsupported extra jump or repeated consumption of a held press |
| Body clearance | Crouch and standing shapes respect overhead clearance; slopes and one-way landings keep the body supported |
| Catch, hang, pull-up | Actual collision probes find a ledge; the root follows a swept vertical pull then horizontal step; neutral hang/release and blocked-headroom cases remain controllable |
| Moving or disappearing ledge | Contact is tracked in the support's space; losing support releases the actor; no invisible anchor or unbounded snap |
| Visual correspondence | Feet, hips, torso, head and hands express run/brake/turn, takeoff/apex/fall/landing, catch/hang/pull/step; presentation never changes facing or physics |
| Continuous flow | Native play must connect run→reverse→jump→catch→pull-up→air-jump→landing in both directions and expose failed transitions clearly |

## Tuning and engine boundary

All motor speeds, accelerations, braking rates, jump curves, buffers, dimensions and ledge timings in the MOKSHA profile are authored starting values. The original MOKSHA speed/jump/gravity values may seed them. A historical developer example may inform a candidate value, but does not turn it into a recovered v35 number. The numerical profile and measured outcomes belong together in the movement verification report.

Godot swept-body collision is an explicit implementation choice. The existing project uses120 physics ticks per second; validation also checks60 Hz behavior in seconds. Dead Cells' recovered wantedFPS60/tmod convention does not prove its missing fixed-update scheduler is identical to either Godot configuration.

No exact Dead Cells parity is claimed. Public developer explanations anchor feature intent; the available video has not supplied controlled-input quantitative measurements. Native MOKSHA testing verifies our implementation, not an original-game executable comparison.

## Reuse and ongoing passes

The PC scene owns its body and references its independent motion profile and wireframe view. The main-action capability interface and separate weapon permissions now support horizontal roll, attack windup/contact/recovery, direction restrictions and interruption without replacing the motor. Existing MOKSHA rigid-prop, hitpause and noise interfaces remain the game integration target. Wall-run and optional high-fall recovery now have bounded executable coverage. Parry, additional weapons and remaining ability-specific rules stay explicit in the full behavior map.

The official ModHelperSkin joint export is now documented in [animation data limits](reference/ANIMATION_DATA_LIMITS.md). Its existence is verified; actual versioned pose samples and playback semantics remain unrecovered here.


The wall reference and authored-policy boundary are detailed in [WALL_TRAVERSAL_CONTRACT.md](reference/WALL_TRAVERSAL_CONTRACT.md). Its source clip proves the connected traversal sequence, while the missing timing, slide, rearm and arbitration rules remain explicit MOKSHA choices.

The high-fall source and authored-policy boundary are detailed in [HARD_LANDING_CONTRACT.md](reference/HARD_LANDING_CONTRACT.md). Ordinary soft-slope collision now preserves incoming horizontal momentum and follows confirmed support through bounded sweeps. The correction is verified in soft_slope_verification.md; it repairs this Godot implementation rather than asserting recovered source behavior.
