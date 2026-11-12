# Experimental authored encounters (not shipped)

Descends from independently reviewed adapter223a879. Accepted gameplayee725ef
and separate fixture11f1160 remain frozen. No smell offer, earned immunity, save
schema, objective dependency or normal exit changes.

- Refuge Terraces: disperser(1150,268). Removed early listener(990,190) and moved
  the next sentinel from(1520,130) to(1640,130), openly in authored layout.
  No enemy hearing is disabled. Upper terraces are an optional retained route.
- Listening Floor / works_baffle_hall: disperser(1200,268). Existing ground
  listener pressure remains; upper baffles bypass aerosol, not all combat.
- Manual Governor: disperser(4740,268). Existing ground listener pressure remains;
  the upper service route bypasses aerosol. Electricity remains unrelated damage.

The catalog validates a bounded finite position-only specification. Room loading
binds sources after campaign ownership/senses are initialized. Only current player
is targeted, not civilians/enemies. No fixtures are loaded by campaign scenes.

Body-local `cough_feedback.gd` renders a small white COUGH label and chest arc on
CanvasLayer24 only while the actor's real0.18-second interruption remains. It is
proprioceptive feedback in retained, blind and deaf play, not a sound or gas sensor.
It reveals no emitter, field rectangle or terrain; no afterimage or HUD timer.
Modal/pending/loading/death/reset/room boundaries hide it immediately. Native
legibility remains a separate acceptance gate.

## Reproducible headless checks
Use official Godot4.6.3 and isolated HOME/XDG directories; fixtures disable saves.

    godot --headless --path . --script res://campaign/quality/irritant/encounter_contract.gd -- --hz=60
    godot --headless --path . --script res://campaign/quality/irritant/encounter_route.gd -- --hz=60 --district=l3_refuge_terraces --lens=retained --route=bypass --output=/tmp/route.json

Contract also runs at120Hz. Route parameters:
- districts: `l3_refuge_terraces`, `works_baffle_hall`, `crown_manual_governor`
- lenses: `retained`, `blind`, `deaf`
- paths: `ground`, `bypass`, `return`
- `--linger=12` exercises repeated warnings/patrol time before ordinary traversal.

Route fixture seeds one local entry then uses ordinary player controller inputs.
Enemy AI stays enabled. It does not alter health, actor motion or objectives after
setup. Its camera can follow for observation. It is not a full district completion,
manual playthrough or proof that an unaided blind human can discover the route.
Return starts on the far upper landing and descends the entry ladder. Bypass uses
held jumps, not one-frame jump taps. Early failed taps/early takeoffs are preserved
externally; no physics or platform edits were made to turn those failures into passes.

Current production runtime selector excludes any `quality` path component; that
covers these fixtures. Actual PCK/export verification is required before shipping.

## Crown fairness correction after a06bf2d
The frozen a06 matrix passed81/84 local cases, not all84. Strength reverse jumps
at both60/120Hz fell from the110-pixel gap/55-pixel rise into gas. The authored
west service landing is now40pixels longer: Rect2(4340,80,440,18), ending4780,
leaving a70-pixel gap. This is deliberate alternate-route fairness for the slower
starting build, not a controller or immunity buff. Cloud, enemies, other platforms,
objectives and motor are unchanged. Collision and scenery use the same authored
platform rectangle. Native visual verification is still required.

Separately, Crown blind120 returned down the ladder onto an enemy body at y272.
The original route driver waited forever for y300 instead of walking off. The
Crown-only driver now leaves descent after exiting climb below the upper landing,
using ordinary horizontal input. The local return endpoint4515 is not a full-room
retreat; a separate input test climbs ladder4540 and walks west above the existing
wall to4400/80, proving a continuation path rather than a stranded endpoint.
Both original failures and their receipts are retained outside production source.
