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
Results: 21 focused checks and 2,581 existing scenery checks passed.

capture.gd is a DIRECT POSITIONED VISUAL FIXTURE for opening/street/upper/clinic
and sight-traded darkness; these stills are not evidence of traversing a route.
Actual-input footage uses the existing nov6_full_campaign_route.gd script,
starting normally and issuing movement/action input; it is automated, not human
play. A short excerpt is not a new complete campaign/Windows/controller test.

Native render environment is Linux llvmpipe software graphics. A preliminary
30-second 1280x720 60fps movie took 172 wall seconds including synchronous movie
encoding: average CPU render18.57ms, GPU19.15ms, encoding17.92ms. These are offline
capture costs, NOT a measured real-time PC framerate. Native movie quit-after
reports existing route-harness teardown resource warnings; no runtime script
errors were observed. This pass makes no broad hardware performance claim.

Limits: one original painted backdrop reused across inhabited profiles; gallery
rails and animated people are stylized overlays, not depth-aware world simulation.
Painting seams use structural joints. Foreground navy terrain fill remains the
existing game art. Native frames are visually reviewed; hardware PC validation
and full integration regression belong to the release owner.
