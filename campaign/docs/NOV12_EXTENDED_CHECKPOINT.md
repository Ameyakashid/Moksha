# November 12 extended source checkpoint

This continues the playable `fe9936a` checkpoint without replacing its saved
artifacts. It remains a five-level, 32-district prototype, not a claim of a
finished commercial game or validated 15–20-minute human levels.

## What changed

- **Foundry / Freight:** an original recessed industrial hall with cyan depth,
  subdued furnace light and sparse background shift workers replaces flat bays.
- **Cistern / Residences:** a separate original waterworks panorama retains the
  wet concrete/pipe identity. Warmer residential framing shows occupied windows.
  Neither location reuses the opening market painting or third-party game art.
- **Thermal Foundry return:** restoring the feed opens a middle-height maintenance
  connector. The exposed floor and high service route remain usable. Existing
  objectives, optional harness, hazards and enemies are preserved.
- **Residential clarity:** the optional supplies now occupy their own reachable
  side landing, rather than sharing the mandatory shelter's interaction point.
  Separate directions distinguish supplies, shelter and roof recovery. Text is
  kept clear of the shelter icon, retaining wall and recovery ladder.
- **Player assembly:** detached configuration/component attachment are separated
  from host-owned creation and activation. Health selection occurs before actors
  enter the tree; contact/defeat binding order is preserved.
- **Editable source:** generated Godot UID/import sidecars are versioned instead
  of making a newly imported checkout dirty. QA output guards preserve archived
  receipts and reject in-project or existing output destinations.

The original `combat_pc/` and `simulation/` files are unchanged. Save version 1,
stable district/objective IDs and existing mandatory progression remain intact.
The campaign host still owns live session/progression policy; the ownership
migration is not claimed complete.

## Evidence and reproduction

Phase records identify their own exact source revisions and scope:

- [Detached assembly](PLAYER_ASSEMBLY.txt) and [current architecture](ARCHITECTURE.md).
- [Thermal design and route receipts](NOV12_THERMAL_RETURN.md). The four clean
  route cases use explicitly recorded observer revisions; they are not presented
  as four runs with one unchanged test harness.
- [Residential collect/skip, sight and checkpoint checks](../quality/nov12_residential_cache/).
- [Foundry visual/render checks](../quality/nov12_foundry/) and
  [Cistern visual/render checks](../quality/nov12_cistern/).
- [Earlier frozen-release full campaigns and footage](../quality/nov12_release_validation/).
  Those remain evidence for `fe9936a`, not a substituted full run of later code.

Before treating an export as a delivery, use its own `BUILD_PROVENANCE.json`
and `BUILD_REPORT.json` to identify the runtime and packed checks. Final source,
full-campaign and package runs produce new external receipts rather than
rewriting these earlier records. A source commit does not automatically update
an already-downloaded EXE/PCK pair.

The bounded source commands include `nov12_domain_checks.py`, `run_quality.py`,
`nov12_thermal_checks.py` and the phase-specific scene contracts. Use the runners'
`--help` and fresh output paths. Do not run filesystem fixtures against player
save directories.

## Deliberate limits

The matched scenery comparisons isolate rendering, not full-game FPS or Windows
hardware. Videos labelled checkpoint-start are excerpts, not full level runs;
scripted input is not human play. A short direct desktop-key review is separate
from those scripted runs. Native Windows execution, physical controller hardware,
audible mix and human pacing remain unverified. The broader unresolved story and
sense-trade vision is not declared complete by this checkpoint.
