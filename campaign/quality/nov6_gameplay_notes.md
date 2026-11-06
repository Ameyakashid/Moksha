# November 6 campaign gameplay regressions

Run from project root after the normal Godot import:

```sh
python3 campaign/quality/nov6_gameplay_checks.py
# GODOT_BIN=/path/to/godot is optional.
# --output must name a NEW directory; historical evidence is never overwritten.
```

The runner uses a fresh HOME/XDG directory for every fixture and rejects engine
errors even when Godot exits zero. It records source hashes and refuses a clean
acceptance claim if any source changes during the run. These checks supplement,
not replace, the normal aggregate quality gate and full campaign route tests.

## What changed

- A campaign-only input gate keeps held menu buttons and navigation from becoming
  jump/strike/guard/movement commands on resume, Continue, retry or district load.
  Both injected raw frames and the actual Godot InputMap event path are checked.
  Native keyboard logical keycodes now use the same command path as physical ones.
  Releasing jump during a menu still produces the ordinary short-jump cut when
  play resumes; expired device-release edges cannot prolong the jump.
- Losing window focus pauses live play, an opening that would automatically start
  play, and queued retries/elevator transitions. Focus gain does not auto-resume.
  Explicit resume rearms held gameplay controls. Interrupted district transitions
  roll back their provisional metric/upgrade receipts when retried or abandoned.
- Nearby active objectives are chosen by distance rather than layout-array order,
  with one shared prompt/interaction radius. Blocked housings cannot steal a nearby
  active objective. Completed-objective feedback is retained.
- Breaker contacts recheck prerequisites at the actual contact boundary, rather
  than trusting a cached previous-frame eligibility flag. The regression revokes
  a real route inside a real strike's phase-entry callback, then verifies genuine
  J contacts work again once power is restored.
- Vitality and agility pickups no longer replace an unchanged melee resource and
  cancel an in-flight strike. Force bonuses remain additive, shared resources stay
  immutable, capacity pickups do not heal, and retry reapplies from base resources.
- Invalid checkpoints explain why Continue is unavailable. Failed writes and
  encode rejection report actionable feedback without interrupting live play.
  Starting New preserves a byte-verified copy of an invalid checkpoint before
  replacing it; a mismatched backup fails closed. Save-error title text traverses
  the real HUD owner/View boundary in the fixture.

The original controller, contact validation, health component, demo, and layout
sources are not modified by these gameplay fixes. Camera and HUD integration
hooks use separate campaign-only adapters owned by their respective modules.

## Reproduction and limits

`nov6_gameplay_input.gd` and `nov6_gameplay_build.gd` accept
`--baseline-host=/absolute/path/to/campaign.gd` for comparison with an independent
copy of a historical script. `nov6_gameplay_objectives.gd` also accepts
`--baseline-contact=/absolute/path/to/breaker_contact.gd` to verify the original
contact-time dependency bug independently. Never overwrite production source to
reproduce a failure. At commit `20d164e`, the input test reproduced intro/menu/retry input
bleed and logical Escape failure, and the build test reproduced vitality/agility
pickups interrupting actual strikes. Test-only scene placements and menu-state
setup are explicitly fixtures, not evidence of traversing those authored routes.

The save fixture requires `MOKSHA_QUALITY_ISOLATED=1`, an owned XDG_DATA_HOME and
`--isolated-save-tests`. Its simulated write failure reserves the temporary save
path as a directory; it does not claim to simulate disk exhaustion, a power cut,
or filesystem durability. It restores any pre-existing checkpoint in its isolated
folder and removes only the backup files it created.
