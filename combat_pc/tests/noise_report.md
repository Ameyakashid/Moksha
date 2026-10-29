# M14 optional noise relay: focused verification

Godot 4.6.3, real engine physics callbacks at 60 Hz and 120 Hz. All six accepted processes exited 0 with no script errors or warnings. Every recorded source hash stayed stable during its run. The focused suite was rerun after the final relay serial-validation change, and all its dependency hashes match the final files at both rates. No production source was changed by this test work.

| Suite | Rate | Scenarios | Assertions | Failures | Real physics ticks |
|---|---:|---:|---:|---:|---:|
| Focused noise relay | 60 | 28 | 186 | 0 | 503 |
| Focused noise relay | 120 | 28 | 186 | 0 | 889 |
| Unchanged M12 health | 60 | 25 | 182 | 0 | 463 |
| Unchanged M12 health | 120 | 25 | 182 | 0 | 824 |
| Unchanged M13 defeat | 60 | 23 | 187 | 0 | 876 |
| Unchanged M13 defeat | 120 | 23 | 187 | 0 | 1654 |

## Focused coverage

- Real walking crosses the footstep threshold once; physical falling lands once; real weapon windup produces one strike receipt at its active-entry blade center. Receipts and local bus history agree exactly on origin, kind, loudness and actor identity. Public receipts are readonly six-field snapshots with distinct serials.
- Settled idle is silent. Local hitpause does not replay the current strike, and applying hitpause during the legacy callback does not discard the valid same-generation receipt.
- Same-generation teleports in both the original hurt movement callback and the legacy noise callback preserve the original hurt origin.
- Reset from actual footstep, landed, roll-start and hurt-start callbacks suppresses stale legacy/committed noise and preserves the replacement actor position/action. Reset in a legacy noise listener suppresses appended commitment; reset in an earlier receipt listener makes the later relay reject the old generation.
- Nested valid receipts arrive at the relay as serial 2 then 1, and both forward. Diagnostics commit before bus observers and external diagnostic copies cannot mutate relay storage.
- Mute/unmute, detach/reattach, repeated bind, replacement actor and failed bind invalidate old subscriptions/callables. Fully freed relay, queued relay/actor/bus, and freed actor/bus cases are covered. Relay destruction leaves independent actor noise production and motor state intact.
- A bus callback may reset the actor, rebind the relay, mute/unmute, detach, reset diagnostics or queue the relay. The bus retains its already-committed event; the invalidated outer operation emits no stale forwarded notification. A fresh event reaches a replacement bus.
- Actor admission rejects nonfinite origins and nonpositive/nonfinite loudness. Relay validation independently rejects malformed origin/kind/loudness, foreign/stale receipts, and missing, zero, negative, string or floating-point serials; positive integer serials remain accepted.
- Attached-versus-absent actor state is exactly equal through run, jump, roll, shield and attack: 180 movement/combat samples at 60 Hz, 360 at 120 Hz, zero mismatched ticks. Hurt, guard, parry and roll defense outcomes plus subsequent recoil/pause/recovery also remain equal.
- One PC with Health, DefeatResponse and NoiseRelay handles nonlethal hurt, lethal hurt, terminal input suppression, physical recoil landing, explicit reset and a new roll. Physical landing remains audible while defeated; it is not treated as a new player action.

## Compatibility and scope

`noise_health_compatibility.gd` invokes every original M12 case without changing its assertions. `noise_defeat_compatibility.gd` invokes every original M13 case, including physical lethal contacts, moving support, reset/lifetime behavior, acquisition callbacks and numeric collapse pose checks. Both write only newly named M14 outputs. Historical health/defeat runners, reports and results were not edited or opened for writing.

The compatibility runs precede the final relay-only serial-validation change. They exercise unchanged actor, Health and Defeat code and never instantiate NoiseRelay. Their recorded `noise_relay.gd` hash is contextual metadata, not an exercised dependency; their exercised source hashes still match the current files. Only the focused suite needed a rerun.

The focused runner uses the real reusable actor, an instance of the unchanged existing `scripts/sensory/noise_bus.gd`, and the optional relay. It explicitly calls admission methods or retained callables only for malformed-data and callback-lifetime contract cases; movement-origin cases use actual motor/weapon events. This is a bounded headless integration check, not an all-controller audit, audio implementation or sensory-behavior test. Native visual/input review is separate.

## Reproduction

```sh
for hz in 60 120; do
  for suite in regression health_compatibility defeat_compatibility; do
    XDG_DATA_HOME=/tmp/m14-noise-data XDG_CONFIG_HOME=/tmp/m14-noise-config XDG_CACHE_HOME=/tmp/m14-noise-cache godot --headless --path . --script res://combat_pc/tests/noise_${suite}.gd -- --hz=${hz}
  done
done
```

Focused results: `noise_results_{60,120}hz.json`. Compatibility results: `noise_{health,defeat}_compatibility_{60,120}hz.json`. Final logs: `noise_{regression,health_compatibility,defeat_compatibility}_{60,120}hz.log`.

## Frozen production SHA-256

- `res://combat_pc/components/defeat_response.gd`: `5a4d4cfba65e77513e9b8ecd6e6a3eb65d3eb6631ac816b70579f4c885b36742`
- `res://combat_pc/components/health_component.gd`: `f9253a10ffe0aba42745006f9b61e4422b04a41ea9e1344690e6e06b5de7bb8c`
- `res://combat_pc/components/noise_relay.gd`: `c95079da13ac1e0528f917e59d4918a2e7b6b67e72da4128d6cd0194f5f874bb`
- `res://combat_pc/components/noise_relay.tscn`: `f31ce3167027022c47e33bb409db048811063b3dfc4cc9af96d11dae3e3ec299`
- `res://combat_pc/player.gd`: `24d453e53737c74d3c747e323cea5901c101b223f12592ab80a9a69b4c1cbe1a`
- `res://combat_pc/player.tscn`: `66cdd188fbb7f495eb21399616ed14306283956306aa21384da5bdeb9bf59e06`
- `res://scripts/sensory/noise_bus.gd`: `c461c3615d72dd825a3d14076b0c39b0307503328e5fa5966bed5a9becbbed4b`
