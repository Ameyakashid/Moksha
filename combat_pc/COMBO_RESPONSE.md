# Fresh-tap combo response: one review piece

This candidate keeps the existing Slash → Backhand → Finisher, including their distinct poses, phase lengths, hitpause, damage, movement and cancellation rules. It changes when fresh input may wait for the next legal attack.

## Try it

F5 opens `combo_response_review.tscn`. Tap **J** repeatedly. **1/2** compare the earlier chain and candidate; **Q** applies identical input to both. Each labelled trial explicitly resets the same PC and passive contact instrument: early follow-up taps, rapid fresh taps, then a held button. The counter records real accepted contacts, not a timed effect. **E** disables target contact for a whiff comparison. **A/D** moves, **R** resets and **Esc** pauses. Existing jump, roll and shield controls remain available.

The approved ground and air profile is used for both chains. The review's 1.5× camera makes the original strike poses easier to inspect; it changes no game units or movement. The target is an instrument with no AI or health policy.

## Admission and commitment

| Rule | Earlier chain | Candidate |
|---|---|---|
| Slash/Backhand follow-up opening | 35 ms elapsed gate | Accept a fresh edge from the start |
| Next-step commitment | After configured legal recovery | Unchanged |
| Finisher input | Every busy-frame press rejected | One fresh restart may queue in the last 120 ms of recovery |
| Finisher commitment | Complete all recovery | Unchanged; queued restart waits for idle |
| Follow-up deadline | 220 ms | Unchanged |
| Fresh restart deadline | No busy-frame restart | Existing 140 ms starter buffer |
| Queue capacity | One next strike | One next strike |
| Held button in Fresh mode | One strike | One strike |

The old gate reads step age before this callback advances it, so a nominal 35 ms opening is not identical to 35 ms of device-to-action latency. The candidate removes that early admission hole without skipping startup, contact or recovery. Contact hitpause still captures fresh edges before freezing gameplay clocks.

Repeated presses cannot increase queue depth, replace its admitted identity or refresh its deadline. Three taps squeezed into an already occupied slot do not store an entire future combo. A new tap after that slot is consumed can request the next step. This keeps the actor controllable when input stops.

A terminal restart belongs to a specific source, configuration epoch and finishing chain serial. Only natural completion can retain it while clearing the old chain. It starts a new chain/strike identity through the existing admission gates. Reset, hurt, cancellation, reconfiguration, expiry and callback replacement keep their clearing/invalidation rules. Full recovery, shield/reuse locks and external permissions remain authoritative.

The new terminal route is Fresh-only. Held Repeat and Held Charge retain their independent policies. They are not implicitly enabled by rapid tapping or by keeping the button down.

## Reuse

Assign `resources/responsive_chain.tres` to the reusable PC's **Melee Chain** property. The prior `light_chain.tres` remains available. No second controller, alternate hitbox system or animation player is introduced. Duplicate resources before editing shared settings.

`MokshaMeleeChainProfile.fresh_restart_window_seconds` defaults to zero, preserving old resources. It controls admission; the existing combat profile's attack buffer controls expiry. Keep those two durations coherent if tuning them. All step fields remain independent, and runtime requests stay on the actor rather than in shared resources.

## Source and verification limits

The [fresh source audit](reference/M20_COMBO_RESPONSE_EVIDENCE.md) records surviving Dead Cells cycle/readiness bodies and absent weapon/input scheduler methods. Neither the queue size nor these timing windows are recovered constants. They are explicit MOKSHA input-policy choices around the existing source-informed action structure.

The companion evidence contains fixed-rate input/ownership tests, current and archived baseline regressions, actual native contact receipts and portable boot checks. The clip preserves native timing and is silent in the cloud environment. This one response change stops for review.
