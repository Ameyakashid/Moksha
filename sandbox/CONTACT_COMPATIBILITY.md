# Sandbox actor/contact composition correction

The first thin wrappers inherited the shared actor's generic contact defaults
(body layer 32, body/terrain mask 1). That omitted cargo layer 8 from the actor's
own movement sweeps. Real pre-fix tests confirmed that both actor wrappers missed
cargo in `test_move` and landed on the floor instead of standing on an unfrozen
crate. The cargo's own rigid solver seeing actors was not sufficient.

The corrected wrappers explicitly assign existing production resources to their
inherited `ContactConfig` child:

| Wrapper | Existing resource | Body layer | Body / terrain mask |
|---|---|---:|---:|
| Player | `demo/resources/player_contact.tres` | 2 | 9 |
| NPC | `demo/resources/sentinel_contact.tres` | 32 | 9 |

Both now query world 1 + cargo 8 and retain the production material-contact
profile. Intentional actor-body pass-through remains: neither mask includes
actor layers 2 or 32. Role-specific melee target/hurtbox masks also come from
these unchanged production resources. Shared actor core, controller, AI and
physics rules are unchanged; this is composition compatibility, not new mechanics.

`tests/cargo_contact_regression.gd` uses actual horizontal `test_move` collision
results and an actual gravity landing onto a freely simulated crate for each
role. NPC intent is disabled only in this labelled support fixture so locomotion
does not walk off the crate. Pre-fix evidence is retained separately. Final
60/120 Hz reports include masks, actual collider identity, support identity and
measured actor/cargo heights. Existing bench and key-navigation tests are rerun
against the corrected scenes.
