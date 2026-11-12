# One compact pull-up presentation experiment

Unaccepted experiment based on independent copy-only 5ff9d96. It does not include
c4's rejected upright/loose-arm pose change. The native reviewer found that simply
removing early-ready overrides made the near-top pose no clearer. This is one
bounded alternative, not an accepted UX improvement or an invitation to endless
small adjustments. Keep the copy-only milestone independently.

## Original logic and authority

Only `climb_pose.gd` and a presentation label in `wireframe.gd` change production.
As feet approach the current attached ladder top, the existing torso blends into
a compact bent-knee/pull-up silhouette: a lower pelvis, forward lean and shorter
torso span. Existing root and foot targets are unchanged. Hands reach toward the
known current ladder's rail endpoints, bounded by shoulder reach. These reaches
are NOT marked planted: no platform contact or unreachable rung is invented.
Existing real rung contact constraints elsewhere are unchanged. Low-body/crouched
variants remain baseline. There is no collision query, remote terrain cue, sensory
permission change, or new motor/input/save authority.

The existing actual `climb_detached` event's top_exit reason labels only the
selected release presentation. Compact-to-ready blending additionally requires
a currently grounded body, within the existing 0.1 s release duration. Early A/D,
bottom/floor exit, damage, jump and invalid target never select this compact
completion. Hurt/roll/attack/jump owners supersede it immediately. No new timer or
input grace is introduced. The ordinary visual reset clears the existing events.

This uses the already-inspected ownership separation in official SuperTux
2975428aef94fdc3d6b6ec04cc94ec7a98b116eb, `src/object/player.cpp` climbing methods
and `src/trigger/climbable.cpp`: actor state/motion owns traversal, presentation
communicates it. https://github.com/SuperTux/supertux/tree/2975428aef94fdc3d6b6ec04cc94ec7a98b116eb
SuperTux is NOT claimed to contain this pose or exit algorithm. No code, animation,
constants or assets were copied. The compact animation is original MOKSHA work.

## Verification scope and native acceptance

`compact_contract.gd` inherits the actual host/owner/painter contract, advances
ordinary Up input through real physics from a staged Mill start, and compares
motor traces against 5ff at 60/120 Hz. `compact_transition_contract.gd` seeds actual
Visual events/action snapshots to check supported versus unsupported/non-top
release, local continuity and action interruption. One initial fixture used the
nonexistent pose label `roll`; its preserved failure was corrected to the actual
`roll_start` contract. Production behavior was not changed to accommodate it.
The original broad climb visual regression checks geometry, reach, contact drift,
low variants, sensor scales and interruptions. Native appearance remains separate.

`sample_compact.gd` run against baseline and candidate exports staged production
pose data at 24/9/2 px below top and supported-ready. It also exports `.transition`
files: actual Visual-event snapshots at 0/.025/.05/.10 s after supported top exit.
The native worker should display those through the unchanged production wardrobe
at actual game size and enlarged, with explicit staged labels. Inspect coherent
bent-knee effort, plausible hands, unchanged soles and compact-to-ready motion.
Discard if not materially clearer, if limbs float implausibly, or if release pops.
This is not earned gameplay footage, and passing tests does not prove human UX.
