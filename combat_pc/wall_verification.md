# Gated wall traversal verification

**Passed at 120 Hz and 60 Hz:** 146 wall scenarios / 478 assertions per rate. All four prior movement, combat, drop/dive and ladder/vine suites also pass on the same controller. Ten runs have zero failures and clean engine logs.

Controller SHA-256: `1484ba48cd23fe0bc0742472e2fd8f5674830919e1767036b08bd775c7b437b9`. [Detailed evidence](wall_verification.json) pins the tested production files, harnesses, traces, profiles and console logs.

## Connected behavior

- Mirrored ground jump → wall approach → finite upward run → supported outward kick → higher opposite landing; separate run-to-slide-to-end and wall-to-ledge handoff with clear/blocked headroom.
- Locked-by-default ability, host/main/input/facing gates, permitted and denied roll/jump/dive/melee transitions, committed kick, damage, reset, grace and regrab timing.
- Same-contact allowance preservation across melee, actual separation/recontact policy, alternate ground-only policy, buffered landing rearm and coplanar collider seams. Actual air jump, dive and roll expenditure remains spent through wall attachment and kick.
- Parsed input on exact recorded physics ticks, full Jump taps through hitpause, adjacent away/Jump, expiry and invalidation, and mirrored toward+Jump immediately before, at and after regrab eligibility.
- Queued tap release across wait, hitpause and temporary host denial; no air spending while reserved; accepted ordinary jumps retain ascent over multiple ticks until separation/apex/replacement. Disabled input, reset, lost support and ability changes recheck or retire the request.
- Thin walls at elevated kick speed, solid ceilings, permitted/restricted one-way passage, targeted drop/roll cleanup, dedicated scaled/static walls and explicit unsupported-shape refusals.
- Moving, blocked, removed, disabled, rotated, replaced and teleported contacts; current/pending geometry, hurt-pause transport, blocked-surface metadata and repeated reset/replacement cycles on the same actor.

## Corrected defects

The earlier e772 pass was provisional after native QA exposed a press just before regrab expiry; that revision and native capture are retained. The revised checks cover both the boundary and later physics ticks.

- **Freed active/recent wall passed into typed geometry helper.** Validate object lifetime before a typed geometry access, including recent-kick support.
- **Coplanar adjacent solid-body seam misidentified as a top ledge.** Reject covered top candidates and change the active coplanar carrier while retaining the same episode and consumed allowance.
- **Stale committed geometry authorizes a moved-away wall episode before immediate detach.** Preflight pending geometry and bounded safe transport before attachment, owner cancellation or episode consumption.
- **Fresh toward plus Jump at valid wall spent air jump before same-tick resumed slide swallowed the impulse.** Resolve eligible fresh supported wall intent before air jump; prevent automatic acquisition from overwriting any accepted jump in that tick.
- **Near regrab expiry, air jump is spent before next-tick wall reattachment swallows ascent.** Reserve the existing jump buffer when regrab cooldown is the only blocker; protect a genuinely accepted ordinary air jump against the same contact throughout upward ascent. No grace or profile value changed.
- **Brief host denial erased the release cut of a queued wall-jump tap.** Preserve that buffered press’s queued marker and release history through a temporary permission denial, clearing them on a new press, consumption, expiry or buffer clear.

Each has a retained before-fix trace or engine-error record in [defect reproductions](tests/wall_defect_reproductions.json) and passing final physical cases. No collision tolerance was loosened. Fixture corrections and geometry-observation distinctions are explicitly listed in the JSON.

## Cross-rate and preservation checks

All 28 paired bounds pass: five wall measurements plus the unchanged 23 earlier bounds. Steady ascent independently equals profile speed × 0.15 seconds within 0.01 px. Phase timing allows one 60 Hz boundary step. The project setting remains 120 Hz; 60 Hz is a runtime test override.

All 35 earlier artifacts and all four M1–M4 ZIPs keep their recorded hashes. Five documentation/output-text updates are recorded separately: standalone wording in two Markdown summaries, one JSON summary and one report template, plus companion-archive instructions in TRACE_ARCHIVE.md. Before/after hashes and exact original content in the historical ZIP are verified; recorded test results, numeric data, trace data and executable test logic are unchanged. The 26 provisional e772 M5 files remain byte-for-byte intact. Compatibility outputs have separate M5 names. Regrab, grace and all movement/combat tuning remain unchanged.

## Scope

- This is original MOKSHA behavior. Historical developer footage establishes airborne approach, upward wall travel and outward kick toward a higher opposite landing. Slide, exhaustion, rearm, timers, cancellation and every numerical value here are authored, not recovered Dead Cells v35 behavior.
- The actor ability defaults locked. Tests explicitly enable it. Supported contacts are dedicated upright positive-scale solid rectangle bodies; coplanar contiguous separate bodies can share an episode. One-way, mixed/multi-shape, rotated, negatively scaled and nonrectangular wall bodies are refused.
- Rearm is an explicit configurable policy. Default genuine separation/recontact plus delay and alternate real-ground/reset behavior are tested. No historical attack-reset exploit or universal source-game same-wall exhaustion rule is claimed.
- Contact queries and fixtures are bounded. No general tilemap, arbitrary polygon, spike/hazard system, rigid-body crowd or impossible crushing-geometry escape guarantee is established. Explicit wall_traversal_blocked metadata is tested.
- Shape observations retain committed PhysicsServer hits and independently test current upright rectangle geometry. A body transported to its pending Node pose can overlap the old committed pose without overlapping its current rectangle; this is reported rather than hidden by whole-body query exclusions. The inherited 0.06 px per-edge query inset is unchanged.
- These are headless actual-physics and parsed keyboard checks. Native visual/feel QA and final isolated-project boot are owned and reported separately. NPCs, parry, health/death and additional weapons are outside this pass.

## Reproduce

Use writable XDG data/cache/config locations, then run:

```sh
XDG_DATA_HOME=/tmp/moksha-combat-test-data XDG_CACHE_HOME=/tmp/moksha-combat-test-cache XDG_CONFIG_HOME=/tmp/moksha-combat-test-config godot --headless --fixed-fps 120 --path . --script combat_pc/tests/wall_regression.gd -- --hz=120
XDG_DATA_HOME=/tmp/moksha-combat-test-data XDG_CACHE_HOME=/tmp/moksha-combat-test-cache XDG_CONFIG_HOME=/tmp/moksha-combat-test-config godot --headless --fixed-fps 60 --path . --script combat_pc/tests/wall_regression.gd -- --hz=60
```

Redirect each wall console to `combat_pc/tests/m5_wall_120.log` or `m5_wall_60.log`. For compatibility, copy the four immutable regression scripts to `/tmp`, replacing only their result filename with `movement_compat_m5_results_%dhz%s.json`, `combat_compat_m5_results_%dhz.json`, `traversal_compat_m5_results_%dhz.json`, or `climb_compat_m5_results_%dhz.json`; save matching `m5_<suite>_<rate>.log` files. `python3 combat_pc/tests/build_wall_report.py` rejects failed or stale runs, engine errors, missing physics samples, changed historical evidence, and exceeded rate bounds.

Traces: [wall 120 Hz](tests/wall_results_120hz.json), [wall 60 Hz](tests/wall_results_60hz.json), and eight `*_compat_m5_results_*hz.json` files indexed in the detailed evidence.
