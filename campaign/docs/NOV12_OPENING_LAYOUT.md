# Opening level-design pass

This is an original, bounded improvement to three existing districts, not a copy
of another game's rooms and not a claim that every district has been redesigned.
The campaign still has five levels, 32 districts, 123 authored objectives and 250
enemy placements. Objective IDs, objective prerequisite graphs, story outcomes,
save meaning and the original actor/simulation are unchanged.

## Design evidence and interpretation

Two primary references inform the synthesis:

- **Dead Cells:** lead designer Sébastien Bénard's [public development diary](https://www.gamedeveloper.com/design/building-the-level-design-of-a-procedurally-generated-metroidvania-a-hybrid-approach-)
  describes purpose-built traversal/combat/reward spaces, constrained enemy
  placement, and pressure separated by quieter passages. Here that informs
  encounter spacing and the safe-maintenance introduction. MOKSHA remains authored;
  no procedural generator, room geometry, code or assets were imported.
- **Hollow Knight:** [Team Cherry's map-design interview](https://www.pcgamer.com/how-to-design-a-great-metroidvania-map/)
  discusses exploration, optional discoveries, non-linear access and keeping
  repeated journeys interesting. Here that informs a district-scale outbound
  roof route whose restored infrastructure opens a different ground route.
  MOKSHA is not being presented as an equivalent interconnected Metroidvania.

The earlier [Celeste workshop introduction](https://www.gamedeveloper.com/design/gdc-2017-level-design-workshop)
provided a supplementary teaching/reward-design lens. These are level-design
references only, not reverse-engineering results or evidence of source architecture.
All new coordinates and encounter choices were authored for MOKSHA's existing
movement, contact combat, ladders, objectives and world rules.

## Exact changes

- **Rainline:** the second ground sentinel moves from x=865 to x=1170. The first
  ground encounter can be read before the next one, rather than immediately
  engaging a pair 85 pixels apart. Later multi-guard pressure and the roof/street
  choice remain. A short street/roof sign identifies the choice before commitment.
- **Night Clinic:** a reserve-powered shutter at x=2850 blocks only the ground
  passage until the existing generator is restored. The always-open upper roof
  route crosses above it to the power cell. Bringing the cell back therefore
  changes the onward journey: the player can use the newly opened street passage
  toward the evacuation pod. Two lower one-way terraces provide intermediate
  landing space beneath the outbound roofs. No new mandatory objective is added.
- **Silent Tram:** the first floor sentinel and first rooftop sentry move farther
  beyond the entrance climb, leaving room to learn the safe maintenance route.
  The early floor listener moves to the far side of the first rail approach.
  Existing rails, periods, objectives and later pressure are preserved; signage
  identifies the elevated alternative before the first discharge strip.

## Reproduction and evidence scope

`campaign/quality/nov12_opening_layout_contract.gd` checks the content counts,
opening order, unchanged objective dependencies and specific design constraints.
The existing `campaign/tests/layout_support.gd` checks objective support across
all 32 districts.

`campaign/quality/nov12_opening_route.gd` extends the existing production-input
route. It begins at the normal title and traverses Rainline, Clinic and Tram using
ordinary automated movement/combat/interact inputs. The clinic observer requires
an actual roof crossing while the new shutter is closed and an actual low
crossing after generator restoration. Its additional return waypoint directs
inputs; it never teleports, edits health, forces objectives or opens the shutter.

Automated route time is not human pacing. Passing these checks does not establish
full manual-playthrough quality, Windows behavior, all optional-route coverage or
the 15–20-minute-per-level design target. Native fixture observations, if retained,
are separate from a continuous input-route receipt.

Run `python3 campaign/quality/nov12_opening_checks.py` for import, static checks
and both input-route rates; `--rates` alone runs only import/static checks.
The retained acceptance evidence is under `campaign/quality/nov12_opening_layout/`.
A first trial exposed insufficient return-terrace headroom; raising that terrace
from y=205 to y=140 corrected it before both passing continuous routes.
Native screenshots explicitly place the actor and stop enemies: they verify
headroom, roof layout, closed shutter and readable hint, not human play. An
open-state fixture did not update before capture and was discarded; the actual
closed-to-open transition is verified by both continuous input-route receipts.
