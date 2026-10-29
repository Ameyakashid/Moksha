# Exchange circulation candidate

Only Exchange's authored data changes. Existing 2,600-unit footprint, six-enemy roster/positions, stats, station, relay locations, cache and original platforms remain. Adds one translating lift, one recovery ladder, one return shelf and two relay-linked shutters; no new controller or mechanic.

- Pressure first: lower listener/prop approach releases the floor access shutter to the moving lift. Ride to the existing cache landing and approach calibration. The lift already runs on its own circuit; the relay opens access, not its motor.
- Calibration first: fixed upper platforms/recovery ladder reach calibration without pressure. Open the upper return bridge, then descend to pressure and use the now-connected routes to leave.
- Both relays remain required by the existing onward gate rule. Relay order is flexible; surviving enemies never block this exit.
- Upper bridge shutter is suspended (y0..200). A missed landing can return on the floor underneath it, rather than becoming trapped behind an unopened barrier. Ladder x1260 reaches the maintenance platform from the floor. Lower access shutter is x1458..1482/y120..300 and can be crossed above on the existing y80 landing.
- Optional sight trade remains at x430 before route commitment, and both choices must pass without tuning changes.

`demo/tests/exchange_route_bot.gd` is an explicitly isolated sector-start diagnostic extending the existing observer. During measured play it submits ordinary raw PC inputs and actual proximity-limited station/relay interactions. Lift coverage observes the genuine moving support for at least half a second and at least100units of ascent. Stairs coverage observes elevated travel and calibration-first activation; lift takes pressure first. Both deliberately walk across the opened return bridge. `--recovery` adds an actual upper-landing fall and return. No position/health/AI/gate writes during measured play.

Acceptance is recorded separately. Optimized simulated route time is not human playtime. This slice improves use of existing space and distinct decisions, not a claim that the campaign has reached30minutes. No enemy-health inflation, waves, forced waits or additional sense mechanics are included.
