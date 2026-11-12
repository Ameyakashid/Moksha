CISTERN / WATERWORKS VISUAL CANDIDATE
Base: c029797. Separate from delivered fe9936a release.

Responsibility: district-owned derived presentation using explicit identity,
camera and visibility inputs, following the previously reviewed map/view lifecycle
boundary. No copied implementation, no physics, objectives, actor authority,
save data or input changes. Level 3 only. Levels 1/2 retain their exact renderers;
Levels 4/5 retain established scenery. Old covered backdrop drawing is suppressed.

One original cyan-green reservoir/residential painting, not market/foundry reuse.
Separate warmer residential framing reveals occupied windows under the HUD;
cistern profile retains cold industrial reservoir depth. Static tiny illustrated
residents occupy dry distant bridges. At most 6 dim drips animate; no person nodes,
water physics, dynamic lights or per-frame generated textures. A 10Hz stationary
redraw request does not cap camera-triggered drawing. Tile/camera work is bounded
by viewport, never total district width. Structural joints hide painting seams.

Exact 2,430,001-byte inventory allowance added for the single new PNG. Existing
individual-file, pixel, count and audio limits remain unchanged. Inventory is
not installed size, GPU memory, target-PC framerate or Windows acceptance.

capture.gd stages Cistern and Homes directly for visual inspection and blind
concealment, NOT traversal evidence. render_sweep.gd uses 600 identical camera
steps, presentation only, no simulation: NOT gameplay footage. Actual-input
footage uses the existing generic checkpoint route recorder at
res://campaign/quality/nov12_foundry/record_route.gd with --district=l3_cistern.
That seeds district entry once, then uses ordinary automated input; not manual
play or whole campaign evidence. Neither fixture nor recorder changes layouts.

Validation receipts below separate staged fixtures, isolated rendering and real-input footage.

VALIDATION RECEIPT
- 10 focused waterworks checks, 40 explicit atmosphere-adapter checks and 2,587
  existing scenery checks pass. Existing scenery test is unchanged; six new
  Level 3 presentation nodes add six recursive decoration-only assertions.
  Exact Level 1/Level 2 renderer/population assertions remain; Levels 4/5 excluded.
- Asset audit passes inventory 17,916,078 bytes against 18,890,638 limit.
  New PNG is 2,430,001 bytes; unrelated file/pixel/count/audio limits unchanged.
- Native Cistern and Homes staged frames inspected. Homes framing lowered to
  reveal occupied windows below HUD; cold reservoir profile remains separate.
  Native blind fixture shows no background/window/drip leakage.
- Matched presentation-only sweep: c029797 baseline versus 91884d2, independent
  clean processes, 600 identical camera steps / 601 recorded frames, 640x360,
  Godot 4.6.3 gl_compatibility/llvmpipe, fixed 60Hz, disabled vsync, Dummy audio.
  All other workers confirmed CPU-heavy jobs idle before the accepted repeat.
  Earlier potentially contaminated pair was retained separately and EXCLUDED.
                    baseline          candidate
  CPU rendering     8.53ms/frame       1.10ms/frame
  GPU rendering    15.61ms/frame       5.51ms/frame
  Movie encoding    3.62ms/frame       4.58ms/frame
  Both exited 0. Isolates derived presentation only, not actors/game simulation;
  no full-game performance parity, target-PC FPS or Windows claim.

Reproduce sweep with the same external script for both project roots:
godot --path <project> --rendering-method gl_compatibility --fixed-fps 60 --disable-vsync --audio-driver Dummy --write-movie <output.avi> --script <absolute-render_sweep.gd>
Use identical project window overrides 640x360; --resolution alone is insufficient.
Native fixture supports --output=<directory> and --prefix=<label-> arguments.

Static illustrated residents are not animated civilians. One original painting
is shared across Level 3; no individually generated art for every district.
No geometry/input/save/objective changes. Full route/Windows/audio/controller
acceptance is outside this bounded visual pass.

ACTUAL-INPUT CLIP
MOKSHA-cistern-91884d2-automated.mp4, 30.033 seconds, 5,884,850 bytes.
Explicit Cistern checkpoint start, then ordinary automated inputs; 0 deaths,
first survey objective observed, no source drift/script errors. This excerpt
DOES NOT complete the district or Level 3. Labelled automated/1x/checkpoint/Linux.
Full ffmpeg decode passed; actual frames at15s/25s visually inspected. SHA256:
720dd01c99c277d322338ffb88fd6f5463f69525cf945d9d40f757b3f5e542e5

SEPARATE INTEGRATED HOMES VISUAL REVIEW
External staged fixtures inspected combined next-candidate c23dc32 after its
independent cache/sign changes. Shelter sign at (3000,250) clears the goal lock
icon in both locked and available states. Supplies, shelter and east-roof labels
remain separated/readable against occupied windows/waterworks. Available state
explicitly seeds the prerequisite for VISUAL review, not traversal evidence.
No integrated production files changed during review. Initial launch before
standard editor import lacked generated texture caches; those initial frames
were rejected and recaptured after import. Final fixtures exited 0 without
script errors. Original delivered fe9936a artifacts remain untouched.
