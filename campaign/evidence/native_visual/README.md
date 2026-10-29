# Actual native rendered QA — 2026-10-29

Source baseline: frozen 4ea2c1102466aabd9d8cf93a01be24139970363d, copied from export-staging to moksha-native-visual-qa. Production source untouched by this review.

Route: supported CUA/Sky desktop Godot app (4.6.3), UI project import of isolated workspace copy, Run. Actual rendered frames captured by native screenshot tools; no mockups. Filesystem shared despite earlier assumptions. Supported Sites preview daemon was independently verified reachable from browser and a ZIP download worked, but was unnecessary; stopped, no Site registration/publication.

## Evidence
- pause.png: normal new campaign, Enter, actual held D movement, Escape pause.
- l1-jump.png: normal new campaign, actual held D then D+Space, first raised platform landed. Not an automated route.
- fixture-sight-choice.png: isolated visual_qa/panels.tscn directly loads sight choice; not route completion.
- fixture-blind-idle.png: actual J accepts choice, then sound fades. Black world with player/HUD only.
- fixture-blind-sonar.png: actual Q input reveals nearby terrain outline.
- fixture-upgrade.png: directly initialized upgrade panel; no progression claim.

## Findings before correction
- Pause help omits TAB field journal and F8 debug toggle; reset wording omits objective reset.
- Initial L1 journal empty of actionable objectives, build line trailing slash and development meta-text.
- Cargo and ladder look like blueprint wireframe against painted environment.
- Title and panels fit native 1280x720 and embedded 1228x691 without text clipping.
- Player filled skin and scenery/platform z-order render; movement/jump responds.
- Blind mode does not leak scenery after sound fades; Q reveals nearby surfaces.
- Editor diagnostics include unsupported VSync on Mesa llvmpipe, audio device failure -> dummy audio, and GDScript lint warnings. Audio unverified.
- Fixture function-key shortcuts conflicted with embedded editor debugging controls; switched to digit fixture keys. Not classified as gameplay defect.

Further screenshots marked fixture are direct state setup plus real native rendering/input, not evidence of full manual campaign traversal.

## Iteration verification
- after-journal.png / after-pause.png: actionable objectives, Next instruction and TAB/reset semantics corrected, no clipped text.
- after-l1-jump.png: material cargo and steel ladder replace blueprint outlines; same manual movement sequence following direct L1 fixture setup.
- after-fixture-l2.png ... after-fixture-l5.png: directly loaded respective level starts, actual rendering. L5 prose truncation found.
- after-wrapped-l5.png: narrative wrapping correction confirmed, full sentence now fits two lines.
- after-dense-journal-1.png: direct CityClinic/full-four-upgrade journal; all five objective lines, Next line and full build line readable and contained.
- after-fixture-final-choice.png / after-fixture-ending.png: real final/ending panel rendering, direct fixture state ONLY. Ending time/counts are fixture values, not completion evidence.
- after-blind-movement.png / after-blind-idle.png: actual J trade + D movement from direct exchange fixture. No painted cargo/ladder/background leak; nearby sound traces remain from other moving sources, as designed.
- manual-combat.png / manual-death.png / manual-retry.png: direct L1 start followed by real D/Space movement to first ground guard, real J attacks, damage, death, R retry; restored60/60 at spawn. Not full route acceptance.

Remaining observed presentation concerns sent to art worker: repeated small wall panels over flat L2-L4 backgrounds and apparently unfilled enemies versus filled player. Await diagnosis; do not claim art pass on those yet.

## Final correction acceptance
- final-fixture-l2/l3/l4.png: revised furnace bays / cistern tank-window motifs / server racks are distinct and actually in camera. Repeated small vent wallpaper concern resolved in reviewed frames. Armor is broader and more legible while original outline remains.
- final-corrected-objective-guard.png: final textured breaker cabinet draws behind live guard. Orange warning exclamation and attack arc remain visible; giant X removed. Corrected BRAKE HOUSING / STRIKE J sign, LOCKED label, and human-readable prerequisite fit.
- final-console-used.png / final-console-completed.png: T fixture set prerequisite and position, then real E inputs cycle circuit0 to target2. Green completion and HUD next-objective update verified. Not whole-route proof.
- final-hazard-sighted.png / final-hazard-blind.png / final-hazard-blind-q.png / final-hazard-blind-fade.png: fixture placement by live hazard, actual Q reveal; no colored scenery/object paint leaks blind. Authoritative white hazard/terrain contours and ongoing CLANG traces remain. Exact warning-pulse timing was not independently quantified.
- final-dense-page1.png / final-dense-page2.png / final-dense-back-page1.png: DrainageCommons nine-row journal with four upgrades; two pages fit cleanly. Actual D/A advances/returns. Arrow keys did not advance in embedded editor runtime, which may intercept them; standalone arrows not verified. Lead informed to expose A/D in footer.

Scope: representative actual native pixels and manual movement/combat/UI inputs, with explicit fixture setup for later content. No assertion of a complete manual campaign playthrough, Windows execution, audio quality, stable FPS, or exhaustive frame-by-frame animation QA. Automated route receipts belong to separate lead validation.
- final-journal-footer.png: final A/D-or-arrows page guidance confirmed at page2, readable and contained.
- final-upper-cistern.png: camera settled at elevated exit fixture(3500,-760). Tank/window motifs cover upper scene. Newly observed defect: objective caption clipped at viewport right and crossed by door stripes. Sent to lead/art for minimal clamp/label layering correction; not accepted yet.

## Final recheck — accepted sampled corrections
- final-upper-cistern-corrected.png: full objective caption now clamped inside viewport and drawn above shutter. Elevated tank/window coverage retained.
- final-journal-right-arrow.png / final-journal-left-arrow.png: after logical-key fallback, actual Right advances to page2 and Left returns to page1 in the same native runtime. Earlier arrow limitation resolved by this recheck; A/D guidance remains useful.
- final-guard-caption-regression.png: final separate caption layer leaves guard body and attack arc visible in front of cabinet; readable LOCKED/prerequisite. Fixture retains prior four-upgrade build, hence75/75 health (not a default-start claim).
- Final live H+Q recheck still displays black world with white authoritative sound contours, no colored paint visible.

All specifically observed blocking presentation defects in this bounded sample were corrected and re-rendered. Native run stopped after review. This does not broaden coverage beyond the stated sample or replace final production-byte automated validation.
