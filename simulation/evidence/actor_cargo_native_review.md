# Native actor / cargo review

Reviewed in Godot 4.6.3 on the frozen actor/cargo candidate. `res://simulation/actor_cargo_review.tscn` is a save-disabled isolated start in unchanged Rainline geometry, with production cargo and actor logic. It is not a complete campaign run.

The native operator used real keyboard input. Grounded A visibly moved an upright crate left while the PC stayed grounded, with no apparent penetration. Actual J from the left launched the crate right and upward with visible rotation. PC Health remained 60. The writer visually checked the walk-push and J-launch JPEGs, which show the grounded adjacent PC/crate and the later airborne rotating crate.

Standing on the top was **not established natively**: jump attempts crossed, missed, or fell. NPC melee launch, charged cargo damage, defense timing, rotational support retention and precise force/impact thresholds were not observed natively; their evidence is the automated real-contact suites. The landing/crossing/missed-top images document attempts, not successful support.

R reset worked, but replaced the review-specific caption with the Rainline tutorial. The isolated-start identity still applies after that reset. There was no visible clipping or runtime interruption. The operator reported Output 0/0; the native Debugger showed 24 stable, unexpanded entries, which are not claimed investigated. F8 released the run.

`actor_cargo_native_capture_hashes.json` records eight verified JPEG captures at 1364×1024. Primary captures are side, walk_push, top_attempt, j_launch and after_launch. The additional landing, crossing and missed_top_fall frames preserve the unsuccessful top-support attempts.
