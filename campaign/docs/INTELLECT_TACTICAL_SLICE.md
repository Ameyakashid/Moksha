# Intellect tactical coaching: bounded source slice

Base is published Memory Loom source `6d7e86d`. This slice is original code for
one existing Quarantine lancer, not a new enemy or a complete companion system.
The user's recorded Intellect idea asks for a travelling aide that helps in combat
and can eventually be lost. This first makes the retained aide useful; it does
not invent a sacrifice reward or add irreversible choice/save fields.

## Reference inspected before implementation

Cataclysm: Dark Days Ahead0.H, exact public commit
`5d069f2eaccd125d22b53617ba73ce7fab157a9f`,
[game.cpp](https://github.com/CleverRaven/Cataclysm-DDA/blob/5d069f2eaccd125d22b53617ba73ce7fab157a9f/src/game.cpp),
SHA256 `cc51fff60dbaec30cafda0e7a21c12f9831071ff98b4ddd6a643f186eba2d879`.
`game::knockback(std::vector<tripoint>&,...)` starts at4780. At4835–4849 an actual
terrain/creature consequence precedes `u.sees(*targ)` and its combat-result
message. `draw_critter`3996–4033 distinguishes visible full paint from coarse
special-sense '?'; `print_creature_info`6660–6667 gates detailed information.
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

Focused seeded actual-actor contracts pass50checks each at60/120Hz, including
real phase entry, suppression/retirement, typed rejection/omission, quiet-dialogue
priority and a reentrant HUD replacement. Initial49-check contracts passed before
that extra acknowledgment adversary was added; earlier receipts remain preserved.

Four deterministic enabled/disabled comparison pairs cover60/120Hz and normal/
traded hearing. Each uses a seeded Quarantine encounter followed solely by actual
InputEventKey controls. Eight seconds each (480/960samples). Compare every player/
enemy position, velocity, health, action/weapon/shield phase and attack serial,
plus exact key-event transcript. Enabled observer must show both cues; disabled
must show none. These are seeded encounter parity, not earned campaign traversal,
human learning, native visual acceptance or a full level run.

Inherited companion/director, hearing-perception and caption-safe contracts are
also retained. No movement, health, enemy policy, level geometry, scent, save codec,
ending, irreversible Intellect trade or audio resource changes. Native motion and
actual-size legibility remain pending; subsecond comprehension is the main risk.
