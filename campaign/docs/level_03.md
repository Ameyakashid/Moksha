# Level 3 — Submerged Residences

Six independently checkpointed districts; **15–20 minutes is a design target only**. Preserve the tested player mechanics, physics and enemy stats. Cistern and Residential use deep-copied original dictionaries with additive local objectives, leaving the originals intact.

## Authored progression

1. **Cistern** retains its fixed wall route, optional maintenance lifts, flood relay and sheltered channel. Recover the current survey on the middle landing and fit its release key at the upper exit. Original flood control remains required. Waypoints: landing `(1370,145)` → original control `(1880,-320)` → sheltered/fixed route → release `(3510,-760)`. Use the inherited Cistern observer for the complete ladder/roof geometry; route hints do not replace actual support evidence.
2. **Inundated Market** puts the flood key on a western upper awning and isolation control on the central deck. Set isolation to its engraved target **2**, install the key on the eastern gallery, and release the family shelter. A locked dry passage really opens, but visual flooding/electrical arcs are not magically removed. Optional medicine record on the eastern upper shelf grants vitality. Route: ladder1460 → key `(1460,-90)` → isolation `(2180,40)` → lock `(2810,110)` → shelter `(3450,180)` → exit. Fixed ladders connect every main platform to the recovery floor.
3. **Waterline Clinic** requires two independently located items: sealed filter and assay record. Set purge **1**, install/validate both at the far clean-water manifold, then release the ward. This is a two-branch collection problem rather than repeating the market key. Optional central volunteer register and ground supply balance are separate discoveries. Route: filter `(1540,-80)` → purge `(2210,60)` → assay `(2800,-80)` → manifold `(3330,180)` → ward `(3950,240)`. The optional plate at `(3610,300)` has a spare prop nearby; destruction does not block progression.
4. **Upper Residential Crossing** preserves the existing hillside steps and rooftop/service alternatives. A refuge register on the early roof unlocks an actual courtyard shelter; release it before returning to the upper roof passage terminal. This gives the previously optional lower courtyard a civic purpose, not another relay. Route: register `(1850,-30)` → courtyard `(2940,300)` → roof passage `(4450,-30)` → original exit `(-85 high)`. Existing fixed ladders and two-way retaining steps are unchanged.
5. **Refuge Terraces** is an elevated ridge with a full lower recovery lane. Recover the manual handle above the first terraces, set roof feed **2**, open the crossing interlock, release upper residents, and hand the beacon to local control. Optional garden stores above the ridge reward vitality. Route: handle `(1490,-60)` → feed `(2670,10)` → crossing `(3230,70)` → refuge `(3890,130)` → beacon `(4320,190)`. No platform movement or new player mechanic is required.
6. **Drainage Commons** closes the local arc with opposed branches and a central return: map on the high western shelf, west switch **1**, east switch **2**, then reconnect the middle controller before releasing the watch and recording the handoff. Physical gate at x3180 is after all needed branch controls. Route: map `(1570,-100)` → west `(1650,90)` → east `(2910,90)` → return to center `(2220,10)` → crew `(3500,170)` → handoff `(4050,245)`. Optional maintenance wraps on the eastern upper shelf reward force. The new ending is a transition toward memory works, not a retcon of unresolved overall lore.

## Recovery and acceptance boundaries

- Every new main gallery has a fixed recovery ladder; secret shelves have ladders based on real gallery supports. Ground arcs have safe staging and permanent upper bypasses, no mandatory waiting.
- All57 L2/L3 objectives combined passed local reference/support checks; L3 specifically contains30. Mandatory objectives never depend on optional rewards or a fragile plate prop.
- Every district has at least one actual objective-controlled StaticBody door plus its exit requirement. E interactions are not presented as physics simulation of pumps/flooding; their verified physical effect is opening the lock or rescue pod via runtime.
- Godot4.6.3 parses both authored level scripts. Input-driven traversal, two-sight-state readability, waypoint navigation and completion have **not** yet been validated by these checks. Use ordinary controller inputs, no teleport/health/goal writes, and verify actual collisions when the runtime is integrated.
- Human playtime remains unmeasured; no footprint-to-minutes conversion or bot-time multiplier is justified.

## Mechanics revision after first input routes

Drainage `west` is now a **physical breaker** (seized west sluice lock), requiring actual J contact rather than cycling another switch. East remains route target2; install requires map, broken west lock and east circuit. Drainage crew rescue is an optional vitality branch; handoff depends directly on the connected drainage link. Refuge's final beacon handoff is optional agility, and its final physical door depends on resident rescue. The clinic and refuge retain rescues as primary outcomes, while other districts vary their progression rather than repeating a uniform E chain.

These revisions need new input-run evidence. Earlier successful routes only establish their earlier layout/runtime versions.

## District captain

Drainage Commons adds one **Lancer** at(3730,300), on the exposed ground approach before the final raised platform. Its actual charge has a commitment and recovery window: parry or evade the charge, then strike during recovery. Existing gallery ladders remain retreat paths. Only this captain must be defeated for the seal, not every guard. This is a shared-controller encounter, not an extra E terminal or repeated Warden. Earlier completion reports do not prove the new encounter; fresh real-input runs are required.
