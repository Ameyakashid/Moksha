# November 12 PC startup and caption check

Source base: `c73159bc61ded1044786d223186225d6c474cd02`.
Engine: `4.6.3.stable.official.7d41c59c4` on Linux.

## Changes

- `Play-MOKSHA.cmd` provides a no-download source launch path. It accepts an
  explicit Godot executable, checks 4.6.3, imports local assets and starts the
  project only after successful import. `PC_QUICKSTART.md` separates this from
  the previously delivered portable Windows EXE/PCK.
- Objective machine paint stays at z=-1. Its caption child moves from z=4 to
  z=7, giving an effective layer of 6, above real crates at z=5. The child stays
  relative and inside its authoritative blind-hidden presentation owner.

## Results

- `python3 tools/pc_startup_contract_test.py`: 2 static safety/docs tests passed.
  These do **not** execute Windows CMD.
- Fresh Godot headless editor import completed without script/parse errors.
  Source main-scene startup (`--headless --quit-after 30`) exited 0 without
  error diagnostics. Import/startup use separate HOME/XDG directories.
- `campaign/presentation/tests/objective_paint_contract.gd`: 151 checks passed.
  The added checks instantiate the real crate scene, compare effective caption
  depth with its actual layer, and retain parent-relative visibility checks.
- Negative control: temporarily restoring only the original caption z=4 caused
  the new foreground-crate check to fail with exit 1. The fix was restored.
- Native rendered comparison: direct fixture loading of Capacitor Mill
  (`l2_capacitor_mill`, district 8), with world position/physics frozen between
  the old/fixed layer captures. The first image deliberately restores the old
  caption layer at runtime; the second uses the fix. The third enters the real
  sight-trade path and asserts caption visibility is off before capture.

The native images were inspected individually at full size. The old-layer image
shows the crate hiding letters in "Ground the live bus: position 2" and its
routing instruction. The fixed image shows both complete lines in front of the
crate. In the blind image, world scenery and objective captions are absent;
HUD guidance and the player sound silhouette remain.

These are **staged presentation fixtures, not playthroughs or route proof**.
The native log reports unsupported V-Sync, no ALSA device/dummy audio fallback,
and ObjectDB/two-resource exit warnings. It exited 0 and completed its image
checks; it is not a clean native/audio acceptance claim. No audio-hardware,
performance, full campaign, or native Windows verification is claimed here.

The delivered November 6 executable is unchanged. This fix reaches players only
through this newer source or a separately rebuilt/verified portable package.
