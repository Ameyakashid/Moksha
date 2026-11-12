# Market continuous service-rail trial

Candidate from ee725ef. No global player/motor, collision, platform, enemy,
objective position/dependency, save, input or sensory-permission changes.

The prior two nearly aligned sensors were lower (1470,300) height 190 and upper
(1460,110) height 200. They looked continuous but the legitimate intermediate top
exit required releasing Up before another grab. A fresh screen-only AI stopped
there before taking damage. This is a navigation observation, not measured human
difficulty. The previous route bot silently read `_climb_needs_neutral` and supplied
that release; its success was feasibility evidence, not discoverability evidence.

## Bounded repair

Market alone now has one sensor at (1470,300), height 390, ending at y=-90.
The unchanged one-way platform at y110 remains an optional midway landing.
Horizontal release ABOVE its plane can land; release BELOW still falls. Downward
travel collides with that floor and requires the ordinary neutral/Down re-entry.
No implicit snap, grip transfer, collision exception or motor safety relaxation
is added. Route metadata now points directly to the upper rail end, not a false
mandatory intermediate endpoint. The guard remains unchanged: climbing past its
height is allowed, not guaranteed safe or claimed to eliminate combat.

The authored objective now says “Recover flood key above Mended Sails”. This is
known mission instruction, not a live unseen-target sensor. An original local
“FLOOD KEY ↑ / MENDED SAILS” plaque is painted beside the rail foot using the
existing Market habitat font/material presentation. Critical key text is warm
#e0b975 on #13282c (about 8.31:1 contrast); the secondary stall name stays muted. Its parent scenery is hidden
by the existing sight-trade gate; hearing loss alone does not hide visible signs.

## Actual-game reference and ownership

Inspected official SuperTux `src/object/infoblock.cpp` at
2975428aef94fdc3d6b6ec04cc94ec7a98b116eb:
https://github.com/SuperTux/supertux/blob/2975428aef94fdc3d6b6ec04cc94ec7a98b116eb/src/object/infoblock.cpp
It keeps authored instruction associated with a world object, handles readable
camera placement and retires messages by distance. The relevant convention is
spatial instruction and truthful environment affordance, not copying its control
rules, code, maps, timings or assets. Here district data owns the ladder topology
and mission wording, existing scenery owns visible wayfinding, and the unchanged
player retains traversal authority. This does not claim SuperTux contains this
specific service ladder or that architecture guarantees usability.

## Verification boundaries

The committed contract uses the actual campaign scene and Market geometry with
explicitly staged actor starts. Three builds and four sight/hearing combinations
are checked at 60/120 Hz. Host and enemy physics schedulers are explicitly stopped
for this actor-only fixture; real player ticks fed explicit movement dictionaries, actual
hit interruption, HUD owner delivery and visibility gates are used. No private
neutral-state steering. These are mechanics checks, not combat or native play.

Separate external fixed-schedule movement-dictionary replays start through Title/C
from SHA-verified genuine Market checkpoints, retain live enemies and world
simulation, and test key recovery plus subsequent descent for retained/blind.
Replay movement uses `host.input_override`; startup/modal events use InputEventKey.
The supplementary full-goal bot also uses `host.input_override`, with inherited
proximity interaction calls into the host key handler. The matrix directly calls
`player.physics_tick` with input dictionaries. None proves OS/action-event movement
bindings or physical-controller behavior. They exercise real motor/collision/combat
but are known-route automation, not fresh screen-only play or full-campaign proof.
Read the accompanying final receipt for actual results and further limitations.

Preserved harness failures: an initial contract named the wrong event signal;
a second actor-only attempt failed to stop independently ticking enemies and
could pause after death. The explicit fixture scheduling was corrected, never the
production enemy or motor. Supplementary full-goal setup initially disabled save
loading; that setup failure is not a gameplay failure.

Native gates still required: rail/one-way crossing readability, plaque size and
occlusion at actual camera scale, optional midway exits, guard decision space,
blind body-local ladder display, and fresh navigation without route knowledge.

Setup note: initial editor import ended with empty editor-settings path errors.
A later isolated import with all HOME/XDG directories explicitly created exited
cleanly; the original error log is preserved and its exact cause is not proven.
Separate rate_probe checks read actual Engine rates 60/120 and player callback
dt 1/60 and 1/120; full matrix logs themselves label configured rates.
The final critical-text color adjustment is view-only and occurred after route
checks; it does not extend those checks into native visual acceptance.
