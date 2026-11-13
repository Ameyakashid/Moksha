# Intellect tactical coaching: bounded source slices

## Published sighted slice: historical scope

The sections below, until **Hearing-only Drainage extension**, describe published
sighted runtime `d3385ed` and its documentation successor `4d792526`. Statements
that blindness is deferred or only Quarantine is observed belong to that shipped
source milestone, not the separate unaccepted hearing candidate below.

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

## Hearing-only Drainage extension (development candidate)

The reachable Level 3 Drainage Commons lancer can provide one generic Intellect
warning, **“Be ready.”**, while sight is traded and hearing retained. It reports a
recent admitted weapon-draw sound, not an enemy identity, position, target, hidden
attack phase, or recovery. Quarantine's sighted warning/recovery path is separate.
The 0.60-second expiry is a design hypothesis, not proven human reaction time.
No sacrifice reward, new save field, motor/AI/attack timing, sound or listener change.

The reference-first separation follows CDDA's `game.cpp` sound-at reporting
(lines 6423–6442 at the commit linked above): report perceived evidence rather than
hidden current state. Original implementation and existing original guard-draw WAV;
no copied third-party code/assets or REA/binary analysis was performed.

Actual committed actor noise passes its existing NoiseRelay checks and bus
forwarding unchanged. A scoped stack identifies the exact currently forwarding
receipt by identity, binding, operation and generation. Nested callbacks restore
the outer context. This is a trusted in-process lifetime boundary, **not** security
against arbitrary code forging actor signals or invoking private methods. Context
is absent outside emission and invalid after rebind, reset diagnostics, disable,
removal or source reset. The observer never uses raw NoiseBus or sonar history as
proof of hearing. Per-frame dedup is capped at 64; overflow fails closed until the
next physics frame. After the shown warning budget, no history is accumulated.
Capability changes and observer disable clear pending evidence and reject admission
through the current physics frame; regain requires a fresh event on a later frame.

The private conservative caption policy explicitly sets range 340 × clamped
loudness (0.2–2), gain 1, ear offset (0,−20), ignore-own-source, terrain mask 1,
blocked multiplier 0 and endpoint tolerance 0.1. The same frozen emission origin
must be within 260 units of the actual viewport-derived fallback listener. Only
the expected root listening viewport, no explicit AudioListener2D, identity host
transform and current authored hearing adapter/WAV are supported. Terrain queries
occur only in physics callbacks. Current player/view geometry can retire a fact;
current hidden actor position/phase cannot enrich it. Mute or missing audio device
is not hearing loss. These logical gates deliberately under-report some sounds;
they do not measure audibility, volume recognition or accessibility.

Godot's [official 4.6.3-tag spatial audio implementation](https://github.com/godotengine/godot/blob/4.6.3-stable/scene/2d/audio_stream_player_2d.cpp#L109-L174)
uses the inverse combined global/canvas transform at viewport center without an
explicit listener. This explains the view-relative margin. Installed logs identify
`7d41c59c4`, while the official tag inspected points to `35e80b3a`; a byte-matched
source audit of the installed binary is not claimed. Existing audio routing,
attenuation and panning remain untouched.

Seeded headless fixtures are not earned routes or native/human listening tests.
Bounded parity receipts retain an incremental SHA-256 of every complete serialized
per-tick player/enemy state row, metrics and noise count, plus exact physical-key
transcripts, sample counts and cue receipts. They do not retain full raw state
traces. Native readability and usefulness remain separate acceptance work.


### Development evidence and remaining gate

The initial seeded hearing contract had 35 checks at each rate; review hardening
added bounded history, invalidation/rearm, unexpected-routing rejection and
immediate remove/readd/reset retirement, then a bound-player identity and room-membership guard against listener replacement. The bound-listener identity successor passes **48 hearing
checks, 54 existing sighted checks, and 47 scoped relay checks at both 60/120 Hz**.
Final enabled/disabled physical-key comparisons match all hashed state rows and
input transcripts for retained hearing and hearing-loss negative controls: 480
samples at 60 Hz and 960 at 120 Hz, each with 84 unchanged noise events. Only the
enabled blind/hearing-retained case presents the warning. Setup is explicitly
seeded, including the blind+deaf negative-control state; no earned route is claimed.

Before the final observer lifecycle-only hardening, the inherited noise regression
passed 186 checks at both rates. The relay's subsequent change was comment-only.
A contemporary external wrapper also ran all twelve unchanged physical contact
scenario functions, passing 255 checks/47 scenarios at each rate. That wrapper
checks current stability of **three actor/relay/bus sources plus six adapter
files**. It does not establish the historical v19 byte-equality assertion: that
old fixture requires an absent baseline file and its failed invocation is retained.

Other retained development failures: Godot rejects direct `free()` of an actively
emitting relay (supported removal and `queue_free()` are tested instead); an early
ear-distance fixture intersected an actual authored ledge and was relocated only
for the isolated range check; one later test callback had a corrected parse error.
These are not concealed as successful runs. No production acceptance rule was
relaxed. Native readability, hearing usefulness and accessibility acceptance are
**pending**. No new Windows build or gameplay movie is implied by this candidate.
