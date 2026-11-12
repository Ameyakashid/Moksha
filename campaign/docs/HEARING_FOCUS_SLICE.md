# Hearing → FOCUS: original playable prototype slice

The original user vision trades hearing for sharper visible pre-strike opportunity, not merely mute, saturation or global slow motion. This milestone implements that exchange using the independently checked attack-local timing foundation. FOCUS's name, bounds, offer placement and restrained white bracket art are original implementation choices, not recovered third-party mechanics or a claim of final balance.

The current project is a five-level / 32-district prototype with companion, durable history, scent and local ladder touch. It is not the entire original adaptive-run/sense/lore vision. Historical staged-build documents remain historical.

## Playing the choice

At the first cleared floor exit, select the ordinary persistent upgrade first. A separate optional hearing offer follows: J accepts FOCUS; K or Escape keeps hearing. Controller X accepts and B declines. Declining keeps all senses and progression available. Acceptance lasts for the run. There is no extra heal, speed or damage award for accepting; ordinary room/build behavior remains independent.

FOCUS removes player auditory pulses and sound-map history, informative world/body sounds and ambience. Q/B still makes a physical tap that enemies can hear. Global M mute remains separate. Non-diegetic completion sound remains; textual objectives, accessibility captions and internal companion text are not secretly treated as world hearing. The intro impact cue is diegetic, not exempt UI feedback.

With sight retained, visible, unobstructed committed melee attacks can acquire one bounded slow final windup. White corner brackets emphasize that late opportunity, not an automatic or guaranteed parry. The beginning of windup, movement, active contact and recovery are not slowed. Projectiles are excluded. Eligibility is sampled once at attack commitment: walking into view later does not re-arm an attack. After admission, hiding the enemy removes the bracket but does not rewrite its already committed timing.

The maximum 0.18 seconds is logical added attack-clock time. Observed contact occurs on physics ticks and is quantized: an 11-tick difference at 60 Hz is 0.1833 seconds and is correctly within one tick of that logical bound. This is not a hard wall-clock/audio/render-latency guarantee.

## Temporary combination limit

Normal UI does not yet offer a second irreversible sight/hearing loss. It explains this as a prototype navigation/combat validation limit, not a permanent rule of MOKSHA. The pure domain and v3 saves can represent both lost. Such a valid loaded checkpoint remains blind and deaf: no silently restored sonar/hearing, and no sight-based FOCUS claim. Full dual-loss campaign playability is not established by scent and a local ladder cue.

## Responsibilities

- `state/sense_state.gd`: pure validated sensory facts and derived capabilities. No nodes, clocks, files or game commands.
- `logic/campaign.gd`: choice UI/commit/application and lifecycle. Acceptance stages a v3 checkpoint for the onward district, verifies/preserves old data, commits it, then changes live listener capabilities. A pinned committed-transition target prevents focus-loss Retry/Title from rolling receipts/upgrades back into the old room after disk commitment.
- `logic/checkpoint_codec.gd`, `state/completion_record.gd`, existing stores: version-aware validation and immutable history. No sensory resource or perception cache is saved.
- `presentation/campaign_sonar.gd`: player-listener intake/history/geometry/drawing gate. NoiseBus, enemy hearing and the shared sonar implementation are unchanged.
- `presentation/hearing_audio.gd`: campaign listener gate for existing voices/ambience; global mute remains the original service. No enemy noise suppression or new audio assets.
- `perception/focus_observer.gd`: bounded current-room registrations, safe physics LOS, current paint/HUD visibility, projectile exclusion, synchronous lease requests. No clock/resource writes. Idle enemies do not cause focus LOS queries. Pending transition/retry, modal, death, room/session loss, hidden paint, changed player/enemy position and objective/tree changes conservatively retire cached presentation marks. LOS itself is sampled only in physics, not during drawing.
- `presentation/focus_view.gd`: detached visible marks drawn as compact corner brackets. No combat or input authority.
- `combat_pc/player.gd`: unchanged in this slice. The accepted foundation owns phase/step clocks, bounded lease admission, cancellation and reentrancy fences.

See [current architecture](ARCHITECTURE.md), [pinned reference foundation](REFERENCE_FOUNDATION.txt), [controller reference contract](../../combat_pc/REFERENCE_CONTRACT.md), [late-windup foundation](LATE_WINDUP_FOUNDATION.md), and the [original source vision](../../docs/MOKSHA-source.md). No fresh decompilation was performed for this slice.

No copied assets, map geometry or third-party code. Existing pinned substantial-source architecture notes ground responsibility separation only; they are not evidence that this hearing algorithm or timing was reverse engineered.

## Save compatibility

New checkpoints use explicit campaign envelope v3 with `senses:{version:1,sight,hearing}`. Sight agrees with the existing progress codec's blind field. New immutable completions use schema2 with identical result/snapshot sensory facts. Legacy v1/v2 checkpoints and schema1/v2 historical completions remain supported without inventing historical senses. Active legacy Continue preserves original bytes before writing a migrated copy; v2 run IDs, origin, metrics and receipt prefixes stay intact. Pre-v3 data carrying the reserved new sensory field rejects rather than silently restoring hearing.

Trade/migration commit failure leaves live capabilities and old checkpoint bytes unchanged. No-save mode stays disk-free. New resets choices; retry and Continue preserve them. Use one running writer per save folder. Old builds do not understand v3: use preserved original backups with the matching old build, not the new checkpoint. Do not downgrade or hand-edit new saves.

## Evidence scope

`hearing_host_contract.gd` explicitly seeds lifecycle/choice and terminal fixtures. `hearing_perception_contract.gd` seeds real campaign actors/geometry and exercises physics input commitments, visibility negatives, listener costs and enemy hearing. Neither is an earned traversal or native readability test.

`hearing_encounter_trace.gd` stages the same flat Clinic encounter and then uses ordinary player shield input and the real enemy AI/controller/damage path. It holds shield from 0.65–0.85 seconds after the first real AI commitment at 60 and 120 physics Hz. No health, attack-clock or objective writes occur during the encounter. This demonstrates a possible timing opportunity, not OP balance or human performance.

Native visibility/audio review and an earned Quarantine-clear → upgrade → hearing choice → Level2 → Title/Continue route remain separate acceptance work. No Windows packaging or gameplay-video claims are made by these headless tests.
