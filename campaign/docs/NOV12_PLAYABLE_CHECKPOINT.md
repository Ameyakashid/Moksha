# November 12 playable-source checkpoint

Five levels and32 authored districts remain playable content, not a claim that
the complete commercial-quality vision is finished. The15–20-minute-per-level
target and broader unresolved story/sense-trade designs are not validated here.

## Visible and playable changes

- **Original inhabited arcology:** layered cyan industrial depth, amber markets,
  magenta lighting and animated civilians behind the playable lane throughout
  Level1. Crowds never own collision, combat or objective state. The reused
  painting is original generated art with provenance, not an Ascent asset.
- **Distinct later locations:** Cistern keeps its water/industrial identity;
  the opening painting is not indiscriminately applied to every level.
- **Opening rhythm:** Rainline introduces one ground attacker before the next.
  Clinic has a roof outbound route and a reserve-powered street shortcut.
  Tram introduces safe maintenance traversal before combined rail/combat pressure.
  See [design evidence and exact changes](NOV12_OPENING_LAYOUT.md), informed by
  Dead Cells and Hollow Knight principles, with original coordinates and code.
- **Readability:** objective captions stay above crates; the shortcut sign stays
  clear of its ladder and shutter. Both remain governed by the sight rules.

## Foundation changes

[The inspected-source/REA blueprint](REFERENCE_FOUNDATION.txt) explains actual
references and limits. Content validation rejects missing districts, duplicate
IDs, unknown prerequisites and cyclic objective graphs. Run/save snapshots are
detached. Disk operations have their own checkpoint store and preserve v1 saves.

Campaign health is now selected before the player enters the active scene,
rather than destroying/replacing live health and manually rebinding four consumers.
`demo/mission.gd` gains a default construction hook. The original `combat_pc/`
and `simulation/` files remain byte-identical; demo assembly changes are explicitly
tested for preserved behavior. Live progression still belongs to the campaign
facade, so the full ownership migration is not claimed complete.

## Evidence available at this checkpoint

- Combined14-stage source gate: content,8,750 build-policy checks,67 health-assembly
  checks per rate, all32 districts, genuine contact damage and save/restore at60/120Hz.
- Continuous normal-title first3 districts at60/120Hz: zero deaths, real closed-shutter
  roof crossing and powered ground-shortcut crossing. Clean engine exits, parsed
  receipts and no source drift. Automated active times230.43s/151.35s are not human timing.
-26 atmosphere assertions and2,575 existing scenery assertions. The lower scenery
  count compared with the initial prototype is documented: six Level3 crowd nodes
  were intentionally removed, not six test assertions disabled.
- After-label import/static checks and all32 objective-support checks pass.
- An independent read-only integration review found no actionable production regression.

See [combined evidence](../quality/nov12_combined_checkpoint/) and neighboring
phase-specific evidence folders. The earlier [foundation checkpoint](NOV12_CHANGES.md)
records its own narrower state, not a description of every later commit.

## Rendering and footage limits

Matched30-second640x360 Linux software-render captures measured CPU13.28ms and
GPU13.86ms per frame after avoiding hidden duplicate background drawing, versus
12.79/13.46ms baseline. This is one shared-cloud-machine comparison, not Windows
FPS certification or a guarantee of hardware parity. The pre-optimization visual
clip is labelled `f1b5fd2`, automated real inputs and1x playback. It is a30-second
opening excerpt, not the combined new-layout full-level recording.

A controlled native health fixture demonstrated real enemy damage, death and retry
but still reports one retained resource on native shutdown. Its headless equivalent
is clean; the warning is retained rather than suppressed or called a proven
production leak. Synthetic QA footage is not presented as natural level play.

## Play and release status

[Windows clone/source and portable-build instructions](PC_QUICKSTART.md) explain
Godot4.6.3 startup. No Python/Node setup is needed to play. At this source checkpoint
the previously delivered portable EXE remains `c73159b`; the new portable export,
continuous combined Level1 movie and all32-district regression are separate pending
release steps. Consult their own build/run receipts when they become available.

Native Windows behavior, controller hardware, full human playthrough, audible mix
and human pacing remain unverified. No promise of a finished entire game is made
by adopting architecture references or passing a focused test suite.
