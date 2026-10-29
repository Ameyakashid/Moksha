# Movement foundation checkpoint — 2026-10-04

The current movement pass was reconciled with implemented SOTN player functions:
instant PC response, distinct walk-off control, release-speed cap, held eligible
apex assistance and explicit state permissions. The primary-source mapping is in
movement/SOURCE_STUDY.md. The source-specific motor suite passes 143 checks; the lab lifecycle/editing suite
passes 63 checks. The complete aggregate passes 19/19 stages at 2026-10-04T02:20:10.273718+00:00.
It rechecks both the new lab and the preserved game.

Native evidence below is from the earlier wireframe checkpoint. Automatic approval
review blocked reopening the editor after the SOTN changes, so those native checks
must not be read as a fresh playthrough of the later response profile.

The default launch is now movement/movement_lab.tscn. It contains exactly one PC
and one NPC using the new shared motor, plus editable test surfaces. F8 opens the
preserved two-level game. Its actor, level, art, combat and sonar source bytes
remain unchanged from v3; only project entry, documentation and test runner changed.
A recoverable complete v3 archive is retained alongside the working project.

- 143 independent motor checks: input adapter, ground/air reversal, short/held jump,
  grace, landing buffer, jump/dash budgets, dash latch/cancel, wall/slope/ceiling,
  hit pause and external impulse interruption
- 10 NPC behavior checks: patrol, chase, stop/resume hysteresis, target loss,
  world obstruction, wall and edge handling, disable and reset
- 63 lab checks: exactly one of each actor, independent prefab/resource contracts,
  saved local tuning and edited polygon, repeated controls, pause and reset
- A real stale-input defect was found: a press immediately before R or Escape
  could replay after reset/resume. All four jump/dash cases now pass after both
  adapter pending events and motor buffers are cleared together
- Held/tap single-jump heights measured 67.62/18.93 px at current settings
- Native real keyboard play tested alternating ground/air facing, slope ascent,
  lower catch floor, jumping onto the final deck, dash against the thin wall,
  jumping over it, reversal beneath the ceiling, pause/reset, and F8 archive entry
- The native reversal capture has 1,318 render samples and zero nonzero-input /
  facing mismatches. Six directional input runs include an airborne reversal
  where velocity briefly keeps its prior sign. Its MP4 is an actual viewport
  sequence, not scripted actor motion or a reconstructed animation
- Native editor inspection exposed independent PC/NPC scenes and editable motor
  tuning in the Inspector; save/reload behavior is additionally tested in-engine

This is a movement-only tuning checkpoint. The NPC does not pathfind between
platforms, jump across gaps or fight. The lab has no attack/recovery animation
state; its interruption probes test the motor's input contract independently.
Numeric tuning is original to this project, not recovered Dead Cells values.
The cloud runs software rendering. No target-hardware framerate claim is made.

See movement/README.md and movement/SOURCE_STUDY.md for the candidate foundation,
controls, source study and test mapping. The earlier two-level verification below
still applies to the preserved game and is rechecked by the aggregate runner.

---

# Verification

The repeatable headless verification command is `bash tests/run_all.sh` with
Godot 4.6.3 and Python 3. See `tests/README.md` for individual suites and setup.

Verified on 2026-10-03T20:13:06.622542+00:00: all 15 aggregate stages passed without
Godot runtime error diagnostics. Original actor, sonar, scene and flow checks
remain clean; all 27 props still settle on their intended support surfaces and
all 244 original EMBERWAKE/standalone-kit hashes match.

The polish adds 41 graphics checks, 15 sensory-warning checks, 44 continuous
route/onboarding checks and 51 drawn-attack integration checks. The connected route starts at the natural arcology
spawn, walks to the station, trades sight with E, climbs all nine ledges, and
uses the exit with E. Guards and props stay active; no teleports, extra healing,
invisibility or invulnerability are applied. It finishes at full health using
a scripted route that bypasses guards near ledge edges. This establishes
connected traversal, not unaided human discovery or a combat playthrough.

The first 96-pixel ascent rise was unnecessarily tight. A runtime-only tuning
comparison found the original second-jump speed 325 passed sampled first-hold
timings 200–433ms; speed 365 passed 133–500ms and raised maximum measured rise
from 105.8 to 118.6 pixels. The new tuning does not clear 192-pixel same-side
floor skips. A persistent instruction teaches holding and pressing again near
the peak; only a grounded first-ledge landing dismisses it.

The aggregate records 93 tested source/resource hashes. The full
runner includes all of the new checks described above.

The focused main-flow suite verifies the two connected playable levels; normal
city vision; proximity plus E at the transition, station and terminal exit;
one sight trade with exactly 1.25 movement multiplier and unchanged baseline
tuning; physical barrier opening; station-origin initial noise; repeated Q taps
at the visible weapon contact; and footsteps at enemy feet. It also checks
pause/resume, vertical camera bounds, death and R retry, N reset, safe repeated
terminal interaction, and clearing old level pulses, sources and geometry.
The optional direct arcology editor-run scene is also checked: it starts indoors
and N still begins a new city run.

Separate actor, sonar and layout suites exercise real collision contacts,
physical prop combat, noise propagation, independent contour arrivals and
focused jump routes. Scene checks exercise independent instantiation and
editor-style saving/reloading of exported overrides without changing defaults.
The preserved-original check compares 155 Emberwake and 89 moksha-assets files
against the captured SHA-256 baseline.

Results and tested source hashes are recorded in `tests/flow_all_report.json`.
Logs and individual JSON reports retain failures as well as successful checks;
the runner treats Godot runtime errors as failures even if Godot exits zero.
These checks use focused setup and do not establish an uninterrupted human
combat/platforming playthrough. Native visuals, audio mix and editor interaction
must be reviewed separately; headless success does not certify them.

## Native review

Reviewed the real Godot desktop game and editor in this cloud workspace:

- City rendering, immediate movement/turning, jumping onto service decks, melee,
  damage feedback and rigid props launching/spinning/bouncing. The polish build
  was played from city spawn to the arcology entrance with all three guards
  killed by physical props and full health remaining
- The interior's E station interaction: sight switches off, speed reads 125%,
  barrier opens, and Q produces travelling white surface fragments
- Separate real prop contact sources marked CLANG and enemy footstep sources
  marked STEP; world contours fade while the self-position cue remains
- Blind double-jump landings on the first and second ascent ledges, an actual
  prop kill on the second ledge, full health, and vertical camera movement
- Revised jump instruction changing after landing, larger animated body-position
  cue, held-weapon motion in the black view, and pause/resume between test batches
- Pose-specific baton grip and final native city combat after graphics changes
- R restores the interior's sighted starting state and 100% speed; N returns to
  the city, including when launched through arcology_run.tscn
- The native 2D editor opens the arcology with separate saved nodes and instances;
  selecting Ascent01 exposes Width 340, Depth 20, One Way Collision and Art Style
  in the Inspector

Native checks are sampled gameplay, including a continuous city completion,
not an uninterrupted completion of both rooms.
Complete transitions, terminal victory, repeated actions and every jump route are
covered by the focused automated suites described above. The latest prop-settling
fix was prompted by native reset inspection and is additionally checked for all 27
placed props after two seconds of normal physics.

The cloud desktop uses software graphics and dummy audio. Screenshots are actual
renderer captures; an audible mix and target-hardware frame rate are not certified.

## Drawn attack checkpoint

Six new original transparent body drawings are integrated through an optional
attack-pose resource. Native Godot review of `tests/attack_showroom.tscn` confirmed
planted boot baselines, real transparent silhouettes, readable extended contact,
measured baton grips and both facing directions at game scale. A frame-boundary
rounding issue found in the fixed-phase study was corrected and covered by tests.

The actual city game was then restarted with these drawings, and movement,
double jumping, repeated strikes and a physical prop kill were checked natively
with full health. The player controller, strike timing and collision code were
not changed for this art pass. The same six body frames currently support all
three weapon patterns; they are not three separate full-body combo cycles.

## Blind contact checkpoint

55 additional checks exercise real strikes, misses, terrain-obstructed strikes,
rigid-body projectile damage and kills, isolated physical prop breaks, resting
props, player damage/invulnerability, freed-source marks, interruption, fade,
pause/reset and overlapping feedback. No successful-hit noises are fabricated.
A 24-defeat stress fixture remains bounded to 18 pulses and consolidates nearby
labels/glyphs while retaining independent propagation. Contact/label CPU work
measured roughly 0.3–0.4ms in this fixture; this is not GPU or hardware-FPS evidence.

Native arcology play separately verified a lethal physical-prop encounter and a
direct melee encounter, each with full health. The latter recorded a nonlethal
HIT followed by DOWN, with zero prop kills. A passive recorder saved the actual
engine frame after each event; it never repositioned actors or drove input.
Visual inspection corrected text/weapon overlap with a raised fading black
backing and prioritized contact glyphs. Pause/resume and subsequent disappearance
of contact labels were also inspected in the real game.
