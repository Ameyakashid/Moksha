# First Ascent: autonomous completion checkpoints

## Scope and acceptance
A finite playable demo using the approved v26 combat actor, from a city awakening through an optional sight-for-speed trade and arcology ascent to a secured evacuation lift and explicit ending. This is one continuous mission divided into retryable sectors, not four finished roguelite floors. The original grand-story contradictions are not resolved here. Target about 30 minutes only if supported by play evidence; do not pad routes or report unmeasured duration.

Baseline: `/workspace/shared/moksha-v26-baseline-20261019.tar.gz` preserves the source before this continuation. Existing review scenes and actor/controller resources remain usable. New composition lives under `demo/` and the optional lithe view under `combat_pc/visuals/`.

1. Replaceable connected lithe animation; no motor changes. Gate: actual pose geometry and motion tests, rendered review.
2. Reusable enemies; genuine physical v26 strike/defense and health/death integration. Gate: enemy regression, no attacks after defeat, props/contact interoperability.
3. Mission host and rooms; start, controls, exploration, sensory choice, checkpoints, finale, ending. Gate: full route integration and interruption/retry tests.
4. Visual and playable QA; inspect real rendered frames and input-driven traversal/combat. Record actual simulated/elapsed duration separately from human first-play estimate.
5. Package: clean import, aggregate tests, source zip, clear controls and verification limits.

## Baseline inventory (before continuation)
- Current F5 scene is target-health review, not a finished run.
- v26 PC exposes `receive_attack`, `reset_actor`, Health and DefeatResponse composition. Old run expects another API. New host avoids a silent incompatible player swap.
- StrikeHealth retains fractional strike damage. Legacy enemy receiver truncates it; new enemies use confirmed-strike composition.
- SurfacePulse forcibly uses preview rendering; blind mode must use the base SonarView or explicit compatible wrapper.
- Godot 4.6.3 available. Shell-created display blocked; cloud-desktop Godot route under inspection. No rendered QA claimed yet.

## Integration progress
- Lithe replacement: native sampled review accepted; focused 60/120 Hz geometry/support/action checks passed. No original controller or view overwritten.
- Melee/listener enemy: physical v26 contact/guard/parry/prop/death checks passed.
- Initial 12-sector route rejected on pacing evidence (82–90-second optimized bot route); retained only as superseded test baseline.
- Revised six-area mission: richer vertical geometry, ladders, translating lifts, ranged sentries, two-relay listening works, bracing Warden. Scope remains the single ascent.
- Ranged carrier: 74 checks at each rate passed. Warden: 76 checks at each rate passed, including real input-only counter duel.
- Sound producer/consumer names normalized without changing real origins; removed duplicate damage pulse. Collected caches now leave no ghost sonar geometry and persist immediately. Markers align exactly with visible geometry.
- Native performance remains variable and does not establish smooth60fps. Culling/batching plus cached shape sampling reduced measured contour refresh work; exact differential parity183/183 passed. See VERIFICATION.md for full benchmarks and limits.
- F5 now enters the mission title. Prior v26 scene remains independently runnable.
- Final focused Exchange lower/upper relay lanes and lower Warden sentry passed all four raw-input routes with no source changes. Timings120.66–135.90 simulated seconds; thirty-minute target remains unmet. No novice timing estimate is retained.
- Opening expanded into a detachable, view-only staged throw / head dodge / catch with micropauses.49 timing/contact checks and five actual native captures passed review.
- Final native mission reel saved seven frames and independently reviewed the updated objectives, ranged overlap, blackout and body pose. Cloud performance remains a documented limit; no smoothness claim.
- Clean-cache source import/default mission boot passed; final source package includes actual test evidence and scope limits.
