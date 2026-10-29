# Level 4 — Memory Works

**Status:** seven authored districts; target 15–20 minutes, not measured or verified. No elapsed-time locks, inflated stats, or repeated waves. Player movement/combat unchanged. Layouts use the existing room format plus campaign objectives. Original art/logic remains separate.

## Beats and playable routes

1. **Receiving Desk (4400):** west inspection balcony holds the original manifest, east lower sorting bay the revision. Bring both to the comparison desk to physically release inspection. Optional upper margin grants vitality. Main walk: `(1300,300) → climb (1300,80) → original (1400,80) → revision (2780,300) → compare (3250,300) → exit`. Enemies cover different elevations rather than sealing the exit.
2. **Listening Floor (4800):** baffle service key is east `(2360,80)`, quiet bus west `(1240,80)`. Deliberate return makes the noise-court approach and shelter route matter. After recovering the service key, physically strike the surveillance breaker with J, then engage interlock `(3730,300)`. Floor pulses have upper bypasses. Spare props support noise diversion; none is a mandatory consumable. Optional calibration notes grant agility.
3. **Return to Sender (5000):** recover tag `(1530,160)`, use flat transfer deck for an intact marked carrier from `(2510,240)` to receiver `(3370,270)`, set receiver circuit 1, then install handoff at `(4100,300)`. Upper sentries can be flanked independently of cargo. Cradle reset is inherited from existing freight behavior. Optional courier note grants force.
4. **Memory Loom (5600):** independent west/east stacks hold contradictory records at `(2320,-250)` and `(4110,-250)`. Preserve both at `(4570,300)` to open the final door. Both stacks have full-height fixed recovery ladders; center lift is optional. Contradiction is evidence, not a definitive explanation of the loop. Optional service index grants vitality.
5. **Service Refuge (4700):** east key `(3370,25)` returns to shelter circuit `(1770,80)`, then opens crew pod `(2180,300)`. Evacuation changes pod/NPC state and releases departure. Side technician `(3900,80)` is optional, grants agility. Floor pulse is bypassed on the service balconies, including on the return journey.
6. **Three Crews (6400):** selectively reuses existing `demo/areas/relay_works.gd` exactly once, with campaign identity and waypoint data. Start at the hub, choose service west, machinery high, dispatch east in any order. Existing three relays physically open different shutters, not three identical E markers. Fixed return ladders remain independent of shortcut power.
7. **Unsent Order (5200):** optional west authorization stamp `(1800,-30)` grants agility; east reset-bus isolation `(3880,-30)`, center sealing desk `(2750,135)`. Preserve the order without transmitting it; physically release Crown approach. East pulse has upper bypass. Optional last-shift register grants force. A distinct departure Captain Keeper at `(4740,300)` uses the approved retreat/thrust encounter; only this captain is a mandatory combat lock, not every district guard. The sign cues attacking during recovery rather than following its retreat into a thrust. This does not make the final Crown decision for the player.

## Geometry and recovery contract

- Continuous floor at y=300 is a safe recovery surface, not a kill plane. Most platforms are one-way at thickness18; solid plinths explicitly exceed18.
- All required elevated goals have fixed ladder access. Movement between galleries is optional relative to using the floor/ladders; no blind-state speed bonus is required.
- Doors near district departure are downstream of all prerequisites. The freight shutter is the intended carrier interlock; no objective needed to release it is behind it.
- Every district has explicit supported `route` waypoint hints. They describe navigation intent, not teleporting proof or measured playthroughs.
- Signs describe branch destinations, return directions, cargo recovery and circuit target. Sonar/climb/collision remain shared production systems; both sight states require runtime QA.

## Validation performed

Godot4.6.3 loaded both authored level resources and enumerated14 districts. A standalone temporary harness checked duplicate district/local IDs, objective prerequisites, door prerequisites and support under every goal, enemy spawn and route waypoint: **0 failures**. This is static/runtime resource validation, **not** an input-driven complete route or15–20-minute duration validation. First test launch encountered sandbox user-data directory errors; rerun using writable XDG directories passed.

## Remaining integration checks

Check actual freight movement/reset, route target0 activation semantics, doors after death/reload, sonar-safe pulse routing, and real player traversal of every climb. Central runtime owns persistence, rewards, presentation, objective state and final narrative handling.

## Corrected-damage final isolated acceptance

On the frozen corrected runtime, all14 districts across levels4/5 passed at60Hz in both sight states (**28/28**), with live autonomous enemies and actual movement/combat/E/Q inputs after explicitly labeled initial district/sight fixtures. Start/end production-source hashes match, and the aggregate also verified those hashes against current files. Evidence: `campaign/route_tests_45/final/summary.json`; reproduce aggregation with `python campaign/route_tests_45/summarize.py`.

These runs include the actual strike-only breakers, intact multi-launch freight latches, mandatory Keeper and Warden encounters, and entry into the real final-choice state. They do not prove uninterrupted campaign continuity, save/Continue, choice resolution, or human15–20-minute timing. Summed optimized isolated routes are approximately4.2–5.0minutes per level, not a measured human session. Earlier diagnostics before the incoming-health receiver fix are explicitly archived as invalid survival evidence.
