# Optional late-windup timing foundation

This is an original controller capability, not a shipped hearing trade. No campaign actor requests it yet. The five-level prototype's hearing choices, save schema, sonar, audio, scenery and geometry are unchanged. The existing hearing blueprint motivates a brief visible pre-strike opportunity; it does not supply recovered timing code or measured balance. These bounds are our proposed tuning.

## Ownership

`combat_pc/player.gd` owns a committed attack's clocks and now an optional bounded timing lease. A future campaign adapter owns hearing-choice eligibility, visibility/occlusion and exclusion of projectile-emitter actors. The generic controller has no dependency on that adapter, hearing state or projectile components. Do not advertise ranged support from this foundation.

During the existing synchronous `attack_started` event only, `late_windup_admission_snapshot()` returns a detached token. `request_late_windup(token, tail_seconds, rate)` accepts at most once for that attack. Tokens include serial, reset/configuration epochs, action/weapon generations and a monotonically increasing admission ID. Requests cannot write elapsed time or replace the committed resource. They emit no new callback. Nested replacement attacks own separate admission scopes; old dispatches cannot clear or reuse newer scopes.

Admission checks both action and weapon generation. Continuing validity checks the weapon identity, serial, reset/configuration and live copied attack, not the original action generation: later legal locomotion is not permission to silently remove an admitted effect. Existing callback-local action and weapon fences remain intact. Cancel, finish and reset retire the lease; invalid configuration cannot use or observe it.

`late_windup_snapshot()` supplies only serial, effective tail, rate, accumulated extra time and whether the current phase is inside the late tail. It is detached and cannot grant contact authority. It is diagnostics, not proof a cue was drawn or an enemy was visible. Future presentation must apply its own current visibility/pause/lifecycle gates.

## Timing contract

Accepted requested tail is greater than zero and at most 0.18 seconds. Rate is from 0.5 through 1.0. Effective tail is additionally at most half the committed windup (the existing 0.001-second phase floor applies). Thus total added time is at most 0.18 seconds. No request means the existing numerical advancement path, unchanged.

Real simulation delta is split across ordinary windup, slowed final tail, and any ordinary remainder after the tail. Both phase-local `_weapon_elapsed` and whole-step `_attack_step_elapsed` lose exactly the same bounded attack time. One large delta can cross both boundaries without slowing active/recovery residual time. Existing configured attacks still preserve one active contact sample before consuming later phases.

Follow-up opening/closing thresholds remain attack-time thresholds. Input buffers, pending request expiry, reuse locks, repeat restart, idle-chain retention, charge loading, physical hold/release and movement retain their existing simulation-time rules, including their pre-existing hitpause/hard-landing exceptions. An early queued request can expire during the extra windup interval; this feature does not extend input buffering. Global pause and local hitpause do not spend extra timing. A charged starter and charged strike are distinct serials; the intervening held-charge clock is unchanged.

## Validation and limits

- `combat_pc/tests/late_windup_contract.gd`: explicitly seeded controller contracts, including short/zero test windups, tail boundaries, large delta, stale/duplicate/NaN requests, reset/cancel/reconfiguration and nested callbacks; actual chain capture and expiration APIs; hitpause, tree pause and defeat. These are not natural traversal claims.
- `combat_pc/tests/late_windup_input_trace.gd`: actual physics-callback-owned input schedules for legacy, chained, repeat and charge paths. Fresh explicit external output is required. Baseline and neutral traces are compared exactly; admitted runs exercise the opt-in capability.
- Existing combat and selected held charge/callback/pause/contact suites run through external wrappers without overwriting their historical result files.

Use isolated HOME and all XDG directories. Supply `--hz=60` or `--hz=120` to the scripts; `--fixed-fps` alone does not set physics frequency. Input trace requires `--out=/absolute/fresh/external/file.json`; add `--admit` only for the opt-in trace. Baseline comparison runs the same trace script externally against frozen c9772b0, where the opt-in-only API is never called.

No hearing station, save migration, campaign ranged admission, native visual cue, counter reward or balance acceptance is included. This foundation needs independent review before integration. No new assets, third-party code or reference map geometry were copied.
