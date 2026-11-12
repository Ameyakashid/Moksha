# HUD-safe world captions (candidate after 45a6c2b)

Observed defect: in the actual Thermal service-ladder frame30975, the optional
harness world caption is partly obscured by the top HUD. The readable bottom E
prompt was observed elsewhere in the live approach, not in that exact frame.

## Small presentation-owned change

- `campaign_hud.gd::caption_safe_rect()` derives the header boundary from the
  same `playing_layout(data)` used for paint, including wrapped guidance and
  controller wording. It reserves the controls/footer and bottom context prompt.
  HUD canvas transformation maps the local rectangle to viewport coordinates.
- The campaign HUD owner forwards that read-only view API. The objective caption
  asks its existing host's HUD for the safe rectangle; no new gameplay authority.
- `objective_caption.gd::place_block()` still culls the actual object against the
  FULL viewport first. It then moves the WHOLE wrapped caption within the safe
  rectangle with8px margins. Offscreen objects are never pulled into view.
  An oversized block is hidden rather than overlapping HUD. Hosts without this
  optional API retain original viewport-only placement.
- Captions stay under the original blind-hidden presentation parent and retain
  their world layer. No raising them over the HUD, objective moves, interaction
  changes, collision changes, save changes or simulation/controller changes.

This is header/footer avoidance, not a general overlapping-caption solver.
Transient chapter/notice panels and crowded world labels are not claimed solved.

## Focused checks

Godot4.6.3 headless import exited0 without warnings/errors. All four focused
contracts exited0 without warnings/errors:

-227 new safe-placement checks: default/narrow viewport, long/multiline guidance,
  keyboard/controller text, locked/available/completed optional recovery captions,
  top/bottom placements, offscreen culling, visible object under HUD, insufficient
  room, old-placement overlap negative control, and hidden-parent ownership.
-2,519 existing campaign presentation assertions.
-151 existing objective paint/state/layer assertions, including actual view-parent
  sight hiding and unchanged objective state.
-19 existing object-skin assertions.

Run after a normal editor import:

```sh
godot --headless --path . --script campaign/quality/nov12_caption_safe/contract.gd
godot --headless --path . --script campaign/quality/nov6_presentation_contract.gd
godot --headless --path . --script campaign/presentation/tests/objective_paint_contract.gd
godot --headless --path . --script campaign/presentation/tests/object_skin_contract.gd
```

These tests print receipts only; they do not overwrite tracked reports. Redirect
logs to fresh paths outside the project. In restricted environments use writable
XDG data/config/cache directories. The new script UID is tracked.

Native comparison is separately requested, not implied by headless success.
No full-campaign replay, Windows run, new build or push for this iteration.
The delivered45a6c2b checkpoint and artifacts are untouched.

## Own-icon regression correction

Native review rejected the first0f52083 candidate: moving the harness caption
below the HUD put it over the recovery ring. Original before/after frames remain
preserved externally; the first successful header-only test was not final visual
acceptance.

`objective_view.gd` now owns conservative local painted bounds for each machine
kind, including strokes. Its optional caption-exclusion API transforms these to
screen space. These are presentation geometry, not interaction/collision bounds.
After preferred placement and HUD clamping, a caption intersecting its own paint
tries whole-block positions above, right, left, then below, with4px separation.
Only candidates wholly inside the8px-inset HUD-safe region are accepted. If none
fit, the caption is culled instead of covering HUD or its own machine. Existing
full-viewport object culling and blind-hidden parenting are unchanged.

Second focused run:611 safe-area assertions (including the rejected0f52083
positions as negative controls, seven objective kinds, viewport edges, three
world scales and translated/scaled HUD bounds), plus2,519 presentation,151
objective paint and19 object-skin checks. All exited0 without warnings/errors.
See `headless-own-icon-receipt.json`; this does not claim native acceptance.
This remains a local own-object/HUD fix, not universal actor, other-object or
caption-to-caption occlusion avoidance. Full campaigns were not rerun.

## Scoped native acceptance of25e96d1

Three Linux native staged comparisons on runtime commit
`25e96d1b7eb50ee9b82bb506a395852adb44ae1a` now verify the harness caption clears
the HUD, its own recovery ring, SERVICE ROUTE sign and ladder/player. The upper
ladder view remains readable; the lower ladder and synthetic wrapped-guidance
views use right-side placement. In the latter views the caption starts around
x695, about8 rendered pixels beyond the ring's right edge at687.

Evidence is in `moksha-caption-review/`:
- `refined-ladder-approach.png`: log `after-refined.log`, exit receipt
  `after-refined-exit.txt`.
- `refined-lower-ladder.png`: log `after-lower-refined.log`, exit receipt
  `after-lower-refined-exit.txt`.
- `refined-wrapped-guidance-fixed.png`: log `after-wrapped-fixed-refined.log`,
  exit receipt `after-wrapped-fixed-refined-exit.txt`.

`native-receipt.json` records exact screenshot, log, exit, fixture and launcher
SHA-256 hashes. All three exited0, with no script/runtime errors or leak lines.
Each log contains the graphics-driver warning that changing V-Sync mode is not
supported. These use GL compatibility rendering and Dummy audio; they are not
performance or audio validation.

These are staged positions/camera comparisons, NOT an exact replay of the live
movie's frame30975. The wrapped case deliberately injects a longer HUD guidance
snapshot. The initial incorrect wrapped fixture accessed owner.data and failed;
its log remains preserved and is not acceptance evidence. Both0f52083 icon-
occluding images remain preserved, as do the negative geometry controls.

The pre-existing coolant-caption overlap with the player's upper body is still
visible in baseline and candidate. This is expressly outside the scoped fix;
we do not claim general actor, other-object or caption-overlap avoidance.
No full-campaign rerun, Windows acceptance, new build or push is claimed.
