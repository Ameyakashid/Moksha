# Durable run completion: original implementation plan

Historical v2 foundation record. Current checkpoints use v3 and new completion
records use schema 2 for explicit sensory facts; v1/v2 and schema 1 history remain
supported. See [Hearing save compatibility](HEARING_FOCUS_SLICE.md#save-compatibility).
The version-2 statements below describe this earlier implementation, not the
current format to restore when switching builds.

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

## Implemented source API and file compatibility

`campaign.gd` retains session authority. `run_id`, `run_status`, and `run_origin`
(new or legacy_resume) are persisted in envelope v2. `session_generation` is a
read-only observation counter incremented only after successful New/Continue
setup; companion observers can detect same-frame resets without owning saves.
Empty run_id on a fresh title means no live run has been loaded. Result review
is a UI state, not a new active/completed gameplay session.

`campaign/state/completion_record.gd` validates detached history envelopes.
`campaign/save/run_history_store.gd` owns immutable put/get/reconcile/latest and
raw preserve_file. Single serialized writer is assumed, not an interprocess lock.
Result timestamps support browsing order; identity/idempotency use the random
128-bit run ID, checked against current checkpoint and existing records.
The record contains stable area IDs and a complete detached checkpoint snapshot;
legacy repeated receipts retain their meaning/order, not silently deduplicated.

The existing `moksha_five_levels_v1.json` filename is retained for discovery, but
its NEW envelope is explicitly version2. V1 remains accepted, backed up before
replacement, and migrated as legacy_resume. Old builds cannot decode v2. To use
an older build, retain the current files and restore a separate preserved v1
backup; never edit the version number to pretend v2 is v1. Legacy results are
preserved under their own content hash and never guessed to belong to an active
legacy checkpoint. Their raw source file is not modified.

A new run's validated opening snapshot is committed BEFORE live reset. Failure
leaves previous live state, generation and checkpoint intact. New does not discard
an unsaved ending. Completion appends final metrics exactly once, freezes one
record, then retries the same bytes. A valid final or pending record for the
checkpoint ID is authoritative at startup; valid pending data is promoted, while
corrupt/conflicting data fails closed with bytes retained. A completed checkpoint
without its record also fails closed. No two-file atomicity or power-loss durability
beyond the engine's flush/rename behavior is claimed.

Title C/controller X resumes an active run or reviews the last result when no
active run exists. Ending Enter/N/controller A/Start/Y returns to Title after
success; while persistence failed these commands retry saving instead. No menu
adapter input mapping, actor controller, physics, combat, geometry or story
resolution changes were needed. HUD snapshots add only last_result_available and
completion_save_failed. No-save fixtures bypass disk stores and checkpoint reads.

## Focused acceptance before wider integration

-72 isolated store/record checks: same-record retry, different-content/corrupt
  collisions, invalid IDs/types/cycles, matching pending recovery, corrupt pending
  preservation, invalid ancestor paths, failed destinations, raw legacy bytes.
-36 seeded host lifecycle checks: genuine final-choice key dispatch, double
  finalization, both close paths, Title/C read-only result, New identity/reset
  failure, explicit retry key, record-first/checkpoint interruption, valid/corrupt
  pending startup, district retry identity, legacy repeated prefix and no-save.
-174 isolated save-adversarial checks including32district roundtrips. The old
  v1-header-only relabel-to-v2 negative remains; validv2 has separate coverage.
-8,754 domain assertions,23 content checks and2,527 presentation assertions.

These are controlled persistence/scene fixtures, not a completed gameplay run,
real crash/power-cut test, Windows acceptance or native UI approval. External
normal-title/legacy gameplay and native review are separate gates. Early rejected
runs exposed a StringName key emitted by the preserved codec and an unclosed
fixture writer; both corrected without weakening schema/collision checks.

## Follow-up: history presentation validation
The history store validates only the portable record envelope. Before any history
record is presented or used to reconcile Continue, the host additionally runs the
full campaign codec against the current content catalog and compares every
duplicated result field with the snapshot (time, receipts, district rows, lens,
upgrades, deaths and kills), plus provenance. Invalid records remain on disk,
produce a visible error and cannot become a read-only completion screen.
No 32-district/5-receipt count is imposed: legacy repeated prefixes are factual.
A legacy receipt preserves any JSON-shaped completed_district metadata accepted
by v1, including absent/null/empty/non-string values, without synthesis or coercion;
this exception requires legacy_resume origin. The current session's frozen
completion takes precedence over timestamp-latest history on Title, including
when the system clock moved backwards.

Retry is not universal automatic repair: storage/access/rename failures may be
retryable after repair, but a retained partial or conflicting pending file
continues to fail closed. Preserve those bytes and recover them explicitly;
the game never deletes/replaces the conflict merely because Retry was pressed.
This change does not provide a power-loss or concurrent-writer transaction.

### Terminal suffix proof
Full codec validity alone does not mean a run finished. Before presentation or
reconciliation, the snapshot must point at the final authored district, its last
metric must name that district, and its last level receipt must name level 5 and
that district. Legacy prefixes remain untouched and may be repeated or sparse.
This is structural terminal evidence, not cryptographic proof of gameplay; a
deliberately fabricated save with a complete matching suffix is not detectable.
The current producer always appends this suffix once on finalization.

Follow-up focused checks: 85 lifecycle assertions and 72 store assertions passed
under isolated XDG roots. Five v1 metadata variants (null, empty string, integer,
object and array) were actually saved, imported, completed and compared in their
JSON representation; new-origin controls reject each. Initial-district completion,
missing suffixes and wrong final metric/receipt identities are rejected. No native
or actual-input full campaign claim. The first run exposed only a fixture's
int-versus-parsed-float dictionary comparison; its log is retained separately.

### Initial Title ordering under clock rollback
Startup now discovers timestamp-sorted history before the base host reconciles
the current checkpoint. The current terminal checkpoint therefore determines
the initial View last result target, just as it already did on later Title visits.
This reorders existing reads; it does not add a read or write, start a session,
load a district or change no-save short-circuiting.

A seeded fresh-host fixture with two valid terminal-shaped records reproduces
the old ordering failure (later timestamp belongs to the other historical run).
After correction, initial Title and C review the checkpoint-owned result with
zero session generation, no room, and unchanged checkpoint/both record hashes.
The same existing files remain undiscovered and unchanged with save_enabled false.
These are lifecycle fixtures, not evidence of two newly played campaigns.
