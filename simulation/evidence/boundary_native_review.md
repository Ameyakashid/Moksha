# Native boundary review

Actual Godot desktop review by the parent reviewer, 2026-10-20. Seven original
1364 × 1024 JPEG captures are indexed in `boundary_native_capture_hashes.json`.

Observed with ordinary controls in the explicitly labelled locked-gap fixture:
- Readable title, controls, four airborne guards and physical cargo.
- J launched rotating cargo over the ledge. Cargo disappearance was seen, but its
  exact retirement timing and pending-contact semantics were not proven natively.
- D caused an ordinary fall, Health 0/60, and the standard defeat screen.
- Enter retry restored Health 60, the crate and all four guards.
- Waiting / Q left the four airborne guards gone; HUD changed from four guards to
  “Reach door”. Exact per-actor Health/Defeat accounting is automated evidence.
- Final presentation check accepted both complete HUD legend lines with no left
  clipping or tutorial-banner overlap; the red boundary remained visible.

The first world-space legend clipped at the left edge and overlapped the black
instruction banner. It was replaced with a fixed HUD legend. The final native
pass checked this presentation only; mechanics were not repeated after that
label-only change. The six earlier observation captures are retained.

Output showed 0/0; Debugger showed 29 stable, unexpanded entries. This is not a
claim that the debugger was investigated or that the native run was error-free.
The exact origin-witness boundary, callback fencing, pending cargo retirement,
and equality across all roles/rates are headless evidence. No audible-mix or
full-campaign native playtest claim is made. CUA was stopped and released.
