# Independent boundary review

## Verdict

Pass for the reviewed boundary contract on the final frozen Godot source snapshot. Two independently reproduced defects were corrected by the implementation owner, and the unchanged targeted reproductions now pass. No remaining blocker was found. This review does not substitute for the owner's full foundation, route, historical, or native acceptance run.

Final execution used Godot `4.6.3.stable.official.7d41c59c4` in an isolated `/tmp` project copy, with separate XDG directories. The original repository's 528 `.gd`, `.tscn`, and `.tres` files remained unchanged during final verification; the copy matches every original source hash. `final_source_verification.json` records zero source changes, zero copied-source mismatches, and zero error/warning lines in the final green logs. The larger owner-managed 592-file freeze additionally includes Python and project configuration, which this independent source manifest does not enumerate.

## Final results

| Run | Rate | Scenarios | Checks | Failures |
|---|---:|---:|---:|---:|
| Independent callback/admission suite | 60 | 26 | 95 | 0 |
| Independent callback/admission suite | 120 | 26 | 95 | 0 |
| Existing ordinary Health compatibility | 60 | 25 | 182 | 0 |
| Existing ordinary Health compatibility | 120 | 25 | 182 | 0 |
| Freed authority inputs | default | — | 2 | 0 |
| Freed participant inputs | default | — | 16 | 0 |
| Exact standalone world-swap reproduction | 60 | 1 | 2 | 0 |
| Exact standalone world-swap reproduction | 120 | 1 | 2 | 0 |

576 executed checks, including deliberately overlapping standalone reproducers. The independent suite reuses the existing production scene factory and two genuine solver/mission fixture helpers, but adds its own callback ordering, replay, boundedness, inbound charge retirement, stale mission, freed source, and world lifecycle probes. It is not a claim that all cases are independent fixtures or physical crossings. Direct API/lifecycle positioning in the capacity probe is explicitly labeled and is not used as gravity-crossing evidence.

## Defects found and verified fixed

1. **Freed public participants raised runtime errors instead of rejecting safely.** A captured boundary packet replayed after its source was freed reached an `is` type test on a freed instance. Freed receiver authority likewise faulted in the player; a typed cargo authority argument raised before entering the rejection guard. The owner added validity-before-type checks and Variant public input boundaries. Red logs preserve these exceptions even though the first suite's numeric assertions alone passed. Final probes verify freed/null/scalar participants reject without errors, debit, retirement, or binding replacement. Evidence: `red_freed_source_60.log`, `red_freed_source_120.log`, `freed_authority_red.log`; final `independent*_final.log`, `freed_authority_final.log`, and `freed_participants_final.log`.
2. **A World2D swap and restoration during an earlier damage subscriber preserved stale authority.** A real falling actor's earlier `damage_resolved` listener changed its SubViewport world and restored it before Health consumed the receipt. The original run recorded unchanged hazard epochs `[5,5]` and Health `0`, failing the retirement check. The owner added ENTER_CANVAS, EXIT_CANVAS and WORLD_2D_CHANGED invalidation to source, receiver and BoundaryScope. The unchanged standalone repro at both rates now records epochs `[8,20]`, Health `60`, and both checks passing. Evidence: `red_world_swap.{json,log}` and `world_swap_{60,120}_green.{json,log}`. This scenario was also added to the final independent suite, increasing it from 25/93 to 26/95.

## Reviewed guarantees and coverage

- Pre-Health same-store reset/rebind; source queue, native physics disable, local transform ABA, profile ABA, pause ABA; receiver local transform/path ABA and replacement; instrumented scope transform ABA.
- Exact original nested receipt consumption once, altered/equal/stripped copy rejection, post-scope replay rejection, and stripped replay rejection after same-life Health reset or rebind.
- Genuine ordinary N+1-before-N receipt ordering remains supported; nested ordinary damage retires stale guarded authority.
- Sixteen simultaneous reservations, explicit release and frame pruning; 128 disjoint guarded history ranges fail closed without breaking ordinary damage; new actor life reopens capacity.
- Genuine solver-held inbound charge packet delivered from a destroyed callback cannot recharge retired cargo; donor pending impact/charge retirement races retain existing genuine solver helpers.
- Current mission defeat observer behavior, including earlier reset and stale callbacks after actor/sector replacement.
- Freed participant entry points, captured closed/freed-source packet replay, and world swap ABA.

The public contract documentation was checked against implementation. It correctly describes an origin-point half-plane, source-local y=0 placed at room y=420, sampled crossings, initial occupancy policy, one attempted outside episode, scalar-only receipt seals, capacity limits, ordinary trusted-signal assumptions, cargo retirement ordering, mission observer identities, and the distinction between the locked-gap fixture and authored Cistern. External movable ancestors must use BoundaryScope or call `invalidate_observations()` before repositioning; arbitrary uninstrumented ancestor ABA is explicitly outside the promise. No hostile arbitrary script mutation defense or whole-shape collision guarantee is implied.

## Reproduction

`commands.sh.txt` lists the exact executable arguments and XDG setup used. Probes are archived as `.gd.txt` to avoid changing an executable source freeze when this evidence is copied into the repository. Restore the five probe filenames to `.gd` at the root of a separate copied project to rerun. Their output paths intentionally remain `/tmp/moksha_boundary_independent`, so create that directory first. The ordinary Health runner writes only within that copied project; its final result bytes are also archived here as `health_60.json` and `health_120.json`.

The initial, revised, and final source manifests are retained along with the red and green logs. Source freezes are distinguished, rather than presenting initial red results as results on final hashes. `MANIFEST.sha256` covers this archive's individual evidence files. No original repository files or prior reports were edited by this reviewer.
