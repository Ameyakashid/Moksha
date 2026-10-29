# Independent Warden diagnostics

These scripts ran only in `/workspace/shared/moksha-warden-final-review`; the live project was read-only. `.gd.txt`/`.tscn.txt` preserve diagnostic source without registering extra project scripts.

- `review_close_shield.gd.txt` is an observation-only wrapper around the pre-adaptation factory suite. Reproduction requires restoring `legacy_warden_factory_regression.gd.txt` to `simulation/tests/warden_factory_regression.gd` and `legacy_expanded_mission_route_bot.gd.txt` to `demo/tests/expanded_mission_route_bot.gd` **in an isolated copy**, then running the wrapper with `--hz=60 --legacy-input`. It returns inherited raw input unchanged. The two decisive Warden contacts have active parry but contact points 0.55 and0.82px behind the shield rectangle's inner edge; the incoming origin is still forward. No gameplay geometry change is implied.
- `review_cargo_contact_spy.gd.txt`, `.tscn.txt`, and `review_cargo_contact_probe.gd.txt` observe real PhysicsDirectBodyState2D contacts before calling the unchanged physical cargo implementation. The original gap60/y-offset-20/velocity-360 fixture qualifies at60Hz but misses at120Hz because measured contact-relative closing speed remains below the authored80px/s threshold. Receiver registration stays ready. This is a rate-sensitive solver/admission observation, not a Warden receiver failure. Final suite uses gap45/y-offset-26 and explicitly asserts qualifying normal speed at both rates.
- `review_warden_api.gd.txt` contains33 independent direct lifecycle/input-commit probes. These are labeled source/API probes, distinct from actual physical gameplay suites.
- `review_null_config.gd.txt` preserves the authored-chain null-step reset probe. The early failure and final no-error logs remain outside this evidence directory with their original red/green names.

Use `godot --headless --path <isolated-project> --fixed-fps <60|120> --script res://<script>.gd -- --hz=<60|120>`, with writable XDG_DATA_HOME/XDG_CONFIG_HOME/XDG_CACHE_HOME. Never overwrite the live project or prior evidence to reproduce a diagnostic.

## Final independent observations

- `review_duel_noise.gd.txt` wraps the unchanged inherited six-counter input-only duel. Both rates pass11 checks: six current-scope Health receipts totaling16, six actor-sourced enemy_damage events, one enemy_death, one defeated, one phase2, no further actor semantic noise/Health/phase/defeat/attack-start activity through the inherited1.2s post-victory wait and disposal. JSON preserves the full event order.
- `review_factory_sources.gd.txt` audits actual configured sources for all46 factory enemies over eight sectors. Both rates pass430 assertions, covering all four kinds, common controller/input/sole-driver identities, melee source binding/enabled state/masks, and sentry canonical registered emitter/profile/release/owner layer/masks. Sector setup uses the existing AI-disabled inspection fixture; actual physical outgoing behavior is proven by separate combat suites.
- `INDEPENDENT_REVIEW.md` records the final conclusions and exact remaining limitations. Full source stability and sealed-Hurt compatibility reports are in the sibling `moksha-warden-hurt-route-review` directory.

## Packaging preservation helper

See `helper_review/` and the final review addendum for the separately reviewed one-line historical-evidence retention fix. The17-check isolated AST probe reproduces the old deletion and verifies the corrected restoration. Earlier gameplay hash sets remain unchanged.
