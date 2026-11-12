# Experimental Market and irritant preview

This is an opt-in source checkpoint, not the accepted gameplay baseline or a new
Windows executable. Its runtime is `ca7762b`, combining the independently checked
irritant checkpoint `9974650` and Market trial `92458a4`. This documentation does
not change their runtime. Accepted source `ee725ef` remains separately preserved.

## What changes

- **Market:** the two almost-aligned ladders below the flood key become one
  continuous service rail. Holding Up reaches the upper roof without a hidden
  second grab. A/D can still release onto the intermediate platform once the
  player's feet clear it. Descending still stops at that one-way floor; this is
  not automatic travel through floors. The player motor, platforms and guards
  are unchanged. A local sign and the objective's wording identify the key above
  Mended Sails.
- **Three dispersers:** Refuge Terraces teaches the effect, Listening Floor adds
  optional ground-route pressure, and Manual Governor provides a later encounter.
  Every location has an untimed alternative. The Crown service landing was
  deliberately widened by 40 pixels after a Strength reverse-route test fell
  into the cloud. The original failed test was retained.
- **Cough:** actual exposure can interrupt attacks and guard for 0.18 seconds.
  It does not directly damage health, stun movement or secretly reduce speed.
  Actor-wide rearm prevents overlapping sources from extending the interruption.
  A white body-local cue indicates the brief active effect.
- **Perception:** sighted players see the warning and cloud. Blind players do not
  see that colored world paint; retained hearing receives temporary real acoustic
  warnings and contour propagation. Hearing-traded players keep the visible
  warning without receiving informative world audio or sonar.

There is no smell-sacrifice offer, earned irritant immunity or save-schema change.
The disperser is stationary, not the proposed pepper-bomb enemy. These encounters
are not evidence that losing smell would already be a powerful or balanced trade.

## What the evidence establishes

The separate source checkpoints have recorded contract, collision, lifecycle and
route checks at 60/120 Hz. The Market mechanics matrix covers all starting builds
and sight/hearing combinations, including combinations not offered by normal menus.
Its actor-only fixture explicitly disables enemy ticking. Separate Market replays
keep guards active and complete the key/descent or all mandatory objectives.

Those Market replays use movement dictionaries through the game's input override.
They exercise the real motor and combat, but are not keyboard-binding, manual or
fresh-player tests. The earlier fresh screenshot-only test did use ordinary UI
keys and exposed the stacked-ladder confusion that motivated this layout change.

On `9974650`, retained, blind and hearing-traded runs also started from genuinely
earned Refuge checkpoints, used physical `InputEventKey` dispatch through the
normal sampler with no movement override, completed the entire district, and
saved Drainage entry normally. Run identities, senses and prior receipts were
preserved, with no deaths. Each had one cough. Their later 12 HP losses occurred
18.7–19.7 seconds after coughing ended; the source of that later damage was not
recorded. No health loss occurred during the cough itself.

These are automated headless results, not human play, native Windows execution,
physical-controller testing or real-time performance measurements. Local seeded
routes and genuine checkpoint continuations are labelled separately. The combined
checkpoint's portable preservation receipt states which integration checks were
completed; do not infer a complete all-systems campaign rerun from component tests.

## What remains unaccepted

Native actual-size sign, ladder, guard and cough-cue readability; acoustic mix and
blind warning interpretation; fresh navigation; general balance; and a new export
or Windows run remain unverified. The prior Windows download still contains the
older `23a5aa6` release. No GitHub publication is claimed by this checkpoint.

This remains a five-level, 32-district prototype, not the entire original MOKSHA
vision. Smell and Intellect trades, broad multi-sense specialization, adaptive
loop enemies and unresolved original story variants remain unfinished.

## Trying this source safely

Use the preservation archive's exact restoration commands. Keep its accepted
branch as the default, and create a separate worktree for this experimental branch.
Open that worktree's `project.godot` in official Godot 4.6.3 standard and press F5.
Do not substitute the isolated pilot's F6 scene for this campaign.

Back up the complete game save folder before switching builds. This preview uses
the existing v3 checkpoint and schema-2 completion formats; older builds may not
read them. Run only one game process against a save folder. Do not hand-edit saves
or overwrite the separately preserved genuine checkpoint inputs.

## Responsibility and reference trail

The actor owns bounded interruption and rearm; simulation owns the finite field;
campaign adapters own room/session binding and perception; views read state rather
than changing combat. Market wayfinding belongs to authored content and scenery,
not controller assistance. See the [irritant encounter notes](../quality/irritant/ENCOUNTERS.md),
[adapter reference mapping](../quality/irritant/README.md), and
[Market trial](MARKET_CONTINUOUS_RAIL_TRIAL.md).

The documented public Cataclysm: Dark Days Ahead and SuperTux source references
informed responsibility boundaries. No proprietary code or assets were copied,
and this milestone is not a new binary decompilation or a new REA run.
