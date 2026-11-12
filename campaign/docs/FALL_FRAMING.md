# Bounded fall framing candidate

Readability experiment, not a guarantee of safe drops. The Market brief explicitly says fixed ladders bypass exposed floor arcs. Retained c977 movie72.5 shows landing floor outside view, and73 shows arc contact/8HP loss; neither establishes unavoidable damage, a ladder defect or poor hazard balance. Slow screenshot-driven controls are not a balance benchmark.

## Real implementation reference and original mapping

Official SuperTux commit2975428aef94fdc3d6b6ec04cc94ec7a98b116eb:
- https://github.com/SuperTux/supertux/blob/2975428aef94fdc3d6b6ec04cc94ec7a98b116eb/src/object/camera.cpp#L499-L595
- https://github.com/SuperTux/supertux/blob/2975428aef94fdc3d6b6ec04cc94ec7a98b116eb/src/object/player.cpp#L1642-L1656

Read source: camera owns feet-relative framing, a separate peek state and final sector clamps; player owns separate PEEK_UP/DOWN intent. MOKSHA maps presentation state/bounds to campaign camera_follow and provides post-controller observations from campaign.gd. Unlike SuperTux's explicit peek, this original experiment derives bias from motion. No code/assets copied; SuperTux code is GPLv3-or-later. Its architecture is a reference, not a quality guarantee. S/Down remains untouched.

## Ownership and hypotheses

Only camera_follow.gd and its campaign caller change. Existing baseline center remains independent; output adds bounded bias without feeding back rendered clamps. Old callers default grounded=true and retain original behavior. Campaign passes actual grounded state only when elapsed gameplay advanced.

Arming requires160pixels continuous descent and speed>220 for0.10s. Slow speed<80 for0.10s disarms; ground/ascent disarm immediately. Target is speed*0.18 capped96pixels, slew480px/s in and360px/s out, step capped0.10s. Rendered bias also keeps feet at/below screen104 before room bounds. Neutral ground/ascent/short-jump/ladder trajectories preserve baseline; after an active fall bias eases away, not instant snapping. These are tunable hypotheses, not borrowed constants or validated comfort claims.

Reset clears all temporal state; dt<=0 freezes output/state; existing >640px teleport resets. Room load already calls reset. No save/input/controller/hazard/audio/sonar changes. Camera only reprojects existing sensed contours; it must not create knowledge. Market shelf-to-floor390pixels exceeds360pixel view, so this does not promise a visible landing before committing.

## Evidence and remaining gates

Headless deterministic contract:2226checks at explicit60/120Hz, neutral parity against frozen9c camera, baseline independence, distance arming, bounded bias/slew, foot bounds, slow-speed hysteresis, landing recovery, dt0, resets, room edges, teleport and large dt. Inherited camera contract384checks passes. Baseline fixture is our own9c camera preserved byte-for-byte, not third-party code.

External logs: /tmp/moksha-fall-tests. Initial process lacked writable user/cache dirs and aborted; rerun uses isolated HOME/XDG dirs. First trajectory test incorrectly descended240pixels instead of120; corrected fixture to stop at one jump cycle, not production tuning. Failed logs retained.

Pending: independent source review; same ordinary-input actual-player baseline/candidate replay equality; native sighted/blind overlay registration and retained motion inspection. Mathematical tests are not gameplay or usability acceptance. Record whether landing becomes visible earlier, but do not claim every deep drop fair/safe. Verify player, scent, touch, sonar contours, HUD notices and caption culling under shifted view; retain intended ladder bypass risk.
