# Production-input district observer

`l23_route.gd` extends the preserved campaign navigation/combat observer and adds actual objective state observation, physical objective-door navigation, local E/Q key dispatch, modern multi-strike freight transport, and a residential roof route.

Example:

```sh
mkdir -p /tmp/moksha-route/{home,config,data,cache}
export HOME=/tmp/moksha-route/home XDG_CONFIG_HOME=/tmp/moksha-route/config
export XDG_DATA_HOME=/tmp/moksha-route/data XDG_CACHE_HOME=/tmp/moksha-route/cache
godot --headless --path . --fixed-fps 60 \
 --script res://campaign/route_tests/l23_route.gd -- \
 --district=l2_capacitor_mill --hz=60 --sector-timeout=240
```

Add `--sacrifice` for an explicitly labeled pre-run traded-sight fixture. The fixture selects the district and sight before timing, then asserts actual blindness. This is **not evidence of reaching that district through the campaign or making the original sight choice**. Use full-campaign testing separately for those claims.

The measured phase supplies ordinary movement/combat button dictionaries accepted by the production player. All E/Q interactions are `InputEventKey` events queued through an ordinary idle-process dispatcher. It neither writes player positions nor alters health, enemy state, gates, objective completion or physics. The observer reads layout, AI state and real collision geometry; it is knowledgeable and is **not** unfamiliar-player testing. Cargo transport follows the current crate and uses repeated real attacks; a broken/off-deck cargo is replaced through the production cradle's E interaction.

Output per district/sight: JSON containing goal receipts, real transitions, last60 input/position snapshots, damage events, script hashes and source drift. `passed` proves onward transition in that isolated run, not frozen-source acceptance when `source_drift` is non-empty. Timing is simulated active bot time, never human duration. Optional goals are not required; incidental completion is recorded.

## Observer iteration, not production fixes

- First draft accidentally retained already-open objective doors in its navigation array. Corrected by rebuilding from actual live door state.
- The inherited obsolete single-hit freight plan assumed ballistic delivery. Modern production cargo requires following and multiple strikes; observer updated to the preserved Freight Journey policy. No cargo friction, strength or acceptance was changed.
- Residential ground shortest paths ignored existing tall retaining walls. The observer now follows the already proven roof sequence, visiting the new required courtyard and returning by a fixed ladder. No original wall was removed.
- Initial traded fixture lacked the choice state required by production `choose_sight`; corrected before any successful traded evidence, with an actual-blindness assertion and explicit fixture label.

Runtime and authored-layout changes invalidate the relevant captured-source acceptance; inspect `source_drift` and rerun on final frozen files. Do not claim a complete five-level run by concatenating isolated reports.

## Added encounter observations

Two final-district captains are integrated into the observer's target choice: after required local objectives, it seeks the living required captain rather than treating all ordinary guards as a kill gate. The production combat controller still receives ordinary facing, strike and shield inputs. L2 Keeper and L3 Lancer each completed in retained/traded development probes. New physical breakers likewise complete through actual J contacts, not E or completion writes.

Final acceptance must capture all recursively hashed `.gd`, `.tscn`, `.tres` and `.gdshader` sources with no in-run drift. `summarize.py` also compares those hashes with current files and reports old-version evidence separately. Isolated test success never establishes the full32-district sequence, persistent upgrade behavior, human usability or75–100minute duration.

## Critical historical-evidence invalidation

The lead found that campaign health replacement left incoming strike/projectile/physical-impact/boundary receiver weak references pointing at the freed store. Those receivers have now been rebound. **All pre-fix route survival results are invalid as combat/survival acceptance**, even where navigation and ordinary objective/cargo contacts were real. Preserve them as historical diagnostics only. Fresh runs must use the rebound receiver source and establish actual survival under admitted enemy damage; do not weaken enemy stats or write health to make the observer pass.
