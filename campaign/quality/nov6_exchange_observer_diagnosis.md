# Route observer and modal rearming

The frozen `f00bf23` campaign intentionally requires release before held controls
can act after a modal. This prevents journal navigation, menu choices and stale
movement from becoming unintended gameplay. The historical full-route observer
never released its continuously held `right` input after closing an archive.

## Reproduction

`nov6_gameplay_exchange_probe.gd` starts at the Exchange entrance with an explicit
lens and first Force upgrade fixture, then uses the unchanged production route
observer. Everything after that starting fixture is ordinary raw actor input and
E/K/Q commands. It records raw input, admitted actor input, the read-only blocked
control map, actual position/velocity and modal transitions.

Both retained-sight Neutral and Strength reproduced at 60 and 120 Hz:

- The cache/archive opens near x1540 while the observer holds `right=1`.
- Closing with E leaves the physical-control release boundary armed.
- Raw `right=1` continues forever, while `blocked.right=true`, admitted `x=0`,
  and horizontal velocity becomes zero. Repeated jump attempts do not release
  the horizontal control.
- An ordinary neutral `{}` frame clears the release requirement. Neutral and
  Strength both then finish Exchange using the same existing route planner.
- A separate Neutral run first observed three seconds of the stall, then issued
  one observed neutral physics frame and completed the district. There were no
  measured position, health, enemy, collision, objective or gate writes.

This is a route-observer incompatibility, not a stuck actor or impassable wall.
Production source was not changed to make the observer pass. Historical failed
full-route receipts are retained in their original round-2 evidence directory.

## Independent Agility Homes reproduction

The failed full Agility route had stopped at `(2960.11, 299.98)` in `l3_homes`,
while asking to move left toward the ladder. An isolated Agility fixture with the
same Force/Agility upgrade build reproduces that exact coordinate. Raw `left=1`
remains held after the archive, `blocked.left=true`, and admitted actor `x=0`.
The same shared neutral-frame helper then completes Homes in 28.73 simulated
seconds at 60 Hz with no death or measured actor/world/goal mutation. This is the
same bidirectional modal input boundary, not a residential collision defect.

## Updated full-route entry points

Use these wrappers in a NEW isolated evidence/project copy. They preserve the
historical base route and its Strength/120-Hz sonar navigation specializations:

- `res://campaign/quality/nov6_full_campaign_route.gd`
- `res://campaign/quality/nov6_full_campaign_strength_route.gd`
- `res://campaign/quality/nov6_full_campaign_route_120_sonar.gd`

All original `--hz`, `--lens`, `--sacrifice` and `--district-timeout` arguments are
inherited. `nov6_modal_route_input.gd` sends only neutral raw controls after a
modal returns to play/transition and waits for an observed physics frame. The
normal loop may maintain that neutral frame until its next decision. Each
occurrence is recorded as `observer_modal_controls_released`, including the old
raw command and actual number of observed neutral physics frames.

The original full-route reporter still writes its normal filenames, so run in a
fresh copy to avoid overwriting old results. Its source-hash inventory includes
the wrappers and helper. The events explicitly identify the observer revision.

The probe accepts `--district=l2_exchange|l3_homes`, `--lens=neutral|strength|agility`,
`--hz=60|120`, an absolute `--output` path, and either `--release-after-modal` or
`--rescue-after-stall`. Omitting both reproduces and stops after three seconds of
suppressed held horizontal input. Starting build is explicitly Force for Exchange
and Force/Agility for Homes. `--seconds` bounds each probe.
It is isolated-district evidence, not a substitute for new full campaign runs.


## Reproducible diagnostic acceptance

Run `python3 campaign/quality/nov6_modal_observer_checks.py --output /new/evidence/path`.
The output directory must not already exist. The runner uses separate writable
user directories, rejects engine errors, checks completion markers and selected
source hashes, and retains each raw report and engine log. Its thirteen cases
cover stale and released controls for Neutral/Strength Exchange and Agility Homes
at both 60 and 120 Hz, plus a deliberate stall-then-release rescue. All thirteen
passed on the frozen November 6 runtime without production changes.

`nov6_modal_route_observer_test.gd -- --hz=60` and `--hz=120` each passed seven
real-dispatch integration assertions: journal boundary preserved, neutral input
observed, fresh movement admitted, normal playing commands unchanged, retained
sight choice, upgrade transition and per-modal evidence. These use explicit
menu/scene fixtures and do not claim full-route acceptance.


## Works Cargo Exchange: a separate observer wait defect

The modal-only f00 baseline's retained Neutral/60-Hz run later stopped in Works
Cargo Exchange. The intact carrier rested at `(3290.142, 226.176)`, with three
actual strikes, while the player waited at `(3214.519, 239.98)` and sent `{}`.
The old `freight_45_plan` assumed every carrier past `receiver.x - 80` would settle
in the receiver. Here it had stopped on the higher approach deck instead. The
receiver correctly required actual basin-floor contact, and no held input was
blocked. The failed full report is preserved verbatim in
`nov6_observer_evidence/cargo/f00_modal_only_full_neutral60_retained_failure.json`.

A trace-matched initial fixture reproduces the stationary wait at 60/120 Hz.
Setup-only actor/cargo positions and the observed hit count are explicit; zero
cargo rotation is an assumption because the original trace did not record it.
Real contacts settle before measurement. No objectives are forced complete.
This is not an exact save-state replay. The earlier full receipt proves that the
edge occurred in a genuine input-only campaign, independently of this fixture.

With `nov6_freight_route_input.gd`, the measured actor re-approaches and gives ONE
ordinary J strike. The same intact cargo latches the actual receiver, and both
fixtures finish the district without death or measured state writes (32.53/40.46
simulated seconds at 60/120 Hz). The helper leaves moving, spinning, seating,
inside-basin and delivered cargo alone. It intervenes only after three seconds
of near-zero velocity/spin, still above and short of the receiver, when the old
planner would otherwise wait. It changes only the observer's input plan.

All three November 6 full-route wrappers now share this fifth observer file.
The historical base planners, original engine/controller and production campaign
were not edited for either observer correction. The exact shared helper passes
135/255 guard assertions at 60/120 Hz; the inherited modal contracts still pass
7 at each rate. Physical paired reports and logs are in
`nov6_observer_evidence/cargo/`, and the contracts in
`nov6_observer_evidence/contracts/`. Fresh final-revision full campaigns are still
required; these targeted fixtures do not substitute for them.
