# M13 optional defeat response: focused verification

Godot 4.6.3, real physics callbacks at 60 Hz and 120 Hz. All four processes exited 0; their logs contain no script errors. Production hashes remained stable throughout each run and matched across rates.

| Suite | Rate | Scenarios | Assertions | Failures | Real physics ticks |
|---|---:|---:|---:|---:|---:|
| Focused defeat | 60 | 23 | 187 | 0 | 877 |
| Focused defeat | 120 | 23 | 187 | 0 | 1652 |
| Unchanged M12 health | 60 | 25 | 182 | 0 | 464 |
| Unchanged M12 health | 120 | 25 | 182 | 0 | 824 |

## Coverage

- Real swept melee fixtures cause lethal direct damage and lethal guard chip. Both preserve their resolved defense outcome, emit one depletion/defeat, reject later identified and legacy hits without recoil or new receipts, and settle while every control is held.
- Nonlethal hurt/guard and fully parried/evaded hits leave the policy inactive.
- Real active attacks, queued attacks, held charge and held shield retire. Stale strike queries and confirmations fail. Inputs held through removal cannot replay; neutral followed by a fresh press works.
- A high airborne defeat lands through the real motor sweep with hard landing enabled, remains terminal and converges to rest. A settled body follows a rising/moving carrier through local hitpause with zero observed relative drift.
- Health refill alone does not revive. Actor reset releases defeat, restores default health and permits another defeat episode. Explicit release preserves host allow_input and external weapon settings.
- Response detach/queue deletion and Health removal release the owned gate. Retained old callbacks are stale; mismatched Health is refused at bind and depletion; zero Health can bind to a replacement actor. Foreign owners cannot release/replace an acquired gate, and old cleanup cannot retire a later owner.
- Synchronous action-change callbacks reset the actor, unbind the response or install replacement ownership during acquisition. The old acquisition does not emit a stale start or overwrite the new state.
- An inactive response matches the bare motor exactly across movement/combat samples. Health without the response retains M12 zero-health behavior.
- 36 passive pose samples cover air/ground, six collapse phases and flat/positive/negative slopes. Every bone is finite and mirrored; weapon presentation is hidden. Settled head/chest alignment reads horizontally.

Measured carrier relative error: 0 px at both rates. Maximum mirrored bone error: 0 px. Minimum sampled ground knee/foot plane clearance: -0.0000002384 px (floating-point noise). High-fall final foot y: 699.9799805 against floor y=700.

## Artifacts and reproduction

`defeat_regression.gd` extends the existing M12 physics helpers and writes only `defeat_results_{60,120}hz.json`. `defeat_health_compatibility.gd` invokes all original M12 case functions without modifying their assertions, and writes only separately named `defeat_health_compatibility_{60,120}hz.json`. Existing M12 output paths are never opened by either runner. New logs use the `defeat_` prefix.

```sh
XDG_DATA_HOME=/tmp/m13-defeat-data XDG_CONFIG_HOME=/tmp/m13-defeat-config XDG_CACHE_HOME=/tmp/m13-defeat-cache godot --headless --path . --script res://combat_pc/tests/defeat_regression.gd -- --hz=60
XDG_DATA_HOME=/tmp/m13-defeat-data XDG_CONFIG_HOME=/tmp/m13-defeat-config XDG_CACHE_HOME=/tmp/m13-defeat-cache godot --headless --path . --script res://combat_pc/tests/defeat_regression.gd -- --hz=120
XDG_DATA_HOME=/tmp/m13-health-data XDG_CONFIG_HOME=/tmp/m13-defeat-config XDG_CACHE_HOME=/tmp/m13-defeat-cache godot --headless --path . --script res://combat_pc/tests/defeat_health_compatibility.gd -- --hz=60
XDG_DATA_HOME=/tmp/m13-health-data XDG_CONFIG_HOME=/tmp/m13-defeat-config XDG_CACHE_HOME=/tmp/m13-defeat-cache godot --headless --path . --script res://combat_pc/tests/defeat_health_compatibility.gd -- --hz=120
```

These are focused headless integration/numeric checks; native visual/input review is separate. They establish the fixtures above, not all terrain or future controller states. Collapse policy, timing and poses are original MOKSHA choices; no source-game death-animation parity is asserted.

Final rerun followed a behavior-neutral rename of defeat API parameters/locals that shadowed Node.owner. All four suites remained clean against the final actor source. `defeat_before_parameter_rename_manifest.json` preserves the previous successful run hashes and summaries.

## Frozen production SHA-256

- `res://combat_pc/components/defeat_response.gd`: `5a4d4cfba65e77513e9b8ecd6e6a3eb65d3eb6631ac816b70579f4c885b36742`
- `res://combat_pc/components/defeat_response.tscn`: `c2ad893de7d0db2a1375bb8890f6934a0856853b6a617e076b46b5a40f323691`
- `res://combat_pc/components/health_component.gd`: `f9253a10ffe0aba42745006f9b61e4422b04a41ea9e1344690e6e06b5de7bb8c`
- `res://combat_pc/player.gd`: `3e99722c95342f84e5d5e3c938a7b5839e707b1ce3856726864ca0ea96e9f5ba`
- `res://combat_pc/player.tscn`: `66cdd188fbb7f495eb21399616ed14306283956306aa21384da5bdeb9bf59e06`
- `res://combat_pc/visuals/defeat_pose.gd`: `74427952a134896b729f93e40c2441d03d215c21d3b47bb339859b2a19a5df97`
- `res://combat_pc/visuals/wireframe.gd`: `f98c421787cb37d33fe1f419593b6c3c0a3bac490530e05b5b955e4c6529c402`
- `res://combat_pc/visuals/wireframe_pose.gd`: `0b1cf2f577a051f79cfbfe9c2d2963fc07f8c2537fe6675f1ba2beff6fddc74f`
