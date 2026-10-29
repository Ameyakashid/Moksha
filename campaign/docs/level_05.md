# Level 5 — The Crown

**Status:** seven authored districts, target15–20 minutes; no verified duration claim. Six preparation/confrontation spaces plus a substantial quiet final threshold. Only one final Warden; no five-boss reskin loop. Final mutually exclusive decision/ending belongs to the campaign host after `crown_choice_threshold`, not to a fake level-exit label.

## Beats and walkthrough

1. **Above the Machines (4600):** a rising exterior spine with lower maintenance balconies. Fuse at `(2970,135)` installs into intake `(4050,-250)`, opening the elevated Crown gate. Seven floor-to-gallery ladders make falls recoverable and the moving lift optional. Optional weather log `(1940,25)` grants agility; its ambiguous duplicate storm entry does not establish a canonical time-loop explanation.
2. **Witness Galleries (5200):** low public record `(1330,190)` and high sealed dissent `(3900,-250)` feed a shared preservation console `(4150,300)`. Neither account overwrites the other. Fixed access/recovery at west balcony and east stacks. Optional letter `(4460,-140)` grants vitality.
3. **Manual Governor (5500):** central spawn/service desk `(2600,300)`; optional west bypass tool `(650,80)` grants force; independent strike-only authority breaker (J) at `(1230,25)` and east local supply2 at `(4050,25)`. Return to governor `(2710,300)` to release manual route. Two pulse strips encourage upper loops, not mandatory waits. Optional tool roll `(5040,135)` grants force.
4. **Before the Silence (4800):** key `(1620,80)` plus refuge circuit1 `(3170,25)` connect independent exit `(2530,300)`, then rescue occupied refuge `(3610,300)`. Opening the pod is consequential: evacuation gates the Crown approach. Side shelter `(4200,135)` is optional vitality. No claim that the machine alone can decide who leaves.
5. **Last Service Run (5300):** tag `(1180,80)`, flat cargo transport `(2150,240) → receiver (3010,270)`, diversion2 `(4160,-30)`, cold-service interlock `(4650,300)`. The second cargo use changes context: protect cooling/evacuation while denying automatic restart. Sentries occupy cover routes above cargo; floor pulse comes after transfer and has a fixed bypass. Optional service plan `(2230,15)` grants agility.
6. **Last Authority (4200):** approach key `(1200,80)` opens dais `(1850,300)` before the sole Warden confrontation. Solid plinths and two short maintenance loops break sightlines; lower floor stays connected. Outer watch provides approach encounters, not repeated waves. Existing roster/stats remain untouched. This one district uses the existing boss all-enemy gate. Optional Warden record `(2880,-40)` grants force and describes unrevised appointment, not immortal identity.
7. **A Choice Without an Order (4000):** no compulsory enemies; independent evacuation1 `(1200,135)` and preserved contradictory record `(2900,80)` unlock manual controls `(2340,135)`. Actual objective door at x3750 opens the final threshold. Optional blank page `(3510,135)` is a narrative gesture without stat reward. The final choice itself must be shown and resolved by the host; safeguards are not the choice.

## Finale contract

`crown_choice_threshold` is the last authored sector. On its completion the central host should offer its real distinct ending choices and preserve them. It should acknowledge the independent evacuation and unedited records. Do not assert the protagonist is immortal, the loop is broken forever, or one contested account is canon. These layouts intentionally leave those questions open.

## Recovery and accessibility

The floor is a recovery surface throughout. Required upper goals have fixed ladders, not lift timing or traded sight-speed requirements. Ground door interlocks lie after their required goals; final boss door is operated from the approach side. The exterior gate is supported by its full-width landing at y=-250. Optional pickups never block exit. Explicit routes contain supported points; signs label key branches and returns. Blind-mode practical legibility and enemy-pressure tests remain integration work.

## Validation

Godot4.6.3 loaded both new level resources:14 districts; unique IDs, valid references, supported objectives/enemies/route waypoints; **0 failures**. This confirms data and support geometry only. Full input-driven routing, freight handling, checkpoint persistence, final-choice execution, and measured level duration remain unverified. No timer padding or combat-stat changes were introduced.

## Corrected-damage final isolated acceptance

On the frozen corrected runtime, all14 districts across levels4/5 passed at60Hz in both sight states (**28/28**), with live autonomous enemies and actual movement/combat/E/Q inputs after explicitly labeled initial district/sight fixtures. Start/end production-source hashes match, and the aggregate also verified those hashes against current files. Evidence: `campaign/route_tests_45/final/summary.json`; reproduce aggregation with `python campaign/route_tests_45/summarize.py`.

These runs include the actual strike-only breakers, intact multi-launch freight latches, mandatory Keeper and Warden encounters, and entry into the real final-choice state. They do not prove uninterrupted campaign continuity, save/Continue, choice resolution, or human15–20-minute timing. Summed optimized isolated routes are approximately4.2–5.0minutes per level, not a measured human session. Earlier diagnostics before the incoming-health receiver fix are explicitly archived as invalid survival evidence.
