# Placeable HUD and explicit body echo

The HUD is a 640 × 360 presentation asset at `simulation/ui/mission_hud.tscn`.
Its root owns a schema-checked snapshot and optional View; appearance is a local
Resource. Default white tint retains the original palette. Null appearance,
hidden root, and removed View suppress paint only. No input, mission, save,
Health, room, or NoiseBus reference lives inside the asset.

`set_snapshot` accepts scalar presentation fields, copies recognized fields,
rejects wrong types/nonfinite numbers and nonpositive health capacity atomically,
and resets omitted fields to documented defaults. `get_snapshot` returns a copy.
Explicitly shared appearance resources share tint by choice; replacing one
unsubscribes the old View callback. The mission computes prompts/objectives and
pushes presentation even while paused. It alone handles keys and gameplay.

The original title, intro, top/bottom bars, chapter/notice, objectives, prompts,
archive/choice/pause/defeat/completion screens and special isolated Freight/Relay
completion screens retain their text and arithmetic. The existing opening drawing
helper remains view-only. The two isolated host subclasses override snapshot
presentation data instead of calling the renderer.

`simulation/ui/body_echo.tscn` receives only an explicit source Visual and enabled
flag. Its optional child View copies the actual pose and the original canvas-space
transform; it never advances the character or senses enemies/geometry. The mission
selects when the echo is enabled. Default identity placement preserves production
behavior; root transforms offer a presentation offset, not physical movement.

Run `simulation/ui/mission_hud.tscn` directly with F6 for its standalone default title presentation. Hosts configure other states through `set_snapshot`; the lifecycle and native-pixel tests exercise those states without giving the HUD gameplay authority.

Validation is recorded separately: schema/lifecycle checks and genuine host-key
transitions, labelled direct modal fixtures, original-source native pixel pairs,
then aggregate/full-route gates on the integrated source. Native pixels compare
only frozen presentation and do not measure audio, human pacing or hardware feel.
