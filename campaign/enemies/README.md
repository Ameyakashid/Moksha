# Campaign captains: shared-controller compositions

Factory mapping:

- `captain_lancer` → `res://campaign/enemies/lancer.tscn`
- `captain_keeper` → `res://campaign/enemies/keeper.tscn`

Both inherit `demo/components/shared_sentinel.tscn`, including its unchanged
production player/controller, IntentDriver, incoming receiver, contact adapter,
health, shield counter, defeat, terrain/hearing and semantic noise components.
`configure(player, bus)`, `set_room_bounds`, `set_blind_mode`, `reset_at`,
`defeated`, `dead`, `_health`, `_terrain_visible`, `_reach`, `_windup`, `ai_state`
and mission tuning overrides are the existing facade API. There is no `_state`.
The player needs the existing mission IncomingStrikeReceiver (layer64).

## Distinct patterns, not health scaling

Both default to 3 HP and damage1; the host can apply its normal mission damage
scale. All attacks remain blockable, parryable/counterable and roll-evadable.

Lancer observes a clear supported 114px lane before requesting a charge from up
to 130px away. It locks direction for a .78s warning, travels at 220px/s for at
most .38s through the stock motor and spends 1.05s recovering. Its live strike
remains a short 43×22 rectangle, not a disguised ranged attack. Walls that enter
a committed lane still physically stop it. It does not home on late dodges.
Ordinary incoming hits interrupt it. The safe-lane check does not grant floating
support: removing terrain still causes shared gravity to act.

Keeper makes at most .32s of terrain-admitted backward movement when crowded,
then turns through normal input and commits to a .68s, 78×22 narrow thrust with
.95s recovery. Terrain that prevents retreat makes it stand and fight; it cannot
kite forever. Closing inside the tip, rolling behind its locked direction,
interrupting the windup or using the stock counter are meaningful responses.

The procedural view adds a lance/halberd silhouette and ground chevrons; it
never moves the actor or emits gameplay damage. Both sight states receive the
same existing committed warning at actor+(0,-26), strike noise at the real
strike center, and damage/death events. Blind rendering respects reveal lifetime.

No new third-party code or assets were needed: reusing this repository's tested
role-neutral components avoids a second incompatible combat/movement stack.

## Tests

From project root, run at both `--hz=60` and `--hz=120`:

```
XDG_DATA_HOME=/tmp/captain_data XDG_CONFIG_HOME=/tmp/captain_config XDG_CACHE_HOME=/tmp/captain_cache /opt/godot/4.6.3/Godot_v4.6.3-stable_linux.x86_64 --headless --path . --script res://campaign/enemy_tests/captain_regression.gd -- --hz=120
```

The suite reuses the existing actual-physics sentinel fixture helpers, but tests
these real scenes and their autonomous decisions. Results live in
`campaign/enemy_tests/results_60.json` and `results_120.json`. Coverage includes
both sight modes, physical damage, guard, lethal parry/counter, roll escape,
reset/identity, normal player melee interruption, terrain occlusion, pause,
charge travel, a door closing during windup, and entire-lane edge refusal.
Headless functional checks are not native visual/playability verification.

### Integrated campaign checks

`campaign/enemy_tests/integrated_captains.gd` instantiates the actual campaign
host and visits all four authored captain districts in sighted and blind mode.
It checks exact scene/policy mapping, grounded authored spawn, local bounds,
target/bus/group wiring, gate participation and retry restoration. The production
player delivers ordinary J attacks to kill each real captain; host kill and
remaining counts, sonar HIT events and dead collision retirement are asserted.
A second live encounter per placement exercises an autonomous attack against
the production player's held guard and confirms its committed sonar warning.

These are focused placement fixtures: the player is reset beside each encounter
and unrelated guards' decisions are disabled. No health or direct-damage writes
resolve the fights. This is **not** evidence of a full traversed campaign route.
The campaign host currently authors captain HP8/damage12; the reusable scenes'
base values remain HP3/damage1. Results are `integrated_60.json` and
`integrated_120.json`; run with the same command/environment as above, replacing
the script path with `res://campaign/enemy_tests/integrated_captains.gd`.

Gate isolation is explicitly a fixture boundary: before each J fight, the test
marks noncombat goals complete and the relay on, verifies the district has no
freight/all-guards requirement, and checks the live captain still seals the exit.
Only real captain death may then open it, while unrelated guards remain alive.
This setup must not be described as completing the district's objectives by play.

The integrated regression also requires all four player receiver bindings to
point to the current campaign Health adapter after every load. It verifies
actual guarded captain receipts reduce Health60→57 and an actual authored
quarantine sentry projectile reduces Health60→48 in both sight states. This
caught a real host bug: replacing Health without rebinding receivers silently
rejected incoming attacks. The runtime now rebinds the existing receivers.
`guard_probe.log` preserves the failing observation and `guard_rebind_probe.log`
the diagnostic rebind result; only `integrated_captains.gd` is acceptance evidence
against the production fix (it performs no receiver rebind itself).

Final integrated result: **198 checks / 8 captain encounters / zero failures at
both 60 and 120 Hz**. Isolated composition result: **99 checks / 25 scenarios /
zero failures at both rates**.
