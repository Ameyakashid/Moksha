# Durable run completion: original implementation plan

Base895a6e4. Preserve released files and every legacy checkpoint/result byte.
No time-loop/immortality resolution, destructive ending, controller or geometry change.

## Inspected architecture references, not copied implementations

- [shapez savegame](https://github.com/tobspr-games/shapez.io/blob/8a79de5255fb6756f3a1d26579b1e9bc36e0c811/src/js/savegame/savegame.js): updateData builds detached shadowData before replacing currentData. Release skips its validation. writeSavegameAndMetadata is sequential, NOT a transactional pair.
- [shapez serializer](https://github.com/tobspr-games/shapez.io/blob/8a79de5255fb6756f3a1d26579b1e9bc36e0c811/src/js/savegame/savegame_serializer.js): domain snapshots and stable IDs. Actual REA examination of two source files was partial static analysis, not binary reconstruction.
- [CDDA0.H memorial output](https://github.com/CleverRaven/Cataclysm-DDA/blob/5d069f2eaccd125d22b53617ba73ce7fab157a9f/src/game.cpp#L3437-L3520), [memorial schema](https://github.com/CleverRaven/Cataclysm-DDA/blob/5d069f2eaccd125d22b53617ba73ce7fab157a9f/src/memorial_logger.cpp#L402-L421), [past games reader](https://github.com/CleverRaven/Cataclysm-DDA/blob/5d069f2eaccd125d22b53617ba73ce7fab157a9f/src/past_games_info.cpp): history separate from resume slots, versioned facts/stable IDs. Timestamped files alone are not idempotency.

These sources were inspected by the architecture reviewer; shapez GPL3 and CDDA
root CC BY-SA3 are study references only. No code/assets are copied.

## Original MOKSHA mapping and integration contract

Campaign checkpoint envelope v2 adds run_id and run_status, while accepting v1
without guessing completion or associating an unrelated legacy result. Pure codec
validates detached values. Store owns disk; session owns transitions. Immutable
completion JSON is keyed by run_id, not timestamp, and is authoritative before
Continue. New preserves the previous active checkpoint bytes before replacement.

Completion commits record first, completed checkpoint second. This two-file
sequence is NOT atomic. Startup reconciles a durable record against an active
checkpoint of the same run_id. Same-ID/different-content writes fail visibly;
same-ID/same-record retries are idempotent. Never delete history. Preserve legacy
result bytes independently and legacy v1 checkpoint bytes before upgrading.
No-save fixtures never invoke stores. Completion failures retain the frozen
in-memory result and allow retry rather than duplicating metrics/receipts.

Narrow session API planned: run_id, run_status, completion_record (detached facts),
retry_completion_save(), view_last_result(). Companion observation should use
run identity/lifecycle only; it must not own completion or persist chatter into
run history without an explicit future schema. No new canonical narrative facts.
