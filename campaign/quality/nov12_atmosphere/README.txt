NEON ARCOLOGY PRESENTATION PASS — 2026-11-12

Boundary: CampaignScenery owns Architecture, which owns InhabitedArcology.
The presentation consumes only district id/width and camera center/viewport size.
It owns no physics bodies, goals, saves, input, actors, global RNG or gameplay state.
The entire subtree is hidden with the established sight trade and destroyed with
its district. Existing scenery host shape remains two children. Level 1 opening
profiles opt in; other districts retain their authored presentation. Cistern
was inspected with the plate; it diluted water identity, so Level3 was excluded.

Presentation: original parallax industrial city painting, tiny gallery service
signs and bounded civilian silhouettes, all at world z=-8 behind terrain (-5)
and gameplay actors. 144 citizen specifications per district, zero citizen nodes;
only viewport-adjacent citizens are drawn (8–12 in reviewed fixtures). Upper tiers
are 72% of near-tier size and darker. Walking and idle variants use bounded local
oscillation, not crowd AI or route navigation. Static painted crowds supply
additional distant population. No foreground collision geometry was altered.

Verification commands (Godot 4.6.3; isolated HOME and XDG dirs):
godot --headless --path . --script res://campaign/quality/nov12_atmosphere/contract.gd
godot --headless --path . --script res://campaign/quality/nov6_scenery/scenery_contract.gd
Results: 21 focused checks and 2,575 existing scenery checks passed.

capture.gd is a DIRECT POSITIONED VISUAL FIXTURE for opening/street/upper/clinic
and sight-traded darkness; these stills are not evidence of traversing a route.
Actual-input footage uses the existing nov6_full_campaign_route.gd script,
starting normally and issuing movement/action input; it is automated, not human
play. A short excerpt is not a new complete campaign/Windows/controller test.

Native render environment is Linux llvmpipe software graphics. Matched sequential
30-second/1,800-frame fixed60Hz captures at640x360 using the same existing route:
                         c73159b baseline    f1b5fd2 atmosphere
CPU rendering             12.79 ms/frame       18.57 ms/frame
GPU rendering             13.46 ms/frame       19.12 ms/frame
Movie encoding             4.78 ms/frame        4.89 ms/frame
Wall recording time       107 seconds          116 seconds
The presentation has a measurable software-render cost (+45% CPU/+42% GPU in
this single shared-host pass). This is not performance parity or target-PC FPS.
Both runs used gl_compatibility, disabled vsync, Dummy audio, fixed60Hz and an
untracked capture-only override.cfg setting window override640x360. --resolution
alone did not override the project setting. No gameplay changes in that config.
A prior1280x720 capture must not be compared with the640x360 baseline.
Camera changes can redraw the whole view every frame;30Hz animation scheduling
only bounds stationary redraw requests, not moving-camera draw frequency. Future
optimization can separate/copy-cache background and crowd draw work; this visual
checkpoint intentionally does not claim that optimization is complete.
Native movie quit-after reports existing route-harness teardown resource warnings;
no runtime script errors observed. Both capture processes exited0. FinalMP4 is
30seconds at30fps,8,260,679bytes; full ffmpeg decode passed, native frames inspected.
Final source video SHA256:
9f6894e9e812af3b98e03f1d8145765105d0ba1d4dc18cb75b6b00da37c7de8f

Limits: one original painted backdrop reused across inhabited profiles; gallery
rails and animated people are stylized overlays, not depth-aware world simulation.
Painting seams use structural joints. Foreground navy terrain fill remains the
existing game art. Native frames are visually reviewed; hardware PC validation
and full integration regression belong to the release owner.
