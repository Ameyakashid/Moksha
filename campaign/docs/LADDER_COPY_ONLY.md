# Ladder footer copy only

Direct child of accepted 7be2c80; no unaccepted pose experiment or pose-dependent
fixture is included. Existing climb animation, physics, collision, input, saves
and sensory behavior remain unchanged.

Keyboard: `W/S climb. Hold W until standing on the ledge. A/D lets go. Space jumps off.`

Controller: `Up/down climb. Hold Up until standing on the ledge. Left/right lets go. A jumps off.`

This replaces ambiguous “reach top” while keeping explicit descent, release and
jump guidance. Actual font measurements at 9 px: 326 px keyboard / 358 px controller;
available widths 477 px / 452 px reserve 12 px before unchanged journal/pause prompts.
The existing real host -> typed HUD owner -> painter contract checks keyboard and
controller wording/fit while ordinary held-Up inputs climb from a clearly staged
Mill starting pose, reach supported exit and retire on an actual hit. Existing
seeded lifecycle tests also cover blind body-known presentation and modal clears.
See the accompanying receipt for executed results. No earned-route, hardware
controller, native visual acceptance or demonstrated human UX benefit is claimed.
