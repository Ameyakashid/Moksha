# Native production sentry review, 2026-10-19

The ordinary full-mission attempt reached the Rainline upper crate/service-badge
area but did not reach Quarantine Intake or a sentry. Those captures remain
explicitly named `native_rainline_route_*`; they are not sentry acceptance.

The independently runnable `simulation/sentry_review.tscn` then used the actual
mission host/factory and unchanged authored Quarantine Intake sector, with only
an explicit initial spawn at (790,135) and saving disabled. This is an isolated
review start, not a completed full mission route. All actors, AI, controls,
Health, cargo and terrain remained live. No post-spawn teleport, forced attack,
AI disabling or synthetic Health/outcome was used.

After the source refresh that removed alternating retreat-facing input, the
native reviewer observed:

- A distinct cyan bow/antenna silhouette, orange warning ring/!, and short locked
  aim line, with readable unclipped presentation.
- Ordinary K raised the player's shield during the exchange; the display stayed
  at 60/60. This does not independently establish that a bolt was blocked.
- Actual D/J approach and strikes reduced the sentry Health bar, then another J
  produced its cyan prone defeat while the PC remained 60/60.
- R restored the live encounter after an unattended death. The earlier death's
  cause was not isolated; it is not attributed to a sentry projectile.
- A final unguarded warning-to-recovery transition. No distinct free-flight bolt,
  player damage or confirmed reflection was captured in that observation.

The native `release` image shows shield/recovery timing, not independent bolt
proof. `warning` was renamed from the misleading provisional `bolt` name. Exact
release timing, flight, reflection and collision/filter outcomes are established
by automated actual-physics tests, not these screenshots. Audio mix is unverified
on the cloud device. Output showed 0 errors/0 warnings; the accumulated Debugger
count 24 was not exhaustively inspected, so this is not a full debugger audit.
Fresh no-cache import and 300-frame boot are separately verified headless.

Evidence: `native_isolated_sentry_{initial,guard,warning,release,melee,defeat,
post_warning}_desktop.jpg`, with SHA-256 in `native_sentry_capture_hashes.json`.
The reviewer stopped the native run and released computer control afterward.
