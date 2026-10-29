# Lithe connected wireframe

An optional, view-only replacement for the established MOKSHA wireframe. All geometry and tuning here are original MOKSHA work. This is not extracted Dead Cells animation data, and no numerical or frame-accurate reference-game parity is claimed.

## Integration

Keep the existing actor, motor, resources, collision, input and contact children. Override the script on its existing child named `Visual`:

```gdscript
const LITHE_VIEW = preload("res://combat_pc/visuals/lithe_wireframe.gd")
var actor = preload("res://combat_pc/player.tscn").instantiate()
actor.get_node("Visual").set_script(LITHE_VIEW)
add_child(actor)
```

Apply the replacement before adding the actor to the tree. The equivalent inherited-scene override is:

```ini
[ext_resource type="Script" path="res://combat_pc/visuals/lithe_wireframe.gd" id="Lithe"]

[node name="Visual" parent="Player" index="1"]
script = ExtResource("Lithe")
```

Update the containing scene's `load_steps` and retain `[editable path="Player"]` when needed for its inherited child override. No change to `combat_pc/player.tscn`, `player.gd`, `wireframe.gd` or `project.godot` is required. Remove the override to restore the baseline.

The replacement subclasses `wireframe.gd`. Its public `present`, `update_visual`, `event`, `reset_presentation`, `evaluate_pose`, `get_pose`, `get_bones`, `phase_event`, preview properties and optional `ground_presentation` resource remain available. Existing stance events and support contacts still come from the original contact layer. It does not move the actor, query input, create a damage area or modify phase timing.

## What changes

- Explicit connected clavicle, pelvis and neck-to-skull lines; the head no longer floats above the body.
- Narrower shoulder/pelvis proportions and a compact torso, with distinct near/far line weight.
- Distance-driven running, linear world-matched stance, smooth swing endpoint tangents and early folded-heel recovery.
- Reachable targets before two-bone solving; 8/8-pixel legs and 6/5.8-pixel arms retain fixed lengths.
- Smooth ordinary locomotion entries, applied before support locking so the planted foot cannot be filtered away from its anchor.
- Smooth authored takeoff/air-jump transitions and roll fold/unfold, while physical action phases remain authoritative.
- Original specialized melee, shield, ledge, climb, wall, hard-landing, dive and defeat geometry is retained. These receive the connected rendering; their contact/weapon evidence and phase ownership are preserved.

`locomotion_blend_seconds` defaults to 0.055. It can be set to zero. Facing reversal is immediate, and mirrored old poses are never blended through the body. Roll/crouch entries and specialized traversal bypass the ordinary standing crossfade. `show_contact_marks` exposes planted feet.

## Runnable review

Open `combat_pc/lithe_animation_review.tscn` and press F6. The upper left is the original view, upper right is the lithe replacement, and the bottom is one real PC. Both enlarged views consume the same actual controller telemetry and events.

The automatic reel runs, jumps, reverses, rolls and performs three strikes. A/D or arrows, Space, Shift, J and K switch to manual movement, jump, roll, melee and shield. G toggles planted-foot dots. R resets the automatic reel. This scene is separate from the main project entry point.

On a working graphical display, capture four real viewport images with:

```sh
godot --path . combat_pc/lithe_animation_review.tscn -- --lithe-capture
```

This writes `combat_pc/tests/lithe_review_{run,jump,roll,melee}.png`. It requires a graphical renderer, not Godot's dummy headless renderer.

## Verification

```sh
godot --headless --path . --script combat_pc/tests/lithe_animation_regression.gd -- --hz=60
godot --headless --path . --script combat_pc/tests/lithe_animation_regression.gd -- --hz=120
```

The focused suite samples 3,636 poses per rate, including both facings. It checks fixed limb lengths, finite complete bone dictionaries, the cyclic gait seam, preserved specialized pose data, stance intervals, world-space foot locking, moving-floor and moving-slope support, duplicate-tick idempotence, pause and reset. A real physics-callback comparison drives the original and replacement views through run, reversal, jump, roll, melee and shield. It explicitly checks that the expected action modes were entered.

Reports: `combat_pc/tests/lithe_results_60hz.json` and `lithe_results_120hz.json`. The two physical actors use translated start positions; the report retains the measured small floating-point translation difference rather than claiming byte-identical physics coordinates. This focused suite does not replace every historical game regression or native visual review.

The final focused runs on Godot 4.6.3 pass 268 checks at 60 Hz and 508 at 120 Hz. Maximum sampled limb-length error is below 0.000003 pixels; planted-foot and moving-support drift are below 0.000001 pixels. A separate 1,800-frame, fixed-120-FPS headless scene run exercises multiple complete automatic reels and resets without runtime errors.

Native visual sampling on 2026-10-19 confirmed the actual review scene launches, and its idle, turn/run, jump-apex and roll-travel presentations remain connected. Manual jump and roll showed tucked knees and a compact roll; no detached limbs or obvious floor penetration were observed in those sampled frames. The small live actor was readable, while the enlarged A/B view appeared somewhat soft. Discrete native observations do not constitute continuous-motion timing or foot-slip measurement; those contact measurements come from the automated traces above.

`lithe_pose_export.gd` plus `lithe_render_pose_sheet.py` produce the labelled `lithe_pose_sheet.png` diagnostic from actual evaluated Godot geometry. This is a pose study, not a native screenshot, and does not establish live timing quality.
