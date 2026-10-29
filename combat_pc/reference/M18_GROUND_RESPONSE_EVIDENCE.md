# M18 ground-response evidence and tuning boundary

Audited 2026-10-05, before the M18 implementation. Scope: the reusable PC's ordinary ground acceleration, braking, reversal, facing presentation, and short movement transients. This is source inspection plus a numerical replay of the existing horizontal update formula, **not a Godot runtime pass, controlled Dead Cells measurement, or exact-parity claim**. No implementation or UI was changed by this audit.

## Reference evidence rechecked

The pinned [DeadCellsDecomp revision][repo] remains a partial behavioral source. Fresh GitHub reads confirmed:

- [Hero.hx][hero], blob `fd03750543f136f7487bf1a030489cddb7cb4280`: `runSpd`, `accelFactor`, `walkCycle`, `frameWalkSpd`, `runFrames`, `speedComboRun`, and footstep-frame arrays are declarations. `shouldTurn()` is a throwing stub; `triggerOnStopAffixes()`, `airControl()`, and `fixedUpdate()` are empty. These do not recover a run cap, acceleration/deceleration curve, turnaround schedule, or footstep/animation playback rate.
- [Beheaded.hx][beheaded], blob `deb5c783b4c72fabc71cd2f70414d6e3f97b6f1a`: `getRunAnimId()` and `moveControlled()` are throwing stubs; `initAnims()` is empty. No usable run-to-turn clip selector or transition duration is supplied.
- [Bénard's GDC 2019 slides][gdc], pages 11, 14, and 17: forgiving controls and interpreting player intent are explicit design goals; the combat slide names free turnaround and aiming assistance. This supports prompt response as a design direction, not unconditional turning during every weapon phase or a numerical movement target.
- [Vasseur's primary animation article][animation], freshly read: deliberate key poses, timing changes, and rapid animation retakes support readable motion aligned to gameplay. Its pose-to-pose explanation concerns attacks. It provides no quantitative ground braking, reversal, or run-start contract. The current page dates the article January 25, 2018; the older local visual note says January 24.

The existing `VISUAL_OBSERVATIONS.md` contains prior qualitative inspection of the article's running media: leg recovery/contact contrast, opposing arm motion, relatively steady upper body, and directional trailing cloth. No new media frames or controlled input trace were measured here. GIF/WebP frame durations, the earlier prototype's animation FPS, and source timing-base declarations cannot establish current Dead Cells motor constants.

**Evidence boundary:** every proposed M18 number and transient-lifetime rule below is original MOKSHA tuning. Missing reference behavior remains missing; no other game's controller or numbers fill the gap.

## Current MOKSHA behavior

`resources/movement_profile.tres` has no overrides, so the script defaults apply: run cap **218 px/s**, ground acceleration **3100 px/s²**, braking **1850 px/s²**, reversal **3600 px/s²**, crouch cap **92 px/s**, turn-pose timer **0.11 s**. The project default physics rate is **120 Hz**.

`player.gd::_update_facing()` accepts permitted nonzero horizontal intent on the same simulation tick. It uses raw sampled intent independently of the movement gate, while respecting `uses_inputs` and `can_turn`. Facing need not wait for momentum to reverse. This is already responsive; introducing a turn lock would be a regression.

`_update_horizontal()` linearly approaches the scaled speed target. Reversal acceleration applies only while velocity opposes input; ordinary acceleration takes over after crossing zero. Ground braking is used for neutral or denied movement. Air acceleration, drag, jump/gravity, and owned roll/dive/wall motion have separate branches.

The shared ground rates also affect crouch and permitted shield/charge/windup/recovery motion. The active grounded melee branch uses `ground_braking` directly when host movement is denied. Therefore a global replacement of these values is **not** proof of unchanged combat movement. A bounded response option can select the faster values only for admitted ordinary standing locomotion, while retaining the prior rates for other owners. Any wider change needs explicit regression evidence and accurate disclosure.

Keep the 218 run cap for this pass: it also supplies the air target, wall-kick/climb grace reach, and visual speed normalization. Raising it would alter more than ground responsiveness. Keep jump, roll, combat, landing, climb, and collision policies unchanged.

## Reachable presentation issues in the current selector

Sources: `visuals/wireframe.gd::present()` and `_select()`, `visuals/wireframe_keys.gd::TUNING`, `player.gd::_select_pose()`.

1. **False turn from rest.** The motor emits no turn at zero prior speed. The visual instead detects a facing change using post-acceleration speed above 20. Starting from rest opposite the previous facing therefore produces both `run_start` and `turn`; turn wins. This occurs at both 60 Hz and 120 Hz with the current profile.
2. **Neutral release cannot immediately replace a turn.** The visual turn test precedes braking and does not require current movement intent. The motor's turn timer also precedes brake/idle selection. A released reversal can retain a turning silhouette after the player is already asking to stop, including a stopped actor while its timer remains active.
3. **Turn phase can jump backward near zero velocity.** Event-age turn selection requires absolute speed above 12. Below that, supplied `turn` falls back to generic `phase_progress`, normally zero in locomotion. The old 120 Hz reversal reaches +8 px/s; the proposed 60 Hz reversal reaches +11.33 px/s. Each crosses this fallback and can restart the visual key before resuming event-age progress.
4. **Old event ages can reclaim fresh movement.** Turn history is not fenced by the intent/generation that created it. A stop and restart inside its 0.16 s lifetime can recover an old turn. Brake selection already requires neutral input or supplied brake, but old brake history can similarly be reused by a later brief stop unless explicitly invalidated.
5. **Presentation durations exceed the short response.** Defaults are start 0.14 s, brake 0.16 s, turn 0.16 s; motor turn is 0.11 s. Start persists beyond reaching full speed, and braking can persist at zero speed. These are authored readability choices, but shortening motor response alone makes the mismatch larger.

Ordinary run gait is distance-driven and subtracts support displacement. Preserve that behavior and its existing foot anchors; faster timers alone should not create steps from input, facing changes, blocked movement, or carrier motion. Strong pose keys can remain without letting old transients own later intent.

## Proposed bounded candidate and analytic effect

Candidate: acceleration **4800**, braking **2700**, reversal **6200 px/s²**; unchanged run cap **218**; motor turn timer **0.07 s**. Optional ground-only visual durations: start **0.075 s**, brake **0.10 s**, turn **0.085 s**, retaining the existing presentation defaults when the option is absent.

The following replays the current `move_toward` formula on an unobstructed flat floor with full digital input, no other action owner, and position integrated from each updated velocity. Times are elapsed simulation ticks from first admitted input, not device/display latency. Distances exclude the last pre-release movement tick.

| Rate / profile | Rest to cap | Release to zero | Release distance | First opposite motion | Opposite cap |
|---|---:|---:|---:|---:|---:|
| 60 Hz / current | 83.33 ms | 133.33 ms | 11.04 px | 66.67 ms | 133.33 ms |
| 60 Hz / candidate | 50.00 ms | 83.33 ms | 7.03 px | 50.00 ms | 83.33 ms |
| 120 Hz / current | 75.00 ms | 125.00 ms | 11.94 px | 66.67 ms | 133.33 ms |
| 120 Hz / candidate | 50.00 ms | 83.33 ms | 7.91 px | 41.67 ms | 83.33 ms |

These are useful authored targets, not empirical Dead Cells values. No reference evidence supports choosing a more aggressive constant over this candidate. Verify the candidate in the engine before finalizing it.

## Implementation and verification constraints

- Keep facing authoritative in the motor, immediate when permitted, and independent of visual clips. Preserve host input/turn/movement gates and analog scaling.
- Admit a reversal transient from genuine opposing prior momentum; a change of facing from rest should enter the new-direction start. Avoid post-acceleration facing detection manufacturing a turn.
- Give ground transients a live owner and intent lifetime. Neutral release, fresh restart, a different reversal, zero-speed settling, and action-owner changes must retire incompatible history. Keep phase monotonic through zero velocity. A short authored drive after zero crossing is acceptable if it still belongs to the same reversal.
- Preserve existing higher-priority jump/roll/weapon/shield/landing/traversal presentation. Ground-only tuning must not change their timings or use a stale locomotion event when they finish.
- Verify flat left/right starts, release, full reverse, opposite-facing idle starts, rapid left/right taps, reversal-release-restart, low analog speed, blocked input, slope transitions, moving support, pause/resume, reset, and host-denied movement/turning at 60/120 Hz. Compare final velocities/distances and selected visual family/progress; use actual runtime observations for completion claims.
- Regression-test unchanged air/jump and other owned action motion. Existing movement tests derive several bounds from the same profile values; they cannot independently prove a desired responsiveness target. Add explicit elapsed-time/distance and interrupted-selector assertions where they protect the behavior above. Keep the parameter ledger synchronized with the final authored settings.

[repo]: https://github.com/N3rdL0rd/DeadCellsDecomp/tree/77c3ad263c4187ade6d048ba77bb61f79e6cec44
[hero]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/en/Hero.hx
[beheaded]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/en/hero/Beheaded.hx
[gdc]: https://media.gdcvault.com/gdc2019/presentations/Benard-Sebastian-DeepCells.pdf
[animation]: https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-
