Level 2 foundry atmosphere candidate from fe9936a

Responsibility map: follows existing district-owned derived view boundary,
informed by previously inspected public shapez map/map_view lifecycle evidence.
No copied implementation. CampaignScenery owns Architecture/FoundryDepth;
explicit district identity and camera values only. No saves, input, physics,
objectives or actor authority. Entire subtree hides with sight trade.

Original foundry painting and cyan/amber industrial palette replace the sparse
flat bay appearance for Level 2. Different Thermal/Freight modulation, distant
crane and service galleries, restrained worker animation. Painting is one shared
plate, not six individually authored district backgrounds. Old procedural paint
is suppressed beneath the opaque plate to avoid duplicate rendering.
Workers are derived paint, max 9visible and zero per-person nodes. Camera moves
redraw the bounded visible view;15Hz scheduling applies only to stationary views.
No per-frame asset generation, lighting simulation or physics crowds.

Focused tests: nov12_foundry/contract.gd; existing adapter test expanded explicitly
to Level 2 and old scenery contract unchanged. Six new Level 2 nodes add6recursive
node assertions (2,575 to2,581), not six new gameplay acceptance categories.
Capture.gd directly stages Thermal/Freight positions and blind view, NOT route proof.
Record_route.gd starts from an explicit district checkpoint, then ordinary
existing automated input. It is not manual play or complete campaign proof.

Budget: one2,221,563 byte original PNG addition is explicitly accounted for in
assets_budgets.json inventory_bytes limit only. All other limits unchanged.
This is source inventory allowance, not GPU memory, FPS or installed size.

Validation measurements and limits appear below.
Frozen fe9936a release and delivered artifacts are not modified by this branch.

FINAL VALIDATION
-8 foundry contract checks,34 explicit adapter checks,2,581 unchanged scenery checks
 passed. Adapter keeps exact Level 1 renderer/144 population assertions, adds exact
 Level 2 renderer/max 9 worker assertions and retains exclusion of Levels 3–5.
-Asset audit passed. Inventory15,481,686 bytes versus16,460,637 reviewed limit;
 largest-file/pixel/count/audio limits unchanged.
-Identically positioned1280x720 Thermal/Freight fixtures compared with fe9936a;
 original bitmap lower boundary softened with gradient/dim service structures.
 Pale enemy/contact silhouettes remain distinct; blind frame hides all new paint.
-Actual-input checkpoint-start Freight clips: both0 deaths, both goals, no source
 drift/script errors. Baseline exited district at24.22s; candidate ran30s after
 extra return movement. Thus these clips are NOT matched timing/complete-level
 proof. No physics, input, goals or layouts changed; route dispatch timing can
 differ. Do not advertise identical traversal or Windows/controller acceptance.
-Correct isolated render comparison: render_sweep.gd, same601 recorded frames,
 600 camera positions,640x360, Godot 4.6.3 gl_compatibility/llvmpipe, fixed 60Hz,
 disabled vsync, Dummy audio, same 640x360 window override, separate fresh processes.
 Other workers paused CPU-heavy jobs. This contains presentation ONLY, no actors
 or gameplay simulation, and must not be described as gameplay footage.
                    fe9936a baseline   foundry candidate
 CPU render          5.20ms/frame       1.32ms/frame
 GPU render         12.52ms/frame       5.01ms/frame
 Movie encoding      3.52ms/frame       4.43ms/frame
 Both exited 0. This single shared-host check detects no renderer regression;
 it is not target-PC FPS, a broad benchmark or complete-game performance parity.

Reproduce isolated sweep:
godot --path <project> --rendering-method gl_compatibility --fixed-fps 60
 --disable-vsync --audio-driver Dummy --write-movie <output.avi>
 --script <absolute-path-to-render_sweep.gd>
Both project
window/size/window_width_override and height must be640/360 for comparison;
--resolution alone can be overridden by project configuration.
Capture fixture: --script res://campaign/quality/nov12_foundry/capture.gd
 -- --output=<review-directory> --prefix=<label->

Delivered real-input video: MOKSHA-foundry-a8c9a18-automated.mp4,
30.033seconds,6,276,277bytes, labelled checkpoint-start/automated/1x/Linux.
Full ffmpeg decode passed; actual frames 15/25s inspected. SHA256:
3a7599374072ac08323bbc083a1a2e98f7795c3dd3dcecc015d30cda46f2973f

Limits: shared painting across Level 2, static distant illustrated workers plus
sparse stylized moving silhouettes, no crowd physics. Actual revised Thermal
layout integration/full-route matrix is a separate worker's responsibility.
Frozen release untouched; this is a separately reviewable candidate.
