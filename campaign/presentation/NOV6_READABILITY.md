# November 6 player guidance and readability

This is campaign-only presentation. It does not change the original controller,
collision, damage, objective authority, input bindings, sonar or checkpoint data.

## Player-facing changes

- The title makes the three starting lenses comparable with selectable cards,
  rather than burying the selection and tradeoffs inside a paragraph.
- The current actionable objective occupies a full-width, measured `NEXT` line.
  Long text wraps instead of silently disappearing at the old health-bar column.
- The header identifies sight state, starting lens, district progress and required
  objective progress from the campaign's read-only snapshot. The timer is explicitly
  active time. Health includes numbers, a bounded segmented bar and a textual
  `LOW` state, not just a color change. A living player is never labelled `0 HP`
  by integer truncation.
- Context actions and prerequisites use compact, measured cards below y305,
  clear of a floor-standing operative's feet at y300. Completion notices instead
  appear under the header at the upper right, expanding only enough to retain
  all authored detail in at most two lines. They take priority over the temporary
  chapter introduction rather than overlapping it. Extraordinary non-authored
  overlong notices visibly ellipsize instead of covering the playfield.
- Pause controls use two explicit columns of separate keycaps and action labels.
  They do not depend on repeated spaces surviving paragraph wrapping.
- Panels measure their title, body and footer independently. Journal completion
  and next-step lines are distinguished with both words and color. Paused panels
  identify that time is stopped. Long words and IDs are split without losing text.
- Objective captions separate the machine's name from its current legal action.
  Locked and optional states are explicit. A route console predicts the next E
  setting; matched consoles warn that E changes the route (or that input is locked
  by a dependency). Breakers say J and pressure plates say cargo, never E.
- A caption is positioned as one block. Camera-edge correction cannot stack its
  individual lines on the same baseline. Culling still tests the actual objective
  anchor first. Captions remain children of the authoritative blind-hidden tree.

## Integration

`campaign/views/campaign_hud.gd` consumes the existing HUD fields plus optional
`guidance`, `lens`, `district_index`, `district_count`, `required_done` and
`required_total` plus `input_device`. Its layout helpers are read-only and fall back to the legacy
objective when the additional guidance field is absent. The host decides what is
possible or required; the view never infers a route from world positions.

`campaign/views/campaign_hud_owner.gd` extends the preserved typed snapshot owner.
It validates only the additional campaign fields and retains the base whitelist,
copying and atomic-rejection behavior. Production pipeline tests exercise the real
host-to-owner-to-view path, not only direct view fixtures.

Controller-aware presentation uses the exact campaign adapter mappings. Title,
pause, journal, choice, upgrade, ending, death and contextual hints switch between
keyboard and ABXY/Back/Start labels. These are explicitly Xbox-style button names,
not hardware detection. Captions read the adapter's current input-device token,
never poll or change input themselves.

`campaign/views/objective_caption.gd` reads objective state only. `describe()`
produces words, not state changes. `place_block()` returns paint placement, not
an object transform. The original `placement()` API remains compatible with the
existing zoom/offscreen contract.

## Focused verification

Run with Godot 4.6.3 and a writable temporary HOME/XDG profile:

```
godot --headless --path . --script res://campaign/quality/nov6_presentation_contract.gd
godot --headless --path . --script res://campaign/tests/ui_player_guidance.gd
godot --headless --path . --script res://campaign/presentation/tests/objective_paint_contract.gd
godot --headless --path . --script res://campaign/presentation/tests/runtime_sight_contract.gd
```

The new suite loads all 32 districts and renders their HUD snapshots, nearby goal
prompts, completion notices and all journal pages. It checks measured text bounds,
read-only snapshots, low-health boundaries, caption state semantics, controller
label contracts and multi-line camera-edge placement. It also checks the actual
production snapshot pipeline, typed rejection, distinct pause-control columns,
full authored notice retention and clearance from the floor actor region. These are controlled scene fixtures, not full campaign
traversal or human learnability evidence. Native visual review is recorded
separately by the November 6 review; earlier evidence is not relabelled.
