# Ladder hint owner-boundary correction

Native inspection caught a real integration error: the host emitted
`ladder_attached`, but the campaign HUD owner discarded it as unknown. The earlier
teaching fixture assigned the painter's data directly, so it did not prove the
host-to-owner-to-painter path. Its passing results remain presentation/lifecycle
unit evidence, not evidence that the hint reached the actual game.

The fix adds a boolean campaign field and an explicit false omission default to
`campaign/views/campaign_hud_owner.gd`. No field is added to the shared mission
HUD. Invalid campaign types reject without changing either accepted snapshot;
a shared-field rejection rolls back the staged campaign update too. Omitting the
grip field clears a previous true hint. Ordinary mission HUD instances continue
to discard this campaign-only key.

The new `owner_contract.gd` uses the actual campaign scene, actual Mill geometry,
production player and ordinary held-Up input in real physics callbacks. Starting
positions are explicitly staged and the normal host scheduler is disabled while
one budgeted fixture driver advances the player. No controller physics is changed.
At actual 60 and 120 Hz it checks supported top exit and accepted-hit interruption,
then routes each host snapshot through `host.hud.set_snapshot` into `View.data`
and the real footer formatter. Keyboard/controller labels are presentation
fixtures, not physical-controller tests. Read-only state identity and the existing
negative/lifecycle, font-width and presentation contracts are preserved.

The before-fix owner test recorded 40 failures despite successful physical
climbing. An early 120-Hz fixture attempt used an unbudgeted driver, allowing
extra physics ticks between awaited render callbacks; that failed observation
was retained. The corrected driver advances exactly the requested count before
waiting again. Final checks pass without modifying production traversal, input,
save, layout or sensory code. Native appearance remains a separate acceptance
gate; the unit test does not replace it.
