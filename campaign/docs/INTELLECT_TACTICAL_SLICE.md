# Intellect tactical coaching: bounded source slice

Base is published Memory Loom source `6d7e86d`. This slice is original code for
one existing Quarantine lancer, not a new enemy or a complete companion system.
The user's recorded Intellect idea asks for a travelling aide that helps in combat
and can eventually be lost. This first makes the retained aide useful; it does
not invent a sacrifice reward or add irreversible choice/save fields.

## Reference inspected before implementation

Cataclysm: Dark Days Ahead 0.H, exact public commit
`5d069f2eaccd125d22b53617ba73ce7fab157a9f`,
[game.cpp](https://github.com/CleverRaven/Cataclysm-DDA/blob/5d069f2eaccd125d22b53617ba73ce7fab157a9f/src/game.cpp),
SHA256 `cc51fff60dbaec30cafda0e7a21c12f9831071ff98b4ddd6a643f186eba2d879`.
`game::knockback(std::vector<tripoint>&,...)` starts at 4780. At 4835–4849 an actual
terrain/creature consequence precedes `u.sees(*targ)` and its combat-result
message. `draw_critter` 3996–4033 distinguishes visible full paint from coarse
special-sense '?'; `print_creature_info` 6660–6667 gates detailed information.
Nearby CDDA messages are not all visibility-gated. This is a specific ownership
reference, not a claim that its whole implementation meets this prototype's rules.
CDDA is turn-based; that code does not establish subsecond coaching usability.
No copied code/assets, binary decompilation or new REA run was involved.

## Concrete mapping and ownership

- Existing shared actor events, not captain policy intent, establish committed
  `attack_started` and `attack_phase_changed(recovery)`. `attack_finished` is idle,
  not recovery. Existing defensive `attack_plan_snapshot()` supplies committed
  serial, generation, configuration epoch and phase. No new actor accessor.
- `narrative/tactical_companion_observer.gd` observes only the existing
  `captain_lancer` in `quarantine_intake`. Weak references and room/session/attack
  identity fence all cues. It never changes AI, inputs, clocks, damage or saves.
- Actual visible `CampaignSecuritySkin`, viewport/caption-safe bounds and clear
  terrain line of sight gate details, using the existing FOCUS perception policy
  independently of the hearing-traded capability requirement. It never requests
  FOCUS or writes a lease.
- `campaign.gd` binds/retire the observer with the room and adds its derived HUD
  facts before quiet companion decoration. Existing quiet dialogue policy stays.
- Typed HUD owner accepts the ID, clears omission and acknowledges only the still
  installed matching notice. Nested replacement cannot spend an unseen cue.

## Behavior and priority

`Step aside.` appears during a perceived real windup, and `An opening.` only for
that acknowledged attack's actual recovery. Neither promises a safe direction,
perfect parry or guaranteed strike. Compact INTELLECT attribution shares the
existing notice panel; no separate overlapping lane or additional voice exists.

Windup/recovery captions expire on real phase exit or bounded .78/1.05 seconds,
whichever happens first. No enemy clock is extended for reading. One acknowledged
warning and one followup maximum per room lifetime. A hidden unacknowledged warning
may be offered on a later attack; a canceled/hidden attack cannot produce its
recovery coaching. Retry can reteach; New/Continue make no persistent cue history.

Modal/panel, chapter, objective/action prompt and existing gameplay notice win.
Quiet banter yields to tactical coaching. Pause, room/session change, actor reset,
configuration replacement, removal, death, disabled observer or lost perception
retire transient facts. Sighted normal-hearing and hearing-traded states receive
visual text; existing FOCUS remains independent. Blind receives no extra clue.
Raw enemy_windup NoiseBus emissions are not proof of listener perception; a blind
adapter is deferred rather than inferring hidden phases from coarse scent/noise.

## Validation and limits

Focused seeded actual-actor contracts pass 54 checks each at 60/120 Hz, including
real phase entry, suppression/retirement, typed rejection/omission, quiet-dialogue
priority and reentrant HUD replacements, including same-ID/text nested priority
changes. Earlier 49- and 50-check receipts are preserved. The final source is
`d3385ed35b0fb9e2a023a6e38f11713048ff2d91`, based on `6d7e86d`.

Four deterministic enabled/disabled comparison pairs cover 60/120 Hz and normal/
traded hearing. Each uses a seeded Quarantine encounter followed solely by actual
InputEventKey controls. Eight seconds each (480/960 samples). Compare every player/
enemy position, velocity, health, action/weapon/shield phase and attack serial,
plus exact key-event transcript. Enabled observer must show both cues; disabled
must show none. These are seeded encounter parity, not earned campaign traversal,
human learning, native visual acceptance or a full level run.

Inherited quiet-observer (29), companion-director (55), hearing-perception (24)
and caption-safe (611) checks also pass. The final headless matrix contains
14 engine runs. Source asset inventory passes at 576 files / 28,292,460 bytes,
without changing its budget policy.

## Native visual verification

The same seeded eight-second encounter ran through the actual Linux game window,
with physical key events, no input override and no gameplay edits during the run.
All 480 player/enemy samples and the complete key transcript exactly match the
headless baseline. Both captions were inspected in untouched native frames, with
separate INTELLECT attribution, clear actor silhouettes and no competing chapter
or interaction prompt. Their same-attack phase and typed acknowledgment were
independently reconciled. The captured native canvas was 1180 x 663, not an
assumed size derived from the requested window dimensions.

The final native run exited 0, with no engine errors or leaked resources. The only
warning was unsupported V-Sync mode on the software-rendered desktop. Its two PNGs
were independently decoded and checked against the SHA256 of the untouched native
image buffers. The warning appears in 46 observed render samples and recovery in
62; these counts do not establish human comprehension or reaction opportunity.

Two earlier failed diagnostic attempts are preserved. The first assumed the
requested window size, tried an unavailable audio device and lacked explicit
observer cleanup. The second fixed audio discovery and cleanup but wrongly equated
ViewportTexture metadata dimensions with actual backing pixels. The final
observer reconciles the different APIs rather than resizing images or changing
the game. Official 4.6.3-tag source helped explain that behavior, but it is not
claimed byte-matched to the installed engine's reported build revision.

Native review was visual-only, with an explicit Dummy audio backend. No new movie,
listening acceptance, real-time frame-rate claim, human first-play test, Windows
hardware run or physical-controller test is implied. This is not a full level
playthrough. Sighted hearing-traded behavior has headless parity coverage, not a
separate native claim. Blind tactical coaching remains deferred.

There are no movement, health, enemy-policy, layout, scent, save-codec, ending,
Intellect-sacrifice or audio-resource changes. The companion's proposed bottle
scene, trade reward and broader story remain unimplemented. Current Windows 596
still uses the older runtime; source changes do not update that download.
