# M11 optional attack-entry facing host

`attack_entry_facing_host.gd` / `.tscn` provide one explicitly registered candidate to the combat PC's optional synchronous entry-assist API. This is original MOKSHA integration policy, guided by the bounded perceived-target proposal. It is not recovered Dead Cells v35 targeting, ranking, timing or perception code.

The host never changes actor facing, attack state, strike geometry, velocity or damage. The motor alone decides whether a fresh starter can query and apply an entry-facing suggestion. No candidate is retained in the strike/damage path. Later target movement can still make the ordinary strike miss.

## Place and bind

The component scene can be placed beneath the player or beneath a host scene. Its inspector exposes `actor_path` (default `..`), `candidate_path`, local aim anchor and explicit classification/eligibility/awareness flags. Editor mode draws only a small placement label; it never binds a provider or queries physics. Runtime paths resolve on `_ready()`. Alternatively bind through the public methods below, including when the lab creates or resets its player.

Defaults deny assistance: `assist_enabled=false`, classification `unknown`, eligible/perceived/visible all false. A path or a damageable body alone does not authorize an offer.

For the existing passive `ChainTarget`, registration is:

```gdscript
host.bind_actor(player)
host.register_candidate(chain_target, {
    "classification": &"opponent",
    "eligible": true,
    "perceived": true,
    "visible": true,
    "local_anchor": Vector2(0, -15),
})
host.set_assist_enabled(false)
```

This reuses the same stationary contact instrument. It adds no NPC, AI, candidate catalogue or level. The lab's optional I control should call `host.set_assist_enabled(value)`, which updates the actor's enable switch only while this host owns the provider. U can call `set_candidate_awareness(value, value)` and change `chain_target.visible` to the same value. Canvas visibility does not disable the target's existing physical strike receiver. Comparison-start positioning belongs to the lab, not this component.

## Public host methods

- `bind_actor(actor: Node2D) -> bool`: detach this host from its old actor, install its own provider callable and apply its current enable value
- `unbind_actor()`: clear only this host's still-bound callable; it never clears or changes a newer host's provider/enable setting
- `provider_callable() -> Callable`: the stable `(actor, request) -> Dictionary` provider
- `register_candidate(target: Node2D, attestation: Dictionary={}) -> bool`: replace the one weak candidate identity; absent attestations revoke previous flags rather than carrying them to a different target
- `clear_candidate()`: remove the identity and revoke flags
- `set_assist_enabled(enabled: bool)`
- `set_candidate_awareness(perceived: bool, visible_to_actor: bool)`
- `set_candidate_eligible(eligible: bool)`
- `set_candidate_classification(classification: StringName)`: only `opponent` and `prop` are recognized; anything else becomes `unknown`
- `diagnostics() -> Dictionary`: enable state, query/offered/rejected counts, a small reason and declared classification/eligibility/awareness flags; no target handle, ID, anchor or coordinates
- `reset_diagnostics()`: clear counters/reason without changing authorization or binding

Calling an obsolete host's enable method only changes that host's stored preference. Its actor write is gated by `attack_entry_provider_matches(own_callable)`. Exiting the tree clears only the matching callable. Actor enablement is not changed by detach; without a provider there can be no offer.

## Exact provider request and offer

The actor API is:

```gdscript
set_attack_entry_provider(provider: Callable)
clear_attack_entry_provider(provider: Callable) -> bool
attack_entry_provider_matches(provider: Callable) -> bool
enable_attack_entry_assist: bool # default false
```

The provider receives the actor plus a fresh request containing integer `token`, `sample_tick`, `engine_tick`, `actor_id`, `attack_serial`, the actor's other request/origin identity fields, world `preview_left` / `preview_right` (`Rect2`), world `origin_left` / `origin_right` (`Vector2`), and integer `terrain_mask`.

The host requires a still-matching binding, positive request token/attack identity, matching actor identity and the current actual engine physics tick. Both preview rectangles and both origins must be finite; rectangles must have positive size. A positive terrain mask is required for this representative host.

An accepted offer is a new Dictionary with:

```gdscript
{
    "token": request.token,
    "sample_tick": request.sample_tick,
    "actor_id": request.actor_id,
    "attack_serial": request.attack_serial,
    "candidate": target,
    "candidate_id": target.get_instance_id(),
    "local_anchor": candidate_local_anchor,
    "anchor_world": target.to_global(candidate_local_anchor),
    "classification": &"opponent",
    "eligible": true,
    "perceived": true,
    "visible": true,
}
```

All rejection paths return `{}`. The actor independently verifies the offer and its own action/configuration/input/permission authority after the synchronous return. Echoed identifiers alone are not proof of a still-current actor state.

## Semantic and physical acceptance

The host checks explicit opposing-combat classification, eligibility, perception and visibility before reading any target position. Missing or false fields reject. The candidate must then remain a live `Node2D` in the tree, not queued for deletion, distinct from the actor, outside the `props` group, and actually visible in the CanvasItem tree.

Only then is the finite local anchor transformed to its current world position. That point must lie in the union of the actor's exact left/right starter previews, with inclusive edges matching the motor's mirrored boundary convention. There is no extra pursuit radius, nearest-target choice or reach extension. A ray from the corresponding left/right request origin to that anchor must find no terrain. Only the actor's own RID is excluded. The candidate is not exempted from terrain, and the host never scans a global enemy group.

Eligibility is an explicit host decision separate from eventual damage reception. The host does not require `receive_strike`, positive health, vulnerability or an unshielded state. A game can mark an invulnerable or shielded opponent as eligible when appropriate. The existing fixture has no health/AI at all. Its host should revoke eligibility when it ceases to represent a valid opponent.

The ray and point-in-preview rule are bounded authored simplifications, not a full visibility/perception system. The host uses current awareness attestations and actual terrain line-of-sight; it does not discover unseen opponents. It does not retain an accepted target, retry during an attack, track movement, home, alter air physics or rotate an active strike.

## Focused checks and packaged proof

The two original development harnesses, logs and JSON results are preserved byte-for-byte. Their development runs did not record the actor hash, so those originals are explicitly **development evidence with an unpinned actor version**, not final-source acceptance:

- Registration-double contract: [original harness](tests/m11_facing_host_contract_development_original.gd.txt), [original log](tests/m11_facing_host_contract_development_original.log), [original results](tests/m11_facing_host_contract_development_original.json)
- Real-player smoke: [original harness](tests/m11_facing_host_player_development_original.gd.txt), [original log](tests/m11_facing_host_player_development_original.log), [original results](tests/m11_facing_host_player_development_original.json)

Both were replayed using copies whose **only edit is their JSON result output path**. No scenario, expected result or production code changed. The replay pinned actor SHA-256 `123058595238d83090cead600dc0934df527f5cd4a18c555d4da52ea971abaa1` and host SHA-256 `954acdc61aa6ea97c5b954090e9795d986ef6f1ac538927c475c6101b5dd29ec`. All 70 tracked production input hashes remained unchanged between the before/after observations. Both Godot 4.6.3 runs exited successfully with clean logs.

The [smoke proof manifest](tests/m11_facing_host_smoke_manifest.json) records the exact original/replay hashes, output-path-only changes, commands, before/after production hashes and result/log inventory.

- **Host contract, 29/29:** [replay harness](tests/m11_facing_host_contract_smoke.gd), [results](tests/m11_facing_host_contract_smoke_results.json), [engine log](tests/m11_facing_host_contract_smoke.log). This uses a minimal actor registration double with real Godot physics to isolate the provider. It covers default-off/missing attestations, identity echo, awareness and actual visibility, eligibility/prop exclusions, stale/invalid requests, mirrored/closed preview boundaries, a real 2 px terrain occluder and its removal, eligibility without a damage receiver, queued/freed candidates, coordinate-free diagnostics and replacement-safe enable/detach.
- **Production-player smoke, 5/5:** [replay harness](tests/m11_facing_host_player_smoke.gd), [results](tests/m11_facing_host_player_smoke_results.json), [engine log](tests/m11_facing_host_player_smoke.log). This instantiates the production player and existing ChainTarget. It checks default-off preservation, one neutral fresh-entry query and turn, an ordinary real strike contact, hidden/unperceived rejection and manual-input query veto.

These are bounded component smoke checks, separate from the independent full M11 motor suite and historical regression acceptance described in the [motor contract](../MOTOR_CONTRACT.md). They do not replace its action-generation, reentrancy, timing and cross-rate coverage. No historical test was edited.
