# Independently placeable physical assets

These are small scene packages of the existing tested production components, not new mechanics. Put a scene into an ordinary Node2D world; mission orchestration is not required. Root visibility affects drawing, not collision, simulation, signals or receiving rules.

| Scene under `simulation/world/` | Configuration and connections |
|---|---|
| `moving_lift.tscn` | Set `travel`, `period`, `platform_size` and placement before entering the tree. The existing one-way AnimatableBody2D carries actors through their existing support rules. Motor sound uses `/root/NoiseBus` only if available. |
| `relay_shutter.tscn` | Set `shutter_size`, `relay_index` before entry or use existing `configure(size, index)`. `set_open(bool)`, `reset()`, read-only `is_open`, and `open_changed` remain the original interface. Host connects a relay/puzzle success signal to `set_open(true)`. |
| `freight_receiver.tscn` | Configure basin dimensions before entry, then `bind_cargo(prop)`. `latched(prop)` announces actual stable contact by that bound cargo. The receiver does not own the mission or door. |
| `freight_cradle.tscn` | Set `auto_spawn=false` if wiring first. `bind_receiver(receiver)`, then `replace_cargo()`; `interact(actor)` retains its existing range/admission rule. Signals are `cargo_spawned` and `cargo_replaced`. Root position is the launch floor height. |
| `mission_cargo.tscn` | The existing crate scene plus the exact production cargo script and collision mask 43. Existing tuning and impact/boundary behavior remain authoritative. No artificial motion or latch is introduced. |
| `mission_ladder.tscn` | The stock climbable plus its passive, nonblocking sonar rails. Set `width`, `height`, `enabled`, `climb_type`, and `draw_guide` through the inherited interface. Width/height changes synchronize rails with the sensor. `climb_geometry()` remains the actor interface. |

For live configuration, preserve each existing component's lifecycle contract: lift and receiver geometry is authored before tree entry; shutter has its explicit configure method; ladder dimensions support live setters outside a physics query flush. This packaging does not invent arbitrary runtime reconfiguration or detach-and-respawn semantics.

## Ownership and compatibility

- Mission room assembly now instantiates these same scenes. It still chooses placements and connects puzzle/door relationships.
- The production crate is also used by ordinary mission props and the freight cradle.
- Sound is optional for standalone lift operation. When the service exists, the same source, interval, event and loudness are emitted.
- The ladder's root group, sensor, controller geometry and draw implementation remain inherited. Its zero-layer/mask sonar body is now inside the asset, not injected by the mission.
- Existing component drawing is unchanged; no new appearance resource is required to hide or replace the complete asset. Existing crate resources are retained; use the component's supported configuration rather than mutating a shared underlying resource blindly.
- Projectiles remain emitter-authorized physical actors. This change does not weaken their launch contract merely to make an editor icon.

## Fresh verification

`simulation/tests/physical_scene_regression.gd` compares the old script-built room with the scene-built room for every authored sector's ordered collision topology and actual sonar contours. Its standalone fixture removes the noise service and checks real lift motion, hidden shutter body sweeps/open/re-close, ladder geometry and reattachment, real falling cargo settling in a hidden receiver, and hidden cradle replacement. These are labelled fixtures, not full-campaign evidence or native appearance review. The existing freight component and host suites are run separately at 60 and 120 Hz; final integration routes remain the parent's responsibility.
