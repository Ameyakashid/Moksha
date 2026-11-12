# MOKSHA architecture and ownership

This is an original Godot game, not a transplanted commercial-game framework.
The November 12 pass uses publicly documented engineering principles as references,
not third-party gameplay code or assets. Existing licensed dependencies keep their
own provenance in `REUSE.md`.

## References examined

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
| `campaign/logic/campaign.gd` | Campaign composition, transitions, live-object wiring, persistence I/O and applying domain results | Duplicated build arithmetic or campaign-envelope validation |
| `campaign/logic/build_rules.gd` | Pure build multipliers/capacity from lens, rewards and upgrades | Live actors, mutable shared resources, input, filesystem or scene tree |
| `campaign/logic/checkpoint_codec.gd` | Pure campaign envelope validation and schema version; delegates stable-ID progress decoding to the preserved demo codec | File reads/writes, UI messages, scene construction or applying progress to live objects |
| `campaign/input/` | Controller bindings, menu navigation and device prompts | Directly changing actor physics or saved-file format |
| `campaign/presentation/`, `campaign/views/` | Optional painting, camera and HUD presentation | Collision/gameplay authority |
| `campaign/quality/` | Explicitly scoped reproducible checks and labelled evidence | Shipping test assistance as ordinary player behavior |

## The November 12 boundary change

`campaign.gd` previously implemented build arithmetic and save-envelope validation
alongside its orchestration. Those two policies now live in independent
`RefCounted` scripts with static entry points:

- `BuildRules.evaluate(lens, rewards, upgrades)` returns a fresh dictionary with
  `speed`, `force` and `capacity`. It does not mutate its inputs. The campaign still
  resets the actor to its original base configuration, applies the result and owns
  the melee-resource replacement guard. Health-only pickups therefore retain the
  existing in-flight-strike behavior.
- `CampaignCheckpoint.decode(raw, sectors)` accepts the parsed envelope and its
  explicit layout dependency. It returns the same success/failure data as before.
  The campaign still owns quiet JSON parsing, atomic pending-file replacement,
  invalid-file preservation, warnings and Continue application. The campaign
  schema remains version **1** and the underlying stable-ID progress codec is
  unchanged. Existing checkpoints do not need migration.

The arithmetic operation order, default/accepted values, validation order and
error messages are preserved. This is a responsibility extraction, not a balance
change. No autoload, service locator, new engine, copied implementation or global
mutable domain state was introduced. The original actor/controller and simulation
files were not edited.

## Focused verification

From the project root, with Python 3 and Godot 4.6.3 available:

```sh
python3 campaign/quality/nov12_domain_checks.py
```

This imports the project, checks all ordered combinations of zero through four
upgrades for three lenses and eight reward subsets without instantiating a game
scene, checks schema acceptance/rejection, smoke-loads all 32 districts, and runs
existing live-build, save-error/backup and adversarial Continue fixtures at 60 and
120 Hz. The runner uses temporary HOME/XDG directories so filesystem fixtures
cannot target a player's saves. It rejects script errors, missing completion
markers, nonzero exits and source drift, and writes a fresh evidence directory.

These checks do not establish Windows hardware behavior, audible mix, full manual
playthrough quality, target frame rate or human level duration. Video/playthrough
receipts must identify their own source revision and control method.

## Boundaries still worth improving when a concrete need arises

The campaign host still inherits the original demo mission and adapts its HUD and
sonar. That is intentional compatibility, not a claim of perfect decoupling.
Future work should isolate one demonstrated problem at a time, retain regression
coverage and avoid changing lifecycle/save contracts during a broad rearrangement.
