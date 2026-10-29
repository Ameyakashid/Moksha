# Continued content development after v27

> **Historical scope record — superseded 2026-10-23:** The stop-expansion language and measurements below describe the earlier v27/Relay Works/Freight checkpoint, not the current work authorization. Subsequent authorized Rainline, Exchange, Freight, Warden and Cistern increments continue the meaningful-demo goal. Further bounded expansion is authorized as planned in `CAMPAIGN_EXPANSION_PLAN.md`; planned areas are not implemented. The no-padding and no-unmeasured-duration principles still apply. Preserve the historical text below as evidence, not as a current instruction to stop.


The delivered v27 source ZIP is an immutable checkpoint. Its two-minute optimized routes establish reachability, not the requested approximately thirty-minute demo. Continuation therefore focuses on meaningful playable depth, without rebranding current shortness as completion or padding with waiting/health.

## Module 1: Relay Works (isolated before integration)

A central hub gives access to three circuits using existing movement/combat/props/lifts. One small reusable addition, a physical relay shutter, makes restored circuits alter routes:

- Service west: approach over the locked low shortcut, drop into the shared prop/listener lane, restore service, return directly through the opened shutter.
- Lift circuit above: ladder/lift entry, a climb with real ranged platforms and an optional archive; restoration opens the low east passage.
- Dispatch east: raised ranged crossings with a lower recovery ledge/ladder, then the final relay opens the exit-side shutter. An initial floor-to-final-relay ladder bypassed the whole encounter and was removed before first-time native play.

Acceptance: ordinary-input completion in both sight states; each relay changes actual collision/reachable routes; no retry/shape/prop softlock; native visible/sonar readability; independent first-time play without map/bot knowledge. Record input/active time, discovery/decision time, pauses and tool latency separately. No estimated novice multiplier or unverified thirty-minute label.

Review scene: `demo/tests/relay_works_review.tscn`. It is not integrated into the main mission until component, route and native review pass.

## Decision after measurement

Use first-time navigation, repeated-route efficiency and failure points to decide the next bounded authored module or redesign. A larger space alone does not count as depth. Candidate next work is a linked return through a changed city/arcology route using existing mechanics, rather than another identical staircase. Any thirty-minute claim needs actual supported play evidence; any inability to measure must identify the concrete control/timing limitation.

Component acceptance: 68/68 shutter checks at 60/120 Hz; integrated module 30/30 checks; unchanged main mission 134/134 contracts. A test harness resumed from the physics-frame signal and hit [Godot issue122378](https://github.com/godotengine/godot/issues/122378); ordinary process-callback input dispatch is used for route UI actions. No production lift workaround is applied without a reproduced game defect.

Final ordinary-input matrix for the frozen candidate: retained 60 Hz 41.083 s, sacrificed 60 Hz 44.150 s, retained 120 Hz 40.875 s, sacrificed 120 Hz 37.417 s. All three circuits/shutters, archive and ending reached; zero deaths, retries, failures or warnings. Final health 48/60 retained, 36/60 sacrificed. These are optimized simulated-active timings, not first-time player duration. First-time native observation is pending, so module integration and the next content decision remain open.

## First-time CUA observations (in progress, not acceptance)
At about 52 seconds on the game clock, the fresh reviewer had found the lift-control region but no relays yet, was at 12/60 health, and had missed a return landing into Dispatch. Orange closed-shutter slats initially read as climbable ladders. Supported input holds worked, but movement distance per remote batch varied; continuous-action feel and human pacing cannot be inferred from that control method. Candidate remains frozen during the run. Queue a distinct shutter visual/tactile vocabulary after evidence, and distinguish a missed remote landing from a demonstrated reachability defect.

## Fresh supported-CUA observation / 2026-10-19
Final frozen candidate reached Service relay 1/3 at 1:23 game clock, then died returning. Retry restored60HP and reset relays. Earlier voluntary retry; one death; retained sight. Lift and Dispatch explored but not completed. Final run ~9m 23s wall versus1:24 HUD; ~45s requested gameplay holds, delivered time unknown. Earlier revision familiarization24 HUD seconds. Tool latency, paused decisions and unreliable short taps cannot be cleanly separated. This is neither human pacing nor evidence for30minutes.
Actionable findings: cross-braced SEALED doors now replace ladder-like slats; ground recovery direction signs added; pause help includes W/S ladders; retry text explicitly resets guards/relays/shutters. Original candidate hashes retained in evidence. CUA released before edits.

## Bounded final acceptance
Replace repetitive Listening Works with three-circuit Relay Works. Add one physical Freight Lock between Exchange and Cistern: real cargo placement, combat/flank/noise choices, recoverable lost cargo. Preserve opening/city, optional eye trade, sonar traversal, Warden and explicit ending. Complete direct/flank and retained/traded-sight tests, save/retry/ending regression and native visual review. Then stop content expansion. Thirty-minute target remains unmet; no guessed novice multiplier.

## Recovery acceptance before release
Full sacrificed-sight routing exposed a genuine closed-shutter floor pocket beneath the Lift circuit. Added a floor-to-gallery recovery ladder at x=1740. Four actual-fall routes (60/120Hz × retained/traded sight) now restore all circuits and finish. Auditing the other shutter compartments found the equivalent Dispatch far-right pocket; a ladder at x=3610 and a top shelf give an ordinary-input return above its shutter. These are recovery routes, not extra objectives or duration padding. Final compartment audit passes 24/24 with all three shutters held closed; integrated matrix follows these geometry fixes.
