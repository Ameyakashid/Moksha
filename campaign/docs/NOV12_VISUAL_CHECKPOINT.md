# November 12 five-environment visual checkpoint

This extends the preserved `45a6c2b` release. It is still the same five-level,
32-district playable prototype, not a claim of a finished commercial game.
Check a download's `BUILD_PROVENANCE.json` for its actual source revision;
new source work does not update an older EXE/PCK pair automatically.

## What is new

- **Memory Works:** a distinct original archive-machine vista, blue-violet
  indexing looms, observation galleries and tiny distant painted staff.
- **Crown:** immense bronze/ceramic bays open onto a cyan-magenta city far below.
  Its warmer authority lighting and exposed height contrast with the enclosed
  Memory Works. All five levels now have separate original environment plates.
- **Objective captions:** the entire caption respects the measured HUD header
  and bottom prompt, then avoids its own machine/icon paint. A side placement is
  used when the band above an item is too small. Offscreen culling and sight-trade
  concealment remain separate and intact. The first attempted fix was rejected
  after native images showed it covering the item icon.
- **Manual Governor directions:** required Authority and Supply branches are
  named instead of directing players toward an optional bypass. The west sign
  says STRIKE without assuming keyboard or controller. The central sign moved
  left only to clear an observed overlap with the Exchange caption.
- **Delivery:** public build reports use portable path placeholders while raw
  verification receipts stay unchanged. Current player guides are included.

The original player controller and simulation are unchanged. This pass does not
move platforms, enemies, objectives or interaction radii, and it does not alter
save identities or dependencies. Static painted staff are not simulated NPCs.
The new views are district-owned, camera-bounded presentation without per-person
nodes or animation ticks. No proprietary game assets or code are copied.

## Evidence is revision-specific

The phase records under `campaign/quality/nov12_caption_safe/`,
`nov12_governor/`, `nov12_memory/` and `nov12_crown/` identify their own source
revisions, focused tests and native scopes. Memory and Crown previews use real
automated input after an explicit checkpoint start; they do not complete those
levels. Directly staged readability/concealment frames are not traversal proof.

The two complete campaigns archived in `nov12_extended_release/` belong to
`45a6c2b`, not to later source by implication. Any new combined campaign/export
acceptance must identify its own frozen revision and preserve those older runs.
No FPS or target-PC performance claim is made from concurrent correctness tests.

## Remaining limits

Native Windows operation, physical controllers, audible mix and human pacing
remain unverified. The requested 15–20 minutes per level is a design target,
not a measured human result. The broader story and other sense trades are not
declared complete. Caption handling is not a general overlap solver: transient
panels, other labels and the pre-existing coolant-caption/player overlap remain
outside this narrowly tested correction. An intermittent staged-fixture shutdown
warning was traced to ambient audio playback retention; a delayed test teardown
was clean, which does not prove every production shutdown is clean.

For controls and local playtesting, see [LOCAL_PLAYTEST.md](LOCAL_PLAYTEST.md).
For source or portable startup, see [PC_QUICKSTART.md](PC_QUICKSTART.md).
