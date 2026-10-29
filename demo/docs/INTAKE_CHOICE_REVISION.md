# Quarantine Intake: bounded route-choice revision

## Why this is a design change, not a repair
The delivered Intake deliberately used `lock: true`: the onward marker required both the relay and all eight guards defeated. CONTENT_BUDGET describes its lower relay detour and guarded crossing; SENTINEL_CONTRACT records that the historical successful route did not board the x1540 ladder from the floor, where the adjacent block obstructed alignment. Those were authored conditions, not an actor-controller defect. This revision intentionally replaces the combat seal with an objective-led exit, retaining ordinary danger and shared rules.

## Changed composition only
- Sector remains index1, title02, width2400, gate at(2355,-280), same relay(1430,230), same cache(1110,80), same eight enemy specifications, props, platform list and archive.
- Existing lower lane presents close combat and prop contacts. The pre-existing upper steps provide a cache-bearing sentry approach. Both converge on the same relay; no second objective or repeated wave.
- Newly placed **existing** relay-shutter asset at(1730,-130), size(24,260), blocks the upper onward crossing until the relay opens it. It is not globally unbypassable. The logical onward interaction still requires the relay even if someone crosses above/below it.
- The floor underneath stays open: a missed right-side landing can return left under the closed shutter. Existing recovery ladder axis moves from1540 to1580 so its floor approach no longer intersects the block edge. No controller change.
- Signs explain branches, relay and recovery. No health/damage/speed/stat changes, time gates, spawned waves, or other-sector changes.

## Player decisions
Fight through the ground approach versus climb past lower guards toward the exposed cache route; stop for the cache or drop toward the relay; confront upper guards or keep moving after restoring the objective. Enemies remain active when bypassed. Route success does not require pacifism or promise zero damage.

## Evidence boundaries
`demo/tests/intake_route_bot.gd` extends the preserved full-route observer. It injects only approach waypoints into the navigation target: normal route initialization uses original sector spawn; measured movement, fighting, relay and exit use raw production inputs/proximity interactions. Both approaches must reach spatially different supported waypoints; upper must exit with at least one living guard. Parent observer tests pause/resume and records actual damage receipts.

Recovery-left requests a real descent from upper approach onto the lower floor before relay. Recovery-right explicitly stages only initial spawn on a right upper platform, then requests actual descent, return underneath the still-closed shutter, relay and onward passage. This is a labelled recovery fixture, **not** a complete start-to-finish route or unmodified mission spawn.

Lifecycle tests use separately labelled direct-state placements to isolate interaction bounds, shutter collision, retry, cache and Continue. These are not substituted for ordinary-input route proof. Native review/video is separate from headless evidence. Optimized bot seconds are reachability/performance measurements, never human duration. This increment is not a claim that the demo lasts thirty minutes.

## Run
Open `demo/tests/intake_review.tscn` and F6 for ordinary manual review starting at sector2, save disabled. Canonical project main remains mission. Headless route examples:

    godot --headless --path . --script demo/tests/intake_route_bot.gd -- --hz=60 --approach=upper
    godot --headless --path . --script demo/tests/intake_route_bot.gd -- --hz=120 --approach=lower
    godot --headless --path . --script demo/tests/intake_route_bot.gd -- --hz=60 --approach=upper --recovery=left
    godot --headless --path . --script demo/tests/intake_route_bot.gd -- --hz=120 --approach=upper --recovery=right

Use an isolated XDG user-data directory. Do not run two observers at the same rate concurrently: the inherited observer first writes its rate-specific diagnostic report before the Intake subclass writes the uniquely named final report.

## Fresh isolated results (2026-10-20)

All eight input routes passed with zero deaths; baseline source stayed unchanged during each run.

| Route / fixture | Hz | Active seconds to onward | Guards alive |
|---|---:|---:|---:|
| lower | 120.0 | 27.17 | 2 |
| lower | 60.0 | 27.82 | 3 |
| upper | 120.0 | 27.39 | 3 |
| upper / staged left recovery | 120.0 | 27.17 | 3 |
| upper / staged right recovery | 120.0 | 21.73 | 4 |
| upper | 60.0 | 28.80 | 4 |
| upper / staged left recovery | 60.0 | 28.53 | 4 |
| upper / staged right recovery | 60.0 | 24.38 | 5 |

The right recovery initial spawn is staged; normal and left routes start at the original spawn. Both recovery floor events occurred with the shutter still closed. The upper route bot sometimes misses the onward landing and returns by floor/ladder; this is real recoverability, not a claim of polished human control. Independent lifecycle29/29 at each rate and full-mission/native review are separately reported by the integration owner. Preliminary `attempt01` reports preserve the rejected tall-shutter experiment and are not evidence for final geometry.
