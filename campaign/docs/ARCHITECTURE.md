# MOKSHA architecture and ownership

This is an original Godot game, not a transplanted commercial-game framework.
The November 12 pass uses publicly documented engineering principles as references,
not third-party gameplay code or assets. Existing licensed dependencies keep their
own provenance in `REUSE.md`.

## References examined

- The released modern factory game shapez is the primary inspected-source
  reference for these ownership changes. Its pinned
  [`GameCore`](https://github.com/tobspr-games/shapez.io/blob/8a79de5255fb6756f3a1d26579b1e9bc36e0c811/src/js/game/core.js)
  composes services and distinguishes initialization from post-load publication;
  [`EntityManager`](https://github.com/tobspr-games/shapez.io/blob/8a79de5255fb6756f3a1d26579b1e9bc36e0c811/src/js/game/entity_manager.js)
  indexes existing components before publishing entity registration. These inform
  construction/activation ownership, not a copied ECS or gameplay implementation.
  Official REA was run on a public source checkout, not a shipped binary. Its
  focused static analysis covered 16 files, not the complete game architecture.
  shapez is not a side-scroller or a substitute claim of recovered Dead Cells
  source. See [the reference foundation](REFERENCE_FOUNDATION.txt) for the exact
  evidence scope and separately attributed Dead Cells observations. No GPL code
  or assets were imported.

- Godot's [scene organization guidance](https://github.com/godotengine/godot-docs/blob/c5b3485cb4b6e14ae3d8a45271bcddac7caad66a/tutorials/best_practices/scene_organization.rst):
  small responsibilities, explicit dependencies provided by an owner, reusable
  scenes, and lifetimes that follow the scene-tree owner.
- The Godot 4 [TPS demo](https://github.com/godotengine/tps-demo/tree/a82f15448e9b015440d3bbdf5e10801b260c4e9f):
  feature-local `player`, `door`, `enemies`, and `menu` folders;
  [`main/main.gd`](https://github.com/godotengine/tps-demo/blob/a82f15448e9b015440d3bbdf5e10801b260c4e9f/main/main.gd)
  owns scene transitions, while
  [`player/player_input.gd`](https://github.com/godotengine/tps-demo/blob/a82f15448e9b015440d3bbdf5e10801b260c4e9f/player/player_input.gd)
  separates input interpretation from the main scene. This is a demo reference,
  not evidence that MOKSHA has the production scope of a commercial title.
  Its code and art have different licenses. None was imported for this pass.

The lesson is to isolate responsibilities with concrete contracts, not reproduce
another game's directory names or add a general framework before it is needed.

## Where a change belongs

| Owner | Responsibility | Must not own |
|---|---|---|
| `combat_pc/`, `simulation/`, original physical modules | Original movement, contact, combat and simulation behavior | Campaign story, save-envelope schema or menu decisions |
| `campaign/layouts/` | Authored district definitions and placements | Input handling or persistent state mutation |
| `campaign/logic/campaign_data.gd`, `campaign/content/campaign_catalog.gd` | Load authored levels; validate and detach the complete catalog before startup | Live actors, partial campaign startup or saved-state mutation |
| `demo/assembly/player_assembler.gd` | Configure a detached actor and attach its selected health/contact components | Tree activation, host state, bus binding, spawn/reset or progression |
| `demo/mission.gd`, `campaign/logic/campaign.gd` | Compatibility facade, session/progression state, district composition, activation, transitions, save timing, UI errors and applying decoded state/domain results | Duplicated build arithmetic, campaign-envelope validation or campaign checkpoint disk operations |
| `campaign/state/run_snapshot.gd` | Capture detached persisted campaign values | Owning the live run, filesystem or applying progress |
| `campaign/save/checkpoint_store.gd` | Read checkpoint bytes, invoke parsing/validation, pending-file commit and verified invalid-file preservation | UI messages, live-state mutation or actor construction |
| `campaign/logic/build_rules.gd` | Pure build multipliers/capacity from lens, rewards and upgrades | Live actors, mutable shared resources, input, filesystem or scene tree |
| `campaign/logic/checkpoint_codec.gd` | Pure campaign envelope validation and schema version; delegates stable-ID progress decoding to the preserved demo codec | File reads/writes, UI messages, scene construction or applying progress to live objects |
| `campaign/input/` | Controller bindings, menu navigation and device prompts | Directly changing actor physics or saved-file format |
| `campaign/presentation/`, `campaign/views/` | Optional painting, camera and HUD presentation | Collision/gameplay authority |
| `campaign/quality/` | Explicitly scoped reproducible checks and labelled evidence | Shipping test assistance as ordinary player behavior |

## Current construction, data and save boundaries

- `CampaignData.load_catalog()` loads the five level definitions;
  `CampaignCatalog.validate()` rejects missing definitions, wrong shipped district
  counts, duplicate stable IDs, unknown objective requirements and cyclic/self
  dependencies. Valid definitions are detached before use. Failure displays a
  startup error before campaign actors or save reads begin. The current 32-district
  count is a shipped-content manifest, not an engine limit; intentional expansion
  must follow [CONTENT_MANIFEST.txt](CONTENT_MANIFEST.txt).
- `BuildRules.evaluate(lens, rewards, upgrades)` returns fresh speed, force and
  capacity values. The host still restores actor base configuration, applies
  those values and owns the melee-resource replacement guard. Health-only pickups
  retain the existing in-flight-strike behavior.
- `RunSnapshot.capture()` detaches persisted lens, upgrades, rewards and level
  receipts/timing. It is not a new authoritative session object: the host still
  owns live run state and assembles the version/progress envelope.
- `CampaignCheckpoint.decode(raw, sectors)` validates the campaign envelope and
  delegates stable-ID progress decoding to the preserved demo codec. It returns
  detached validated data before the host applies any Continue state.
- `CheckpointStore.read()` owns campaign checkpoint reads and invokes the existing
  quiet parser plus codec. `commit()` writes, flushes and renames a pending file;
  `preserve_invalid()` retains and verifies invalid bytes before replacement.
  These are the existing disk semantics, not a new crash-durability guarantee or
  transactional live-state restore. The host decides when to save, presents errors,
  and applies Continue results. Current campaign envelopes are version **3**, including explicit sensory state.
  Valid v1/v2 checkpoints remain readable through the current codec; migration
  preserves the old bytes before a committed replacement. Older builds cannot
  read v3: keep the matching backup rather than hand-editing or downgrading saves. Other host I/O, such as results
  export, is not claimed to have moved into this checkpoint-only store.
- The host instantiates and assigns the player. `PlayerAssembler.configure_actor()`
  configures profiles and the optional visual while detached. The host then
  selects Health or campaign BuildHealth through `_create_player_health()`;
  campaign depletion policy connects before DefeatResponse's readiness binding.
  `PlayerAssembler.attach_components()` preserves the exact child topology/order.
  Only the host calls `room.add_child(player)`, then binds the noise bus, resets
  spawn/facing and connects its defeat listener. No live health replacement is
  needed. See [PLAYER_ASSEMBLY.txt](PLAYER_ASSEMBLY.txt) for the two-phase contract.

Godot supplies scene instantiation, resource loading, parent-owned node lifetime
and readiness/tree activation. The game layer supplies component selection and
session policy. Child readiness is not simply construction order: some contact
adapters await the actor's ready signal. The assembler does not replace those
bindings, drive simulation or introduce a service locator. Original actor/controller
and simulation files remain unchanged; the demo mission assembly facade has a
behavior-preserving delegation change, not byte-for-byte preservation.

## Focused verification

From the project root, with Python 3 and Godot 4.6.3 available:

```sh
python3 campaign/quality/nov12_domain_checks.py
```

The 16-stage runner imports the project, checks detached player assembly and
host-observable activation/topology contracts, validates catalog failure cases,
checks all ordered combinations of zero through four
upgrades for three lenses and eight reward subsets without instantiating a game
scene, checks schema acceptance/rejection, smoke-loads all 32 districts, and runs
existing health-assembly, real-contact damage, live-build, save-error/backup and
adversarial Continue fixtures at 60 and 120 Hz. The runner uses temporary HOME/XDG directories so filesystem fixtures
cannot target a player's saves. It rejects script errors, missing completion
markers, nonzero exits and source drift, and writes a fresh evidence directory.

These checks do not establish Windows hardware behavior, audible mix, full manual
playthrough quality, target frame rate or human level duration. Video/playthrough
receipts must identify their own source revision and control method.

## Boundaries still worth improving when a concrete need arises

The campaign host still inherits the original demo mission and adapts its HUD and
sonar. It still owns run progression, live state, district/enemy/objective assembly,
transition policy and application of restored progress. The detached snapshot is
not a fully migrated run/session model, and the player helper is not a district
factory. That is intentional compatibility, not a claim of perfect decoupling or
complete framework recovery from another game.
Future work should isolate one demonstrated problem at a time, retain regression
coverage and avoid changing lifecycle/save contracts during a broad rearrangement.
