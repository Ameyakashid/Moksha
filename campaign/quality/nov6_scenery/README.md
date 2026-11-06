# November 6 district identity

This pass is removable background paint. It adds no colliders, input, objective
state, sound events, navigation, saves, camera behavior or actors. The original
skyline/atlas pixels and controller sources are unchanged.

## What changes

- All 32 campaign IDs have explicit decorative profiles in
  `campaign/presentation/district_identity.gd`. Their small wall placards reuse
  existing district names/purposes; they introduce no new locations or lore.
- City and Crown use different deterministic crops of the supplied city plate.
  Both clipped edge tiles preserve the original aspect ratio and remain inside
  the source image. Dark vertical joints mask the non-tileable plate boundary.
- Industrial bays vary their width, stagger, equipment and empty space. The
  capacitor mill has coils, the freight district has bolted wall shutters, the
  stamping galleries have recessed press housings, and the thermal foundry has
  furnace grilles. Water, residential, refuge, archive, acoustic and memory-loom
  equipment use their corresponding existing district purposes rather than the
  same machine in every room.
- Compact, faded, bolted wall placards use a shared icon vocabulary. They do not
  show arrows, keys, objective status, glowing rings or live circuit indicators.
  Sparse upper-wall repeats carry the same identity through taller rooms.
- Decorations remain at world z=-8, below exact terrain skins, actors, hazards
  and objectives. They add no freestanding crates, floors, cover or usable doors.
  Every new drawing remains under the existing sight-hidden scenery root.

The profiles use local integer mixing, not the global random stream. Rebuilding
or hiding scenery cannot consume randomness used by the simulation. Geometry
still comes from the existing room contract. The optional spawn position only
places the first wall placard near the district entrance, including the two
middle-spawn districts; it does not move the player.

## Reproduce the focused gate

From the project root, with Godot 4.6.3 available:

```
python campaign/quality/nov6_scenery/run.py --output /tmp/moksha-scenery-results
```

The runner uses isolated temporary HOME/XDG paths, captures logs and source
hashes, requires success markers and rejects script/engine errors, leaked objects,
timeouts and source changes during the run. A Godot process exiting zero alone
is not accepted as a passing test.

- `scenery_contract.gd`: 2,569 assertions across all 32 districts. Includes actual
  crop uniqueness for all 13 City/Crown starts, source bounds and aspect ratio,
  full-width coverage, deterministic bay selection, independent profile copies,
  global RNG isolation, all-physics-tree snapshots, actor/source-pose preservation,
  no objective mutation, and sight-hidden rebuilds.
- `input_parity.gd`: 1,205 assertions on 5 district-start fixtures, one per level.
  Each compares 120 real input ticks with scenery attached versus removed:
  movement, jump, strike, guard and roll. Positions, velocities, movement/combat
  states, health and facing agree. This is bounded parity evidence, not a full
  campaign traversal or comprehensive combat proof.
- Existing `presentation_contract.gd` and `runtime_sight_contract.gd` are rerun,
  including the real sight trade, blind district rebuild/retry and fresh new run.

## Visual evidence and limits

The first actual native fixture pass showed excessive placard size. That version
was not accepted as the final composition. Placards were reduced to 65% scale
and given bounded seeded placement. All 61 actual native fixtures in
`nov6_native_review_round3` were then inspected: 32 district starts plus 29
objective-position fixtures. The smaller signs, district-specific equipment and
varied skyline crops preserve the foreground contrast of actors, objectives and
real platforms. Native `nov6_native_ui_round1` blind fixtures for Rainline, Cistern
and Crown also show no skyline, placard or equipment leakage, with and without
a sonar tap. These are direct scene fixtures, not complete native traversal.

The focused gate passed with no engine errors or leaks; its source-hashed report
and four logs are produced by `run.py`. The capture-all native exit warning was
identified separately as active `audio/ambience.wav` playback, not a scenery/font
resource. Native capture teardown is tracked by the main QA pass. This scenery
review does not establish frame performance, audible mix, or human playtime.
