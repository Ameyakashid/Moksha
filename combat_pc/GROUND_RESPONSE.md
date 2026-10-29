# Ground response: one review piece

The candidate improves the time between a directional decision and useful ground motion. It keeps the current speed cap, air control, jump shape and committed combat motion. Its poses communicate a new start, a brief skid and a turn without retaining an old intention.

## Try the comparison

Run `ground_response_review.tscn`. **1** selects the previous profile, **2** selects Agile, and **Q** supplies the same eight-second input sequence to each. The sequence uses actual physics and the ordinary player input API. It is labelled as a guided comparison; free control is available afterwards or by choosing a profile. **F** selects flat, sloped or moving ground. **R** resets that course. **Esc** pauses.

Movement is A/D, jump Space, roll Shift, attack J, shield K. The same optional Health, DefeatResponse and NoiseRelay remain attached. The noise counter confirms the existing source is active; this review adds no sensory feature. The viewport is silent in this cloud capture.

## What changes

| Setting | Previous | Candidate |
|---|---:|---:|
| Run cap | 218 px/s | 218 px/s |
| Ground acceleration | 3100 px/s² | 4800 px/s² |
| Neutral braking | 1850 px/s² | 2700 px/s² |
| Opposite-input acceleration | 3600 px/s² | 6200 px/s² |
| Motor turn-pose interval | 110 ms | 70 ms |
| View start / brake / turn | 140 / 160 / 160 ms | 75 / 100 / 85 ms |

The acceleration values only apply while grounded, standing, in ordinary locomotion, with no weapon or shield owner. Crouch, air, hurt, roll, charge, attacks and shield keep the previous response rates. The ordinary override becomes available again when the existing action graph actually returns to locomotion. It cannot bypass input or weapon permissions.

The optional visual profile also fixes three lifetime issues: a fresh opposite-facing start from rest no longer invents a momentum turn; neutral braking retires a turn; and crossing near zero velocity no longer rewinds a turn to phase zero. Body facing continues to follow admitted input immediately while momentum changes over a short interval. Strong original pose keys and collision/foot support remain unchanged.

## Reuse and removal

- On an instance of `player.tscn`, assign `resources/ground_response_agile.tres` to **Profile**
- On its **Visual** child, assign `resources/ground_presentation_agile.tres` to **Ground Presentation**
- To tune physical response independently, duplicate the movement resource and its **Ordinary Ground Response** subresource before editing shared values
- Remove **Ordinary Ground Response** or restore `movement_profile.tres` to restore the earlier motor rates
- Clear **Ground Presentation** to restore the earlier presentation behavior independently

The optional physical resource is validated before use; invalid values fall back to the base movement profile. Presentation durations have an independent finite positive fallback. These are authoring resources, not mutable per-player timers. Runtime state stays on the player/view. The original `player.tscn` defaults and earlier scenes retain their previous profile; the new review explicitly opts in for comparison.

## Evidence and limits

At 120 Hz, measured full-speed startup falls from 75 to 50 ms, stopping from 125 to 83 ms and 11.94 to 7.91 pixels, and full reversal from 133 to 83 ms. At 60 Hz, startup is 83 to 50 ms and stopping is 133 to 83 ms / 11.04 to 7.03 pixels. Discrete integration explains the small rate differences; left and right agree. The full measured table is in `tests/ground_response_report.md`.

The numerical settings are original MOKSHA tuning. The [source evidence](reference/M18_GROUND_RESPONSE_EVIDENCE.md) identifies which Dead Cells bodies remain missing and which developer statements support responsive control and deliberate animation timing. It does not establish exact Dead Cells acceleration or frame data. Faster top speed, a different air-control curve and new agility actions are separate decisions for later review.
