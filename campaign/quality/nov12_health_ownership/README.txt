Pre-activation health ownership: scoped assembly refactor

Production change
- demo/mission.gd's player assembly now calls _create_player_health(); its default
  implementation instantiates the SAME original HealthScene, still named Health
  and configured to60HP before entering the tree. The demo assembly file changed;
  its behavior is tested for preservation, not described as byte-identical.
- Campaign overrides only that hook to select BuildHealth and connect its existing
  depletion policy before DefeatResponse binds. The old post-activation Health
  destruction and four manual contact rebinds are removed.
- combat_pc/ and simulation/ have ZERO tracked-byte differences from c73159b.
  No original controller, damage algorithm, contact adapter or scene was edited.

Why this boundary
See campaign/docs/NEXT_OWNERSHIP_STEP.txt and its pinned shapez GameCore and
EntityManager sources. Services/components are selected before activation. Godot
already supplies node ownership and _ready; we did not copy an ECS implementation,
commercial code/assets or GPL code. This is not a whole actor/level factory rewrite.

Automated evidence
14/14 isolated stages passed, zero source drift, Godot4.6.3. Includes67 assembly
checks per60/120Hz: default demo health type/capacity, all contact/death consumers
pointing to one live authority, one damage subscriber, repeated actor retirement,
lens capacities/refill and Continue. Actual gravity causes one lethal debit/death.
Baseline at8b97202 and new code both produce the same observed callback sequence:
  campaign policy: state playing, defeat inactive
  defeat response callback: state dead, defeat active
An intentionally deferred campaign policy is detected by the ordering assertion.

Existing authentic-contact fixture additionally covers all32 districts, real retry/
Continue, autonomous melee, projectile sweep, J-launched rigid cargo and gravity.
Build/save/content fixtures remain included. Tests isolate HOME and XDG paths.

Native evidence (controlled QA, NOT natural campaign footage)
Real Linux OpenGL renderer, manually issued Enter/J/D/R/Escape/F10 through desktop
keyboard controls. Synthetic flat district, player x75, sentinel x108, enemy damage
set to12, intro skipped. No direct health subtraction, forced defeat or scripted
retry. Observed real attack/contact animation; HP60 to36 to24 to12 to0; one death
overlay; manual R retry followed by pause/resume restored60HP and a fresh actor.
Native death/retry images and original recording log are retained here. The24second
recording used MovieMaker fixed60FPS; it ran slower than real time. It is NOT a
performance benchmark and should not be presented as representative level play.

The original recording log retains a one-resource/ObjectDB shutdown warning.
Explicit host cleanup alone did not remove it in a short native capture follow-up;
the cause is NOT established. A final bounded native run with image capture also
skipped still reports it; the corresponding headless run is clean. The retained
fixture supports --cleanup-only (no images) and --output=PATH. This remains an
unresolved native-environment/harness lifecycle limitation, not a proven production
regression or a clean-shutdown claim. Investigation stopped at the bounded check;
no production behavior was changed to hide it.

Reproduce headless: python campaign/quality/nov12_domain_checks.py --output NEW_DIR
Native: run native_fixture.gd with a native renderer and an isolated user directory;
Enter starts the controlled encounter, J attacks, let actual enemy hits cause death,
R retries, Escape pauses/resumes, F10 ends. This is QA setup, not shipped content.

Limits: not Windows verification, not a full manual campaign, not a complete
session/level ownership migration. Live progression and transitions remain in the
campaign facade. Keep the remaining blueprint phases separately gated/reversible.
