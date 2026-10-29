# Warden climax composition

## Integration

Load `res://demo/components/warden.tscn` for the mission's `warden` entry only. It inherits `enemy.tscn` and extends `enemy.gd`; no changes to either baseline, the PC, health, contact, shield, knockback, or movement components are required.

The scene defaults to 16 health and 18 attack damage, matching the mission's 60-health player. Existing host overrides (`max_health`, `attack_damage_override`, `movement_speed`, `windup_override`) remain valid. Call `configure(player, noise_bus)` and `set_room_bounds(...)` as for another enemy. Existing `defeated`, `attack_resolved`, and `noise_requested` signals are preserved. Optional `phase_changed(warden, 2)` reports the single below-half transition. `reset()` / `reset_at(position)` restore phase one and the opening cut, while attack identity remains monotonic.

## Encounter rules

- Alternates a 57-pixel cut and 73-pixel sweep. Both attack rectangles are 27 pixels high, with the inherited four-pixel forward offset. The visible windup outline and active fill describe the same rectangle used by the inherited physics query.
- Cut: 0.78-second windup, 0.14-second active window, 0.90-second recovery. Sweep: 1.014-second windup, 0.18-second active window, 1.10-second recovery. Host windup overrides scale the sweep by 1.30.
- Windup/active stance visibly braces with broad shoulders and planted feet. Ordinary hit/prop impulses below 0.70 seconds cannot displace or stagger this committed stance. The original damage receiver still takes full damage, including lethal hits. The preserved hitpause still supplies physical impact feedback.
- Actual shield parry/counter authority stays in the unchanged player and ShieldContactAdapter. Their established 0.75/0.78-second interrupts break brace. A forged/stale counter request remains rejected by the inherited validation. Held guard merely absorbs its normal share of damage.
- Recovery is unbraced and ordinary melee can stagger it. The encounter rewards a timed parry or leaving the committed reach and punishing the opening.
- Below half health (strictly below 8 of 16), the broken-crown/core cue appears and recovery accelerates to 0.64 seconds for cut / 0.80 seconds for sweep. Windups, attack damage, and capacity do not change; there is no heal, damage immunity, additional health bar, or timed survival gate.
- Uses the existing canonical `enemy_windup`, `enemy_attack`, `enemy_damage`, `enemy_death`, `enemy_step`, and `landing` noise path with real actor provenance. No secondary sound bus or fabricated input events.
- The inherited attack epoch fences reset, death, and synchronous shield callbacks. No timer or delayed hit is queued by this module.

Suggested player-facing hint: “The Warden braces through ordinary blows. Parry the flash, or leave its reach and strike during recovery.”

## Verification

Run from the project directory with a writable user-data directory:

```sh
HOME=/tmp/moksha_warden_home XDG_CACHE_HOME=/tmp/moksha_warden_home/.cache XDG_DATA_HOME=/tmp/moksha_warden_home/.local/share godot --headless --path . --script demo/tests/warden_regression.gd -- --hz=60
HOME=/tmp/moksha_warden_home XDG_CACHE_HOME=/tmp/moksha_warden_home/.cache XDG_DATA_HOME=/tmp/moksha_warden_home/.local/share godot --headless --path . --script demo/tests/warden_regression.gd -- --hz=120
```

The suite runs production physics callbacks and the actual PC, ContactAdapter, ShieldContactAdapter, movement, health, and knockback components. It covers physical windup/active hits, both patterns' timed parries, held guard, recovery punish, lethal brace, reset, below-half transition, visible/physical reach boundaries, escape, late terrain obstruction, roll evasion, rejected stale counters, and a complete input-only duel won through six actual counters. The duel never teleports actors, edits health, changes phases, or forces enemy states after the initial AI enable. Deliberate setup and lifecycle API probes are labeled. Results are saved in `warden_results_60hz.json` and `warden_results_120hz.json`, including preserved-source SHA-256 hashes. Focused checks are not a claim of full mission traversal or manual visual QA.

Verified on Godot 4.6.3: 15 scenarios and 76 checks pass at each of 60 Hz and 120 Hz, with zero failures. The input-only duel ended with six confirmed counters, zero player health lost, and a single Warden defeat in 13.30 seconds (60 Hz) / 12.94 seconds (120 Hz) of simulated physics. These deterministic, AI-aware timing results demonstrate a bounded mechanical encounter, not a human completion-time estimate.
