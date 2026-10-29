# Air steering: one review piece

The optional candidate makes horizontal correction in an ordinary jump or fall respond sooner. Both comparison profiles include the previously reviewed ground response. Jump launch speed, hold/release behavior, gravity, air-jump budget, speed cap and neutral drift remain the same.

## Try it

F5 opens `air_response_review.tscn`. **1** selects the previous air response; **2** selects the candidate. **Q** applies the same input sequence to each, with ordinary physics throughout. It demonstrates mirrored corrections, releasing direction without removing momentum, the existing air jump, and a short jump. The comparison does not drive character positions or use a trajectory animation.

Use **A/D** to steer and **Space** to jump/air jump. **F** changes the existing flat, slope and moving-floor fixtures; **R** resets and **Esc** pauses. The gold arrow shows actual horizontal momentum, while body facing follows admitted directional input. The dim curve records actual airborne travel. These are inspection guides, independent of the game's sound/surface systems.

## The one parameter

The candidate uses 2300 px/s² instead of 1450 px/s² when steering freely in air. The same existing `move_toward` path changes velocity toward the input-scaled 218 px/s target. Neutral input continues to use 120 px/s² drag. No vertical calculation changes.

Eligibility is explicit: airborne `locomotion`, `jump` or `air_jump`; no crouch or uncleared drop body; no custom action driver; idle weapon and shield; inputs and movement permitted; positive movement scale. Other owners use their earlier rates. Once an owner such as a wall kick or roll actually ends and returns to an eligible jump/fall, the candidate applies normally. This does not promise that the entire subsequent airborne trajectory remains identical.

The resource does not decide whether an action can begin, cancel or refill. It does not add a jump, wall ability, combat modifier or target-dependent assistance. The existing action/weapon permission system remains authoritative.

## Use it elsewhere

Assign `resources/air_response_agile.tres` to a `player.tscn` instance's **Profile**. It contains the reviewed ordinary-ground resource plus the new independent **Ordinary Air Response** resource. Keep `resources/ground_presentation_agile.tres` on the Visual child to use the reviewed ground presentation; the view is unchanged in this pass.

Duplicate resources before changing shared values. Clear **Ordinary Air Response** to restore previous air control while retaining the ground option. Restore `ground_response_agile.tres` for the same result. The reusable player's default resource and all older review scenes keep their prior behavior. Null/invalid air resources fall back to the existing base acceleration.

The new review inherits the previous review host and geometry. Its before/after input program, trace drawing and capture controls are review-only code; the reusable player needs none of them.

## Reference and verification boundary

The source audit freshly checked the pinned Dead Cells Hero, jump skills and manager routines. The relevant air-control bodies and their scheduler are absent. This value is therefore authored MOKSHA calibration, not recovered or translated Dead Cells tuning. See [exact source evidence and gaps](reference/M19_AIR_STEERING_EVIDENCE.md).

Measured physical comparisons, owner boundaries, vertical-curve equality, contact cases and native observations are recorded in `tests/air_response_report.md` and the companion evidence archive. The native clip is silent in this cloud environment. Review the response preference before adding another agility component.
