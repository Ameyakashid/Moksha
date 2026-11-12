# Original local ladder touch: recovery slice

This is an added design assumption motivated by a screen-only play observation: a blind+sonar player contacted and partly climbed a ladder, stepped off, then could not relocate its faded outline. The original user asked for interacting senses and blind/deaf possibilities, but did not prescribe this contact implementation. This does not implement hearing sacrifice or claim blind+deaf navigation works throughout the campaign.

## Ownership

Shared `combat_pc/player.gd`, `climbable.gd`, simulation, ladder sensors, physics/timing, audio and save formats remain unchanged. The new campaign observer runs in a physics callback after the normal actor tick. It performs a capped64-hit body-sized Area overlap, reads valid current `climb_geometry()`, checks current-room ownership/mask and the actual declared span, then admits only contact within24 units of the actor's chest. An oversized sensor cannot enlarge that reach. A short terrain-only segment to the contact point rejects a separating wall; it is not a forward search ray. This conservative slice measures reach to the ladder axis, so it may omit a very wide ladder whose edge alone is reachable.

`_climb_candidates()` is not reused because its endpoint filters depend on input direction. `_validate_climb()` is not called because it can detach the actor. Current held target is read only and preferred only after contact/geometry/obstruction admission. No view initiates or maintains a climb.

The snapshot exposes only body-local rail/rung segments and a held boolean. The observer clips the full geometry before presentation: a36-unit-high window, at most two short rails and three rungs. Full endpoints, IDs, map positions and future terrain never reach the view. Disabled, moved, resized, foreign-room, removed, session-stale and player-position-stale snapshots fail closed. Menus, death, pause and room replacement retire contact, with no after-image or saved memory.

## Presentation and limits

Only sight-traded play draws the contact fragment, like existing proprioception. Retained-sight art stays unchanged. The query is modality-neutral for tests/future composition. Thin stationary local strokes differ from expanding sonar and persist only while actual reach/overlap exists; held strokes are slightly firmer. The ordinary controls and regrab cooldown remain authoritative. A touch cue does not promise that pressing Up immediately attaches, nor indicate a remote ladder's location.

The reference responsibility separation comes from prior documented source/REA work in REFERENCE_FOUNDATION.txt; no external algorithm, map, code or art was copied. This is not a recovered commercial game's tactile system.

## Verification scope

`campaign/quality/nov12_ladder_touch_contract.gd` uses the real unchanged player and production ladder in real physics callbacks. Its driver supplies ordinary input frames for approach, climb and jump-away; adversarial configurations are explicitly seeded fixtures. It checks local output bounds, true controller-held state, presentation on/off trace equality, and outside-reach/oversized sensor/wall/disabled/moved/freed/foreign-room/mask/pause/death/session negatives. It does not establish human usability or natural campaign traversal.

Native review and a fresh screen-only recovery attempt must separately establish that the local fragment is legible with sonar/body pose and improves the reported ladder recovery. No release, packaging or full-game-complete claim follows from focused fixtures alone.

Focused acceptance:41 checks passed at explicitly configured60 and120 physicsHz, with matching frame-driver cadence. A prior fixed-render-cadence attempt did not configure physicsHz and its120-cadence approach was too short; that failed QA attempt was retained and not accepted. The corrected test uses duration-scaled inputs, not altered movement. The32-district smoke and inherited64-check scent contract passed (the latter at project-default120 physicsHz). Native readability/recovery and broader combined regression remain separate.
