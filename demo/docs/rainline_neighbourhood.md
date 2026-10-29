# Rainline neighbourhood — opening assembly candidate

This is a new, larger opening composition, authorized after the earlier bounded demo checkpoints. It does not retroactively change those checkpoints' scope or claim the thirty-minute human target has been achieved.

## Three connected beats

1. **Shutter market (0–1800):** readable first street, low step and ladder access to the roof walk. Street encounters pair melee guards around loose props; the roof trades close combat for jumps and an exposed patrol. Both paths remain in the same simulated world.
2. **Hillside homes / maintenance court (1800–4000):** stepped homes lead to the optional medic cache and service badge above the roofs. The lower court has different patrols, props and maintenance ladders. One badge objective—not three repeated relays—opens the low maintenance shortcut. The badge can be approached from either side. Falling returns to a real lower path, not a teleport.
3. **Intake service spine (4000–6200):** take the elevated sentry line or street-side melee route. Existing lift and upright ladders reconnect heights. The intake exit still needs the badge, but does not require defeating every guard.

The extra width is connected playable space, not empty run time: intersections, reversible climbs, cover/prop contacts and different encounter heights occur throughout. Whether those choices are legible or enjoyable remains a native/human review question, not something an optimized route timer proves.

## Components / invariants

Data uses the existing room composer, floor/platform scenes, relay marker, relay shutter, cache, cargo props, ladder, moving lift, shared PC/NPC bodies and existing intent policies. No extra enemy health, altered controller rules, forced waves, elapsed-time gates or completion setters. Upright unscaled physical instances use their existing dimensions APIs. Decorative favela architecture is selected through the generic `backdrop_scene` PackedScene interface and must never change collision, hearing, actor stats or route outcomes. Removing that key returns the standard city backdrop; this is an art choice, not a separate physical version of the district.

`demo/areas/rainline_neighbourhood.gd` is the only new level-data module. `demo/tests/rainline_review.tscn` substitutes sector0 in the existing mission host and disables saving for isolated review. Production `mission_data.gd` now selects this module for sector0; the other seven entries remain unchanged.

## Route and recovery evidence

`rainline_route_bot.gd` extends the preserved layout-aware input observer. Normal routes begin at the same original(75,300)spawn. Street and roof routes must reach three different supported waypoints, activate the real badge relay, cross into Intake and leave living bypassed enemies. Normal roof routes additionally require at least400px of actual elevated horizontal traversal in the shared approach band(x500–2800); street routes require at least600px low traversal. The street route must physically cross the opened ground shutter. All movement/combat is ordinary shared-controller input; interactions use the observer's proximity-limited production handler. No player repositioning, forced kills, AI disabling or relay writes occur in measured route gameplay.

Recovery variants first reach the market roof, then deliberately descend onto a lower court on the left or right of the still-closed shortcut before recovering to the badge. Recovery acceptance requires actual grounded feet at y300(±4px), not a crate top or projected point inside a solid step, while the shutter is still closed and badge inactive. These are actual-input route variations, not staged-position substitutions. Separate lifecycle/sweep probes, if used, must identify their direct-state fixture setup and must not replace route evidence.

Run with an isolated XDG user-data directory:

    godot --headless --path . --script demo/tests/rainline_route_bot.gd -- --hz=60 --approach=roof
    godot --headless --path . --script demo/tests/rainline_route_bot.gd -- --hz=120 --approach=street
    godot --headless --path . --script demo/tests/rainline_route_bot.gd -- --hz=60 --approach=roof --recovery=left
    godot --headless --path . --script demo/tests/rainline_route_bot.gd -- --hz=120 --approach=roof --recovery=right

Do not run two observers at the same rate simultaneously: the inherited observer initially writes a shared rate-specific report. Final Rainline report names distinguish approach and recovery. Native review should separately check first-time route signs, skyline versus physical-platform distinction, guard visibility, shutter change and fall recovery. No bot-to-human duration multiplier is valid.

## Preserved failed experiments

Initial observer type annotation incorrectly assigned an untyped conditional array to `Array[Vector2]`; it was corrected in the new test only. A street waypoint was originally inside a solid step and was moved to open ground. An upper patrol initially stood beside an intermediate ladder segment, repeatedly drawing the deterministic bot into guard/disengage rather than climbing; its position was moved to the upper landing, with the same actor kind/stats. The first right-recovery waypoint allowed support on a loose crate rather than floor; final acceptance explicitly checks floor height. Attempt logs remain separate from final evidence. None of these experiments changed shared actor/controller rules.

## Fresh integrated input results — 2026-10-23

All eight final route/recovery cases passed with zero deaths and unchanged recorded runtime/test/art sources. These are optimized deterministic observations, not human play duration.

| Case | Hz | Active seconds to Intake | Exit HP | Living guards | Caches |
|---|---:|---:|---:|---:|---:|
| roof | 60 | 48.28 | 60 | 5 | 1 |
| street | 60 | 42.58 | 45 | 6 | 0 |
| left | 60 | 43.33 | 45 | 7 | 0 |
| right | 60 | 53.27 | 45 | 7 | 0 |
| roof | 120 | 40.59 | 60 | 7 | 1 |
| street | 120 | 43.78 | 42 | 6 | 0 |
| left | 120 | 43.40 | 48 | 7 | 0 |
| right | 120 | 53.69 | 48 | 7 | 0 |

Normal roof routes traversed1524/1290px above y100 in the shared approach band(60/120Hz), collected the optional cache and exited with60HP. Normal street routes traversed2058/2103px below y270 and0px in that high band, skipped the cache and exited with45/42HP. Both genuinely crossed the opened ground shortcut. These measurements demonstrate different actual routes rather than only different waypoint labels; they do not establish human balance or enjoyment.

Both left/right recovery cases at both rates reached real floor height while the shortcut was still closed and badge inactive, then completed onward without teleport or reset. Independent ladder/shutter/relay/retry contract19/19 per rate and broader lifecycle/native/full-mission evidence are separately maintained by integration owners; this document does not substitute for those reports.
